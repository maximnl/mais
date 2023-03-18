 
/****** Object:  StoredProcedure [dbo].[A_SP_FC_PARALLEL]    Script Date: 18-3-2023 10:59:32 ******/
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
   
    DECLARE @SP varchar(20) = 'A_SP_FC_PARALLEL';
  
-- SNIPPET INIT ********************************************************
	SET NOCOUNT ON;
    SET DATEFIRST 1  -- SET MONDAY AS THE FIRST DAY OF WEEK 

	--  ADDITIONAL VARIABLES FOR FETCHING CONFIGURATION FROM THE IMPORT DATA	
	DECLARE @p1 varchar(2000)=''  -- parameters
	DECLARE @p2 varchar(2000)=''
	DECLARE @p3 varchar(2000)=''
	DECLARE @p4 varchar(2000)=''
	DECLARE @p5 varchar(2000)=''
	DECLARE @date_import_from date='9999-01-01' -- calculated by the import query using imports and procedures fields
	DECLARE @date_import_until date='1900-01-01'
	DECLARE @fields_source varchar(2000)='' -- source fields
	DECLARE @fields_target varchar(2000)=''  -- target fields value1
	DECLARE @schedule varchar(2000)=''
	DECLARE @filter nvarchar(4000)='' -- where filter for filtering source data
	DECLARE @source varchar(2000)=''
	DECLARE @date varchar(2000)=''
    DECLARE @parent varchar(200)=''

	-- PROCEDURE SUPPORT GLOBAR VARIABLES
	DECLARE @output nvarchar(max)='';
	DECLARE @imports_fetched int=0
	DECLARE @start_time datetime=null
	DECLARE @step varchar(200)=''
    DECLARE @errors_global int = 0; 
	DECLARE @warnings_global int =0;
    DECLARE @rows_deleted_global INT = 0;
    DECLARE @rows_inserted_global INT = 0;
	DECLARE @rows_updated_global INT = 0;

    IF @session_id is null SET @session_id=newid();    
--------------------------------------------------------------------------------------------------
	SET @step='SQL SP START';
--------------------------------------------------------------------------------------------------
	EXEC dbo.[A_SP_SYS_LOG] @category='MAIS SP', @session=@session_id, @site = @site_id, @object=@SP, @step=@step, @data=@commands,@result='Succeeded'
	SET @start_time     = GETDATE()
	
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
      ,parent
    FROM   dbo.[A_IMPORT_RUN]
    WHERE   (import_id=@import_id or @import_id=0) 
    AND (site_id=@site_id or site_id is null or @site_id=0)
    AND ([procedure_id] = try_convert(int,@procedure_name) or [procedure_name] like @procedure_name or @procedure_name='') 
    AND (activity_id=@activity_id or @activity_id=0)
    AND procedure_code=@SP 
    AND active=1
    ORDER BY [sort_order],[procedure_name]

	----------------------------------------------
	--  FETCH ALL IMPORTS FOR THE CURRENT SP
	----------------------------------------------
	OPEN TAB_CURSOR 
	FETCH NEXT FROM TAB_CURSOR 
	INTO     @import_id 
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
     		,@date
			,@commands
			,@procedure_name 
			,@site_id
            ,@parent
	WHILE @@FETCH_STATUS = 0 
   	BEGIN 

		-- IMPORT SUPPORT VARIABLES 
		DECLARE @fact_day nvarchar(200)='[A_FACT_DAY]' -- day dataset 
		DECLARE @fact_intraday nvarchar(200)='[A_FACT_INTRADAY]' -- intraday dataset  
		DECLARE @sqlCommand NVARCHAR(MAX) -- 	
		DECLARE @data  varchar(4000)=''  -- log data
		DECLARE @rows INT=0   -- keep affected rows
		DECLARE @rows_deleted INT=0
		DECLARE @rows_inserted INT=0
		DECLARE @rows_updated INT = 0;
		DECLARE @errors int = 0 ; -- import errors
		DECLARE @warnings int =0;
		DECLARE @start_time_step datetime=null
		DECLARE @start_time_import datetime=null
		DECLARE @duration real=null	
		DECLARE @date_source_min date='9999-01-01' -- source date analysis for delta range
		DECLARE @date_source_max date='1900-01-01'
		DECLARE @day_source varchar(max)=''
		DECLARE @on_schedule bit=1

		SET @imports_fetched=@imports_fetched+1;
		SET @start_time_import     = GETDATE()

		-------------------------------------------------------
		SET @step= 'SCHEDULE TEST';
		-------------------------------------------------------
		SET @start_time_step     = GETDATE()
		IF @schedule>'' BEGIN TRY
            SET @sqlCommand = N'SELECT @on_schedule =  CASE WHEN ' + @schedule + ' THEN ''1'' ELSE ''0'' END'
            EXEC sp_executesql @sqlCommand, N'@on_schedule bit OUTPUT', @on_schedule=@on_schedule OUTPUT
        END TRY
		BEGIN CATCH  
            SET @errors=@errors+1;
			SET @data=dbo.[A_FN_SYS_ErrorJson]() 
            SET @output=@output+ '<b>error information ' + @data+'</b></br>' + @sqlCommand + '</br></br>';
            PRINT @data; PRINT @sqlCommand ; 
			SET @data=@data + @sqlCommand;
            EXEC dbo.[A_SP_SYS_LOG] @category='MAIS SP', @result='Failed', @session=@session_id, @site = @site_id, @object=@SP, @object_sub=@procedure_name, @object_id=@import_id, @step=@step, @data=@data; 
        END CATCH;   

		--------------------------------------------------------------------------------------------------
		SET @step = 'PARAMETERS TEST';
		--------------------------------------------------------------------------------------------------
		SET @start_time_step     = GETDATE()

		-- FOLLOWED ALWAYS BY A PROCEDURE SPECIFIC PARAMETERS SETUP AND TESTS

