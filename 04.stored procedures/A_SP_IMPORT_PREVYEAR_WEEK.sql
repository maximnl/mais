 
/****** Object:  StoredProcedure [dbo].[A_SP_IMPORT_PREVYEAR_WEEK]    Script Date: 27-9-2021 16:52:33 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


ALTER   PROCEDURE [dbo].[A_SP_IMPORT_PREVYEAR_WEEK] 		
  
 @forecast_id int = null,
 @forecast_from_id int = null,
 @date_from datetime=NULL, --='2019-01-01',
 @lag_years int=1	 

AS
BEGIN

 SET @date_from=isnull(@date_from,[dbo].[A_FN_TI_FirstDayPreviousYear](null));

 DELETE W
		  from [dbo].[A_FACT_DAY] W 
		  where W.forecast_id=@forecast_id and date>=@date_from

INSERT INTO  [dbo].[A_FACT_DAY] ([date],[activity_id],[forecast_id],[Value1],[Value2],[Value3],[Value4],[Value5],[Value6],[Value7],[Value8],[Value9],[Value10]) 
SELECT D.date,activity_id,@forecast_id, A.Value1, A.Value2, A.Value3, A.Value4, A.Value5, A.Value6,A.Value7,A.Value8,A.Value9,A.Value10
from ( select W.*, d.[day_week], d.[week], d.[year52] 
    from [dbo].[A_FACT_DAY] W
    INNER JOIN [dbo].[A_TIME_DATE] D on W.[date]=D.[date]
    where forecast_id=@forecast_from_id) as A
     inner join [dbo].[A_TIME_DATE] D on  D.date>=@date_from and  A.[day_week]=D.[day_week] 
and ((A.[week]=D.[week] and A.[year52]=(D.[year52]-@lag_years))  
or (A.[week]=1 and D.[week]=53 and A.[year52]=(D.[year52]-@lag_years+1)) )   

END
 