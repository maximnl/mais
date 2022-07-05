SET ANSI_NULLS OFF
GO
SET QUOTED_IDENTIFIER ON
GO



-- template stored procedure for loading data from source tables
ALTER  PROCEDURE [dbo].[A_SP_FC_CORELATION]
 @activity_id int = 0 
,@session_id uniqueidentifier   = null
,@commands varchar(2000)='' -- '-LOG_ROWCOUNT -LOG_INSERT -LOG_DELETE' --'-PRINT' -NOGROUPBY -SUMFIELDS -SET_IMPORT_ID
,@procedure_name nvarchar(200)='A_SP_FC_CORELATION'
,@site_id int = 0
,@import_id int = 0
AS
BEGIN

    SET NOCOUNT ON;
	
--  configuration
	DECLARE @fact_day nvarchar(200)='[A_FACT_DAY]' -- data per day stored here
    DECLARE @sqlCommand NVARCHAR(MAX) -- 

--  source data parameters
	DECLARE @forecast_id int = 0
	DECLARE @filter nvarchar(4000)='' -- where filter for filtering source data
	DECLARE @date_import_from date='9999-01-01' -- calculated by the import query using imports and procedures fields
	DECLARE @date_import_until date='1900-01-01'
	DECLARE @fields_source varchar(2000)='' -- source fields
	DECLARE @fields_target varchar(2000)=''  -- target fields value1
	DECLARE @schedule varchar(2000)=''
	DECLARE @source varchar(2000)=''
	DECLARE @group_by varchar(2000)=''
	DECLARE @p1 varchar(2000)=''  -- parameters
	DECLARE @p2 varchar(2000)=''
	DECLARE @p3 varchar(2000)=''
	DECLARE @p4 varchar(2000)=''
	DECLARE @p5 varchar(2000)=''
	DECLARE @groupby varchar(2000)=''
    DECLARE @parent varchar(200)=''

	-- login parameters
	DECLARE @data  varchar(4000)=''  -- log data
	DECLARE @rows INT   -- keep affected rows
	DECLARE @start_time datetime=null
    DECLARE @output nvarchar(max)='';

	-- source data analysis
	DECLARE @date_source_min date='9999-01-01' -- calculated by the import query using imports and procedures fields
	DECLARE @date_source_max date='1900-01-01'

	
	DECLARE TAB_CURSOR CURSOR  FOR 
    SELECT import_id 
 	  ,[activity_id]
      ,[forecast_id]
      ,[p1]
      ,[p2]
      ,[p3]
      ,[p4]
      ,[p5]
      ,[date_import_from]
      ,[date_import_until]
      ,[fields_source]
      ,[fields_target]
      ,[schedule]
      ,isnull([filter],'1=1') filter
      ,[source]
      ,[group_by]
	  ,concat(@commands,' ',commands)
	  ,[procedure_name]
	  ,site_id
      ,parent
    FROM   dbo.[A_IMPORT_RUN]
    WHERE   (import_id=@import_id or @import_id=0) 
		AND (site_id=@site_id or site_id is null or @site_id=0)
		AND ([procedure_name] like @procedure_name or procedure_code like @procedure_name or @import_id>0) 
		and (activity_id=@activity_id or @activity_id=0)
    ORDER BY [sort_order]
    
	EXEC dbo.[A_SP_SYS_LOG] 'PROCEDURE START' ,@session_id  ,@activity_id  , @procedure_name ,@commands
	SET @start_time     = GETDATE()

