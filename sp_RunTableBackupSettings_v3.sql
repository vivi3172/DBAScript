USE [iSettle2]
GO

/****** Object:  StoredProcedure [dbo].[sp_RunTableBackupSettings_v3]    Script Date: 2026/2/9 上午 12:25:33 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO




/***********************************************
 名稱：sp_RunTableBackupSettings_v3
 功能：
	   依序讀取 TableBackupSetting 設定表中「啟用」的備份設定，
       並逐筆呼叫 sp_MonthlyBackupAndClean
       進行實際的批次備份與清檔作業。

 流程：
   1️.宣告變數
   2️.使用 CURSOR (游標) 讀取設定表中每一筆
   3️.逐筆呼叫備份主 SP（sp_MonthlyBackupAndClean）
   4️.執行完畢後關閉並釋放游標
************************************************/
CREATE PROCEDURE [dbo].[sp_RunTableBackupSettings_v3]
(
	@ExecGroup NVARCHAR(50) = NULL  -- 可指定要執行的分組
)
AS
BEGIN
    ---------------------------------------------------------------
    -- Step 0：初始化
    ---------------------------------------------------------------
    SET NOCOUNT ON; -- 停止輸出每次 SQL 操作的影響筆數，避免訊息過多

	DECLARE @HasDataChanged BIT;
	---------------------------------------------------------------
    -- Step 1：宣告變數，用來接收游標每筆的欄位值
    ---------------------------------------------------------------
    DECLARE 
        @ID INT,					
        @DBName NVARCHAR(128),              -- 主資料來源 DB 名稱
        @SchemaName NVARCHAR(128),          -- 主資料來源 Schema 名稱
        @BaseTableName NVARCHAR(128),       -- 主資料表名稱（來源）
        @HistoryDBName NVARCHAR(128),       -- 備份目的 DB 名稱
        @HistorySchemaName NVARCHAR(128),   -- 備份目的 Schema 名稱
        @WhereCondition NVARCHAR(MAX),      -- WHERE 條件，用於過濾要清除/備份的資料
        @KeepMonths INT,                    -- 要保留的月份數
		@CleanMonths INT,					-- 要清除的月數 (例 : 3 表示清除 3 個月前)
        @TopSize INT,                       -- 每批搬移筆數（例：1000）
        @Rounds INT,                        -- 要執行的批次輪數（例：4 表示 4 × TopSize）
        @WaitSeconds INT,                   -- 每批間的延遲秒數（避免壓力過高）
        @DoBackup BIT                       -- 是否執行備份 (1=備份, 0=僅清檔)

    ---------------------------------------------------------------
    -- Step 2：建立游標（Cursor）
    -- 作用：逐筆取出 TableBackupSetting 表中啟用的備份設定
    ---------------------------------------------------------------
    DECLARE BackupCursor CURSOR FOR
       SELECT 
			ID,DBName, SchemaName, BaseTableName,
			HistoryDBName, HistorySchemaName,
			WhereCondition, KeepMonths, CleanMonths, 
			TopSize, Rounds, WaitSeconds, DoBackup
		FROM dbo.TableBackupSetting AS t
		WHERE IsError = 0 and (@ExecGroup IS NULL OR t.ExecGroup = @ExecGroup)
		ORDER BY t.ExecGroup, t.ExecOrder;

    ---------------------------------------------------------------
    -- Step 3：開啟游標，開始逐筆讀取設定
    ---------------------------------------------------------------
    OPEN BackupCursor;

    -- 第一次讀取游標中的一筆資料
    FETCH NEXT FROM BackupCursor INTO
        @ID, @DBName, @SchemaName, @BaseTableName,
        @HistoryDBName, @HistorySchemaName,
        @WhereCondition, @KeepMonths, @CleanMonths, 
		@TopSize, @Rounds, @WaitSeconds, @DoBackup;

    ---------------------------------------------------------------
    -- Step 4：開始逐筆執行
    -- @@FETCH_STATUS = 0 表示目前還有資料
    ---------------------------------------------------------------
    WHILE @@FETCH_STATUS = 0
    BEGIN
        PRINT '開始執行備份任務' 
              + @DBName + '.' + @SchemaName + '.' + @BaseTableName;

       BEGIN TRY
            -------------------------------------------------------
            -- 呼叫實際執行的主 SP
            -------------------------------------------------------
            EXEC dbo.sp_MonthlyBackupAndClean_v3
                @DBName = @DBName,
                @SchemaName = @SchemaName,
                @BaseTableName = @BaseTableName,
                @HistoryDBName = @HistoryDBName,
                @HistorySchemaName = @HistorySchemaName,
                @WhereCondition = @WhereCondition,
                @KeepMonths = @KeepMonths,
				@CleanMonths = @CleanMonths,
                @TopSize = @TopSize,
                @Rounds = @Rounds,
                @WaitSeconds = @WaitSeconds,
                @DoBackup = @DoBackup,
				@HasDataChanged = @HasDataChanged OUTPUT;  -- OUTPUT 接收寫法
			
			-- 如果該資料表, 有資料需執行備份/清檔作業, 則更新該表最後異動時間
			IF (@HasDataChanged = 1)
			BEGIN
				UPDATE dbo.TableBackupSetting SET UpdatedAt = GETDATE()
				WHERE ID = @ID;
			END
			
        END TRY
        BEGIN CATCH
			DECLARE 
				@ErrMsg NVARCHAR(4000),
				@ErrSeverity INT,
				@ErrState INT;

			SELECT 
				@ErrMsg = ERROR_MESSAGE(),
				@ErrSeverity = ERROR_SEVERITY(),
				@ErrState = ERROR_STATE();

			PRINT '錯誤：' + @ErrMsg;

			UPDATE dbo.TableBackupSetting SET IsError = 1, ErrorUpdatedAt = GETDATE() , ErrorMessage = '錯誤：' + @ErrMsg
			WHERE ID = @ID;

			THROW 51000, @ErrMsg, 1;
		END CATCH;
           

        -----------------------------------------------------------
        -- 讀取下一筆設定，直到游標結束
        -----------------------------------------------------------
        FETCH NEXT FROM BackupCursor INTO
            @ID, @DBName, @SchemaName, @BaseTableName,
            @HistoryDBName, @HistorySchemaName,
            @WhereCondition, @KeepMonths, @CleanMonths, 
			@TopSize, @Rounds, @WaitSeconds, @DoBackup;
    END

    ---------------------------------------------------------------
    -- Step 5：關閉與釋放游標
    ---------------------------------------------------------------
    CLOSE BackupCursor;        -- 關閉游標
    DEALLOCATE BackupCursor;   -- 釋放資源

    ---------------------------------------------------------------
    -- Step 6：結束訊息
    ---------------------------------------------------------------
    PRINT '所有設定表任務執行完成。';
END

GO


