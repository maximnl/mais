/****** Object:  Table [S_1_W].[A_IMPORT]    Script Date: 28-10-2021 09:33:49 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[A_IMPORT](
	[import_id] [int] IDENTITY(1,1) NOT NULL,
	[import_code] [nvarchar](50) NULL,
	[domain] [nvarchar](50) NULL,
	[procedure_id] [int] NULL,
	[procedure_code] [nvarchar](150) NULL,
	[import_guid] [nvarchar](40) NULL,
	[activity_id] [int] NULL,
	[forecast_id] [int] NULL,
	[p1] [nvarchar](2000) NULL,
	[p2] [nvarchar](2000) NULL,
	[p3] [nvarchar](2000) NULL,
	[p4] [nvarchar](2000) NULL,
	[p5] [nvarchar](2000) NULL,
	[schedule] [nvarchar](400) NULL,
	[date_import_from] [datetime] NULL,
	[date_import_until] [datetime] NULL,
	[description] [nvarchar](2000) NULL,
	[sort_order] [int] NULL,
	[active] [bit] NULL,
	[fields_source] [nvarchar](2000) NULL,
	[fields_target] [nvarchar](2000) NULL,
	[source] [nvarchar](2000) NULL,
	[filter] [nvarchar](2000) NULL,
	[group_by] [nvarchar](2000) NULL,
	[template_id] [int] NULL,
	[site_id] [int] NULL,
	[date_updated] [datetime] NULL,
	[date_created] [datetime] NULL,
	[timestamp] [timestamp] NULL,
 CONSTRAINT [PK_A_IMPORT] PRIMARY KEY CLUSTERED 
(
	[import_id] ASC
)WITH (STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO


