SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE dbo.[A_FACT_DAY](
	[date] [date] NOT NULL,
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
CREATE NONCLUSTERED INDEX [idx_fact_day_activity_id] ON dbo.[A_FACT_DAY]
(
	[activity_id] ASC
)WITH (STATISTICS_NORECOMPUTE = OFF, DROP_EXISTING = OFF, ONLINE = OFF, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [idx_fact_day_date] ON dbo.[A_FACT_DAY]
(
	[date] ASC
)WITH (STATISTICS_NORECOMPUTE = OFF, DROP_EXISTING = OFF, ONLINE = OFF, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [idx_fact_day_forecast_id] ON dbo.[A_FACT_DAY]
(
	[forecast_id] ASC
)WITH (STATISTICS_NORECOMPUTE = OFF, DROP_EXISTING = OFF, ONLINE = OFF, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [nci_wi_A_FACT_DAY_8113372A535D0AD40A0D73E22E1FBA54] ON dbo.[A_FACT_DAY]
(
	[forecast_id] ASC,
	[activity_id] ASC
)
INCLUDE([date],[value1]) WITH (STATISTICS_NORECOMPUTE = OFF, DROP_EXISTING = OFF, ONLINE = OFF, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
