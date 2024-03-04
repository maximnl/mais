SET ANSI_NULLS OFF
GO
SET QUOTED_IDENTIFIER ON
GO

-- stored procedure for regresion base transformation of time lagged timeserie data value1
ALTER  PROCEDURE [dbo].[A_SP_FC_REG]
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

    DECLARE @SP varchar(20) = 'A_SP_FC_REG';

  
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

		-- procedure specific = p1 Parameters source_file filter
		DECLARE @param_filter nvarchar(1000) ='';
        SET @param_filter = try_convert(nvarchar(1000),@p1) -- file_id=417 and A = 639  -- source file filter ; B is a text filter, can be used instead of numeric A
        SET @param_filter=@param_filter + ' AND A = '+convert(varchar(10),@activity_id);

        IF @param_filter='' BEGIN
            SET @errors=@errors+1 
            SET @data = '-- <b>Error: [param_filter] parameter should have filter on A_SOURCE_FILE table to select right parameters. </b><br>';
            SET @output=@output+@data;   
            EXEC dbo.[A_SP_SYS_LOG] @category='MAIS SP', @session=@session_id, @site = @site_id, @object=@SP, @object_sub=@procedure_name, @object_id=@import_id, @step='Parameter filter TEST', @data=@data,@result='Failed';
        END

        DECLARE @timelag_max int = 30 -- max of time lag to stretch @date_min

        -- test parameters before running all
        IF @filter='' BEGIN
            SET @errors=@errors+1 
            SET @data= '-- <b>Error: [filter] parameter should define forecast_id and optionaly activity_ids (activity_set) for a timeserie data from the SOURCE table. 
            If activity_id is missing, a default parent_activity_id will be used.  </b><br>';
            SET @output=@output+ @data;    
            EXEC dbo.[A_SP_SYS_LOG] @category='MAIS SP', @session=@session_id, @site = @site_id, @object=@SP, @object_sub=@procedure_name, @object_id=@import_id, @step='IMPORT FILTER TEST', @data=@data,@result='Failed'
        END
        ELSE BEGIN
            IF @filter not like '%activity%' SET @filter=@filter + ' AND activity_id='+convert(varchar(10),@parent);
            IF @filter not like '%forecast%' SET @filter=@filter + ' AND forecast_id=0';
            SET @filter=@filter + ' AND site_id='+convert(varchar(10),@site_id);
        END

        IF @source='' BEGIN
            SET  @source=@fact_day;
            SET @output=@output+'<br>-- <i>Source was set to [A_FACT_DAY] table by deafult. </i>';
        END       

        -- if source or target fields are empty set it by default to all value fields
        IF @fields_source='' BEGIN 
            SET @warnings=@warnings+1;
            SET @fields_source='[value1]';        
            SET @output=@output+'<br>-- <i>WARNING: Source fields are not specified. Setting default value1. </i>';
        END

        -- if source or target fields are empty set it by default to all value fields
        IF @fields_target=''  BEGIN 
            SET @warnings=@warnings+1;
            SET @fields_target='[value1]';
            SET @output=@output+'<br>-- <i>WARNING: Target field was not specified. Setting default value1. </i>';
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
 		' DELETE FROM '+ @fact_day +' WHERE activity_id =' +  convert(nvarchar(max),@activity_id) 
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
 		 
		SET @sqlCommand = '
    with D as 
    (select date, sum(value1) value1 from [A_FACT_DAY] 
    where ' + @filter + '  
    and date between dateadd(day,-' + convert(varchar(max),@timelag_max) +  ',''' + convert(char(10),@date_import_from,126)  + ''') and ''' + convert(char(10),@date_import_until,126)  + ''' 
    group by date
    )
    , T as (
    select date 
    , case when day_week=1 then 1 else 0 end d1
    , case when day_week=2 then 1 else 0 end d2
    , case when day_week=3 then 1 else 0 end d3
    , case when day_week=4 then 1 else 0 end d4
    , case when day_week=5 then 1 else 0 end d5
    , case when day_week=6 then 1 else 0 end d6
    from [A_TIME_DATE]  
    where date between ''' + convert(char(10),@date_import_from,126)  + ''' AND ''' + convert(char(10),@date_import_until,126) + '''  
    ),

    D_CAT as (
    select date
    , 0 as cat
    , isnull(value1,0) val 
    from D 
    union all 
    select date
    , 1 as cat
    , sum(isnull(value1,0)) OVER(ORDER BY D.Date 
    ROWS BETWEEN 1 PRECEDING AND 1 PRECEDING )  as val
    from D
    union all 
    select date
    , 2 as cat
    , sum(isnull(value1,0)) OVER(ORDER BY D.Date 
    ROWS BETWEEN 2 PRECEDING AND 2 PRECEDING )  as val
    from D
    union all 
    select date
    , 3 as cat
    , sum(isnull(value1,0)) OVER(ORDER BY D.Date 
    ROWS BETWEEN 6 PRECEDING AND 3 PRECEDING )  as val
    from D
    union all 
    select date
    , 4 as cat
    , sum(isnull(value1,0)) OVER(ORDER BY D.Date 
    ROWS BETWEEN 13 PRECEDING AND 7 PRECEDING ) as val
    from D 
    )

    , P as (
    select try_convert (smallint,right(C,1))  cat 
    , try_convert(int,A) activity_id
    , try_convert(real,D) offset 
    , try_convert(real,E) inc 
    , try_convert(real,F) d1 
    , try_convert(real,G) d2 
    , try_convert(real,H) d3 
    , try_convert(real,I) d4 
    , try_convert(real,J) d5 
    , try_convert(real,K) d6
    , try_convert(real,L) f      
    from [A_SOURCE_FILE] 
    where ' + @param_filter  + ' 
    )
    , D_LOG as (
    select date,D_CAT.cat,LOG(val+P.f) val_log, val
    from D_CAT inner join P on D_CAT.cat=P.cat
    )
    , RES as (
    select T.date
    , sum(EXP(P.offset + D_LOG.val_log*P.inc + T.d1*P.d1+T.d2*P.d2+ T.d3*P.d3+T.d4*P.d4+T.d5*P.d5+T.d6*P.d6)-P.f) value1
    , sum(CASE WHEN D_LOG.cat=0 then EXP(P.offset + D_LOG.val_log*P.inc + T.d1*P.d1+T.d2*P.d2+ T.d3*P.d3+T.d4*P.d4+T.d5*P.d5+T.d6*P.d6)-P.f ELSE 0 END) value2
    , sum(CASE WHEN D_LOG.cat=1 then EXP(P.offset + D_LOG.val_log*P.inc + T.d1*P.d1+T.d2*P.d2+ T.d3*P.d3+T.d4*P.d4+T.d5*P.d5+T.d6*P.d6)-P.f ELSE 0 END) value3
    , sum(CASE WHEN D_LOG.cat=2 then EXP(P.offset + D_LOG.val_log*P.inc + T.d1*P.d1+T.d2*P.d2+ T.d3*P.d3+T.d4*P.d4+T.d5*P.d5+T.d6*P.d6)-P.f ELSE 0 END) value4
    , sum(CASE WHEN D_LOG.cat=3 then EXP(P.offset + D_LOG.val_log*P.inc + T.d1*P.d1+T.d2*P.d2+ T.d3*P.d3+T.d4*P.d4+T.d5*P.d5+T.d6*P.d6)-P.f ELSE 0 END) value5
    , sum(CASE WHEN D_LOG.cat=4 then EXP(P.offset + D_LOG.val_log*P.inc + T.d1*P.d1+T.d2*P.d2+ T.d3*P.d3+T.d4*P.d4+T.d5*P.d5+T.d6*P.d6)-P.f ELSE 0 END) value6
    , null value7
    , sum(EXP(P.offset + D_LOG.val_log*P.inc + T.d1*P.d1+T.d2*P.d2+ T.d3*P.d3+T.d4*P.d4+T.d5*P.d5+T.d6*P.d6)-P.f) 
    - sum(CASE WHEN D_LOG.cat=0 then EXP(P.offset + D_LOG.val_log*P.inc + T.d1*P.d1+T.d2*P.d2+ T.d3*P.d3+T.d4*P.d4+T.d5*P.d5+T.d6*P.d6)-P.f ELSE 0 END) 	as value8
    , null value9
    , null value10
    from D_LOG inner join T on D_LOG.date=T.date
    inner join P on D_LOG.cat=P.cat
    group by T.date
    )

    INSERT INTO '+ @fact_day 
    +' ([date],activity_id,forecast_id, import_id,' + @fields_source + ',site_id) 
    select date,' +  convert(varchar(max),@activity_id)  
    + ', ' +  convert(varchar(max),@forecast_id) + ','+ convert(varchar(max),@import_id) + ',' + @fields_target + ',' + convert(nvarchar(max),@site_id) + ' FROM RES;'       
					
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
		SET @output=@output + '</br>' + @data  + '</br>';
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
   	VERSION 20240304  <br>
    <p>Fields source parameter accepts value1, value2,...,value10.
    Extra calculations can be made eg. value1,value2,value1-value2.
    Fields target value1,value2,value3
    
    </p>
    <H3>VERSION INFORMATION </H3>
   	VERSION 20230315  <br>
    logging improved, snippets design <br></br>
     
