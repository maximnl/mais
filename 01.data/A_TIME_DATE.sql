SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[A_TIME_DATE](
	[date] [date] NOT NULL,
	[date_key] [int] NULL,
	[date_key_char] [char](8) NULL,
	[year] [char](4) NULL,
	[year52] [char](4) NULL,
	[year_quarter_char] [char](7) NULL,
	[year_month_char] [char](7) NULL,
	[year_week] [char](6) NULL,
	[year_week_long] [char](7) NULL,
	[year_week_short] [char](5) NULL,
	[semester] [char](10) NULL,
	[quarter] [char](10) NULL,
	[month] [char](2) NULL,
	[month_quarter] [char](10) NULL,
	[month_long] [char](10) NULL,
	[month_short] [char](3) NULL,
	[month_days] [smallint] NULL,
	[months_2000] [int] NULL,
	[week] [char](2) NULL,
	[week_quarter] [char](2) NULL,
	[week_month] [char](10) NULL,
	[weeks_2000] [int] NULL,
	[day_long] [char](10) NULL,
	[day_short] [char](2) NULL,
	[day_year] [char](3) NULL,
	[day_quarter] [char](10) NULL,
	[day_month] [char](2) NULL,
	[day_week] [char](1) NULL,
	[days_2000] [int] NULL,
	[YYYYMMDD] [char](8) NULL,
	[MM/DD/YYYY] [char](10) NULL,
	[YYYY/MM/DD] [char](10) NULL,
	[YYYY-MM-DD] [char](10) NULL,
	[DD-MM-YYYY] [char](10) NULL,
	[MMM DD YYYY] [char](11) NULL,
	[country] [char](2) NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[A_TIME_DATE] ADD  CONSTRAINT [PK_A_TIME_DATE] PRIMARY KEY CLUSTERED 
(
	[date] ASC
)WITH (STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
