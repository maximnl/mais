/****** Object:  Table [A_FACT_DAY]    Script Date: 21-2-2022 10:02:54 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE .[A_FACT_DAY] (
	[date] [datetime] NOT NULL,
	[activity_id] [int] NOT NULL,
	[forecast_id] [int] NOT NULL,
	[value1] [real] NULL,
	[value2] [real] NULL,
	[value3] [real] NULL,
	[value4] [real] SPARSE  NULL,
	[value5] [real] SPARSE  NULL,
	[value6] [real] SPARSE  NULL,
	[value7] [real] SPARSE  NULL,
	[value8] [real] SPARSE  NULL,
	[value9] [real] SPARSE  NULL,
	[value10] [real] SPARSE  NULL,
	[site_id] [int] NULL,
	[import_id] [int] NULL,
	[date_updated] [datetime] NULL
) ON [PRIMARY]
GO

/****** Object:  Index [idx_fact_day_activity_id]    Script Date: 21-2-2022 10:02:54 ******/
CREATE NONCLUSTERED INDEX [idx_fact_day_activity_id] ON .[A_FACT_DAY]
(
	[activity_id] ASC
)WITH (STATISTICS_NORECOMPUTE = OFF, DROP_EXISTING = OFF, ONLINE = OFF) ON [PRIMARY]
GO

/****** Object:  Index [idx_fact_day_date]    Script Date: 21-2-2022 10:02:54 ******/
CREATE NONCLUSTERED INDEX [idx_fact_day_date] ON .[A_FACT_DAY]
(
	[date] ASC
)WITH (STATISTICS_NORECOMPUTE = OFF, DROP_EXISTING = OFF, ONLINE = OFF) ON [PRIMARY]
GO

/****** Object:  Index [idx_fact_day_forecast_id]    Script Date: 21-2-2022 10:02:54 ******/
CREATE NONCLUSTERED INDEX [idx_fact_day_forecast_id] ON .[A_FACT_DAY]
(
	[forecast_id] ASC
)WITH (STATISTICS_NORECOMPUTE = OFF, DROP_EXISTING = OFF, ONLINE = OFF) ON [PRIMARY]
GO


