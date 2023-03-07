 
/****** Object:  StoredProcedure [dbo].[A_SP_FC_PARALLEL]    Script Date: 7-3-2023 10:51:07 ******/
SET ANSI_NULLS OFF
GO
SET QUOTED_IDENTIFIER ON
GO



-- template stored procedure for loading data from source tables
ALTER  PROCEDURE [dbo].[A_SP_FC_PARALLEL]
 @import_id int = 0
,@activity_id int = 0 -- serie activity_id
,@forecast_id int = 0 -- serie forecast_id
,@commands varchar(2000)='' -- -LOG_ROWCOUNT -LOG_INSERT -LOG_DELETE -PRINT -NOGROUPBY -SUMFIELDS -SET_IMPORT_ID -HELP -VERSION
,@procedure_name nvarchar(200)=''
,@site_id int = 0
,@category nvarchar(200) ='' -- procedure category to run; empty to run all
,@session_id varchar(50)  = null
AS
BEGIN
    SET NOCOUNT ON;
    SET DATEFIRST 1
--  configuration
    DECLARE @sqlCommand NVARCHAR(MAX) =''-- 
    DECLARE @SP varchar(20) = 'A_SP_FC_PARALLEL';

--  source data parameters
	DECLARE @filter nvarchar(4000)=''           -- where filter for filtering source data
	DECLARE @date_import_from date='9999-01-01' -- calculated by the import query using imports and procedures fields
	DECLARE @date_import_until date='1900-01-01'
	DECLARE @fields_source varchar(2000)=''     -- source fields
	DECLARE @fields_target varchar(2000)=''     -- target fields value1
	DECLARE @schedule varchar(2000)=''
	DECLARE @source varchar(2000)=''
	DECLARE @group_by varchar(2000)=''

-- target parameters
    DECLARE @fact_day nvarchar(200) ='[A_FACT_DAY]' -- data per day stored here
    DECLARE @fact_intraday nvarchar(200)='[A_FACT_INTRADAY]' -- data per day/interval_id is stored here. conform a_time_interval dimension
    
    -- parameters
	DECLARE @p1 varchar(2000)=''                
	DECLARE @p2 varchar(2000)=''
	DECLARE @p3 varchar(2000)=''
	DECLARE @p4 varchar(2000)=''
	DECLARE @p5 varchar(2000)=''
	DECLARE @groupby varchar(2000)=''

	-- log variables
	DECLARE @data  varchar(4000)=''  -- log data
	DECLARE @rows INT   -- keep affected rows
	DECLARE @start_time datetime=null
    DECLARE @output nvarchar(max)='';
    DECLARE @imports_fetched int=0
    DECLARE @errors int = 0 ; -- import errors
    DECLARE @errors_global int = 0; 
    DECLARE @rows_deleted_global INT = 0;
    DECLARE @rows_inserted_global INT = 0;
    DECLARE @summary varchar(200) = '';  

	-- source data analysis
	DECLARE @date_source_min date='9999-01-01' -- calculated by the import query using imports and procedures fields
	DECLARE @date_source_max date='1900-01-01'
    DECLARE @day_source varchar(max)=''

	-- intraday parameters
	DECLARE @intraday_join varchar(2000)=''
	DECLARE @intraday_interval_id varchar(200)='interval_id'
	DECLARE @intraday_duration varchar(5)='15' -- default intraday interval duration in min
    DECLARE @intraday_source varchar(max)=''

    IF @session_id is null BEGIN SET @session_id=newid() END

	DECLARE TAB_CURSOR CURSOR  FOR 
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
    FROM   dbo.[A_IMPORT_RUN]
    WHERE   (import_id=@import_id or @import_id=0) 
		AND (site_id=@site_id or site_id is null or @site_id=0)
		AND ([procedure_id] = try_convert(int,@procedure_name) or [procedure_name] like @procedure_name or @procedure_name='' ) 
		AND (activity_id=@activity_id or @activity_id=0)
        AND ([category] like @category or @category='')
        AND procedure_code=@SP
        AND active=1
    ORDER BY [sort_order],[procedure_name];
    
	EXEC dbo.[A_SP_SYS_LOG] @category='MAIS SP', @session=@session_id, @site = @site_id, @object=@SP, @step='SQL SP START', @data=@commands;
	SET @start_time     = GETDATE()

----------------------------------------------
--  FETCH ALL IMPORTS FOR THE CURRENT SP
----------------------------------------------
	OPEN TAB_CURSOR 

	FETCH NEXT FROM TAB_CURSOR 

	INTO   @import_id 
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
        
        DECLARE @on_schedule bit=1
        SET @errors  = 0 
        SET @imports_fetched=@imports_fetched+1;

        -- if source or target fields are empty set it by default to all value fields
        IF @fields_source='' OR @fields_target='' BEGIN 
            SET @fields_source='[value1],[value2],[value3],[value4],[value5],[value6],[value7],[value8],[value9],[value10]';
            SET @fields_target='[value1],[value2],[value3],[value4],[value5],[value6],[value7],[value8],[value9],[value10]';
            SET @output=@output+'-- <b>WARNING: Source or target fields are not specified. Setting defaults. <b>';
        END

        IF @schedule>'' BEGIN
            SET @sqlCommand = N'SELECT @on_schedule =  CASE WHEN ' +@schedule + ' THEN 1 ELSE 0 END'
            EXEC sp_executesql @sqlCommand, N'@on_schedule bit OUTPUT', @on_schedule=@on_schedule OUTPUT
        END 

        IF @filter='' SET @filter='S.activity_id='+convert(varchar(10),@activity_id)

 		SET @p1 = TRY_CONVERT(INT,@p1) ; -- forecast from id 
 		SET @p5 = TRY_CONVERT(INT,@p5) ; -- LAG YEARS      
		
        IF @p2 like '%m%' BEGIN
        -- procedure is per maand
            SET @p2 = '[day_month]'	--	DAY LEVEL FIELD (FROM TIME_DATE)
            SET @p3 = '[month]'		--	SEAZON LEVEL
            SET @p4 = '[year]' 		--	YEAR LEVEL
        END
        ELSE BEGIN -- DEFAULT per week, overwrite parameters in case garbadge in
            SET @p2 = '[day_week]'
            SET @p3 = '[week]'
            SET @p4 = '[year52]' 
        END
        
        SET @date_import_from=isnull(@date_import_from,[dbo].[A_FN_TI_FirstDayCurrentYear](NULL));
 		SET @date_import_until=isnull(@date_import_until,[dbo].[A_FN_TI_LastDayCurrentYear](NULL));

		-- we skip source delta check , there are no requirements

        -- test parameters before running all
        IF @activity_id=0 OR @forecast_id=0 SET @errors=@errors+1 
        IF @date_import_until<@date_import_from  BEGIN 
            SET @errors=@errors+1 
            SET @output=@output+'-- <b>ERROR: date_import_from is larger than date_import_until. <br> 
            Queries will not be executed due to errors. <br>
            Please check if source exists and/or the dates parameters.</b><br>'   ;

            EXEC dbo.[A_SP_SYS_LOG] @category='MAIS SP', @session=@session_id, @site = @site_id, @object=@SP, @step='IMPORT DATE RANGE TEST', @result='Failed' ;
            PRINT @output;
        END
		 
	----------------------------------------------------------------------------------------------------------------------
	--  CLEAN DAY

 	-- this SP supports batch loading, so several activities passed in the @filter parameter, 
	-- so we deviate from the standard import delete here
	--------------------------------------------------------------------------------	
		SET @sqlCommand =' DELETE S FROM ' + @fact_day + ' S'+ 
		' INNER JOIN [A_DIM_ACTIVITY] A on S.activity_id=A.activity_id' +
        ' WHERE ' + @filter + ' AND S.forecast_id=' + convert(varchar(10),@forecast_id) 
        + ' AND S.site_id =' + convert(varchar(10),@site_id) 
        + ' AND S.date between ''' 
		 + convert(varchar(10),@date_import_from,126) + ''' AND '''+ convert(varchar(10),@date_import_until,126) + ''';';
 		BEGIN TRY			
            SET @output=@output+'-- DELETING DAY DATA <br>'+@sqlCommand+'<br><br>';
			IF @commands not like '%-PRINT%' 
            BEGIN
                IF @errors=0 BEGIN 
                    IF (@on_schedule=1) BEGIN                     
                        EXEC( @sqlCommand); SET @rows = @@ROWCOUNT   
                        SET @rows_deleted_global=@rows_deleted_global+@rows;         
                        SET @output=@output+'day records deleted ' + convert(varchar(10),@rows)+'<br><br>'
                        IF @commands like '%-LOG_ROWCOUNT%' EXEC dbo.[A_SP_SYS_LOG] @category='MAIS SP', @result='Succeeded', @session=@session_id, @site = @site_id, @object=@SP, @object_sub=@procedure_name, @object_id=@import_id, @step='-LOG_ROWCOUNT DELETED',@data=@fact_day, @value=@rows; 
                        IF @commands like '%-LOG_DELETE%' EXEC dbo.[A_SP_SYS_LOG] @category='MAIS SP', @result='Succeeded', @session=@session_id, @site = @site_id, @object=@SP, @object_sub=@procedure_name, @object_id=@import_id, @step='-LOG_DELETE', @data=@sqlCommand; 
                    END
                    ELSE SET @output=@output+'-- <b>WARNING: Delete query was not executed due to the schedule parameter.</b> <br>';
                END
                ELSE SET @output=@output+'-- <b>ERROR: Queries will not be executed due to errors. Please check the parameters.</b><br>';              
            END ELSE PRINT @sqlCommand
 		END TRY
 		BEGIN CATCH  
            SET @errors=@errors+1;
			SET @data=dbo.[A_FN_SYS_ErrorJson]() 
            SET @sqlCommand = @sqlCommand + '/* error information:' + @data + '*/';
            PRINT @sqlCommand;
            SET @output=@output+ '<b>ERROR:' + @data+'</b><br><br>';
			EXEC dbo.[A_SP_SYS_LOG] @category='MAIS SP', @result='Failed', @session=@session_id, @site = @site_id, @object=@SP, @object_sub=@procedure_name, @object_id=@import_id, @step='CLEAN DAY', @data=@sqlCommand; 
 		END CATCH;   

	--------------------------------------------------------------------------------------------------------------------------
	--  INSERT TO DAY
	-------------------------------------------------------------------------------------
 		 
		SET @sqlCommand = ' INSERT INTO '+ @fact_day 
        +' ([date],activity_id,forecast_id,import_id,' + @fields_target + ',site_id) '+
       ' SELECT D.date, activity_id, ' + convert(varchar(10),@forecast_id) 
	+ ' as forecast_id, ' + convert(varchar(10),@import_id) + ','+
	+ @fields_source +',site_id FROM ( select S.*, d.' + @p2+', d.'+@p3+', d.'+@p4+',A.activity_set,A.domain,A.category'+
   		' FROM ' + @fact_day +'  S'+
		' INNER JOIN [A_DIM_ACTIVITY] A on S.activity_id=A.activity_id' +
   		' INNER JOIN [A_TIME_DATE] d on S.[date]=d.[date]' +
   		' AND forecast_id=' + convert(varchar(10),@p1) + ' AND ' + @filter +' WHERE S.site_id =' + convert(varchar(10),@site_id) + ' ) as SD'+
     	 ' INNER JOIN [A_TIME_DATE] D on D.date between ''' 
		 + convert(varchar(10),@date_import_from,126) + ''' and '''+ convert(varchar(10),@date_import_until,126) 
		 + ''' AND SD.' + @p2+'=D.' + @p2+' AND ((SD.'+@p3+'=D.'+@p3+' and SD.'+@p4+'=(D.'+@p4+'-' + convert(varchar(10),@p5)+ ')));'
 	
 		BEGIN TRY
            SET @output=@output+ '-- INSERTING DAY DATA <br>'+ @sqlCommand + '<br><br>';
			IF @commands not like '%-PRINT%'
            BEGIN 
                IF @errors=0 BEGIN 
                    IF (@on_schedule=1) BEGIN
                        EXEC( @sqlCommand); SET @rows= @@ROWCOUNT;
                        SET @rows_inserted_global=@rows_inserted_global+@rows;
                        IF @commands like '%-LOG_ROWCOUNT%' EXEC dbo.[A_SP_SYS_LOG] @category='MAIS SP', @result='Succeeded', @session=@session_id, @site = @site_id, @object=@SP, @object_sub=@procedure_name, @object_id=@import_id, @step='-LOG_ROWCOUNT INSERT',@data=@fact_day, @value=@rows; 
                        IF @commands like '%-LOG_INSERT%' EXEC dbo.[A_SP_SYS_LOG] @category='MAIS SP', @result='Succeeded', @session=@session_id, @site = @site_id, @object=@SP, @object_sub=@procedure_name, @object_id=@import_id, @step='-LOG_INSERT', @data=@sqlCommand; 
                        SET @output=@output+' day records inserted ' + convert(varchar(10),@rows)+'<br><br>'  
                    END
                    ELSE SET @output=@output+'-- <b>WARNING: Delete query was not executed due to the schedule parameter.</b> <br>'
                END
                ELSE SET @output=@output+'-- <b>ERROR: Queries will not be executed due to errors. Please check the parameters.</b><br>'       
            END 
            ELSE PRINT @sqlCommand
        END TRY
   		BEGIN CATCH  
            SET @errors=@errors+1;
   			SET @data=dbo.[A_FN_SYS_ErrorJson]()
            SET @sqlCommand = @sqlCommand + '/* error information:' + @data + '*/';
            PRINT @sqlCommand; 
            SET @output=@output+ '<b>ERROR:' + @data+'</b><br>'
			EXEC dbo.[A_SP_SYS_LOG] @category='MAIS SP', @result='Failed', @session=@session_id, @site = @site_id, @object=@SP, @object_sub=@procedure_name, @object_id=@import_id, @step='INSERT DAY', @data=@sqlCommand; 
	    END CATCH;   	  

        SET @errors_global=@errors_global+@errors;

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

	SET @data=format(DATEDIFF(MILLISECOND,@start_time,getdate())/1000.0,'N3')
    SET  @summary='{}'
		set  @summary=JSON_MODIFY( @summary,'$.ImportsFetched',CONVERT(varchar(10), @imports_fetched))
		set  @summary=JSON_MODIFY( @summary,'$.RowsDeleted',CONVERT(varchar(10), @rows_deleted_global))
		set  @summary=JSON_MODIFY( @summary,'$.RowsInserted',CONVERT(varchar(10), @rows_inserted_global))
        set  @summary=JSON_MODIFY( @summary,'$.Errors',CONVERT(varchar(10), @errors_global))
		 
	EXEC dbo.[A_SP_SYS_LOG] @category='MAIS SP', @session=@session_id, @site = @site_id, @object=@SP
    , @step='SQL SP FINISH', @duration=@data, @result='Succeeded', @data=@summary;

    SET @output=@output + '<br> It took ' + @data + ' sec.'

    
    DECLARE @version nvarchar(max)='
    <H3>VERSION INFORMATION </H3>
    -- version 20220711  <br>
    -- scheduling parameter added  <br>
    -- more error handling  <br>

    -- version 20220622  <br>
    -- default day and intraday tables are used if the source parameter left empty.  <br>

    -- version 20220603  <br>
    -- generic import of transactional data into time series/ MAIS data format  <br>
    -- this SP will generate queries and run/print them for every row from [A_IMPORT_RUN] view  <br>
    -- template stored procedure for loading data from source tables  <br>
';
    IF @commands like '%-VERSION%'  SET @output = @output + @version;

    DECLARE @help nvarchar(max)='
	<H3>HELP INFORMATION </H3>
	Calculates historical parallel periods. It can run on the current acitivity or in a batch mode. 
	<br> Batch mode calculates a number of activities in a single query. This is done for easier configuration and performance considerations)
    <br> P1 - forecast from  
    <br> P2 - level; day_week (default, per week), day_month - per month  
    <br> P3 - filled in automatically based on P2   
    <br> P4 - idem aan P3  
    <br> P5 - lag years, 1 for last year, 2 for 2 years ago , etc. 

    <br> <br> Filter - Batch mode - any filter on the activity fields, the current activity used if filter is empty. 
	<br> Single activity mode - If empty, the current activity will go <br>
    <br> Source - inactive, A_FACT_DAY will be substituted automatically
';
    IF @commands like '%-HELP%'  SET @output = @output + @help  
    IF @commands like '%-OUTPUT%'  select @output as SQL_OUTPUT

END
