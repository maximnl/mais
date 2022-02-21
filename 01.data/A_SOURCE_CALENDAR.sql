
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [A_SOURCE_CALENDAR](
	[calendar_id] [int] IDENTITY(1,1) NOT NULL,
	[category] [nvarchar](150) NULL,
	[domain] [nvarchar](250) NULL,
	[segment] [nvarchar](250) NULL,
	[subject] [nvarchar](250) NULL,
	[start_date] [datetime2](7) NULL,
	[end_date] [datetime2](7) NULL,
	[timezone] [nvarchar](255) NULL,
	[recurence] [nvarchar](250) NULL,
	[allday] [bit] NULL,
	[region] [nvarchar](250) NULL,
	[resource] [nvarchar](250) NULL,
	[description] [nvarchar](1000) NULL,
	[type] [nvarchar](255) NULL,
	[path] [nvarchar](255) NULL,
	[value1] [float] NULL,
	[value2] [float] NULL,
	[value3] [float] NULL,
	[text1] [nvarchar](4000) NULL,
	[text2] [nvarchar](4000) NULL,
	[text3] [nvarchar](4000) NULL,
	[status] [nvarchar](250) NULL,
	[p1] [nvarchar](250) NULL,
	[p2] [nvarchar](250) NULL,
	[p3] [nvarchar](250) NULL,
	[date_updated] [datetime] NULL,
	[timestamp] [timestamp] NULL,
	[site_id] [int] NOT NULL,
 CONSTRAINT [PK_A_DIM_TIME_CALENDAR_1] PRIMARY KEY CLUSTERED 
(
	[calendar_id] ASC
)WITH (STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

ALTER TABLE [A_SOURCE_CALENDAR] ADD  CONSTRAINT [DF_A_DIM_TIME_CALENDAR_DateUpdated]  DEFAULT (getdate()) FOR [date_updated]
GO



