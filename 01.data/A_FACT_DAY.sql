SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [A_FACT_DAY](
	[date] [datetime] NOT NULL,
	[activity_id] [int] NOT NULL,
	[forecast_id] [int] NOT NULL,
	[value1] [float] NULL,
	[value2] [float] NULL,
	[value3] [float] NULL,
	[value4] [float] SPARSE  NULL,
	[value5] [float] SPARSE  NULL,
	[value6] [float] SPARSE  NULL,
	[value7] [float] SPARSE  NULL,
	[value8] [float] SPARSE  NULL,
	[value9] [float] SPARSE  NULL,
	[value10] [float] SPARSE  NULL,
	[site_id] [int] NULL,
	[import_id] [int] NULL,
	[date_updated] [datetime] NULL,
) ON [PRIMARY]


