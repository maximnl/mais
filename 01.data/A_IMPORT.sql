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
	[activity_id] [int] NULL,
	[forecast_id] [int] NULL,
	[source] [nvarchar](2000) NULL,
	[filter] [nvarchar](2000) NULL,
	[fields_source] [nvarchar](2000) NULL,
	[fields_target] [nvarchar](2000) NULL,
	[group_by] [nvarchar](2000) NULL,
	[category] [nvarchar](150) NULL,
	[status] [nvarchar](150) NULL,
	[version] [nvarchar](50) NULL,
	[commands] [nvarchar](500) NULL,
	[p1] [nvarchar](2000) NULL,
	[p2] [nvarchar](2000) NULL,
	[p3] [nvarchar](2000) NULL,
	[p4] [nvarchar](2000) NULL,
	[p5] [nvarchar](2000) NULL,
	[schedule] [nvarchar](400) NULL,
	[days_back] [nvarchar](150) NULL,
	[days_forward] [nvarchar](150) NULL,
	[date_import_from] [datetime] NULL,
	[date_import_until] [datetime] NULL,
	[description] [nvarchar](2000) NULL,
	[sort_order] [int] NULL,
	[active] [bit] NULL,
	[template_id] [int] NULL,
	[site_id] [int] NULL,
	[date_updated] [datetime] NULL,
	[date_created] [datetime] NULL,
	[import_guid] [nvarchar](40) NULL,
	[timestamp] [timestamp] NULL,
	[file_id] [int] NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[A_IMPORT] ADD  CONSTRAINT [PK_A_STG_IMPORT] PRIMARY KEY CLUSTERED 
(
	[import_id] ASC
)WITH (STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
ALTER TABLE [dbo].[A_IMPORT] ADD  CONSTRAINT [DF_A_IMPORT_active]  DEFAULT ((1)) FOR [active]
GO
ALTER TABLE [dbo].[A_IMPORT] ADD  CONSTRAINT [DF_A_IMPORT_date_updated_1]  DEFAULT (getdate()) FOR [date_updated]
GO
ALTER TABLE [dbo].[A_IMPORT] ADD  CONSTRAINT [DF_A_IMPORT_date_created_1]  DEFAULT (getdate()) FOR [date_created]
GO
ALTER TABLE [dbo].[A_IMPORT] ADD  CONSTRAINT [DF_A_IMPORT_import_guid]  DEFAULT (newid()) FOR [import_guid]
GO
