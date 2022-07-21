USE [Anwb_Rhl]
GO
/****** Object:  StoredProcedure [A_SP_IMPORT]    Script Date: 21-7-2022 09:13:59 ******/
SET ANSI_NULLS OFF
GO
SET QUOTED_IDENTIFIER ON
GO

-- version 20220711
-- scheduling parameter added
-- more error handling
-- see more version information at the end

ALTER     PROCEDURE [A_SP_IMPORT]
 @activity_id int = 0 
,@session_id nvarchar(50)  = null
,@commands varchar(2000)='' -- '-LOG_ROWCOUNT -LOG_INSERT -LOG_DELETE -PRINT -NOGROUPBY -SUMFIELDS -NOINTRADAY -NODELTA -INTRADAY -VERSION -HELP
,@procedure_name nvarchar(200)='A_SP_IMPORT'
,@site_id int =0
,@import_id int =0
,@fact_day nvarchar(200) ='[A_FACT_DAY]' -- data per day stored here
,@fact_intraday nvarchar(200)='[A_FACT_INTRADAY]' -- data per day/interval_id is stored here. conform a_time_interval dimension
AS
BEGIN
    SET NOCOUNT ON;
    SET DATEFIRST 1
--  configuration
    DECLARE @sqlCommand NVARCHAR(MAX) -- 

--  source data parameters
	DECLARE @forecast_id int = 0
	DECLARE @filter nvarchar(4000)=''           -- where filter for filtering source data
	DECLARE @date_import_from date='1900-01-01' -- calculated by the import query using imports and procedures fields
	DECLARE @date_import_until date='9999-01-01'
	DECLARE @fields_source varchar(2000)=''     -- source fields
	DECLARE @fields_target varchar(2000)=''     -- target fields value1
	DECLARE @schedule varchar(2000)=''
	DECLARE @source varchar(2000)=''
	DECLARE @group_by varchar(2000)=''
    
    -- parameters
	DECLARE @p1 varchar(2000)=''                
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
    DECLARE @day_source varchar(max)=''

	-- intraday parameters
	DECLARE @intraday_join varchar(2000)=''
	DECLARE @intraday_interval_id varchar(200)='interval_id'
	DECLARE @intraday_duration varchar(5)='15' -- default intraday interval duration in min
    DECLARE @intraday_source varchar(max)=''

	DECLARE TAB_CURSOR CURSOR  FOR 
    SELECT import_id 
 	  ,[activity_id]
      ,[forecast_id]
      ,isnull([p1],'')
      ,isnull([p2],'')
      ,isnull([p3],'')
      ,isnull([p4],'')
      ,isnull([p5],'')
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
    WHERE   (import_id=@import_id or @import_id=0) AND (site_id=@site_id or @site_id=0)  
    AND ([procedure_name] like @procedure_name or procedure_code like @procedure_name or @import_id>0) and (activity_id=@activity_id or @activity_id=0)
    ORDER BY [sort_order]
    
	EXEC dbo.[A_SP_SYS_LOG] 'PROCEDURE START' ,@session_id  ,@activity_id  , @procedure_name ,@commands, @site_id
	SET @start_time     = GETDATE()

