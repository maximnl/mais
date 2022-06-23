SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO




/****** Script for SelectTopNRows command from SSMS  ******/
CREATE view [dbo].[A_FACT_INTRADAY_VIEW] as
SELECT D.date  date_view
      ,D.[activity_id]
      ,D.[forecast_id]
      ,[value1]
      ,[value2]
      ,[value3]
      ,[value4]
      ,[value5]
      ,[value6]
      ,[value7]
      ,[value8]
      ,[value9]
      ,[value10]
	  ,A.[activity_name]
	  ,F.forecast_name
	  ,A.activity_set
	  ,A.domain
	  ,A.region
	  ,T.[year]  as YYYY --	  ,concat('Y',T.[year])  as YYYY
	  ,T.[year_month_char]  [YYYYMM]
	  ,T.[year_week_short]  [YYYYWww]
	  ,T.week
	  ,T.month
	  ,T.day_week
      ,D.site_id
      ,A.slicer1
      ,A.slicer2
      ,A.slicer3
      ,I.time_start
  FROM dbo.[A_FACT_INTRADAY] D
  inner join dbo.[A_DIM_ACTIVITY] A on D.[activity_id]=A.[activity_id]
  inner join dbo.[A_DIM_FORECAST] F on D.[forecast_id]=F.[forecast_id]
  inner join dbo.[A_TIME_DATE] T on D.date=T.date
  inner join dbo.A_TIME_INTERVAL I on I.interval_id=D.interval_id

GO
