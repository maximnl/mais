/****** Object:  Table [S_1_W].[A_IMPORT_FILE]    Script Date: 28-10-2021 10:53:18 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[A_IMPORT_FILE](
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
	[date_created] [datetime] NULL,
	[date_updated] [datetime] NULL,
 CONSTRAINT [PK_A_IMPORT_FILE] PRIMARY KEY CLUSTERED 
(
	[file_id] ASC
)WITH (STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO


