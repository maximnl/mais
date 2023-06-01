USE [Anwb_Rhl]
GO
/****** Object:  StoredProcedure [dbo].[A_SP_ALERT]    Script Date: 1-6-2023 12:31:57 ******/
SET ANSI_NULLS OFF
GO
SET QUOTED_IDENTIFIER ON
GO



-- template stored procedure for loading data from source tables
ALTER  PROCEDURE [dbo].[A_SP_ALERT]
 @activity_id int = 0 
,@forecast_id int = 0 -- run imports for a forecast_id
,@session_id nvarchar(50)  = null -- session id for loging, keep empty for an autogenerated uid
,@commands varchar(2000)='' -- '-LOG_ROWCOUNT -LOG_INSERT -LOG_DELETE' --'-PRINT' -NOGROUPBY -SUMFIELDS -SET_IMPORT_ID -NODELTA
,@procedure_name nvarchar(200)=''
,@site_id int =0
,@import_id int =0
,@category nvarchar(200) ='' -- procedure category to run; empty to run all
AS
BEGIN

    DECLARE @SP varchar(20) = 'A_SP_ALERT';

  
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
		DECLARE @data  nvarchar(max)=''  -- log data
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
        DECLARE @benchmark_filter varchar(2000) ='';
        SET @benchmark_filter = try_convert(varchar(2000),ltrim(rtrim(@p2)));
        IF @benchmark_filter='' BEGIN
            SET @benchmark_filter= '1=0'
        END
        ELSE BEGIN
            SET @benchmark_filter=@benchmark_filter + ' AND DATA.site_id='+convert(varchar(10),@site_id);
            IF (CHARINDEX('activity',lower(@benchmark_filter))=0) 
                SET @benchmark_filter=@benchmark_filter + ' AND DATA.activity_id='+convert(varchar(10),@activity_id);
        END
         
        DECLARE @test varchar(2000) ='';
        SET @test = try_convert(varchar(2000),ltrim(rtrim(@p3)));
        
        -- test parameters before running all
        IF @filter = '' BEGIN
            SET @errors=@errors+1 
            SET @data= '-- <b>Error: [filter] parameter should define a timeserie data. </b><br>';
            SET @output= @output+ @data;    
            EXEC dbo.[A_SP_SYS_LOG] @category='MAIS SP', @session=@session_id, @site = @site_id, @object=@SP, @object_sub=@procedure_name, @object_id=@import_id, @step='IMPORT FILTER TEST', @data=@data,@result='Failed'
        END
        ELSE SET @filter = @filter + ' AND DATA.site_id='+convert(varchar(10),@site_id);
        -- test if activity present otherwise add filter on the current activity
        IF (CHARINDEX('activity',lower(@filter))=0) BEGIN
            SET @filter = @filter + ' AND DATA.activity_id='+convert(varchar(10),@activity_id);
        END

        IF @source = '' BEGIN
            SET @source=@fact_day;
        END       

        -- if source or target fields are empty set it by default to all value fields
        IF @date = '' BEGIN 
            SET @warnings=@warnings+1;
            SET @date = '[date]';        
            SET @output=@output+'<br>-- <i>WARNING: Date group by was not specified. Setting default [date]. </i>';
        END
	 
        IF @fields_source='' BEGIN 
            SET @warnings=@warnings+1;
            SET @fields_source='[value1]';        
            SET @output=@output+'<br>-- <i>WARNING: Source fields are not specified. Setting default value1. </i>';
        END

        -- if source or target fields are empty set it by default to all value fields
        IF @fields_target=''  BEGIN 
            SET @warnings=@warnings+1;
            SET @fields_target=@fields_source;
            SET @output=@output+'<br>-- <i>WARNING: Target field was not specified. Setting default value1s. </i>';
        END
        
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
		SET @sqlCommand = 
 		' DELETE FROM '+ @source +' WHERE activity_id =' +  convert(nvarchar(max),@activity_id) 
    + '	AND forecast_id = ' +  convert(varchar(10),@forecast_id)
    + '	AND site_id = ' +  convert(varchar(10),@site_id) 
    + ' AND [date] BETWEEN ''' + convert(char(10),@date_import_from,126)  + ''' AND ''' + convert(char(10),@date_import_until,126) + ''';';
       		 		
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
		DECLARE @having varchar(100)=''
		IF @date like '%week%' SET @having =' having count(*)=7';
		IF @date like '%month%' SET @having= ' having count(*)=min(month_days)';
		
        SET @sqlCommand = '
        WITH S AS (
        select T.' + @date  + ' , sum(' + @fields_source  + ' ) value
        from ' + @source + ' DATA
        inner join [A_DIM_ACTIVITY] A on DATA.[activity_id]=A.[activity_id]
        inner join [A_TIME_DATE] T on DATA.date=T.date
        where ' + @filter + 
        ' and DATA.date BETWEEN ''' + convert(char(10),@date_import_from,126)  + ''' AND ''' + convert(char(10),@date_import_until,126) + '''  
        group by T.' + @date  + ')
        , 
        B as (
        select T.' + @date  + ' , sum(' + @fields_target  + ') benchmark   
        from ' + @source + ' DATA
        inner join [A_DIM_ACTIVITY] A on DATA.[activity_id]=A.[activity_id]
        inner join [A_TIME_DATE] T on DATA.date=T.date
        where ' + @benchmark_filter +' and DATA.date BETWEEN ''' + convert(char(10),@date_import_from,126)  + ''' AND ''' + convert(char(10),@date_import_until,126) + '''  
        group by T.' + @date  + '
        )
        , 
        D as (
            select min(date) date_first, ' + @date  + ', count(*) as days 
            from [A_TIME_DATE]
            where [date] BETWEEN ''' + convert(char(10),@date_import_from,126)  + ''' AND ''' + convert(char(10),@date_import_until,126) + '''  
            group by ' + @date +  @having  
            + ')
        , 
        C as (  
        select D.date_first, value, benchmark
        , case when value<>0 and value is not null and benchmark is not null then abs((value-benchmark)/value) else null end dif_pct
        from D left join S on D.' + @date  + '=S.' + @date  + '
        left join B on D.' + @date  + '=B.' + @date  + '
        )
         INSERT INTO '+ @source  
            + '([date],activity_id,forecast_id,import_id,site_id, value1, value2, value3) ' 
            + 'SELECT date_first ,' +  convert(varchar(10),@activity_id)  
            + ',' +  convert(varchar(10),@forecast_id) 
            + ',' + convert(varchar(10),@import_id)
            + ',' + convert(varchar(10),@site_id) 
            + ', value, benchmark, dif_pct 
        from C
        where ' + @test  + ' OR value is null';

-- --where dif_pct > 0.20 or dif_pct is NULL
					
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
   	--  VERSION 20230517  <br>
    --  Initial version <br></br>

'
    IF @commands like '%-VERSION%'  BEGIN SET @output = @output + @version; PRINT @version; END 

    DECLARE @help nvarchar(max)='<br><i>HELP INFORMATION</i>
    <br>
    <br> An stored procedure for alerting on data values differences versus a benchmark data or a fixed value at a specified date aggregation level.
    <br> time periods not passing the test will be inserted into the alert time serie. 
 
    <br>
    <br>SP PARAMETERS
    <br>@activity_id int = 0     -- run imports for an activity_id or 0 for all.
    <br>@import_id int = 0       -- run import_id or 0 for all.
    <br>@session_id nvarchar(50)  = null -- session id for loging, keep empty for an autogenerated uid.
    <br>@procedure_name nvarchar(200)=A_SP_FC_SPLIT -- the app / procedure name to run
    <br>@site_id int = 0 -- site to run
    <br>@commands varchar(2000)
    
    <br><br>Inherited parameters from procedure or import configuration:
    <br>[Source] - hidden and always [A_FACT_DAY] at the moment.
    <br>[filter] - Source data filter, eg forecast_id = 1 . If activity_id or activity_set is omitted , the current activity_id will be used
    <br>[fields_source] A single source field expression, by default value1. Any value1-value10 can be used. 
    <br>[fields_target] A single benchmark field expression, by default value1. Any value1-value10 can be used. 
    <br>[group_by] Date group, one of {date, year_week,year_month,year_quarter} - testing is done on the specified date aggregation level, per day, week, month or quarter.  
    <br>[p2] Benchmark data filter, similar to source data filter for obtaining the benchmark data
    <br>[p3] A test expression - eg  value<100. value is for the source value, benchmark is for the benchmark value. dif_pct is auto computed 
    and can be used as well eg dif_pct>0.5 will insert alerts if source and benchmark differ by 50%. 
     
    <br>
    
    <br>Supported commands:
    <br>Commands from the procedure and the import will be added to the list (combined) 
    <br><table>
    <tr><td>-PRINT          </td><td>Let skip execution to only output the queries and information.</td></tr>
    <tr><td>-NOGROUPBY      </td><td>Cancels grouping by by group by/date field.</td></tr>
    <tr><td>-SUMFIELDS      </td><td>Adds sum function for all source fields given that a simple commaseparated list is provided.</td></tr>
    <tr><td>-NODELTA        </td><td>Skips any source date range detaction and loads data according to [Date Import From]/[Date Import Until] parameters.</td></tr>
    <tr><td>-INTRADAY       </td><td>Triggers intraday table update. Additional p1 parameter let setup interval detection logic. By default the source must have interval_id field in line with A_TIME_INTERVAL table</td></tr>
    <tr><td>-NOINTRADAY     </td><td>Skips intraday update even if it was set up in a procedure or an import.</td></tr>
    <tr><td>-LOG_ROWCOUNT   </td><td>Logs a number of rows affected after all executions to A_SYS_LOG.</td></tr>
    <tr><td>-LOG_INSERT     </td><td>Logs insert queries.</td></tr>
    <tr><td>-LOG_DELETE     </td><td>Logs delete queries.</td></tr>
    <tr><td>-NOSCHEDULE     </td><td>Supress scheduling if any and force queries execution.</td></tr>
    <tr><td>-VERSION        </td><td>Outputs the version information.</td></tr>
    <tr><td>-HELP           </td><td>Outputs help information.</td></tr>
    <tr><td> </td><td></td></tr>
    </table>
    '
    IF @commands like '%-HELP%'  BEGIN SET @output = @output + @help ; PRINT @help; END 
    IF @commands like '%-OUTPUT%'  select @output as SQL_OUTPUT

END
