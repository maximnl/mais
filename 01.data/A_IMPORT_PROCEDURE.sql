 
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[A_IMPORT_PROCEDURE](
	[procedure_id] [int] IDENTITY(1,1) NOT NULL,
	[procedure_name] [nvarchar](200) NULL,
	[procedure_guid] [nvarchar](40) NULL,
	[active] [bit] NULL,
	[description] [nvarchar](4000) NULL,
	[domain] [nvarchar](250) NULL,
	[category] [nvarchar](150) NULL,
	[status] [nvarchar](150) NULL,
	[app] [nvarchar](100) NULL,
	[version] [nvarchar](50) NULL,
	[procedure_code] [nvarchar](150) NOT NULL,
	[commands] [nvarchar](500) NULL,
	[sort_order] [int] NULL,
	[schedule] [nvarchar](400) NULL,
	[source] [nvarchar](2000) NULL,
	[fields_source] [nvarchar](2000) NULL,
	[fields_target] [nvarchar](2000) NULL,
	[filter] [nvarchar](2000) NULL,
	[group_by] [nvarchar](2000) NULL,
	[days_back] [nvarchar](150) NULL,
	[days_forward] [nvarchar](150) NULL,
	[date_import_from] [datetime] NULL,
	[date_import_until] [datetime] NULL,
	[date_updated] [datetime] NULL,
	[date_created] [datetime] NULL,
	[site_id] [int] NULL,
	[timestamp] [timestamp] NULL,
 CONSTRAINT [PK_A_IMPORT_PROCEDURE] PRIMARY KEY CLUSTERED 
(
	[procedure_id] ASC
)WITH (STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

ALTER TABLE [dbo].[A_IMPORT_PROCEDURE] ADD  CONSTRAINT [DF_A_IMPORT_PROCEDURE_procedure_guid]  DEFAULT (newid()) FOR [procedure_guid]
GO

ALTER TABLE [dbo].[A_IMPORT_PROCEDURE] ADD  CONSTRAINT [DF_A_IMPORT_PROCEDURE_active_1]  DEFAULT ((1)) FOR [active]
GO

ALTER TABLE [dbo].[A_IMPORT_PROCEDURE] ADD  CONSTRAINT [DF_A_IMPORT_PROCEDURE_date_updated_1]  DEFAULT (getdate()) FOR [date_updated]
GO

ALTER TABLE [dbo].[A_IMPORT_PROCEDURE] ADD  CONSTRAINT [DF_A_IMPORT_PROCEDURE_date_created_1]  DEFAULT (getdate()) FOR [date_created]
GO

ALTER TABLE [dbo].[A_IMPORT_PROCEDURE] ADD  CONSTRAINT [DF_A_IMPORT_PROCEDURE_site_id]  DEFAULT ((1)) FOR [site_id]
GO