----------------------------------------------
--  FETCH ALL IMPORTS FOR THE CURRENT SP
----------------------------------------------
	OPEN TAB_CURSOR 

	FETCH NEXT FROM TAB_CURSOR 

	INTO   @import_id 
 			,@activity_id
     		,@forecast_id
     		,@p1
     		,@p2
     		,@p3
     		,@p4
     		,@p5
     		,@date_import_from
     		,@date_import_until
     		,@fields_source
     		,@fields_target
     		,@schedule
     		,@filter
     		,@source
     		,@group_by
			,@commands
			,@procedure_name 
			,@site_id
            ,@parent

	WHILE @@FETCH_STATUS = 0 

   	BEGIN 
		 
        DECLARE @activity_corelated_id INT=try_convert(int,@p1)  
        DECLARE @forecast_corelated_id INT=try_convert(int,@p2) 
        DECLARE @forecast_source_id INT=try_convert(int,@p3)	
        DECLARE @lag INT=try_convert(int,@p4)  
        DECLARE @errors int = 0 

        IF @activity_corelated_id= 0 BEGIN
            SET @activity_corelated_id=try_convert(int,@parent)
        END

        IF @activity_corelated_id=0 OR @forecast_corelated_id=0 OR @forecast_source_id=0 SET @errors=@errors+1  
		 
		SET @date_import_from=isnull(@date_import_from,[dbo].[A_FN_TI_FirstDayCurrentYear](NULL));
 		SET @date_import_until=isnull(@date_import_until,[dbo].[A_FN_TI_LastDayCurrentYear](NULL));

		-- we skip source delta check , there are no requirements
		 
	----------------------------------------------------------------------------------------------------------------------
	--  CLEAN DAY

 	-- this SP supports batch loading, so several activities passed in the @filter parameter, 
	-- so we deviate from the standard import delete here
	--------------------------------------------------------------------------------	
		SET @sqlCommand ='DELETE FROM [dbo].[A_FACT_DAY] ' 
        + ' WHERE forecast_id=' + convert(varchar(10),@forecast_id) + ' AND activity_id=' + convert(varchar(10),@activity_id) 
        + ' AND [date] between ''' 
		+ convert(varchar(10),@date_import_from,126) + ''' AND '''+ convert(varchar(10),@date_import_until,126) + '''' 
        + '	AND site_id = ' +  convert(nvarchar(max),@site_id);
		  
 		BEGIN TRY
			IF @commands like '%-PRINT%' PRINT @sqlCommand 
            SET @output=@output+'-- DELETE DAY DATA QUERY <br>'+@sqlCommand+'<br><br>';
			IF @commands not like '%-PRINT%' AND @date_import_until>=@date_import_from 
            BEGIN
                IF @errors=0 BEGIN EXEC( @sqlCommand);SET @rows= @@ROWCOUNT;
                    SET @output=@output+'-- DELETE QUERY EXECUTED <br>';
                    SET @output=@output+'day records deleted ' + convert(varchar(10),@rows)+'<br><br>'
                END
                ELSE SET @output=@output+'-- QUERIES WILL NOT BE EXECUTED DUE TO ERRORS. Please check the parameters.<br>'       
                IF @date_import_until<@date_import_from AND  @commands like '%-LOG_ROWCOUNT%' EXEC dbo.[A_SP_SYS_LOG]  'IMPORT WARNING' ,@session_id ,@import_id ,'NODATA ON DELETE', @sqlCommand  
                
                IF @commands like '%-LOG_ROWCOUNT%' EXEC dbo.[A_SP_SYS_LOG] 'LOG ROWS' ,@session_id ,@import_id ,'RECORDS DELETE DAY',@rows  
                IF @commands like '%-LOG_DELETE%' EXEC dbo.[A_SP_SYS_LOG] 'LOG DELETE ROWS' ,@session_id ,@import_id ,'DELETE QUERY DAY',@sqlCommand  
            END
 		END TRY
 		BEGIN CATCH  
			SET @data=JSON_MODIFY( @data,'$.error',dbo.[A_FN_SYS_ErrorJson]()) 
            SET @output=@output+dbo.[A_FN_SYS_ErrorJson]()+'<br><br>'
			EXEC dbo.[A_SP_SYS_LOG] 'IMPORT ERROR' ,@session_id ,@import_id ,'CLEAN DAY',@sqlCommand  
 		END CATCH;   

	--------------------------------------------------------------------------------------------------------------------------
	--  INSERT TO DAY
	-------------------------------------------------------------------------------------
SET @sqlCommand = '
/* aggregate correlation data for the activity to be forecasted */
;with ACT as (
SELECT weeks_2000 as timekey
, sum(isnull(value1,0)) value1
FROM [dbo].[A_FACT_DAY] S
RIGHT JOIN [dbo].[A_TIME_DATE] D on S.date=D.[date]
WHERE S.activity_id='+ convert(varchar(10),@activity_id)+' AND forecast_id='+ convert(varchar(10),@forecast_corelated_id) +' 
GROUP BY D.weeks_2000
)
,
/* add moving average / smoothing */
ACT1 as(
SELECT timekey
, value1 as actual1
,avg(value1) over (order by timekey rows between 1 preceding and 1 following) as value1
FROM ACT)
,
/* add MA laging / lagin 0 is no laging */
ACT2 as(
SELECT timekey, actual1
,value1
FROM ACT1)

/* aggregated benchmark activity */
,REF as (SELECT weeks_2000 as timekey
, sum(isnull(value1,0)) value1
FROM [dbo].[A_FACT_DAY] S
RIGHT JOIN [dbo].[A_TIME_DATE] D on S.date=D.[date]
WHERE S.activity_id='+ convert(varchar(10),@activity_corelated_id )+ ' AND forecast_id='+ convert(varchar(10),@forecast_corelated_id ) 
+ ' GROUP BY D.weeks_2000)

/* add moving average for smoothing */
,REF1 as(
SELECT timekey
,avg(value1) over (order by timekey rows between 1 preceding and 1 following) as value1
FROM REF)

/* add ma lagging */
,REF2 as(
SELECT timekey--, value1
, LAG(value1,' + convert(varchar(10),@lag) +' ) over (order by timekey) as value1
FROM REF1)

/* aggregate benchmark forecast */
,F as (SELECT weeks_2000 as timekey
, sum(isnull(value1,0)) value1
FROM [dbo].[A_FACT_DAY] S
RIGHT JOIN [dbo].[A_TIME_DATE] D on S.date=D.[date]
WHERE S.activity_id='+ convert(varchar(10),@activity_corelated_id) +' and forecast_id='+ convert(varchar(10),@forecast_source_id) 
+' GROUP BY D.weeks_2000)

/* add ma lagging */
,F1 as(
SELECT timekey
, LAG(value1,' + convert(varchar(10),@lag) +' ) over (order by timekey) as value1 
FROM F)

/* calculate ratio on historical correlated data */
, R as (
SELECT ACT2.timekey
, ACT2.actual1 
, ACT2.value1 as ACT_value1
, REF2.value1 REF_value1
, ACT2.value1/REF2.value1 ratio1
FROM ACT2 INNER JOIN REF2 ON ACT2.timekey=REF2.timekey
WHERE isnull(REF2.value1,0)<>0
)
 
/* -- CORRELATION TEST
SELECT 
(Avg(ACT_value1 * REF_value1) - (Avg(ACT_value1) * Avg(REF_value1))) / --continued 
(StDevP(ACT_value1) * StDevP(REF_value1))  as PearsonCoefficient,
(Avg(ACT_value1 * REF_value1) - (Avg(ACT_value1) * Avg(REF_value1))) as numerator,
(StDevP(ACT_value1) * StDevP(REF_value1))  as denominator
FROM r
 */

, R1 as (
/* join forecast with legged historical ratios */ 
SELECT   F1.timekey, R1.actual1, R1.ACT_value1 , R1.REF_value1, F1.value1 forecast
,R1.ratio1 f1
,R5.ratio1 as f5
,R52.ratio1 as f52
, (isnull(F1.value1*R1.ratio1,0) + isnull(F1.value1*R5.ratio1,0) + isnull(F1.value1*R52.ratio1,0) )
/ (case when R1.ratio1 is not null then 1 else 0 end + case when R5.ratio1 is not null then 1 else 0 end + case when R52.ratio1 is not null then 1 else 0 end ) f
FROM F1
left join R as R1 on F1.timekey=R1.timekey+1 
left join R as R5 on F1.timekey=R5.timekey+5
left join R as R52 on F1.timekey=R52.timekey+52
WHERE (case when R1.ratio1 is not null then 1 else 0 end + case when R5.ratio1 is not null then 1 else 0 end + case when R52.ratio1 is not null then 1 else 0 end ) >0
)  

INSERT INTO [dbo].'+ @fact_day 
        +' ([date],activity_id,forecast_id,import_id,' + @fields_target + ',site_id) '+
       ' SELECT D.date, '+ convert(varchar(10),@activity_id)+', ' + convert(varchar(10),@forecast_id) 
	+ ',' + convert(varchar(10),@import_id)  
    + ',R1.f/7 ,' +  convert(nvarchar(max),@site_id) 
    + ' FROM R1 
INNER JOIN [dbo].[A_TIME_DATE] D on R1.timekey=D.[weeks_2000] 
WHERE D.date between ''' + convert(varchar(10),@date_import_from,126) + ''' and '''+ convert(varchar(10),@date_import_until,126)+ ''''

        
 		BEGIN TRY
			IF @commands like '%-PRINT%' PRINT @sqlCommand 
            SET @output=@output+ '-- INSERT DAY DATA QUERY <br>'+ @sqlCommand + '<br><br>';
			IF @commands not like '%-PRINT%' AND @date_import_until>=@date_import_from 
            BEGIN 
                IF @errors=0 BEGIN EXEC( @sqlCommand);SET @rows= @@ROWCOUNT;
                    SET @output=@output+'-- INSERT QUERY EXECUTED <br>';
                    SET @output=@output+'day records inserted ' + convert(varchar(10),@rows)+'<br><br>';  
                END              
                IF @date_import_until<@date_import_from AND @commands like '%-LOG_ROWCOUNT%'  EXEC dbo.[A_SP_SYS_LOG] 'IMPORT WARNING' ,@session_id ,@import_id ,'NODATA ON INSERT', @sqlCommand  
                IF @commands like '%-LOG_ROWCOUNT%' EXEC dbo.[A_SP_SYS_LOG] 'LOG ROWS' ,@session_id ,@import_id ,'RECORDS INSERT DAY',@rows  
                IF @commands like '%-LOG_INSERT%' EXEC dbo.[A_SP_SYS_LOG] 'LOG INSERT ROWS' ,@session_id ,@import_id ,'INSERT QUERY DAY',@sqlCommand 
            END
        END TRY
   		BEGIN CATCH  
   			SET @data=JSON_MODIFY( @data,'$.error',dbo.[A_FN_SYS_ErrorJson]()) 
            SET @output=@output+dbo.[A_FN_SYS_ErrorJson]()+'<br><br>'
			EXEC dbo.[A_SP_SYS_LOG] 'IMPORT ERROR' ,@session_id ,@import_id ,'INSERT DAY',@sqlCommand
	    END CATCH;   	  

 		FETCH NEXT FROM TAB_CURSOR 
 		INTO @import_id 
 			,@activity_id
     		,@forecast_id
     		,@p1
     		,@p2
     		,@p3
     		,@p4
     		,@p5
     		,@date_import_from
     		,@date_import_until
     		,@fields_source
     		,@fields_target
     		,@schedule
     		,@filter
     		,@source
     		,@group_by
			,@commands 
			,@procedure_name 
			,@site_id
            ,@parent
   		END -- END OF FETCHING IMPORTS

	CLOSE TAB_CURSOR 
	DEALLOCATE TAB_CURSOR
    SET @output=@output + '<br><br>This import procedure calculates a forecast from a forecast source for a corelated activity 
    based on the historical ratios defined by the corelated activity and corelated forecast (actuals). 
    <br>Procedure parameters: 
    <br>p1  - activity_corelated_id = '+ convert(varchar(max),@activity_corelated_id)+';
    <br>p2 - forecast_corelated_id = '+ convert(varchar(max),@forecast_corelated_id)+';
    <br>p3 - forecast_source_id = '+ convert(varchar(max),@forecast_source_id)+';
    <br>p4 - lag - '+ convert(varchar(max),@lag)+';
    <br>p1 will be replaced by activity parent ='+ convert(varchar(max),@parent)+' if p1 is left empty.';
 
	SET @data=format(DATEDIFF(MILLISECOND,@start_time,getdate())/1000.0,'N3')
	EXEC dbo.[A_SP_SYS_LOG] 'PROCEDURE FINISH' ,@session_id  ,null  , @procedure_name , @data

    SET @output=@output + '<br> It took ' + @data + ' sec.'
    IF @commands like '%-OUTPUT%'  select @output as SQL_OUTPUT

END
-- VERSION 20220705 
-- Parent activity id is added to complement p1
GO