'
    IF @commands like '%-VERSION%'  BEGIN SET @output = @output + @version; PRINT @version; END 

    DECLARE @help nvarchar(max)='<br><i>HELP INFORMATION</i>
    <br>
    <br> A procedure for regression based time laggen transformation of (parent)  serie set by the [filter].
    <br> P1 specifies file with the parameters from (S_SOURCE_FILE) table. 
    <br> Example:
    
    <br>
    <br>SP PARAMETERS
    <br>@activity_id int = 0     -- run imports for an activity_id or 0 for all.
    <br>@import_id int = 0       -- run import_id or 0 for all.
    <br>@session_id nvarchar(50)  = null -- session id for loging, keep empty for an autogenerated uid.
    <br>@procedure_name nvarchar(200)=A_SP_FC_SPLIT -- the app / procedure name to run
    <br>@site_id int = 0 -- site to run
    <br>@commands varchar(2000)
    
    <br><br>Inherited parameters from procedure or import configuration:
    <br>[Source] - a list , comma separated with totals per month. the first value will map with the first month, determined by the [Filter] parameter. To be used at import level, leave empty at the procedure level.
    <br>[Fields source] - value1 by default
    <br>[Fields target] - a single value column name, value1 used as default
    <br>[Filter] -  activity_id=372 and forecast_id=4 , parent activity filter added if activity_id missing
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
GO
