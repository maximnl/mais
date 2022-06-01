SET ANSI_NULLS OFF
GO
SET QUOTED_IDENTIFIER ON
GO



-- template stored procedure for loading data from source tables
ALTER  PROCEDURE [dbo].[A_SP_IMPORT_YTM]
 @activity_id int = 0 
,@session_id uniqueidentifier   = null
,@commands varchar(2000)='' -- '-LOG_ROWCOUNT -LOG_INSERT -LOG_DELETE' --'-PRINT' -NOGROUPBY -SUMFIELDS -SET_IMPORT_ID
,@procedure_name nvarchar(200)='A_SP_IMPORT_YTM'
,@site_id int =1
,@import_id int =0
AS
BEGIN

    SET NOCOUNT ON;
	
--  configuration
	DECLARE @fact_day nvarchar(200)='[A_FACT_DAY]' -- data per day stored here
	DECLARE @fact_intraday nvarchar(200)='[A_FACT_INTRADAY]' -- data per day/interval_id is stored here. conform a_time_interval dimension
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

	-- login parameters
	DECLARE @data  varchar(4000)=''  -- log data
	DECLARE @rows INT   -- keep affected rows
	DECLARE @start_time datetime=null
    DECLARE @output nvarchar(max)='';

	-- source data analysis
	DECLARE @date_source_min date='9999-01-01' -- calculated by the import query using imports and procedures fields
	DECLARE @date_source_max date='1900-01-01'

	-- intraday parameters
	DECLARE @intraday_join varchar(2000)=''
	DECLARE @intraday_interval_id varchar(200)='interval_id'
	DECLARE @intraday_duration varchar(5)='15' -- default intraday interval duration in min

    
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
      ,[filter]
      ,[source]
      ,[group_by]
	  ,concat(@commands,' ',commands)
	  ,[procedure_name]
	  ,site_id
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

	WHILE @@FETCH_STATUS = 0 

   	BEGIN 
		 SET @fields_target='[value1],[value2],[value3],[value4],[value5],[value6],[value7],[value8],[value9],[value10]'
 		 IF TRY_CONVERT(INT,@p1)=0 SET @p1 = 1  -- forecast from id / default actuals forecast		 
		 IF LEN(@filter)<4 SET @filter='S.activity_id='+convert(varchar(10),@activity_id)
		 IF @p2 like '%w%' BEGIN
			-- procedure is per week
			SET @p2 = '[year_week]' 
			SET @p3 = '[year52]' 
		 END
		 ELSE BEGIN -- DEFAULT per month, overwrite parameters in case garbadge in
			SET @p2 = '[year_month_char]'	--	DAY LEVEL FIELD (FROM TIME_DATE)
			SET @p3 = '[year]'		--	SEAZON LEVEL
		 END

		 SET @date_import_from=isnull(@date_import_from,[dbo].[A_FN_TI_FirstDayCurrentYear](NULL));
 		 SET @date_import_until=isnull(@date_import_until,[dbo].[A_FN_TI_LastDayCurrentYear](NULL));

		-- we skip source delta check , there are no requirements
		 
	----------------------------------------------------------------------------------------------------------------------
	--  CLEAN DAY

 	-- this SP supports batch loading, so several activities passed in the @filter parameter, 
	-- so we deviate from the standard import delete here
	--------------------------------------------------------------------------------	
		SET @sqlCommand ='DELETE S FROM [A_FACT_DAY] S'+ 
		' INNER JOIN [A_DIM_ACTIVITY] A on S.activity_id=A.activity_id' +
        ' WHERE S.forecast_id=' + convert(varchar(10),@forecast_id) + ' AND ' + @filter + ' and date between ''' 
		 + convert(varchar(10),@date_import_from,126) + ''' AND '''+ convert(varchar(10),@date_import_until,126) + '''' + '	AND S.site_id = ' +  convert(nvarchar(max),@site_id)  ;
		  
 		BEGIN TRY
			IF @commands like '%-PRINT%' PRINT @sqlCommand 
            SET @output=@output+'-- DELETING DAY DATA <br>'+@sqlCommand+'<br><br>';
			IF @commands not like '%-PRINT%' AND @date_import_until>=@date_import_from 
            BEGIN
                EXEC( @sqlCommand)
                SET @rows= @@ROWCOUNT
               
                IF @date_import_until<@date_import_from AND  @commands like '%-LOG_ROWCOUNT%' EXEC dbo.[A_SP_SYS_LOG]  'IMPORT WARNING' ,@session_id ,@import_id ,'NODATA ON DELETE', @sqlCommand  
                SET @output=@output+'day records deleted ' + convert(varchar(10),@rows)+'<br><br>'
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
 		
SET @sqlCommand = ' INSERT INTO '+ @fact_day 
+' ([date],activity_id,forecast_id,import_id,' + @fields_target + ',site_id) '
+   ' SELECT date, activity_id, ' + convert(varchar(10),@forecast_id) + ','+convert(varchar(10),@import_id)
+',sum(value1) over (partition by activity_id, [year] order by [date] rows unbounded preceding) value1'+
',sum(value2) over (partition by activity_id, [year] order by [date] rows unbounded preceding) value2'+
',sum(value3) over (partition by activity_id, [year] order by [date] rows unbounded preceding) value3'+
',sum(value4) over (partition by activity_id, [year] order by [date] rows unbounded preceding) value4'+
',sum(value5) over (partition by activity_id, [year] order by [date] rows unbounded preceding) value5'+
',sum(value6) over (partition by activity_id, [year] order by [date] rows unbounded preceding) value6'+
',sum(value7) over (partition by activity_id, [year] order by [date] rows unbounded preceding) value7'+
',sum(value8) over (partition by activity_id, [year] order by [date] rows unbounded preceding) value8'+
',sum(value9) over (partition by activity_id, [year] order by [date] rows unbounded preceding) value9'+
',sum(value10) over (partition by activity_id, [year] order by [date] rows unbounded preceding) value10'+
',site_id 
FROM (SELECT S.activity_id,D.'+@p2+',D.'+@p3+' as year , max(d.date) as [date] 
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
, ' +  convert(nvarchar(max),@site_id) + ' as site_id'+
' FROM [A_FACT_DAY] S INNER JOIN [A_TIME_DATE] D on S.Date=D.Date '+
' INNER JOIN [A_DIM_ACTIVITY] A on S.activity_id=A.activity_id' +
' WHERE forecast_id=' + convert(varchar(10),@p1) + ' AND ' + @filter +
+ ' AND S.date between '''+ convert(varchar(10),@date_import_from,126) + ''' and '''+ convert(varchar(10),@date_import_until,126)
+ ''' GROUP BY S.activity_id, D.'+@p2+',D.'+@p3+'
) AS T'

		 
 		BEGIN TRY
			IF @commands like '%-PRINT%' PRINT @sqlCommand 
            SET @output=@output+ '-- INSERT QUERY DAY DATA <br>'+ @sqlCommand + '<br><br>';
			IF @commands not like '%-PRINT%' AND @date_import_until>=@date_import_from 
            BEGIN 
                EXEC( @sqlCommand);
                SET @rows= @@ROWCOUNT
                IF @date_import_until<@date_import_from AND @commands like '%-LOG_ROWCOUNT%'  EXEC dbo.[A_SP_SYS_LOG] 'IMPORT WARNING' ,@session_id ,@import_id ,'NODATA ON INSERT', @sqlCommand  
                IF @commands like '%-LOG_ROWCOUNT%' EXEC dbo.[A_SP_SYS_LOG] 'LOG ROWS' ,@session_id ,@import_id ,'RECORDS INSERT DAY',@rows  
                IF @commands like '%-LOG_INSERT%' EXEC dbo.[A_SP_SYS_LOG] 'LOG INSERT ROWS' ,@session_id ,@import_id ,'INSERT QUERY DAY',@sqlCommand 
                SET @output=@output+'day records inserted ' + convert(varchar(10),@rows)+'<br><br>'  
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
   		END -- END OF FETCHING IMPORTS

	CLOSE TAB_CURSOR 
	DEALLOCATE TAB_CURSOR

	SET @data=DATEDIFF(second,@start_time,getdate())
	EXEC dbo.[A_SP_SYS_LOG] 'PROCEDURE FINISH' ,@session_id  ,null  , @procedure_name , @data
    IF @commands like '%-OUTPUT%'  select @output as SQL_OUTPUT

END
GO