----------------------------------------------
--  FETCH ALL IMPORTS FOR THE CURRENT SP
----------------------------------------------
	OPEN TAB_CURSOR 
	FETCH NEXT FROM TAB_CURSOR 
	INTO     @import_id 
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

        DECLARE @errors int = 0 
        DECLARE @on_schedule bit=1
        IF RTRIM(@schedule)>'' BEGIN
            SET @sqlCommand = N'SELECT @on_schedule =  CASE WHEN ' +@schedule + ' THEN 1 ELSE 0 END'
            EXEC sp_executesql @sqlCommand, N'@on_schedule bit OUTPUT', @on_schedule=@on_schedule OUTPUT
        END 
        SET @day_source= case when @source>'' then @source else @fact_day end
        IF @commands NOT like '%-NODELTA%' BEGIN
            declare @dates varchar(30)
            SET @sqlCommand = 'select @dates = convert(char(10),convert(date,isnull(min(' + @group_by + '),''9999-12-31'')),126) + convert(char(10),convert(date,isnull(max(' + @group_by + '),''1900-12-31'')),126)
                FROM ' + @day_source +' WHERE ' + @filter
            BEGIN TRY
                EXEC sp_executesql @sqlCommand, N'@dates varchar(30) OUTPUT', @dates=@dates OUTPUT
                SET @date_source_min=left(@dates,10)
                SET @date_source_max=right(@dates,10)
            END TRY
     		BEGIN CATCH  
                SET @data=dbo.[A_FN_SYS_ErrorJson]()
                SET @output=@output+@data+'<br><br>'
                EXEC dbo.[A_SP_SYS_LOG] 'IMPORT ERROR' ,@session_id ,@import_id ,'CLEAN DAY',@data, @site_id
     		END CATCH;   

            IF @date_import_from<@date_source_min BEGIN SET @date_import_from=@date_source_min END
            IF @date_import_until>@date_source_max BEGIN SET @date_import_until=@date_source_max END				 
        END

        SET @output=@output+'-- DETECTED SOURCE DATES RANGE '+@dates+'<br>';
        SET @output=@output+'-- '+@sqlCommand+'<br>'; 


        IF @commands like '%-SUMFIELDS%' and @fields_source not like '%SUM(%)%' set @fields_source= concat('SUM(convert(float,',replace(@fields_source,',',')),SUM(convert(float,('),'))')

        set @data = left((concat(concat('{"p1":"',@p1,'",'),
        concat('"p2":"',@p2,'",'),
        concat('"p3":"',@p3,'",'),
        concat('"p4":"',@p4,'",'),
        concat('"p5":"',@p5,'"}')) 
        ),4000)
        set @data=JSON_MODIFY( @data,'$.filter',@filter)
        set @data=JSON_MODIFY( @data,'$.group_by',@group_by)
        set @data=JSON_MODIFY( @data,'$.fields_source',@fields_source)
        set @data=JSON_MODIFY( @data,'$.fields_target',@fields_target)

		--@category --@session_id --@object_id --@step_id -- data
		EXEC dbo.[A_SP_SYS_LOG] 'IMPORT RUN' ,@session_id  ,@import_id  , @procedure_name ,@data  , @site_id

        -- test parameters before running all
        IF @activity_id=0 OR @forecast_id=0 SET @errors=@errors+1 
        IF @date_import_until<@date_import_from  BEGIN 
            SET @errors=@errors+1 
            SET @output=@output+'-- <b>ERROR: Source dates cannot be found. Queries will not be executed due to errors. 
            Please check if source exists and/or the dates parameters.</b><br>'   
            EXEC dbo.[A_SP_SYS_LOG]  'IMPORT ERROR' ,@session_id ,@import_id , NULL, @sqlCommand , @site_id   
        END

	----------------------------------------------------------------------------------------------------------------------
	--  CLEAN DAY
	--------------------------------------------------------------------------------
 		
		SET @sqlCommand = 
 		'DELETE FROM '+ @fact_day +' WHERE [date] BETWEEN ''' + convert(char(10),@date_import_from,126)  + ''' AND ''' + convert(char(10),@date_import_until,126) + ''' AND activity_id =' +  convert(nvarchar(max),@activity_id) 
+ '	AND forecast_id = ' +  convert(nvarchar(max),@forecast_id);
        IF @commands like '%-PRINT%' PRINT @sqlCommand
 		BEGIN TRY		 
            SET @output=@output+'-- DELETING DAY DATA <br>'+@sqlCommand+'<br><br>';
			IF @commands not like '%-PRINT%'
            BEGIN
                IF @errors=0 BEGIN 
                    IF (@on_schedule=1) BEGIN
                        EXEC( @sqlCommand);SET @rows= @@ROWCOUNT          
                        SET @output=@output+'-- Number of day records deleted ' + convert(varchar(10),@rows)+'<br><br>'
                        IF @commands like '%-LOG_ROWCOUNT%' EXEC dbo.[A_SP_SYS_LOG] 'LOG ROWS' ,@session_id ,@import_id ,'RECORDS DELETE DAY',@rows  , @site_id
                        IF @commands like '%-LOG_DELETE%' EXEC dbo.[A_SP_SYS_LOG] 'LOG DELETE ROWS' ,@session_id ,@import_id ,'DELETE QUERY DAY',@sqlCommand , @site_id 
                    END
                    ELSE SET @output=@output+'-- <b>WARNING: Delete query was not executed due to the schedule parameter.</b> <br>'
                END
                ELSE SET @output=@output+'-- <b>ERROR: Queries will not be executed due to errors. Please check the parameters.</b><br>'       
            END
 		END TRY
 		BEGIN CATCH  
			SET @data=dbo.[A_FN_SYS_ErrorJson]()
            SET @output=@output+@data+'<br><br>'
			EXEC dbo.[A_SP_SYS_LOG] 'IMPORT ERROR' ,@session_id ,@import_id ,'CLEAN DAY',@sqlCommand  , @site_id
 		END CATCH;   

	--------------------------------------------------------------------------------------------------------------------------
	--  INSERT TO DAY
	-------------------------------------------------------------------------------------
 		IF @commands not like '%-NOGROUPBY%' OR @commands like  '%-SUMFIELDS%' 
            BEGIN SET @groupby=concat(' GROUP BY ',@group_by) END 
        ELSE SET @groupby=''

		SET @sqlCommand = 'INSERT INTO '+ @fact_day 
        +' ([date],activity_id,forecast_id,import_id,' + @fields_target + ',site_id)' + 
        'SELECT ' + @group_by + ',' +  convert(nvarchar(max),@activity_id)  
   		+ ', ' +  convert(nvarchar(max),@forecast_id) + ','+ convert(nvarchar(max),@import_id)
   		+ ',' + @fields_source +','+ convert(nvarchar(max),@site_id) +
 		' FROM '+ @day_source +' WHERE ' + @filter  
		+ ' AND ' + @group_by + ' BETWEEN ''' + convert(char(10),@date_import_from,126)  + ''' AND ''' + convert(char(10),@date_import_until,126) + '''' + @groupby +';'
        IF @commands like '%-PRINT%' PRINT @sqlCommand     

 		BEGIN TRY			
            SET @output=@output+ '-- INSERTING DAY DATA <br>'+ @sqlCommand + '<br><br>';
			IF @commands not like '%-PRINT%' 
            BEGIN 
                IF @errors=0 BEGIN 
                    IF (@on_schedule=1) BEGIN
                        EXEC( @sqlCommand); SET @rows= @@ROWCOUNT
                        IF @date_import_until<@date_import_from AND @commands like '%-LOG_ROWCOUNT%'  EXEC dbo.[A_SP_SYS_LOG] 'IMPORT WARNING' ,@session_id ,@import_id ,'NODATA ON INSERT', @sqlCommand  
                        IF @commands like '%-LOG_ROWCOUNT%' EXEC dbo.[A_SP_SYS_LOG] 'LOG ROWS' ,@session_id ,@import_id ,'RECORDS INSERT DAY',@rows  , @site_id
                        IF @commands like '%-LOG_INSERT%' EXEC dbo.[A_SP_SYS_LOG] 'LOG INSERT ROWS' ,@session_id ,@import_id ,'INSERT QUERY DAY',@sqlCommand , @site_id
                        SET @output=@output+'day records inserted ' + convert(varchar(10),@rows)+'<br><br>'  
                    END
                    ELSE SET @output=@output+'-- <b>WARNING: Delete query was not executed due to the schedule parameter.</b> <br>'
                END
                ELSE SET @output=@output+'-- <b>ERROR: Queries will not be executed due to errors. Please check the parameters.</b><br>'       
            END
        END TRY
   		BEGIN CATCH  
   			SET @data=JSON_MODIFY( @data,'$.error',dbo.[A_FN_SYS_ErrorJson]()) 
            SET @output=@output+dbo.[A_FN_SYS_ErrorJson]()+'<br><br>'
			EXEC dbo.[A_SP_SYS_LOG] 'IMPORT ERROR' ,@session_id ,@import_id ,'INSERT DAY',@sqlCommand, @site_id
        END CATCH;   

	IF @commands  like '%-INTRADAY%' AND @commands not like '%-NOINTRADAY%' BEGIN  
		SET @intraday_join= case when @p1>'' then @p1 else @intraday_join end
		SET @intraday_interval_id = case when @p1>'' then 'I.interval_id' else @intraday_interval_id end -- p1 has a join with interval table with alias I , we need override default
		SET @intraday_duration = case when @p2>'' then @p2 else @intraday_duration end  -- standard duration of the interval is 15 min
        SET @intraday_source= case when @source>'' then @source + ' ' + @intraday_join  else @fact_intraday end
	----------------------------------------------------------------------------------------------------------------------
	--  CLEAN INTRADAY
	--------------------------------------------------------------------------------	
		SET @sqlCommand = 
 		'DELETE	FROM '+  @fact_intraday 
        +' WHERE [date] BETWEEN ''' + convert(char(10),@date_import_from,126)  + ''' AND ''' 
        + convert(char(10),@date_import_until,126) +'''	AND activity_id =' +  convert(nvarchar(max),@activity_id) 
        + '	AND forecast_id = ' +  convert(nvarchar(max),@forecast_id) 
        ;
  
 		BEGIN TRY
			IF @commands like '%-PRINT%' PRINT @sqlCommand;
            SET @output=@output+ '-- DELETING INTRADAY DATA <br>'+ @sqlCommand + '<br><br>';
			IF @commands not like '%-PRINT%'
            BEGIN
            IF @errors=0 BEGIN 
                IF (@on_schedule=1) BEGIN
                    EXEC( @sqlCommand);SET @rows= @@ROWCOUNT;
                    IF @commands like '%-LOG_ROWCOUNT%' EXEC dbo.[A_SP_SYS_LOG]  'IMPORT WARNING' ,@session_id ,@import_id ,'NODATA ON DELETE', @sqlCommand  
                    SET @output=@output+'Number of intraday records deleted ' + convert(varchar(10),@rows)+'<br><br>'  
                    IF @commands like '%-LOG_ROWCOUNT%' EXEC dbo.[A_SP_SYS_LOG] 'LOG ROWS' ,@session_id ,@import_id ,'RECORDS DELETE INTRADAY',@rows  
                    IF @commands like '%-LOG_DELETE%' EXEC dbo.[A_SP_SYS_LOG] 'LOG DELETE ROWS' ,@session_id ,@import_id ,'DELETE QUERY INTRADAY',@sqlCommand  
                END
                ELSE SET @output=@output+'-- <b>WARNING: Delete intraday query was not executed due to the schedule parameter.</b> <br>'
            END
            ELSE SET @output=@output+'-- <b>ERROR: Intraday queries will not be executed due to errors. Please check the parameters.</b><br>'                  
            END
 		END TRY
 		BEGIN CATCH  
			SET @data=JSON_MODIFY( @data,'$.error',dbo.[A_FN_SYS_ErrorJson]()) 
            SET @output=@output + dbo.[A_FN_SYS_ErrorJson]()+'<br><br>'
			EXEC dbo.[A_SP_SYS_LOG] 'IMPORT ERROR' ,@session_id ,@import_id ,'CLEAN INTRADAY',@sqlCommand , @site_id 
 		END CATCH;   

	--------------------------------------------------------------------------------------------------------------------------
	--  INSERT TO INTRADAY
	-------------------------------------------------------------------------------------
 		IF @commands not like '%-NOGROUPBY%' OR @commands like  '%-SUMFIELDS%' BEGIN SET @groupby = concat(' GROUP BY ', @group_by, ',',@intraday_interval_id) END ELSE SET @groupby=''
        
		SET @sqlCommand = 'INSERT INTO '+ @intraday_source 
        +' ([date], activity_id, forecast_id, import_id, interval_id, duration_min,' + @fields_target + ',site_id)'
        +' SELECT ' + @group_by + ',' +  convert(nvarchar(max),@activity_id)  
   		+ ',' +  convert(nvarchar(max),@forecast_id) + ','+ convert(nvarchar(max),@import_id)
   		+ ',' + @intraday_interval_id + ', '+ convert(varchar(5),@intraday_duration) + ',' + @fields_source 
        + ',' + convert(nvarchar(max),@site_id) 
 		+ ' FROM '+ @intraday_source + ' WHERE ' + @filter  
		+ ' AND ' + @group_by + ' BETWEEN ''' + convert(char(10),@date_import_from,126)  + ''' AND ''' + convert(char(10),@date_import_until,126) + '''' 
        + @groupby +';'
        IF @commands like '%-PRINT%' PRINT @sqlCommand    
 		BEGIN TRY		 
            SET @output=@output+ '-- INSERTING INTRADAY DATA <br>'+ @sqlCommand + '<br><br>';
			IF @commands not like '%-PRINT%'
            BEGIN
                IF @errors=0 BEGIN 
                    IF (@on_schedule=1) BEGIN
                        EXEC( @sqlCommand);
                        SET @rows= @@ROWCOUNT;
                        IF @date_import_until<@date_import_from AND @commands like '%-LOG_ROWCOUNT%'  EXEC dbo.[A_SP_SYS_LOG] 'IMPORT WARNING' ,@session_id ,@import_id ,'NODATA ON INSERT', @sqlCommand  
                        SET @output=@output+'intraday records inserted ' + convert(varchar(10),@rows)+'<br><br>'  
                        IF @commands like '%-LOG_ROWCOUNT%' EXEC dbo.[A_SP_SYS_LOG] 'LOG ROWS' ,@session_id ,@import_id ,'RECORDS INSERT DAY',@rows  , @site_id
                        IF @commands like '%-LOG_INSERT%' EXEC dbo.[A_SP_SYS_LOG] 'LOG INSERT ROWS' ,@session_id ,@import_id ,'INSERT QUERY DAY',@sqlCommand , @site_id
                    END
                ELSE SET @output=@output+'-- <b>WARNING: Insert intraday query was not executed due to the schedule parameter.</b> <br>'
                END
                ELSE SET @output=@output+'-- <b>ERROR: Intraday queries will not be executed due to errors. Please check the parameters.</b><br>'                  
            END
        END TRY
   		BEGIN CATCH  
   			SET @data=dbo.[A_FN_SYS_ErrorJson]() 
            SET @output=@output + @data+'<br><br>'
			EXEC dbo.[A_SP_SYS_LOG] 'IMPORT ERROR' ,@session_id ,@import_id ,'INSERT DAY',@sqlCommand, @site_id
	    END CATCH;   

	END -- end if intraday

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
	EXEC dbo.[A_SP_SYS_LOG] 'PROCEDURE FINISH' ,@session_id  ,'Duration sec' , @procedure_name , @data, @site_id
    SET @output=@output + '<br> It took ' + @data + ' sec.'

    DECLARE @version nvarchar(max)='
    <br><i>VERSION INFORMATION </i>
    -- version 20220711
    -- scheduling parameter added
    -- more error handling
    -- intraday source fix for empty situation
    <br>
    -- version 20220622
    -- default day and intraday tables are used if the source parameter left empty.
    <br>
    -- version 20220603
    -- generic import of transactional data into time series/ MAIS data format
    -- this SP will generate queries and run/print them for every row from [A_IMPORT_RUN] view
    -- template stored procedure for loading data from source tables'
    IF @commands like '%-VERSION%'  SET @output = @output + @version

    DECLARE @help nvarchar(max)='<br><i>HELP INFORMATION</i>'
    IF @commands like '%-HELP%'  SET @output = @output + @help

    IF @commands like '%-OUTPUT%'  select @output as SQL_OUTPUT

END

