/******     Script Date: 15-2-2022 10:49:32 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [DBO].[A_FACT_INTRADAY](
	[date] [datetime] NULL,
	[interval_id] [smallint] NULL,
	[activity_id] [int] NULL,
	[forecast_id] [int] NULL,
	[value1] [float] NULL,
	[value2] [float] NULL,
	[value3] [float] NULL,
	[value4] [float] NULL,
	[value5] [float] NULL,
	[value6] [float] NULL,
	[value7] [float] NULL,
	[value8] [float] NULL,
	[value9] [float] NULL,
	[value10] [float] NULL,
	[duration_min] [tinyint] NULL,
	[import_id] [int] NULL,
	[date_updated] [datetime] NULL,
	[site_id] [int] NULL
) ON [PRIMARY]
GO
 
