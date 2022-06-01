 
/****** Object:  StoredProcedure [dbo].[A_SP_IMPORT_YTM]    Script Date: 1-6-2022 13:33:23 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


ALTER    PROCEDURE [dbo].[A_SP_IMPORT_YTM] 	
	@forecast_id int = NULL
,   @forecast_from_id int =NULL
,	@date_from datetime=NULL
AS
BEGIN

SET @date_from = isnull(@date_from,[dbo].[A_FN_TI_FirstDayCurrentYear](NULL))  -- first date of current year

DELETE W
		  from [dbo].[A_FACT_DAY] W 
		  where W.forecast_id=@forecast_id and [date]>=@date_from
;

with  D as 
(select  activity_id,D.[year_month_char],D.[year] , max(d.date) as [date] 
,sum(Value1) value1 
,sum(Value2) value2 
,sum(Value3) value3 
,sum(Value4) value4 
,sum(Value5) value5
,sum(Value6) value6 
,sum(Value7) value7
,sum(Value8) value8
,sum(Value9) value9
,sum(Value10) value10
	from [dbo].[A_FACT_DAY] A inner join [dbo].[A_TIME_DATE] D on A.Date=D.Date
where forecast_id=@forecast_from_id and A.[date]>=@date_from 
group by activity_id, D.[year_month_char],D.[year]
	)	 
INSERT INTO  [dbo].[A_FACT_DAY] ([date],[activity_Id],[forecast_Id],[value1],[value2],[value3],[value4],[value5],[value6],value7,value8,value9,value10) 
select [date],activity_id,@forecast_id 
,sum(value1) over (partition by activity_id, [year] order by [date] rows unbounded preceding) value1
,sum(value2) over (partition by activity_id, [year] order by [date] rows unbounded preceding) value2
,sum(value3) over (partition by activity_id, [year] order by [date] rows unbounded preceding) value3
,sum(value4) over (partition by activity_id, [year] order by [date] rows unbounded preceding) value4
,sum(value5) over (partition by activity_id, [year] order by [date] rows unbounded preceding) value5
,sum(value6) over (partition by activity_id, [year] order by [date] rows unbounded preceding) value6
,sum(value7) over (partition by activity_id, [year] order by [date] rows unbounded preceding) value7
,sum(value8) over (partition by activity_id, [year] order by [date] rows unbounded preceding) value8
,sum(value9) over (partition by activity_id, [year] order by [date] rows unbounded preceding) value9
,sum(value10) over (partition by activity_id, [year] order by [date] rows unbounded preceding) value10
from D

END
