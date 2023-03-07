 
/****** Object:  StoredProcedure [dbo].[A_SP_IMPORT]    Script Date: 7-3-2023 10:42:49 ******/
SET ANSI_NULLS OFF
GO
SET QUOTED_IDENTIFIER ON
GO

-- generic import procedure for importing source data into A_FACT_DAY and A_FACT_INTRADAY time series tables
-- option to update the source table records with the import_id according to import where conditions

ALTER   PROCEDURE [dbo].[A_SP_IMPORT]
-- Parameters defined at interface/ SP level / to select and batch run several imports after each other
 @activity_id int = 0 -- run imports for an activity_id
,@forecast_id int = 0 -- run imports for a forecast_id
,@import_id int = 0 -- run import_id
,@session_id nvarchar(50)  = null -- session id for loging, keep empty for an autogenerated uid
,@commands varchar(2000)='' -- '-PRINT -LOG_ROWCOUNT -LOG_INSERT -LOG_DELETE -NOGROUPBY -SUMFIELDS -NOINTRADAY -NODELTA -FORCEDELTA -INTRADAY -VERSION -HELP -NOSCHEDULE; see HELP for docs
,@procedure_name nvarchar(200)='' -- run procedure name or empty for all procedures 
,@site_id int = 0 -- site to run
,@category nvarchar(200) = '' -- procedure category to run; empty to run all
,@import_update_field nvarchar(100) = '' -- if specified, records of the source table will be updated with the all imports accessing those records 
AS
BEGIN
    SET DATEFIRST 1 
    SET NOCOUNT ON;
--  configuration
    DECLARE @SP varchar(20) = 'A_SP_IMPORT';
    DECLARE @sqlCommand NVARCHAR(MAX) =''-- 

