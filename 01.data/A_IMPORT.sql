/****** Object:  Table [dbo].[A_IMPORT]    Script Date: 12-10-2021 16:26:50 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[A_IMPORT](
	[import_id] [int] IDENTITY(1,1) NOT NULL,
	[import_num] [int] NULL,
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
 CONSTRAINT [PK_A_STG_IMPORT] PRIMARY KEY CLUSTERED 
(
	[import_id] ASC
)WITH (STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

ALTER TABLE [dbo].[A_IMPORT] ADD  CONSTRAINT [DF_A_IMPORT_domain]  DEFAULT (N'ALC') FOR [domain]
GO

ALTER TABLE [dbo].[A_IMPORT] ADD  CONSTRAINT [DF__A_STG_IMP__Activ__4984CAEC]  DEFAULT ((1)) FOR [active]
GO

ALTER TABLE [dbo].[A_IMPORT] ADD  CONSTRAINT [DF__A_STG_IMP__SiteI__4890A6B3]  DEFAULT ((1)) FOR [site_id]
GO

ALTER TABLE [dbo].[A_IMPORT] ADD  CONSTRAINT [DF_A_IMPORT_date_updated]  DEFAULT (getdate()) FOR [date_updated]
GO

ALTER TABLE [dbo].[A_IMPORT] ADD  CONSTRAINT [DF_A_IMPORT_date_created]  DEFAULT (getdate()) FOR [date_created]
GO

