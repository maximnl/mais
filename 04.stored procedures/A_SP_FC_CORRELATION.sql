 
/****** Object:  StoredProcedure [dbo].[A_SP_FC_CORRELATION]    Script Date: 24-10-2024 17:33:53 ******/
SET ANSI_NULLS OFF
GO
SET QUOTED_IDENTIFIER ON
GO

-- template stored procedure for loading data from source tables
ALTER  PROCEDURE [dbo].[A_SP_FC_CORRELATION]
 @activity_id int = 0 
,@forecast_id int = 0 -- run imports for a forecast_id
,@session_id varchar(50)  = null
,@commands varchar(2000)='' -- '-LOG_ROWCOUNT -LOG_WARNING -LOG_QUERY -PRINT -NOGROUPBY -SUMFIELDS -SET_IMPORT_ID -VERSION -HELP -NOSCHEDULE
,@procedure_name nvarchar(200)=''
,@site_id int = 0
,@import_id int = 0
,@category nvarchar(200) ='' -- procedure category to run; empty to run all
AS
BEGIN

    DECLARE @SP varchar(20) = 'A_SP_FC_CORRELATION';	

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
		IF @schedule>''  AND ( @commands not like '%-NOSCHEDUL%' )   BEGIN TRY
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


		-- PROCEDURE SPECIFIC SUPPORT VARIABLES 
		DECLARE @activity_correlated_id INT=try_convert(int,@p1)  
		DECLARE @forecast_correlated_id INT=try_convert(int,@p2) 
		DECLARE @forecast_source_id INT=try_convert(int,@p3)	
		DECLARE @lag INT=try_convert(int,@p4) 
		DECLARE @coef real=try_convert(real,@p5)        
		 
		IF @fields_target='' BEGIN        
			SET @fields_target='[value1]';			         
			IF @commands like '%-LOG_WARNING%' BEGIN
				SET @warnings=@warnings+1;
				SET @data= 'WARNING: parameter [fields_target] is not set. Setting to [value1] by default.';  
				SET @output=@output+@data +'<br>';
				EXEC dbo.[A_SP_SYS_LOG] @category='MAIS SP', @result='Warning', @session=@session_id, @site = @site_id, @object=@SP, @object_sub=@procedure_name
				, @object_id=@import_id, @step=@step, @data=@data; 
				PRINT @data;
			END
		END

		IF @activity_correlated_id= 0 SET @activity_correlated_id=try_convert(int,@parent)
		IF @activity_correlated_id= 0 BEGIN
			SET @errors=@errors+1;
			SET @data ='ERROR:correlated activity parameter was not set. Use p1 or use activity parent field to set it.'
			SET @output=@output+'<b>' + @data + '<b><br>';
			PRINT @data;
			EXEC dbo.[A_SP_SYS_LOG] @category='MAIS SP', @result='Failed', @session=@session_id, @site = @site_id, @object=@SP, @object_sub=@procedure_name, @object_id=@import_id, @step=@step, @data=@data; 
		END

		IF @forecast_correlated_id=0 OR @forecast_source_id=0 BEGIN
			SET @errors=@errors+1;
			SET @data ='ERROR:correlated forecast parameter was not set.'
			SET @output=@output+'<b>' + @data + '<b><br>';
			PRINT @data;
			EXEC dbo.[A_SP_SYS_LOG] @category='MAIS SP', @result='Failed', @session=@session_id, @site = @site_id, @object=@SP, @object_sub=@procedure_name, @object_id=@import_id, @step=@step, @data=@data; 	
		END

		IF @coef=0 BEGIN 
			SET @warnings=@warnings+1;
			SET @data= 'WARNING: coeficient [p5] is not set or set to 0. Setting 1 by default.';
			SET @coef=1; 
			SET @output=@output+'<b>'+ @data +'</b><br>';
			IF @commands like '%-LOG_WARNING%' BEGIN
				EXEC dbo.[A_SP_SYS_LOG] @category='MAIS SP', @result='Warning', @session=@session_id, @site = @site_id, @object=@SP, @object_sub=@procedure_name, @object_id=@import_id, @step=@step, @data=@data; 
				PRINT @data;
			END
		END
        
		SET @date_import_from=isnull(@date_import_from,[dbo].[A_FN_TI_FirstDayCurrentYear](NULL));
 		SET @date_import_until=isnull(@date_import_until,[dbo].[A_FN_TI_LastDayCurrentYear](NULL));	
 
		--------------------------------------------------------------------------------	
		SET @step='DELETE DAY'
		----------------------------------------------------------------------------------------------------------------------
		
		SET @sqlCommand ='DELETE FROM '+ @fact_day + 
        + ' WHERE activity_id=' + convert(varchar(10),@activity_id)  
        + ' AND forecast_id=' + convert(varchar(10),@forecast_id)  
        + '	AND site_id = ' +  convert(nvarchar(max),@site_id)
        + ' AND [date] between ''' 
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
		 
		SET @sqlCommand = '
        /* aggregate correlation data for the activity to be forecasted */
        ;with ACT as (
        SELECT weeks_2000 as timekey
        , sum(isnull(value1,0)) value1
        FROM ' + @fact_day + ' S WITH (NOLOCK)
        RIGHT JOIN [A_TIME_DATE] D on S.date=D.[date]
        WHERE S.activity_id='+ convert(varchar(10),@activity_id)
        +' AND forecast_id='+ convert(varchar(10),@forecast_correlated_id) 
        +' GROUP BY D.weeks_2000
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
        FROM '+ @fact_day +' S WITH (NOLOCK)
        RIGHT JOIN [A_TIME_DATE] D on S.date=D.[date]
        WHERE S.activity_id='+ convert(varchar(10),@activity_correlated_id )+ ' AND forecast_id='+ convert(varchar(10),@forecast_correlated_id ) 
        + ' GROUP BY D.weeks_2000)

        /* add moving average for smoothing */
        ,REF1 as(
        SELECT timekey
        ,avg(value1) over (order by timekey rows between 1 preceding and 1 following) as value1
        FROM REF)

        /* add ma lagging */
        ,REF2 as(
        SELECT timekey
        , LAG(value1,' + convert(varchar(10),@lag) +' ) over (order by timekey) as value1
        FROM REF1)

        /* aggregate correlation forecast */
        ,F as (SELECT weeks_2000 as timekey
        , sum(isnull(value1,0)) value1
        FROM '+ @fact_day +' S WITH (NOLOCK)
        RIGHT JOIN [A_TIME_DATE] D on S.date=D.[date]
        WHERE S.activity_id='+ convert(varchar(10),@activity_correlated_id) +' and forecast_id='+ convert(varchar(10),@forecast_source_id) 
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

        , R1 as (
        /* join forecast with lag historical ratios */ 
        SELECT   F1.timekey, R1.actual1, R1.ACT_value1 , R1.REF_value1, F1.value1 forecast
      --  ,R1.ratio1 f1
      --  ,R5.ratio1 as f5
      --  ,R52.ratio1 as f52
	--	,R104.ratio1 as f104
	--	,R156.ratio1 as f156
        , (5.0*isnull(F1.value1*R1.ratio1,0) + 4.0*isnull(F1.value1*R5.ratio1,0) + 3.0*isnull(F1.value1*R52.ratio1,0)  + 2.0*isnull(F1.value1*R104.ratio1,0) + isnull(F1.value1*R156.ratio1,0) )
        / (case when R1.ratio1 is not null then 5 else 0 end 
		+ case when R5.ratio1 is not null then 4 else 0 end 
		+ case when R52.ratio1 is not null then 3 else 0 end 
		+ case when R104.ratio1 is not null then 2 else 0  end
		+ case when R156.ratio1 is not null then 1 else 0  end ) 
		as f
        FROM F1
        left join R as R1 on F1.timekey=R1.timekey+1 
        left join R as R5 on F1.timekey=R5.timekey+5
        left join R as R52 on F1.timekey=R52.timekey+52
		left join R as R104 on F1.timekey=R104.timekey+104
		left join R as R156 on F1.timekey=R156.timekey+156
        WHERE (case when R1.ratio1 is not null then 1 else 0 end 
		+ case when R5.ratio1 is not null then 1 else 0 end 
		+ case when R52.ratio1 is not null then 1 else 0 end 
		+ case when R104.ratio1 is not null then 1 else 0  end
		+ case when R156.ratio1 is not null then 1 else 0  end
		) >0
        )  
        INSERT INTO '+ @fact_day 
                +' ([date],activity_id,forecast_id,import_id,' + @fields_target + ',site_id,date_updated) '+
            ' SELECT D.date, '+ convert(varchar(10),@activity_id)+', ' + convert(varchar(10),@forecast_id) 
            + ',' + convert(varchar(10),@import_id)  
            + ',R1.f/7 * ' + convert(varchar(max),@coef) + ',' +  convert(varchar(10),@site_id)  
            + ',getdate()  FROM R1 
        INNER JOIN [A_TIME_DATE] D on R1.timekey=D.[weeks_2000] 
        WHERE D.date between ''' + convert(varchar(10),@date_import_from,126) + ''' and '''+ convert(varchar(10),@date_import_until,126)+ ''';'



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
		

-- SNIPPET END PROCEDURE ********************************************************
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
 
        IF @commands like '%-LOG_IMPORT%' AND @errors=0 BEGIN 
            EXEC dbo.[A_SP_SYS_LOG] @category='MAIS SP', @result='Succeeded', @session=@session_id, @site = @site_id, @object=@SP, @object_sub=@procedure_name
            , @object_id=@import_id, @step=@step, @data=@data, @duration=@duration, @value=@warnings; 
        END
        IF @errors>0  BEGIN   EXEC dbo.[A_SP_SYS_LOG] @category='MAIS SP', @result='Failed', @session=@session_id, @site = @site_id, @object=@SP, @object_sub=@procedure_name
        , @object_id=@import_id, @step=@step, @data=@data, @duration=@duration, @value=@errors; 	 
		END
 
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


-------------------------------------------------------------------------------------
    DECLARE @version nvarchar(max)
    DECLARE @help nvarchar(max)

    SET @version='
    <i>VERSION INFORMATION </i>  <br>  
	--  VERSION 20230315  <br>
    --  logging improved, snippets design <br>
	<br>-- VERSION 20230314 NOLOCK added, logging improvements 
    <br>-- VERSION 20220705 
    <br>-- VERSION 20220708 Schedule parameter included in all Exec
    <br>-- VERSION 20220705 
    <br>-- Parent activity id is added to complement p1
    '
    IF @commands like '%-VERSION%'  SET @output = @output + @version + '</br>';

    SET @help='<br>
    <br><i>HELP INFORMATION</i>
    <br>This import procedure calculates a forecast from a forecast source for a correlated activity 
    based on the historical ratios defined by the correlated activity and correlated forecast (actuals). 
    <br>Procedure parameters: 
    <br>p1  - activity_correlated_id = '+ convert(varchar(max),@activity_correlated_id)+';
    <br>p2 - forecast_correlated_id = '+ convert(varchar(max),@forecast_correlated_id)+';
    <br>p3 - forecast_source_id = '+ convert(varchar(max),@forecast_source_id)+';
    <br>p4 - lag - '+ convert(varchar(max),@lag)+';
    <br>p5 - coefficient, default is 1. = '+ convert(varchar(max),@coef)+';
    <br>p1 will be replaced by activity parent ='+ convert(varchar(max),@parent)+' if p1 is left empty.';

    IF @commands like '%-HELP%'  SET @output = @output + @help + '</br>';
    IF @commands like '%-OUTPUT%'  select @output as SQL_OUTPUT

END

