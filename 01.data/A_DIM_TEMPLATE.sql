SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [A_DIM_TEMPLATE](
	[template_id] [int] IDENTITY(1,1) NOT NULL,
	[template_name] [nvarchar](150) NOT NULL,
	[template_guid] [nvarchar](40) NULL,
	[description] [nvarchar](2000) NULL,
	[category] [nvarchar](50) NULL,
	[domain] [nvarchar](50) NULL,
	[status] [nvarchar](50) NULL,
	[value1] [nvarchar](50) NULL,
	[value1_description] [nvarchar](150) NULL,
	[value2] [nvarchar](50) NULL,
	[value2_description] [nvarchar](150) NULL,
	[value3] [nvarchar](50) NULL,
	[value3_description] [nvarchar](150) NULL,
	[value4] [nvarchar](50) NULL,
	[value4_description] [nvarchar](150) NULL,
	[value5] [nvarchar](50) NULL,
	[value5_description] [nvarchar](150) NULL,
	[value6] [nvarchar](50) NULL,
	[value6_description] [nvarchar](150) NULL,
	[value7] [nvarchar](50) NULL,
	[value7_description] [nvarchar](150) NULL,
	[value8] [nvarchar](50) NULL,
	[value8_description] [nvarchar](150) NULL,
	[value9] [nvarchar](50) NULL,
	[value9_description] [nvarchar](150) NULL,
	[value10] [nvarchar](50) NULL,
	[value10_description] [nvarchar](150) NULL,
	[date_updated] [datetime] NULL,
	[timestamp] [timestamp] NULL,
	[site_id] [int] NULL,
	[active] [bit] NULL,
 CONSTRAINT [PK_A_DIM_TEMPLATE] PRIMARY KEY CLUSTERED 
(
	[template_id] ASC
)WITH (STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

ALTER TABLE [A_DIM_TEMPLATE] ADD  CONSTRAINT [DF_A_DIM_TEMPLATE_active]  DEFAULT ((1)) FOR [active]
GO
