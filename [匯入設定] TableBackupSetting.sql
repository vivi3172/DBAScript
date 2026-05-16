USE [iSettle2]
GO
SET IDENTITY_INSERT [dbo].[TableBackupSetting] ON 
GO
INSERT [dbo].[TableBackupSetting] ([ID], [DBName], [SchemaName], [BaseTableName], [HistoryDBName], [HistorySchemaName], [WhereCondition], [KeepMonths], [CleanMonths], [TopSize], [Rounds], [WaitSeconds], [DoBackup], [ExecGroup], [ExecOrder], [CreatedAt], [UpdatedAt], [CreatedBy], [IsError], [ErrorMessage], [ErrorUpdatedAt]) VALUES (1, N'iSettle2', N'dbo', N'IM_ISET_CONSUMPD_W', N'hticcard', N'dbo', N'TAR_FILE_NAME like ''ICCSales2BP.{YYYYMM}%''', 3, 1, 2, 2, 2, 1, N'Group1', 1, CAST(N'2025-11-08T19:24:38.057' AS DateTime), CAST(N'2026-02-01T18:07:03.130' AS DateTime), N'Mason', 0, N'', CAST(N'2026-02-01T23:51:32.560' AS DateTime))
GO
INSERT [dbo].[TableBackupSetting] ([ID], [DBName], [SchemaName], [BaseTableName], [HistoryDBName], [HistorySchemaName], [WhereCondition], [KeepMonths], [CleanMonths], [TopSize], [Rounds], [WaitSeconds], [DoBackup], [ExecGroup], [ExecOrder], [CreatedAt], [UpdatedAt], [CreatedBy], [IsError], [ErrorMessage], [ErrorUpdatedAt]) VALUES (2, N'iSettle2', N'dbo', N'IM_ISET_TXLOG_T', N'hticcard', N'dbo', N'ZIP_FILE_NAME LIKE ''TMLOG_{YYYYMM}%'' OR  ZIP_FILE_NAME LIKE ''TXLOG_{YYYYMM}%'' OR  ZIP_FILE_NAME LIKE ''ACICICCG{MM}%'' OR  ZIP_FILE_NAME LIKE ''FILL58_ACICICCG{MM}%'' OR  ZIP_FILE_NAME LIKE ''Icash_DeductFile_{YYYYMM}%'' OR  ZIP_FILE_NAME LIKE ''Icash2_G2DeductFile_{YYYYMM}%'' OR  ZIP_FILE_NAME LIKE ''Icash2_G2LockFile_{YYYYMM}%'' OR  ZIP_FILE_NAME LIKE ''Icash2_G2BonusChargeFile_{YYYYMM}%''', 1, 1, 8, 2, 1, 1, N'Group2', 1, CAST(N'2025-11-08T19:24:38.057' AS DateTime), CAST(N'2026-02-08T16:47:51.147' AS DateTime), N'Mason', 0, N'', CAST(N'2026-02-08T16:10:01.100' AS DateTime))
GO
SET IDENTITY_INSERT [dbo].[TableBackupSetting] OFF
GO
