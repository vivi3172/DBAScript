USE [iSettle2]
GO

/****** Object:  StoredProcedure [dbo].[sp_MonthlyBackupAndClean_v3]    Script Date: 2026/2/9 上午 12:23:35 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO






-- =============================================
-- 名稱：sp_MonthlyBackupAndClean_v3
-- 功能：依月份批次備份主資料表至歷史庫，並刪除原始資料
-- 說明：
--   1. 直接使用 DELETE TOP + OUTPUT 搬移與刪除資料。
--   2. 每批獨立 Transaction，出錯僅回滾該批。

--防呆 → 計算月份  → 批次搬移/刪除 → 等待 → 下一月
--將TRANSATION 包在迴圈內 ，某批次出錯只ROLLBACK該批次，不影響其他已完成批次
-- =============================================
CREATE   PROCEDURE [dbo].[sp_MonthlyBackupAndClean_v3]
(
	@HasDataChanged BIT OUTPUT,  -- 是否有資料異動 (1=有, 0=無)

    @DBName NVARCHAR(128),             -- 主資料來源 DB（例：iSettle2、ShopA_DB）
    @SchemaName NVARCHAR(128),         -- 主資料來源 Schema（例：dbo、shop01）
    @BaseTableName NVARCHAR(128),      -- 主資料表名稱（例：IM_ISET_CONSUMPD_W）
    @HistoryDBName NVARCHAR(128),      -- 備份目標 DB（例：HistoryDB、hticcard）
    @HistorySchemaName NVARCHAR(128),  -- 備份目標 Schema（例：dbo、backup01）
    @WhereCondition NVARCHAR(MAX),     -- 動態條件
    @KeepMonths INT = 1,               -- 要保留的月數（預設1表示保留本月，例：保留10月則清9月）
	@CleanMonths INT = 1,              -- 要清除的月數（例：3 表示清除 3 個月前以前）
    @TopSize INT = 1000,               -- 每批搬移筆數
    @Rounds INT = 4,                   -- 幾輪（例：4 表示最多執行 4 輪 × 每輪 BatchSize 筆）
    @WaitSeconds INT = 5,             -- 每批之間等待秒數
    @DoBackup BIT = 1			　　   -- 是否進行備份 (1=備份, 0=只清檔)
)
AS
BEGIN
    SET NOCOUNT ON;  -- 停止回傳每個 SQL 執行後的影響筆數訊息，減少輸出雜訊

	SET @HasDataChanged = 0;  -- 預設：無異動
    ------------------------------------------------------------
    -- 防呆：避免誤刪當月資料
    ------------------------------------------------------------
    IF @KeepMonths < 1
    BEGIN
        PRINT '不允許設定 @KeepMonths = 0（防止清除當月資料）';
        RETURN;
    END;

    -- 宣告變數
    DECLARE 
        @TargetMonth CHAR(6),			-- 目標月份 (yyyyMM)
        @HistoryTable NVARCHAR(300),	-- 歷史資料庫備份表
        @SQL NVARCHAR(MAX),				-- 動態 SQL 暫存變數
        @MonthsToClean INT,				-- 要清除的月數（依 @KeepMonths 計算）
        @BatchCount INT,				-- 每月批次次數控制
        @SourceTableName NVARCHAR(300);	-- 組合後的完整資料表名稱（含DB與Schema）

    -- ★新增：WHERE 條件樣板與實際執行條件
    DECLARE 
        @WhereTemplate NVARCHAR(MAX),   -- 原始條件樣板（含 {YYYYMM}、{MM}）
        @WhereRuntime  NVARCHAR(MAX),   -- 每個月份實際執行用條件
        @MM CHAR(2);                    -- 月份兩碼（01~12）


    PRINT '===== 【開始執行多月份備份程序】 =====';
    PRINT '主資料表：' + @BaseTableName + '，保留月數：' + CAST(@KeepMonths AS NVARCHAR(10)) +
          '，清除月數：' + CAST(@CleanMonths AS NVARCHAR(10));

    -- 組合完整來源表名 [DB].[Schema].[Table]
    SET @SourceTableName = QUOTENAME(@DBName) + '.' + QUOTENAME(@SchemaName) + '.' + QUOTENAME(@BaseTableName);
    PRINT '來源完整表名：' + @SourceTableName;

    BEGIN TRY
		------------------------------------------------------------------------
        -- Step 1：先計算要清除幾個月的資料
        ------------------------------------------------------------------------
        -- 例如：現在是 2026/1，@KeepMonths = 1，代表保留 1 月，清除 12 月以前的月份，@CleanMonths = 1，代表清除1個月
        -- 這裡我們假設要清除所有「保留月數以外」的月份
        SET @MonthsToClean = @KeepMonths; -- 清除範圍會從 (KeepMonths + 1) 月開始往前推

        ------------------------------------------------------------------------
        -- Step 2：開始清除舊月份（從 @KeepMonths + 1 月往前推）
        ------------------------------------------------------------------------
		PRINT '開始清除舊月份，最多往前 ' + CAST(@CleanMonths AS NVARCHAR(10)) + ' 個月...';

        -- 例如：現在是 2026/1，@KeepMonths = 1，代表保留 1 月，清除 12 月以前的月份，@CleanMonths = 1，代表清除1個月
        WHILE @MonthsToClean < (@KeepMonths + @CleanMonths)-- 2 < 保留2+清除1成立進來
        
        BEGIN
			-- 計算目前要處理的目標月份
            SET @TargetMonth = CONVERT(CHAR(6), DATEADD(MONTH, -(@MonthsToClean), GETDATE()), 112);
            PRINT '====== 備份月份：' + @TargetMonth + ' ======';


            -- ★新增：只在第一次進來時保留 WHERE 條件樣板
            IF @MonthsToClean = @KeepMonths
            BEGIN
                SET @WhereTemplate = @WhereCondition;
            END

            --------------------------------------------------------------------
            --  組合歷史資料庫備份表名稱（含 DB 與 Schema）
            --------------------------------------------------------------------
            SET @HistoryTable = 
                QUOTENAME(@HistoryDBName) + '.' + QUOTENAME(@HistorySchemaName) + '.' +
                QUOTENAME(@BaseTableName + '_' + @TargetMonth);

            --------------------------------------------------------------------
			-- Step 3：僅檢查備份表是否存在，表存在正常跑
			--------------------------------------------------------------------
			IF @DoBackup = 1
			BEGIN
				IF OBJECT_ID(@HistoryTable) IS NULL
				BEGIN
					DECLARE @ErrorMsg NVARCHAR(4000);
					SET @ErrorMsg = N'歷史備份表不存在，請先建立：' + @HistoryTable;
				
					THROW 50001, @ErrorMsg, 1;
				END
			END

            --------------------------------------------------------
            -- Step 4：批次執行 DELETE OUTPUT
            --------------------------------------------------------
            PRINT '開始批次搬移 & 刪除資料 (' + @TargetMonth + ') ...';
            
			-- 初始化批次次數（計算輪迴用）
			SET @BatchCount = 0;
            WHILE @BatchCount < @Rounds
            BEGIN
                BEGIN TRY
                    BEGIN TRANSACTION;		-- 每批獨立 Transaction

                    -- 防呆：WHERE 條件必須存在
					IF @WhereTemplate IS NULL OR LEN(LTRIM(RTRIM(@WhereTemplate))) = 0
					BEGIN
					    PRINT '未提供 @WhereCondition / @WhereTemplate，系統已停止以避免全表搬移。';
					    ROLLBACK TRANSACTION;
					    BREAK;
					END;



					-- 使用 REPLACE() 將 WHERE 條件樣板中的參數替換成實際月份
					-- {YYYYMM}：例如 202602
					-- {MM}     ：例如 02（用於檔名）
					SET @MM = RIGHT(@TargetMonth, 2);

					SET @WhereRuntime = @WhereTemplate;
					SET @WhereRuntime = REPLACE(@WhereRuntime, '{YYYYMM}', @TargetMonth);
					SET @WhereRuntime = REPLACE(@WhereRuntime, '{MM}', @MM);


                    -- 若為備份模式
                    IF @DoBackup = 1
                    BEGIN
                        PRINT '[備份模式] DELETE TOP(' + CAST(@TopSize AS NVARCHAR(10)) + 
                              ') 並輸出至歷史表 (' + @HistoryTable + ') ...';

                        SET @SQL = N'
                            DELETE TOP (' + CAST(@TopSize AS NVARCHAR(10)) + N') sre
                            OUTPUT deleted.* INTO ' + @HistoryTable + N'
                            FROM ' + @SourceTableName + N' AS sre
							WHERE ' + @WhereRuntime + N';

                        ';
                    END
                    ELSE
                    BEGIN
                        PRINT '[清檔模式] DELETE TOP(' + CAST(@TopSize AS NVARCHAR(10)) + ') ...';
                        SET @SQL = N'
                            DELETE TOP (' + CAST(@TopSize AS NVARCHAR(10)) + N') sre
                            FROM ' + @SourceTableName + N' AS sre
                            WHERE ' + @WhereRuntime + N';
                        ';
                    END;

                    EXEC(@SQL);

                    IF @@ROWCOUNT = 0
                    BEGIN
                        PRINT '無符合條件資料，結束該月份搬移。';
                        ROLLBACK TRANSACTION;
                        BREAK;
                    END;

                    COMMIT TRANSACTION;	-- 每批成功提交

					SET @HasDataChanged = 1;  -- [Output] 標記為有異動

                    SET @BatchCount += 1;	-- 每輪完成後 + 1
                    PRINT '已完成第 ' + CAST(@BatchCount AS NVARCHAR(10)) + 
                          ' 批（每批 ' + CAST(@TopSize AS NVARCHAR(10)) + ' 筆）';

                END TRY
                BEGIN CATCH
					DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();
					DECLARE @ErrLine INT = ERROR_LINE();
					DECLARE @ErrProc NVARCHAR(200) = ERROR_PROCEDURE();

					PRINT '批次錯誤：' + @ErrMsg;
					PRINT '發生於 ' + ISNULL(@ErrProc, '未知程序') + ' 第 ' + CAST(@ErrLine AS NVARCHAR(10)) + ' 行';
    
					IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
                    PRINT '已回滾此批次。';
					THROW;
                END CATCH;

                -- 等待間隔
                IF @WaitSeconds > 0
                BEGIN
					PRINT '進入等待間隔'+CAST(@WaitSeconds AS NVARCHAR(10));
                    DECLARE @DelayTime CHAR(8) = '00:00:' + RIGHT('00' + CAST(@WaitSeconds AS VARCHAR(2)), 2);
                    WAITFOR DELAY @DelayTime;
					PRINT '等待時間結束，繼續下輪作業';
                END;
            END;

            PRINT '完成月份：' + @TargetMonth + ' 備份搬移完成';
			-- 繼續往前一個月
            SET @MonthsToClean += 1;
        END;

        PRINT '===== 【多月份備份程序完成】 =====';
    END TRY
    BEGIN CATCH
		--------------------------------------------------------------------
		-- 錯誤處理：發生例外時回滾交易並輸出錯誤訊息
		--------------------------------------------------------------------
        PRINT '發生錯誤：' + ERROR_MESSAGE();
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        PRINT '多月份備份程序已回滾。';
		THROW;
    END CATCH;
END;
GO


