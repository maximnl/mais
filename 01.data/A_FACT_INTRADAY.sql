SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[A_FACT_INTRADAY]
(
    [date] [date] NOT NULL,
    [interval_id] [smallint] NOT NULL,
    [activity_id] [int] NOT NULL,
    [forecast_id] [int] NOT NULL,
    [value1] [real] NULL,
    [value2] [real] NULL,
    [value3] [real] NULL,
    [value4] [real] SPARSE NULL,
    [value5] [real] SPARSE NULL,
    [value6] [real] SPARSE NULL,
    [value7] [real] SPARSE NULL,
    [value8] [real] SPARSE NULL,
    [value9] [real] SPARSE NULL,
    [value10] [real] SPARSE NULL,
    [duration_min] [tinyint] NULL,
    [import_id] [int] NULL,
    [date_updated] [datetime] NULL,
    [site_id] [int] NOT NULL
) ON [PRIMARY]
GO