--  Parameters obtained from the configuration tables / cannot be passed into SP directly by are managed at the procedure/import levels.
--  source data parameters
	DECLARE @filter nvarchar(4000)=''           -- where filter for filtering source data
	DECLARE @date_import_from date='9999-01-01' -- calculated by the import query using imports and procedures fields
	DECLARE @date_import_until date='1900-01-01'
	DECLARE @fields_source varchar(2000)=''     -- source fields
	DECLARE @fields_target varchar(2000)=''     -- target fields value1
	DECLARE @schedule varchar(2000)=''
	DECLARE @source varchar(2000)=''
	DECLARE @group_by varchar(2000)=''
    DECLARE @day_source varchar(max)=''

    -- target parameters
    DECLARE @fact_day nvarchar(200) ='[A_FACT_DAY]' -- data per day stored here
    DECLARE @fact_intraday nvarchar(200)='[A_FACT_INTRADAY]' -- data per day/interval_id is stored here. conform a_time_interval dimension
    
    -- input parameters
	DECLARE @p1 varchar(2000)=''          -- intraday_join      
	DECLARE @p2 varchar(2000)=''
	DECLARE @p3 varchar(2000)=''
	DECLARE @p4 varchar(2000)=''
	DECLARE @p5 varchar(2000)=''
	DECLARE @groupby varchar(2000)=''

	-- log variables
	DECLARE @data  varchar(4000)=''  -- log data
	DECLARE @rows INT   -- keep affected rows
	DECLARE @start_time datetime=null
    DECLARE @output nvarchar(max)='';               -- keep output log for applications
    DECLARE @imports_fetched int=0;                 -- number of imports processed
    DECLARE @errors int = 0 ;                       -- import errors


    -- GLOBAL SP VARIABLES FOR THE SUMMARY AT THE END
    DECLARE @errors_global int = 0;                 -- 
    DECLARE @rows_deleted_global INT = 0;
    DECLARE @rows_inserted_global INT = 0;
    DECLARE @rows_deleted_intraday_global INT = 0;
    DECLARE @rows_inserted_intraday_global INT = 0;
    DECLARE @rows_updated_source_global INT = 0;
    DECLARE @summary varchar(200) = '';  
	DECLARE @warning_global int=0;

	-- source data variables
	DECLARE @date_source_min date='9999-01-01' -- calculated by the import query using imports and procedures fields
	DECLARE @date_source_max date='1900-01-01'


	-- intraday variables, used only in combination with the command -INTRADAY
	DECLARE @intraday_join varchar(2000)=''
	DECLARE @intraday_interval_id varchar(200)='interval_id'    -- intraday field name in the source
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
    AND procedure_code= @SP  -- This SP only 
    AND (site_id=@site_id or @site_id=0)  
    AND ([procedure_id] = try_convert(int,@procedure_name) or [procedure_name] like @procedure_name or @procedure_name = '') 
    AND (activity_id=@activity_id or @activity_id=0)
    AND (forecast_id=@forecast_id or @forecast_id=0)
    AND ([category] like @category or @category='')
    AND active=1
    ORDER BY [sort_order],[procedure_name];
    
	EXEC dbo.[A_SP_SYS_LOG] @category='MAIS SP', @session=@session_id, @site = @site_id, @object=@SP, @step='SQL SP START', @data=@commands, @result='Succeeded';
	SET @start_time     = GETDATE();

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
     		,@group_by
			,@commands
			,@procedure_name
			,@site_id 
	WHILE @@FETCH_STATUS = 0 
   	BEGIN
        
        SET @errors  = 0 
        SET @imports_fetched=@imports_fetched+1;

        DECLARE @on_schedule bit=1;


        -- if source or target fields are empty set it by default to all value fields
        IF @fields_source='' OR @fields_target='' BEGIN 
            SET @fields_source='[value1],[value2],[value3],[value4],[value5],[value6],[value7],[value8],[value9],[value10]';
            SET @fields_target='[value1],[value2],[value3],[value4],[value5],[value6],[value7],[value8],[value9],[value10]';
            SET @output=@output+'-- <b>WARNING: [source_fields] or [target_fields] parameters are not specified. Setting defaults. <b>';
        END

        IF @filter='' BEGIN
            SET @filter='1=1'; 
            SET @output=@output+'-- <b>WARNING: [filter] parameter was not set. All source data will be used. <b>';
        END
        
		SET @source=LTRIM(@source);
        SET @day_source=@source;
        SET @intraday_source=@source;
        -- if source is a framework table than add site_id filter or set fact_day as default
        IF @source='' BEGIN
            SET @day_source=@fact_day;
            SET @intraday_source=@fact_intraday      
        END
        IF @source like 'A_%' or @source like '[A_%' BEGIN    
            SET @filter=@filter + ' AND site_id=' + convert(varchar(10),@site_id);
        END

        IF @schedule>'' BEGIN
            SET @sqlCommand = N'SELECT @on_schedule =  CASE WHEN ' +@schedule + ' THEN 1 ELSE 0 END'
            EXEC sp_executesql @sqlCommand, N'@on_schedule bit OUTPUT', @on_schedule=@on_schedule OUTPUT
        END 

        -- SET UP DELTA SOURCE DATES
        IF @commands NOT like '%-NODELTA%' OR @commands like '%-FORCEDELTA%' BEGIN
            DECLARE @dates varchar(30)
            SET @sqlCommand = 'select @dates = convert(char(10),convert(date,isnull(min(' + @group_by 
                + '),''9999-12-31'')),126) + convert(char(10),convert(date,isnull(max(' + @group_by 
                + '),''1900-12-31'')),126) FROM ' + @day_source +' WHERE ' + @filter;
            BEGIN TRY
                EXEC sp_executesql @sqlCommand, N'@dates varchar(30) OUTPUT', @dates=@dates OUTPUT
                SET @date_source_min=left(@dates,10);
                SET @date_source_max=right(@dates,10);
                IF @date_import_from<@date_source_min BEGIN SET @date_import_from=@date_source_min; END
                IF @date_import_until>@date_source_max BEGIN SET @date_import_until=@date_source_max; END
                IF @commands like '%-FORCEDELTA%'  
                    BEGIN
                        SET @date_import_from=@date_source_min;
                        SET @date_import_until=@date_source_max; 
                    END

            END TRY
     		BEGIN CATCH  
                SET @errors=@errors+1;
                SET @data=dbo.[A_FN_SYS_ErrorJson]();
                SET @output=@output+'-- <b>Error: ' +@data+'</b><br><br>';
                PRINT @output
				EXEC dbo.[A_SP_SYS_LOG] @category='MAIS SP', @result='Failed', @session=@session_id, @site = @site_id, @object=@SP,
				@object_sub=@procedure_name, @object_id=@import_id, @step='DELTA DETECTION', @data=@data; 
     		END CATCH;   

            SET @output=@output+'-- DETECTED SOURCE DATES RANGE '+@dates+'<br>';
			SET @output=@output+'-- '+@sqlCommand+'<br>'; 

        END
   

        IF @commands like '%-SUMFIELDS%' and @fields_source not like '%SUM(%)%' set @fields_source= concat('SUM(try_convert(real,',replace(@fields_source,',',')),SUM(try_convert(real,('),'))')

        set @data = left((concat(concat('{"p1":"',@p1,'",'),
        concat('"p2":"',@p2,'",'),
        concat('"p3":"',@p3,'",'),
        concat('"p4":"',@p4,'",'),
        concat('"p5":"',@p5,'"}')) 
        ),4000);
        set @data=JSON_MODIFY( @data,'$.filter',@filter);
        set @data=JSON_MODIFY( @data,'$.group_by',@group_by);
        set @data=JSON_MODIFY( @data,'$.fields_source',@fields_source);
        set @data=JSON_MODIFY( @data,'$.fields_target',@fields_target);
		 
        -- test parameters before running all
        IF @activity_id=0 OR @forecast_id=0 SET @errors=@errors+1 ;
        IF @date_import_until<@date_import_from  BEGIN  
			SET @warning_global=@warning_global+1;
            SET @output=@output+'-- <b>Warning: Source dates range cannot be found. The import query will not be executed. 
            Please check if the source exists and has data for the current import id= ' + convert(varchar(10),@import_id) + '. filter=' + @filter + ' . </b><br>';               
        END
  
	----------------------------------------------------------------------------------------------------------------------
	--  DELETE DAY
	--------------------------------------------------------------------------------
		SET @sqlCommand = 
 		  ' DELETE FROM '+ @fact_day 
        + ' WHERE activity_id =' +  convert(varchar(10),@activity_id) 
        + '	AND forecast_id = ' +  convert(varchar(10),@forecast_id)
        + '	AND site_id = ' +  convert(varchar(10),@site_id)
        + ' AND [date] BETWEEN ''' + convert(char(10),@date_import_from,126)  + ''' AND ''' + convert(char(10),@date_import_until,126) + ''';';
        SET @output=@output+'<br>-- DELETE DAY QUERY:<br>'+@sqlCommand+'<br>';

 		IF @commands like '%-PRINT%' PRINT @sqlCommand
        ELSE BEGIN TRY			 
            IF @errors=0 BEGIN 
                IF (@on_schedule=1 OR @commands like '%-NOSCHEDUL%' ) BEGIN
                    EXEC( @sqlCommand); SET @rows= @@ROWCOUNT;
                    SET @output=@output+'-- Number of day records deleted ' + convert(varchar(10),@rows)+'<br><br>';
                    SET @rows_deleted_global=@rows_deleted_global+@rows;         
                    IF @commands like '%-LOG_ROWCOUNT%' EXEC dbo.[A_SP_SYS_LOG] @category='MAIS SP', @result='Succeeded', @session=@session_id, @site = @site_id, @object=@SP, @object_sub=@procedure_name, @object_id=@import_id, @step='-LOG_ROWCOUNT DELETED',@data=@sqlCommand, @value=@rows; 
                    IF @commands like '%-LOG_DELETE%' EXEC dbo.[A_SP_SYS_LOG] @category='MAIS SP', @result='Succeeded', @session=@session_id, @site = @site_id, @object=@SP, @object_sub=@procedure_name, @object_id=@import_id, @step='-LOG_DELETE', @data=@sqlCommand; 
                END
                ELSE SET @output=@output+'-- <b>WARNING: Delete query was not executed due to the schedule parameter.</b> <br>';
            END
            ELSE SET @output=@output+'-- <b>ERROR: Queries will not be executed due to errors. Please check the parameters.</b><br>';                      
 		END TRY
 		BEGIN CATCH  
            SET @data=dbo.[A_FN_SYS_ErrorJson]() ;
            SET @sqlCommand = @sqlCommand + '/* error information:' + @data + '*/';
            PRINT @sqlCommand;
            SET @output=@output+@data+'<br><br>';
            EXEC dbo.[A_SP_SYS_LOG] @category='MAIS SP', @result='Failed', @session=@session_id, @site = @site_id, @object=@SP, @object_sub=@procedure_name, @object_id=@import_id, @step='CLEAN DAY', @data=@sqlCommand; 
 		END CATCH;   

	--------------------------------------------------------------------------------------------------------------------------
	--  INSERT TO DAY
	-------------------------------------------------------------------------------------
 		IF @commands not like '%-NOGROUPBY%' OR @commands like  '%-SUMFIELDS%' 
            BEGIN SET @groupby=concat(' GROUP BY ',@group_by); END 
        ELSE SET @groupby='';

		SET @sqlCommand = 'INSERT INTO '+ @fact_day 
        +' ([date],activity_id,forecast_id,import_id,' + @fields_target + ',site_id)' + 
        ' SELECT ' + @group_by + ',' +  convert(varchar(10),@activity_id)  
   		+ ', ' +  convert(varchar(10),@forecast_id) + ','+ convert(varchar(10),@import_id)
   		+ ',' + @fields_source +','+ convert(varchar(10),@site_id) +
 		' FROM '+ @day_source +' WHERE ' + @filter  
		+ ' AND ' + @group_by + ' BETWEEN ''' + convert(char(10),@date_import_from,126)  + ''' AND ''' + convert(char(10),@date_import_until,126) + '''' + @groupby +';';
		
        SET @output=@output+ '<br>-- INSERT DAY QUERY <br>'+ @sqlCommand + '<br><br>';
        IF @commands like '%-PRINT%' PRINT @sqlCommand;	
        ELSE BEGIN TRY			         
            IF @errors=0 BEGIN 
                IF (@on_schedule=1 OR @commands like '%-NOSCHEDUL%' ) BEGIN
                    EXEC( @sqlCommand); SET @rows= @@ROWCOUNT

                    SET @rows_inserted_global=@rows_inserted_global+@rows;
                    IF @commands like '%-LOG_ROWCOUNT%' EXEC dbo.[A_SP_SYS_LOG] @category='MAIS SP', @result='Succeeded', @session=@session_id, @site = @site_id, @object=@SP, @object_sub=@procedure_name, @object_id=@import_id, @step='-LOG_ROWCOUNT INSERT DAY',@data=@sqlCommand, @value=@rows; 
                    IF @commands like '%-LOG_INSERT%' EXEC dbo.[A_SP_SYS_LOG] @category='MAIS SP', @result='Succeeded', @session=@session_id, @site = @site_id, @object=@SP, @object_sub=@procedure_name, @object_id=@import_id, @step='-LOG_INSERT DAY', @data=@sqlCommand; 

                    SET @output=@output+'day records inserted ' + convert(varchar(10),@rows)+'<br><br>';  
                END
                ELSE SET @output=@output+'-- <b>WARNING: Delete query was not executed due to the schedule parameter.</b> <br>';
            END
            ELSE SET @output=@output+'-- <b>ERROR: Queries will not be executed due to errors. Please check the parameters.</b><br>';       
        END TRY
   		BEGIN CATCH  
            SET @errors=@errors+1; 
   			SET @data=dbo.[A_FN_SYS_ErrorJson](); 
            SET @output=@output+@data+'<br><br>';
            SET @sqlCommand = @sqlCommand + '/* error information:' + @data + '*/';
            PRINT @sqlCommand;
			EXEC dbo.[A_SP_SYS_LOG] @category='MAIS SP', @result='Failed', @session=@session_id, @site = @site_id, @object=@SP, @object_sub=@procedure_name, @object_id=@import_id, @step='INSERT DAY', @data=@sqlCommand; 
        END CATCH;   	  

--***********************************************************
-- update import_field
--***********************************************************
        IF @import_update_field>'' BEGIN
            SET @sqlCommand = 'UPDATE '+ @day_source 
            + ' SET ' + @import_update_field + '=' + convert(varchar(10),@import_id) 
   		    + ' WHERE ' + @filter  
		    + ' AND ' + @group_by + ' BETWEEN ''' + convert(char(10),@date_import_from,126)  + ''' AND ''' + convert(char(10),@date_import_until,126) + '''' +';';   
            SET @output=@output+ '<br>-- UPDATE ACCESSED RECORDS WITH IMPORT_ID IN THE SOURCE <br>'+ @sqlCommand + '<br><br>';
            IF @commands like '%-PRINT%' PRINT @sqlCommand;	
            ELSE BEGIN TRY			         
                IF @errors=0 BEGIN 
                    IF (@on_schedule=1 OR @commands like '%-NOSCHEDUL%' ) BEGIN
                        EXEC( @sqlCommand); SET @rows= @@ROWCOUNT;
                        SET @rows_updated_source_global=@rows;
                        SET @output=@output+'source records import field updated ' + convert(varchar(10),@rows)+'<br><br>';  
						IF @commands like '%-LOG_ROWCOUNT%' EXEC dbo.[A_SP_SYS_LOG] @category='MAIS SP', @result='Succeeded', @session=@session_id,
						@site = @site_id, @object=@SP, @object_sub=@procedure_name, @object_id=@import_id, @step='-LOG_ROWCOUNT UPDATE SOURCE',@data=@sqlCommand, @value=@rows; 

                    END
                    ELSE SET @output=@output+'-- <b>WARNING: Update query was not executed due to the schedule parameter.</b> <br>';
                END
                ELSE SET @output=@output+'-- <b>ERROR: Update import field query will not be executed due to errors. Please check the parameters.</b><br>';       
            END TRY
       		BEGIN CATCH  
                SET @errors=@errors+1; 
       			SET @data=dbo.[A_FN_SYS_ErrorJson](); 
                SET @output=@output+@data+'<br><br>';
                SET @sqlCommand = @sqlCommand + '/* error information:' + @data + '*/';
                PRINT @sqlCommand;
                EXEC dbo.[A_SP_SYS_LOG] @category='MAIS SP', @result='Failed', @session=@session_id, @site = @site_id, 
				@object=@SP, @object_sub=@procedure_name, @object_id=@import_id, @step='UPDATE IMPORT_ID', @data=@sqlCommand; 
            END CATCH;   	  
        END

	----------------------------------------------------------------------------------------------------------------------
	--  PROCESS INTRADAY
	--------------------------------------------------------------------------------	
	IF @commands  like '%-INTRADAY%' AND @commands not like '%-NOINTRADAY%' BEGIN  

		SET @intraday_join= case when @p1>'' then @p1 else @intraday_join end
		SET @intraday_interval_id = case when @p1>'' then 'I.interval_id' else @intraday_interval_id end -- p1 has a join with interval table with alias I , we need override default
		SET @intraday_duration = case when @p2>'' then @p2 else @intraday_duration end  -- standard duration of the interval is 15 min
        IF @intraday_join>'' SET @intraday_source=@intraday_source + ' ' + @intraday_join;

	----------------------------------------------------------------------------------------------------------------------
	--  DELETE INTRADAY
	--------------------------------------------------------------------------------	
		SET @sqlCommand = 
 		' DELETE FROM '+  @fact_intraday 
        + ' WHERE activity_id =' +  convert(varchar(10),@activity_id) 
        + '	AND forecast_id = ' +  convert(varchar(10),@forecast_id)
        + '	AND site_id = ' +  convert(varchar(10),@site_id)
        + ' AND [date] BETWEEN ''' + convert(char(10),@date_import_from,126)  + ''' AND ''' 
        + convert(char(10),@date_import_until,126) +''';';
        SET @output=@output+ '<br>-- DELETE INTRADAY QUERY <br>'+ @sqlCommand + '<br>';
        IF @commands like '%-PRINT%' PRINT @sqlCommand
        ELSE BEGIN TRY
            IF @errors=0 BEGIN 
                IF (@on_schedule=1 OR @commands like '%-NOSCHEDUL%' ) BEGIN
                    EXEC( @sqlCommand);SET @rows= @@ROWCOUNT;
                    SET @output=@output+'Number of intraday records deleted ' + convert(varchar(10),@rows)+'<br><br>'  
                    SET @rows_deleted_intraday_global=@rows_deleted_intraday_global+@rows;         
                    IF @commands like '%-LOG_ROWCOUNT%' EXEC dbo.[A_SP_SYS_LOG] @category='MAIS SP', @result='Succeeded', @session=@session_id, @site = @site_id, @object=@SP, @object_sub=@procedure_name, @object_id=@import_id, @step='-LOG_ROWCOUNT DELETED INTRADAY',@data=@sqlCommand, @value=@rows; 
                    IF @commands like '%-LOG_DELETE%' EXEC dbo.[A_SP_SYS_LOG] @category='MAIS SP', @result='Succeeded', @session=@session_id, @site = @site_id, @object=@SP, @object_sub=@procedure_name, @object_id=@import_id, @step='-LOG_DELETE INTRADAY', @data=@sqlCommand; 

                END
                ELSE SET @output=@output+'-- <b>WARNING: Delete intraday query was not executed due to the schedule parameter.</b> <br>';
            END
            ELSE SET @output=@output+'-- <b>ERROR: Intraday queries will not be executed due to errors. Please check the parameters.</b><br>';                  
 		END TRY
 		BEGIN CATCH  
            SET @errors=@errors+1; 
            SET @data=dbo.[A_FN_SYS_ErrorJson]() ;
            SET @output=@output +@data+'<br><br>';
            SET @sqlCommand = @sqlCommand + '/* error information:' + @data + '*/';
            PRINT @sqlCommand;
            EXEC dbo.[A_SP_SYS_LOG] @category='MAIS SP', @result='Failed', @session=@session_id, @site = @site_id, @object=@SP, @object_sub=@procedure_name, @object_id=@import_id, @step='CLEAN INTRADAY', @data=@sqlCommand; 
 		END CATCH;   

	--------------------------------------------------------------------------------------------------------------------------
	--  INSERT TO INTRADAY
	-------------------------------------------------------------------------------------
 		IF @commands not like '%-NOGROUPBY%' OR @commands like  '%-SUMFIELDS%' BEGIN SET @groupby = concat(' GROUP BY ', @group_by, ',',@intraday_interval_id) END ELSE SET @groupby=''
        
		SET @sqlCommand = 'INSERT INTO '+ @fact_intraday 
        +' ([date], activity_id, forecast_id, import_id, interval_id, duration_min,' + @fields_target + ',site_id)'
        +' SELECT ' + @group_by + ',' +  convert(varchar(10),@activity_id)  
   		+ ',' +  convert(varchar(10),@forecast_id) + ','+ convert(varchar(10),@import_id)
   		+ ',' + @intraday_interval_id + ', '+ convert(varchar(10),@intraday_duration) + ',' + @fields_source 
        + ',' + convert(varchar(10),@site_id) 
 		+ ' FROM '+ @intraday_source + ' WHERE ' + @filter  
		+ ' AND ' + @group_by + ' BETWEEN ''' + convert(char(10),@date_import_from,126)  + ''' AND ''' + convert(char(10),@date_import_until,126) + '''' 
        + @groupby +';';
        SET @output=@output+ '-- INSERT INTRADAY QUERY <br>'+ @sqlCommand + '<br><br>';
        
        IF @commands like '%-PRINT%' PRINT @sqlCommand    
 		ELSE BEGIN TRY		 
            IF @errors=0 BEGIN 
                IF (@on_schedule=1 OR @commands like '%-NOSCHEDUL%' ) BEGIN
                    EXEC( @sqlCommand);
                    SET @rows= @@ROWCOUNT;
                    SET @output=@output+'intraday records inserted ' + convert(varchar(10),@rows)+'<br><br>'

                    SET @rows_inserted_intraday_global=@rows_inserted_intraday_global+@rows;
                    IF @commands like '%-LOG_ROWCOUNT%' EXEC dbo.[A_SP_SYS_LOG] @category='MAIS SP', @result='Succeeded', @session=@session_id, @site = @site_id, @object=@SP, @object_sub=@procedure_name, @object_id=@import_id, @step='-LOG_ROWCOUNT INSERT INTRADAY',@data=@sqlCommand, @value=@rows; 
                    IF @commands like '%-LOG_INSERT%' EXEC dbo.[A_SP_SYS_LOG] @category='MAIS SP', @result='Succeeded', @session=@session_id, @site = @site_id, @object=@SP, @object_sub=@procedure_name, @object_id=@import_id, @step='-LOG_INSERT INTRADAY', @data=@sqlCommand; 

                END
                ELSE SET @output=@output+'-- <b>WARNING: Insert intraday query was not executed due to the schedule parameter.</b> <br>'
            END
            ELSE SET @output=@output+'-- <b>ERROR: Intraday queries will not be executed due to errors. Please check the parameters.</b><br>'                  
        END TRY
   		BEGIN CATCH  
            SET @errors=@errors+1; 
   			SET @data=dbo.[A_FN_SYS_ErrorJson](); 
            SET @output=@output + @data+'<br><br>';
            SET @sqlCommand = @sqlCommand + '/* error information:' + @data + '*/';
            PRINT @sqlCommand;
			EXEC dbo.[A_SP_SYS_LOG] @category='MAIS SP', @result='Failed', @session=@session_id, @site = @site_id, @object=@SP, @object_sub=@procedure_name, @object_id=@import_id, @step='INSERT INTRADAY', @data=@sqlCommand; 
	    END CATCH;   

	END -- end if intraday

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

    IF @imports_fetched=0 BEGIN
        SET @data= 'No active imports found for A_SP_IMPORT SQL SP. Try to check the procedure name and other parameters ';
        SET @output=@output + '<br>' + @data;
        PRINT @data; 
    END

    -- LOG FINISH ----------------------------------
	SET @data=format(DATEDIFF(MILLISECOND,@start_time,getdate())/1000.0,'N3')
    SET  @summary='{}'
		set  @summary=JSON_MODIFY( @summary,'$.ImportsFetched',CONVERT(varchar(10), @imports_fetched))
		set  @summary=JSON_MODIFY( @summary,'$.RowsDeleted',CONVERT(varchar(10), @rows_deleted_global))
		set  @summary=JSON_MODIFY( @summary,'$.RowsInserted',CONVERT(varchar(10), @rows_inserted_global))
        set  @summary=JSON_MODIFY( @summary,'$.Errors',CONVERT(varchar(10), @errors_global))
		set  @summary=JSON_MODIFY( @summary,'$.Warnings',CONVERT(varchar(10), @warning_global))
		

	IF @rows_inserted_intraday_global>0 OR 	 @rows_deleted_intraday_global>0 BEGIN
        set  @summary=JSON_MODIFY( @summary,'$.RowsDeletedIntraday',CONVERT(varchar(10), @rows_deleted_intraday_global))
        set  @summary=JSON_MODIFY( @summary,'$.RowsInsertedIntraday',CONVERT(varchar(10), @rows_inserted_intraday_global))    
    END

    IF @import_update_field>'' BEGIN
        set  @summary=JSON_MODIFY( @summary,'$.RowsUpdatedSource',CONVERT(varchar(10), @rows_updated_source_global))   
    END

	EXEC dbo.[A_SP_SYS_LOG] @category='MAIS SP', @session=@session_id, @site = @site_id, @object=@SP
    , @step='SQL SP FINISH', @duration=@data, @result='Succeeded', @data=@summary;

    ----------------------------------------------------------------------------------------------------------------

    SET @output=@output + '<br>-- Procedure finished. It took ' + @data + ' sec.';
    PRINT 'Procedure '+ @procedure_name + ' finished. It took ' + @data + ' sec.';

    DECLARE @version nvarchar(max)='
    <br><i>VERSION INFORMATION </i>
    --  VERSION 20230305 
    --  Logging improved

    --  VERSION 20230228 
    --  New parameter -FORCEDELTA, to supres any date range parameters and force max source range

    --  VERSION 20230103 
    --  Explicit filter on A_SP_IMPORT 
    --  Info by no imports found

    --  VERSION 220727
    --  Order of where parameters set to activity first for index reusage.

    <br>
    --  VERSION 220722
    --  Filtering of imports on the procedure category added. Parameter @category
    <br>
    --  VERSION 20220711
    --  scheduling parameter added
    --  more error handling
    --  intraday source fix for empty situation
    <br>
    --  VERSION 20220622
    --  default day and intraday tables are used if the source parameter left empty.
    <br>
    --  version 20220603
    --  generic import of transactional data into time series/ MAIS data format
    --  this SP will generate queries and run/print them for every row from [A_IMPORT_RUN] view
    --  template stored procedure for loading data from source tables';
    IF @commands like '%-VERSION%'  BEGIN SET @output = @output + @version; PRINT @version; END 

    DECLARE @help nvarchar(max)='<br><i>HELP INFORMATION</i>
    <br>
    <br>General import procedure for converting data/transactions from any source to the timeseries format of MAIS.
    <br>Tables [A_FACT_DATE] and optionally [A_FACT_INTRADAY] will be updated from the source data.
    <br>
    <br>Data will be updated withing the measured date range. This range is controlled by procedure/import scheduling parameters.
    <br>Date range in the source data (after filtering) will be automatically measured. MAIS data will be deleted and inserted only in this range.
    <br>Date range is influenced by the procedure and/or import scheduling paramters Days Back/Forward for relative ranges vs the current date,
    <br>or by hard set [Date Import From]/[Date Import Until] parameters for the hard dates. 
    <br>This SP has a limited set of parameters, the rest is picked up from the A_IMPORT_PROCEDURE and A_IMPORT tables using the view A_IMPORT_RUN
    <br>@p1 - @intraday_join
    <br>A_SP_IMPORT PARAMETERS
    <br>@activity_id int = 0    -- run imports for an activity_id.
    <br>@import_id int =0       -- run import_id.
    <br>@session_id nvarchar(50)  = null -- session id for loging, keep empty for an autogenerated uid.
    <br>@procedure_name nvarchar(200) -- the procedure name or an app name to run, use % to broaden the selection
    <br>@site_id int =0 -- site to run
    <br>@import_update_field nvarchar(100) = '' -- if specified, records of the source table will be updated with the all imports accessing those records 

    <br>@commands varchar(2000)
    <br>Supported commands:
    <br>Commands from the procedure and the import will be added to the list (combined) 
    <br><table>
    <tr><td>-PRINT          </td><td>Let skip execution to only output the queries and information.</td></tr>
    <tr><td>-NOGROUPBY      </td><td>Cancels grouping by by group by/date field.</td></tr>
    <tr><td>-SUMFIELDS      </td><td>Adds sum function for all source fields given that a simple commaseparated list is provided.</td></tr>
    <tr><td>-NODELTA        </td><td>Skips any source date range detaction and loads data according to [Date Import From]/[Date Import Until] parameters.</td></tr>
    <tr><td>-FORCEDELTA     </td><td>Supress any date range parameters and force max source range.</td></tr>
    <tr><td>-INTRADAY       </td><td>Triggers intraday table update. The source/view must have interval_id field in line with A_TIME_INTERVAL table</td></tr>
    <tr><td>-NOINTRADAY     </td><td>Skips intraday update even if it was set up in a procedure or an import.</td></tr>
    <tr><td>-LOG_ROWCOUNT   </td><td>Logs a number of rows affected after all executions to A_SYS_LOG.</td></tr>
    <tr><td>-LOG_INSERT     </td><td>Logs insert queries.</td></tr>
    <tr><td>-LOG_DELETE     </td><td>Logs delete queries.</td></tr>
    <tr><td>-NOSCHEDULE     </td><td>Supress scheduling if any and force queries execution.</td></tr>
    <tr><td>-VERSION        </td><td>Outputs the version information.</td></tr>
    <tr><td>-HELP           </td><td>Outputs help information.</td></tr>
    <tr><td> </td><td></td></tr>
    </table>
    ';
    IF @commands like '%-HELP%'  BEGIN SET @output = @output + @help ; PRINT @help; END 

    IF @commands like '%-OUTPUT%'  select @output as SQL_OUTPUT

END

