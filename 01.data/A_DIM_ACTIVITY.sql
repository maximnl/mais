 SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[A_DIM_ACTIVITY](
	[activity_id] [int] IDENTITY(1,1) NOT NULL,
	[activity_name] [nvarchar](150) NOT NULL,
	[activity_set] [nvarchar](250) NULL,
	[activity_code] [nvarchar](150) NULL,
	[description] [nvarchar](4000) NULL,
	[segment] [nvarchar](250) NULL,
	[domain] [nvarchar](250) NULL,
	[region] [nvarchar](250) NULL,
	[template_id] [int] NULL,
	[slicer1] [nvarchar](150) NULL,
	[slicer2] [nvarchar](150) NULL,
	[slicer3] [nvarchar](150) NULL,
	[sort_order] [tinyint] NULL,
	[resource] [nvarchar](250) NULL,
	[channel] [nvarchar](250) NULL,
	[reference] [nvarchar](250) NULL,
	[parent] [nvarchar](250) NULL,
	[status] [nvarchar](150) NULL,
	[plantype] [nvarchar](150) NULL,
	[category] [nvarchar](150) NULL,
	[site_id] [int] NULL,
	[activity_guid] [nvarchar](40) NULL,
	[active] [bit] NULL,
	[tags] [nvarchar](1000) NULL,
	[color] [nvarchar](50) NULL,
	[font_awesome] [nvarchar](550) NULL,
	[date_updated] [datetime] NULL,
	[date_created] [datetime] NULL,
	[timestamp] [timestamp] NULL,
 CONSTRAINT [PK_A_DIM_ACTIVITY_NEW] PRIMARY KEY CLUSTERED 
(
	[activity_id] ASC
)WITH (STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

ALTER TABLE [dbo].[A_DIM_ACTIVITY] ADD  CONSTRAINT [DF_A_DIM_ACTIVITY_site_id]  DEFAULT ((1)) FOR [site_id]
GO

ALTER TABLE [dbo].[A_DIM_ACTIVITY] ADD  CONSTRAINT [DF_A_DIM_ACTIVITY_activity_guid]  DEFAULT (newid()) FOR [activity_guid]
GO

ALTER TABLE [dbo].[A_DIM_ACTIVITY] ADD  CONSTRAINT [DF_A_DIM_ACTIVITY_active]  DEFAULT ((1)) FOR [active]
GO