-- SNIPPET INIT END  *********************************************************

        -- if source or target fields are empty set it by default to all value fields
        IF @fields_source='' OR @fields_target='' BEGIN 
            SET @fields_source='[value1],[value2],[value3],[value4],[value5],[value6],[value7],[value8],[value9],[value10]';
            SET @fields_target='[value1],[value2],[value3],[value4],[value5],[value6],[value7],[value8],[value9],[value10]';
			IF @commands like '%-LOG_WARNING%' BEGIN
				SET @data='WARNING: [source_fields] or [target_fields] parameters are not specified. Setting defaults.
				 import id= ' + convert(varchar(10),@import_id) + ' Step: ' + @step; 
				PRINT @data; SET @output=@output+'<b>' + @data + '</b><br>';  
				EXEC dbo.[A_SP_SYS_LOG] @category='MAIS SP', @result='Warning', @session=@session_id, @site = @site_id, @object=@SP, @object_sub=@procedure_name, @object_id=@import_id, @step=@step, @data=@data;   
			END
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

        IF  @date_import_until<@date_import_from  BEGIN  
			SET @warnings=@warnings+1;
			IF @commands like '%-LOG_WARNING%' BEGIN
				SET @data='Warning: Date import from is larger than date import until. The import query will not be executed. 
				 import id= ' + convert(varchar(10),@import_id) + '. filter=' + @filter + ' Step: ' + @step; 
				PRINT @data; SET @output=@output+'<b>' + @data + '</b><br>';  
				EXEC dbo.[A_SP_SYS_LOG] @category='MAIS SP', @result='Warning', @session=@session_id, @site = @site_id, @object=@SP, @object_sub=@procedure_name, @object_id=@import_id, @step=@step, @data=@data;   
			END
		END
		 
	--------------------------------------------------------------------------------	
		SET @step='DELETE DAY'
		----------------------------------------------------------------------------------------------------------------------
		SET @sqlCommand =' DELETE S FROM ' + @fact_day + ' S'+ 
		' INNER JOIN [A_DIM_ACTIVITY] A on S.activity_id=A.activity_id' +
        ' WHERE ' + @filter + ' AND S.forecast_id=' + convert(varchar(10),@forecast_id) 
        + ' AND S.site_id =' + convert(varchar(10),@site_id) 
        + ' AND S.date between ''' 
		 + convert(varchar(10),@date_import_from,126) + ''' AND '''+ convert(varchar(10),@date_import_until,126) + ''';';


 		 		
-- SNIPPET QUERY EXECUTE START ********************************************************
		SET @start_time_step     = GETDATE();
		SET @rows=0;
		IF @commands like '%-LOG_QUER%' BEGIN
			SET @data = @step +  ' QUERY'; 
			SET @output=@output + @data + '<br>'+@sqlCommand+'<br><br>';  			 
			EXEC dbo.[A_SP_SYS_LOG] @category='MAIS SP', @result='Debug', @session=@session_id, @site = @site_id, @object=@SP, @object_sub=@procedure_name
			, @object_id=@import_id, @step=@step, @data=@sqlCommand; 
			PRINT @data; PRINT @sqlCommand;
		END
         
        IF @commands not like '%-PRINT%' AND  @date_import_until>=@date_import_from BEGIN TRY
            IF @errors=0 BEGIN 
                IF (@on_schedule=1 OR @commands like '%-NOSCHEDUL%' ) BEGIN
                    EXEC( @sqlCommand); SET @rows= @@ROWCOUNT;				
					
					SET @duration=convert(real,format(DATEDIFF(MILLISECOND,@start_time_step,getdate())/1000.0,'N3'))
					IF @commands like '%-LOG_ROWCOUNT%' BEGIN
						EXEC dbo.[A_SP_SYS_LOG] @category='MAIS SP', @result='Succeeded', @session=@session_id, @duration=@duration
						, @site = @site_id, @object=@SP, @object_sub=@procedure_name, @object_id=@import_id, @step=@step,@data=@sqlCommand, @value=@rows;
						SET @data=@step + ' query executed. import_id=' + convert(varchar(20),@import_id) + '. Total records ' + convert(varchar(10),@rows);
						SET @output=@output + @data +  '<br>';
						PRINT @data;
					END
                END
                ELSE BEGIN		-- not on schedule, no execution		
					SET @warnings=@warnings+1;
					IF @commands like '%-LOG_WARNING%' BEGIN
						SET @data = 'WARNING: ' + @step + ' query was not executed due to the scheduling parameter.';				
						PRINT @data;
						EXEC dbo.[A_SP_SYS_LOG] @category='MAIS SP', @result='Warning', @session=@session_id, @site = @site_id, @object=@SP, @object_sub=@procedure_name, @object_id=@import_id, @step=@step, @data=@data; 
						SET @output=@output+'<b>' + @data +'</b> <br>';						
					END
				END
            END           
 		END TRY
 		BEGIN CATCH  
            SET @errors=@errors+1;
			SET @data=dbo.[A_FN_SYS_ErrorJson]();
			SET @data = @data + 'ERROR: ' +  'import_id=' + convert(varchar(10),@import_id) + ' STEP '  + @step;
            SET @output=@output+ '<b>' + @data+'</b></br>' + @sqlCommand + '</br></br>';
            PRINT @data; PRINT @sqlCommand ; 
			SET @data=@data + @sqlCommand;
            EXEC dbo.[A_SP_SYS_LOG] @category='MAIS SP', @result='Failed', @session=@session_id, @site = @site_id, @object=@SP, @object_sub=@procedure_name, @object_id=@import_id, @step=@step, @data=@data; 
		END CATCH;   

-- SNIPPET QUERY EXECUTE END  *********************************************************

		SET @rows_deleted=@rows;		

	-------------------------------------------------------------------------------------
        SET @step='INSERT DAY';
		--------------------------------------------------------------------------------------------------------------------------	
 		 
		SET @sqlCommand = ' INSERT INTO '+ @fact_day 
        +' ([date],activity_id,forecast_id,import_id,' + @fields_target + ',site_id) '+
       ' SELECT D.date, activity_id, ' + convert(varchar(10),@forecast_id) 
	+ ' as forecast_id, ' + convert(varchar(10),@import_id) + ','+
	+ @fields_source +',site_id FROM ( select S.*, d.' + @p2+', d.'+@p3+', d.'+@p4+',A.activity_set,A.domain,A.category'+
   		' FROM ' + @fact_day +'  S  WITH (NOLOCK) '+
		' INNER JOIN [A_DIM_ACTIVITY] A  WITH (NOLOCK) on S.activity_id=A.activity_id' +
   		' INNER JOIN [A_TIME_DATE] D  WITH (NOLOCK) on S.[date]=d.[date]' +
   		' AND forecast_id=' + convert(varchar(10),@p1) + ' AND ' + @filter +' WHERE S.site_id =' + convert(varchar(10),@site_id) + ' ) as SD'+
     	 ' INNER JOIN [A_TIME_DATE] D on D.date between ''' 
		 + convert(varchar(10),@date_import_from,126) + ''' and '''+ convert(varchar(10),@date_import_until,126) 
		 + ''' AND SD.' + @p2+'=D.' + @p2+' AND ((SD.'+@p3+'=D.'+@p3+' and SD.'+@p4+'=(D.'+@p4+'-' + convert(varchar(10),@p5)+ ')));'
 	
			
-- SNIPPET QUERY EXECUTE START ********************************************************
		SET @start_time_step     = GETDATE();
		SET @rows=0;
		IF @commands like '%-LOG_QUER%' BEGIN
			SET @data = @step +  ' QUERY'; 
			SET @output=@output + @data + '<br>'+@sqlCommand+'<br><br>';  			 
			EXEC dbo.[A_SP_SYS_LOG] @category='MAIS SP', @result='Debug', @session=@session_id, @site = @site_id, @object=@SP, @object_sub=@procedure_name
			, @object_id=@import_id, @step=@step, @data=@sqlCommand; 
			PRINT @data; PRINT @sqlCommand;
		END
         
        IF @commands not like '%-PRINT%' AND  @date_import_until>=@date_import_from BEGIN TRY
            IF @errors=0 BEGIN 
                IF (@on_schedule=1 OR @commands like '%-NOSCHEDUL%' ) BEGIN
                    EXEC( @sqlCommand); SET @rows= @@ROWCOUNT;				
					
					SET @duration=convert(real,format(DATEDIFF(MILLISECOND,@start_time_step,getdate())/1000.0,'N3'))
					IF @commands like '%-LOG_ROWCOUNT%' BEGIN
						EXEC dbo.[A_SP_SYS_LOG] @category='MAIS SP', @result='Succeeded', @session=@session_id, @duration=@duration
						, @site = @site_id, @object=@SP, @object_sub=@procedure_name, @object_id=@import_id, @step=@step,@data=@sqlCommand, @value=@rows;
						SET @data=@step + ' query executed. import_id=' + convert(varchar(20),@import_id) + '. Total records ' + convert(varchar(10),@rows);
						SET @output=@output + @data +  '<br>';
						PRINT @data;
					END
                END
                ELSE BEGIN		-- not on schedule, no execution		
					SET @warnings=@warnings+1;
					IF @commands like '%-LOG_WARNING%' BEGIN
						SET @data = 'WARNING: ' + @step + ' query was not executed due to the scheduling parameter.';				
						PRINT @data;
						EXEC dbo.[A_SP_SYS_LOG] @category='MAIS SP', @result='Warning', @session=@session_id, @site = @site_id, @object=@SP, @object_sub=@procedure_name, @object_id=@import_id, @step=@step, @data=@data; 
						SET @output=@output+'<b>' + @data +'</b> <br>';						
					END
				END
            END           
 		END TRY
 		BEGIN CATCH  
            SET @errors=@errors+1;
			SET @data=dbo.[A_FN_SYS_ErrorJson]();
			SET @data = @data + 'ERROR: ' +  'import_id=' + convert(varchar(10),@import_id) + ' STEP '  + @step;
            SET @output=@output+ '<b>' + @data+'</b></br>' + @sqlCommand + '</br></br>';
            PRINT @data; PRINT @sqlCommand ; 
			SET @data=@data + @sqlCommand;
            EXEC dbo.[A_SP_SYS_LOG] @category='MAIS SP', @result='Failed', @session=@session_id, @site = @site_id, @object=@SP, @object_sub=@procedure_name, @object_id=@import_id, @step=@step, @data=@data; 
		END CATCH;   

-- SNIPPET QUERY EXECUTE END  *********************************************************
		
		SET @rows_inserted=@rows;    

 		  
-- SNIPPET FINISHING PROCEDURE ********************************************************
		--------------------------------------------------------------------------------------------------------------------------    
		SET @step = 'IMPORT SUMMARY';
		--------------------------------------------------------------------------------------------------------------------------
		SET @errors_global=@errors_global+@errors;
		SET @warnings_global=@warnings_global+@warnings;
		SET @rows_deleted_global=@rows_deleted_global+@rows_deleted;
		SET @rows_inserted_global=@rows_inserted_global+@rows_inserted;
		SET @rows_updated_global=@rows_updated_global+@rows_updated;
		SET @duration=convert(real,format(DATEDIFF(MILLISECOND,@start_time_import,getdate())/1000.0,'N3'))
		
		SET  @data='{}'
		SET  @data=JSON_MODIFY( @data,'$.N',CONVERT(varchar(10), @imports_fetched))
		SET  @data=JSON_MODIFY( @data,'$.Errors',CONVERT(varchar(10), @errors))
		SET  @data=JSON_MODIFY( @data,'$.Warnings',CONVERT(varchar(10), @warnings))	
		SET  @data=JSON_MODIFY( @data,'$.Deleted',CONVERT(varchar(10), @rows_deleted))
		SET  @data=JSON_MODIFY( @data,'$.Inserted',CONVERT(varchar(10), @rows_inserted))
		SET  @data=JSON_MODIFY( @data,'$.Updated',CONVERT(varchar(10), @rows_updated))
		SET  @data=JSON_MODIFY( @data,'$.DateImportFrom',CONVERT(varchar(10), convert(char(10),convert(date,@date_import_from),126)))
		SET  @data=JSON_MODIFY( @data,'$.DateImportUntil',CONVERT(varchar(10), convert(char(10),convert(date,@date_import_until),126)))
		

		IF @errors=0 BEGIN 
			EXEC dbo.[A_SP_SYS_LOG] @category='MAIS SP', @result='Succeeded', @session=@session_id, @site = @site_id, @object=@SP, @object_sub=@procedure_name
			, @object_id=@import_id, @step=@step, @data=@data, @duration=@duration, @value=@warnings; 
		END
		ELSE EXEC dbo.[A_SP_SYS_LOG] @category='MAIS SP', @result='Failed', @session=@session_id, @site = @site_id, @object=@SP, @object_sub=@procedure_name
		, @object_id=@import_id, @step=@step, @data=@data, @duration=@duration, @value=@errors; 	 
		
		SET @data= convert(varchar(20),getdate(),120) +' #' + convert(varchar(10),@imports_fetched) + ') import_id=' + convert(varchar(10),@import_id) + ' duration=' + convert(varchar(10),@duration) + ' ' +  @data;
		SET @output=@output + @data  + '</br>';
		PRINT @data;
		

		/*
		
		set @data = left((concat(concat('{"p1":"',@p1,'",'),
        concat('"p2":"',@p2,'",'),
        concat('"p3":"',@p3,'",'),
        concat('"p4":"',@p4,'",'),
        concat('"p5":"',@p5,'"}')) 
        ),4000);
        set @data=JSON_MODIFY( @data,'$.filter',@filter);
        set @data=JSON_MODIFY( @data,'$.group_by',@date);
        set @data=JSON_MODIFY( @data,'$.fields_source',@fields_source);
        set @data=JSON_MODIFY( @data,'$.fields_target',@fields_target);
		 
		*/

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
        ,@date
        ,@commands 
        ,@procedure_name 
        ,@site_id
        ,@parent
    END -- END OF FETCHING IMPORTS
    CLOSE TAB_CURSOR 
    DEALLOCATE TAB_CURSOR

	-------------------------------------------------------------------------------------------------------------------------------
	SET @step= 'SP END';
	--------------------------------------------------------------------------------------------------
	IF @imports_fetched=0 BEGIN
        SET @data= 'No active imports found for ' + @SP + ' SQL SP.';
        SET @output=@output  + @data + '<br>';
        PRINT @data; 
		IF @commands like '%-LOG_WARNING%' BEGIN
			EXEC dbo.[A_SP_SYS_LOG] @category='MAIS SP', @result='Warning', @session=@session_id, @site = @site_id, @object=@SP, @object_sub=@procedure_name, @object_id=@import_id, @step=@step, @data=@data; 
		END
    END
    
    SET  @data='{}'
	SET  @data=JSON_MODIFY( @data,'$.Imports',CONVERT(varchar(10), @imports_fetched))
	SET  @data=JSON_MODIFY( @data,'$.Errors',CONVERT(varchar(10), @errors_global))
	SET  @data=JSON_MODIFY( @data,'$.Warnings',CONVERT(varchar(10), @warnings_global))	
	SET  @data=JSON_MODIFY( @data,'$.Deleted',CONVERT(varchar(10), @rows_deleted_global))
	SET  @data=JSON_MODIFY( @data,'$.Inserted',CONVERT(varchar(10), @rows_inserted_global))
	SET  @data=JSON_MODIFY( @data,'$.Updated',CONVERT(varchar(10), @rows_updated_global))

	SET @duration=convert(real,format(DATEDIFF(MILLISECOND,@start_time,getdate())/1000.0,'N3'))

    IF @errors_global=0 BEGIN
		EXEC dbo.[A_SP_SYS_LOG] @category='MAIS SP', @session=@session_id, @site = @site_id, @object=@SP
		, @step=@step, @duration=@duration, @result='Succeeded', @data=@data, @value=@warnings_global;

	END
	ELSE EXEC dbo.[A_SP_SYS_LOG] @category='MAIS SP', @session=@session_id, @site = @site_id, @object=@SP
		, @step=@step, @duration=@duration, @result='Failed', @data=@data , @value=@errors_global;  

	SET @data = @SP + ' finished. It took ' + convert(varchar(20),@duration) + ' sec.' + @data ; 
	SET @output=@output + '</br>' + @data + '</br>';
	PRINT @data;

-- SNIPPET END  *********************************************************

    
    DECLARE @version nvarchar(max)='
    <H3>VERSION INFORMATION </H3>
   	--  VERSION 20230315  <br>
    --  logging improved, snippets design <br>

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
