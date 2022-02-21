
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [A_IMPORT_FILE](
	[file_id] [int] IDENTITY(1,1) NOT NULL,
	[file_name] [nvarchar](200) NULL,
	[source] [nvarchar](50) NULL,
	[attributes] [nvarchar](250) NULL,
	[file_created] [nvarchar](50) NULL,
	[file_updated] [nvarchar](50) NULL,
	[file_last_access] [nvarchar](50) NULL,
	[size] [numeric](10, 2) NULL,
	[field_date] [nvarchar](150) NULL,
	[field_date_format] [nvarchar](50) NULL,
	[rows_skip] [int] NULL,
	[fields] [nvarchar](2000) NULL,
	[session] [nvarchar](50) NULL,
	[domain] [nvarchar](250) NULL,
	[category] [nvarchar](150) NULL,
	[description] [nvarchar](500) NULL,
	[status] [nvarchar](50) NULL,
	[site_id] [int] NULL,
	[active] [bit] NULL,
	[file_guid] [nvarchar](40) NULL,
	[tab] [nvarchar](150) NULL,
	[records] [int] NULL,
	[date_created] [datetime] NULL,
	[date_updated] [datetime] NULL,
 CONSTRAINT [PK_A_IMPORT_FILE] PRIMARY KEY CLUSTERED 
(
	[file_id] ASC
)WITH (STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

ALTER TABLE [A_IMPORT_FILE] ADD  CONSTRAINT [DF_A_IMPORT_FILE_active]  DEFAULT ((1)) FOR [active]
GO

ALTER TABLE [A_IMPORT_FILE] ADD  CONSTRAINT [DF_A_IMPORT_FILE_file_guid]  DEFAULT (newid()) FOR [file_guid]
GO

ALTER TABLE [A_IMPORT_FILE] ADD  CONSTRAINT [DF_A_IMPORT_FILE_date_created]  DEFAULT (getdate()) FOR [date_created]
GO

ALTER TABLE [A_IMPORT_FILE] ADD  CONSTRAINT [DF_A_IMPORT_FILE_date_updated]  DEFAULT (getdate()) FOR [date_updated]
GO


