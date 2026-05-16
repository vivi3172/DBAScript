USE [iSettle2]
GO

/****** Object:  Table [dbo].[TableBackupSetting]    Script Date: 2026/2/9 上午 12:27:38 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[TableBackupSetting](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[DBName] [nvarchar](128) NOT NULL,
	[SchemaName] [nvarchar](128) NOT NULL,
	[BaseTableName] [nvarchar](128) NOT NULL,
	[HistoryDBName] [nvarchar](128) NOT NULL,
	[HistorySchemaName] [nvarchar](128) NOT NULL,
	[WhereCondition] [nvarchar](max) NOT NULL,
	[KeepMonths] [int] NOT NULL,
	[CleanMonths] [int] NOT NULL,
	[TopSize] [int] NOT NULL,
	[Rounds] [int] NOT NULL,
	[WaitSeconds] [int] NOT NULL,
	[DoBackup] [bit] NOT NULL,
	[ExecGroup] [nvarchar](50) NULL,
	[ExecOrder] [int] NOT NULL,
	[CreatedAt] [datetime] NULL,
	[UpdatedAt] [datetime] NULL,
	[CreatedBy] [nvarchar](50) NULL,
	[IsError] [bit] NOT NULL,
	[ErrorMessage] [nvarchar](max) NULL,
	[ErrorUpdatedAt] [datetime] NULL,
PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

ALTER TABLE [dbo].[TableBackupSetting] ADD  DEFAULT ((1)) FOR [KeepMonths]
GO

ALTER TABLE [dbo].[TableBackupSetting] ADD  DEFAULT ((1000)) FOR [TopSize]
GO

ALTER TABLE [dbo].[TableBackupSetting] ADD  DEFAULT ((1)) FOR [Rounds]
GO

ALTER TABLE [dbo].[TableBackupSetting] ADD  DEFAULT ((10)) FOR [WaitSeconds]
GO

ALTER TABLE [dbo].[TableBackupSetting] ADD  DEFAULT ((1)) FOR [DoBackup]
GO

ALTER TABLE [dbo].[TableBackupSetting] ADD  DEFAULT ((1000)) FOR [ExecOrder]
GO

ALTER TABLE [dbo].[TableBackupSetting] ADD  DEFAULT (getdate()) FOR [CreatedAt]
GO

ALTER TABLE [dbo].[TableBackupSetting] ADD  DEFAULT (getdate()) FOR [UpdatedAt]
GO

ALTER TABLE [dbo].[TableBackupSetting] ADD  DEFAULT ((0)) FOR [IsError]
GO


