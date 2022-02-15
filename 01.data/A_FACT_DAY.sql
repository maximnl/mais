/****** Object:  Table [S_1_W].[A_FACT_DAY]    Script Date: 15-2-2022 10:46:51 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[A_FACT_DAY](
	[date] [datetime] NOT NULL,
	[activity_id] [int] NOT NULL,
	[forecast_id] [int] NOT NULL,
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
	[import_id] [int] NULL,
	[site_id] [int] NULL,
	[date_updated] [datetime] NULL
) ON [PRIMARY]
GO

ALTER TABLE [S_1_W].[A_FACT_DAY] ADD  CONSTRAINT [DF_A_FACT_DAY_date_updated]  DEFAULT (getdate()) FOR [date_updated]
GO


