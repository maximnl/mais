
CREATE TABLE [A_FACT_INTRADAY](
	[date] [datetime] NULL,
	[interval_id] [smallint] NULL,
	[activity_id] [int] NULL,
	[forecast_id] [int] NULL,
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
	[duration_min] [tinyint] NULL,
	[import_id] [int] NULL,
	[date_updated] [datetime] NULL,
	[site_id] [int] NULL
) ON [PRIMARY]
GO
