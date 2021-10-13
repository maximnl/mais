/****** Object:  Table [dbo].[A_DIM_FORECAST]    Script Date: 12-10-2021 16:11:31 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[A_DIM_FORECAST](
	[forecast_id] [int] IDENTITY(1,1) NOT NULL,
	[forecast_name] [nvarchar](150) NOT NULL,
	[forecast_code] [nvarchar](50) NULL,
	[forecast_guid] [nvarchar](40) NULL,
	[description] [nvarchar](1500) NULL,
	[domain] [nvarchar](50) NULL,
	[category] [nvarchar](50) NULL,
	[status] [nvarchar](50) NULL,
	[active] [bit] NULL,
	[sort_order] [int] NULL,
	[site_id] [int] NULL,
	[date_valid_from] [datetime] NULL,
	[date_valid_until] [datetime] NULL,
	[date_updated] [datetime] NULL,
	[date_created] [datetime] NULL,
	[timestamp] [timestamp] NULL,
 CONSTRAINT [PK_A_DIM_FORECAST] PRIMARY KEY CLUSTERED 
(
	[forecast_id] ASC
)WITH (STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO


