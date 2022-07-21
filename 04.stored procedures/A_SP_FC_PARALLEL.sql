SET ANSI_NULLS OFF
GO
SET QUOTED_IDENTIFIER ON
GO



-- template stored procedure for loading data from source tables
CREATE  PROCEDURE [dbo].[A_SP_FC_PARALLEL]
    @activity_id int = 0 
,
    @session_id varchar(50)  = null
,
    @commands varchar(2000)='' -- -LOG_ROWCOUNT -LOG_INSERT -LOG_DELETE -PRINT -NOGROUPBY -SUMFIELDS -SET_IMPORT_ID -HELP -VERSION
,
    @procedure_name nvarchar(200)='A_SP_FC_PARALLEL'
,
    @site_id int =0
,
    @import_id int =0
AS
BEGIN

    SET NOCOUNT ON;
    SET DATEFIRST 1

    --  configuration
    DECLARE @fact_day nvarchar(200)='[A_FACT_DAY]'
    -- data per day stored here
    DECLARE @fact_intraday nvarchar(200)='[A_FACT_INTRADAY]'
    -- data per day/interval_id is stored here. conform a_time_interval dimension
    DECLARE @sqlCommand NVARCHAR(MAX)
    -- 

    --  source data parameters
    DECLARE @forecast_id int = 0
    DECLARE @filter nvarchar(4000)=''
    -- where filter for filtering source data
    DECLARE @date_import_from date='9999-01-01'
    -- calculated by the import query using imports and procedures fields
    DECLARE @date_import_until date='1900-01-01'
    DECLARE @fields_source varchar(2000)=''
    -- source fields
    DECLARE @fields_target varchar(2000)=''
    -- target fields value1
    DECLARE @schedule varchar(2000)=''
    DECLARE @source varchar(2000)=''
    DECLARE @group_by varchar(2000)=''
    DECLARE @p1 varchar(2000)=''
    -- parameters
    DECLARE @p2 varchar(2000)=''
    DECLARE @p3 varchar(2000)=''
    DECLARE @p4 varchar(2000)=''
    DECLARE @p5 varchar(2000)=''
    DECLARE @groupby varchar(2000)=''

    -- login parameters
    DECLARE @data  varchar(4000)=''
    -- log data
    DECLARE @rows INT
    -- keep affected rows
    DECLARE @start_time datetime=null
    DECLARE @output nvarchar(max)='';

    -- source data analysis
    DECLARE @date_source_min date='9999-01-01'
    -- calculated by the import query using imports and procedures fields
    DECLARE @date_source_max date='1900-01-01'
    DECLARE @day_source varchar(max)=''

    -- intraday parameters
    DECLARE @intraday_join varchar(2000)=''
    DECLARE @intraday_interval_id varchar(200)='interval_id'
    DECLARE @intraday_duration varchar(5)='15'
    -- default intraday interval duration in min


    DECLARE TAB_CURSOR CURSOR  FOR 
    SELECT import_id 
 	  , [activity_id]
      , [forecast_id]
      , [p1]
      , [p2]
      , [p3]
      , [p4]
      , [p5]
      , [date_import_from]
      , [date_import_until]
      , [fields_source]
      , [fields_target]
      , [schedule]
      , isnull([filter],'1=1') filter
      , [source]
      , [group_by]
	  , concat(@commands,' ',commands)
	  , [procedure_name]
	  , site_id
    FROM dbo.[A_IMPORT_RUN]
    WHERE   (import_id=@import_id or @import_id=0)
        AND (site_id=@site_id or site_id is null or @site_id=0)
        AND ([procedure_name] like @procedure_name or procedure_code like @procedure_name or @import_id>0)
        and (activity_id=@activity_id or @activity_id=0)
    ORDER BY [sort_order]

    EXEC dbo.[A_SP_SYS_LOG] 'PROCEDURE START' ,@session_id  ,@activity_id  , @procedure_name ,@commands, @site_id
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
        DECLARE @errors int = 0
        DECLARE @on_schedule bit=1
        IF RTRIM(@schedule)>'' BEGIN
            SET @sqlCommand = N'SELECT @on_schedule =  CASE WHEN ' +@schedule + ' THEN 1 ELSE 0 END'
            EXEC sp_executesql @sqlCommand, N'@on_schedule bit OUTPUT', @on_schedule=@on_schedule OUTPUT
        END
        SET @day_source= case when @source>'' then @source else @fact_day end

        IF TRY_CONVERT(INT,@p1)=0 SET @p1 = 1
        -- forecast from id 
        IF TRY_CONVERT(INT,@p5)=0 SET @p5 = 1
        -- LAG YEARS
        IF LEN(@filter)<4 SET @filter='S.activity_id='+convert(varchar(10),@activity_id)

        IF @p2 like '%m%' BEGIN
            -- procedure is per maand
            SET @p2 = '[day_month]'
            --	DAY LEVEL FIELD (FROM TIME_DATE)
            SET @p3 = '[month]'
            --	SEAZON LEVEL
            SET @p4 = '[year]'
        --	YEAR LEVEL
        END
		 ELSE BEGIN
            -- DEFAULT per week, overwrite parameters in case garbadge in
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
            SET @output=@output+'-- <b>ERROR: Source dates cannot be found. Queries will not be executed due to errors. 
            Please check if source exists and/or the dates parameters.</b><br>'
            EXEC dbo.[A_SP_SYS_LOG]  'IMPORT ERROR' ,@session_id ,@import_id , NULL, @sqlCommand , @site_id
        END

        ----------------------------------------------------------------------------------------------------------------------
        --  CLEAN DAY

        -- this SP supports batch loading, so several activities passed in the @filter parameter, 
        -- so we deviate from the standard import delete here
        --------------------------------------------------------------------------------	
        SET @sqlCommand ='DELETE S FROM ' + @fact_day + ' S'+ 
		' INNER JOIN [A_DIM_ACTIVITY] A on S.activity_id=A.activity_id' +
        ' WHERE forecast_id=' + convert(varchar(10),@forecast_id) + ' AND ' + @filter + ' and date between ''' 
		 + convert(varchar(10),@date_import_from,126) + ''' AND '''+ convert(varchar(10),@date_import_until,126) + '''' + '	AND S.site_id = ' +  convert(nvarchar(max),@site_id)
        ;
        IF @commands like '%-PRINT%' PRINT @sqlCommand
        BEGIN TRY			
            SET @output=@output+'-- DELETING DAY DATA <br>'+@sqlCommand+'<br><br>';
			IF @commands not like '%-PRINT%' 
            BEGIN
            IF @errors=0 BEGIN
                IF (@on_schedule=1) BEGIN
                    EXEC( @sqlCommand);
                    SET @rows = @@ROWCOUNT
                    SET @output=@output+'day records deleted ' + convert(varchar(10),@rows)+'<br><br>'
                    IF @commands like '%-LOG_ROWCOUNT%' EXEC dbo.[A_SP_SYS_LOG] 'LOG ROWS' ,@session_id ,@import_id ,'RECORDS DELETE DAY',@rows  , @site_id
                    IF @commands like '%-LOG_DELETE%'   EXEC dbo.[A_SP_SYS_LOG] 'LOG DELETE ROWS' ,@session_id ,@import_id ,'DELETE QUERY DAY',@sqlCommand  , @site_id
                END
                    ELSE SET @output=@output+'-- <b>WARNING: Delete query was not executed due to the schedule parameter.</b> <br>'
            END
                ELSE SET @output=@output+'-- <b>ERROR: Queries will not be executed due to errors. Please check the parameters.</b><br>'
        END
 		END TRY
 		BEGIN CATCH  
			SET @data=dbo.[A_FN_SYS_ErrorJson]() 
            SET @output=@output+ '<b>ERROR:' + @data+'</b><br><br>'
			EXEC dbo.[A_SP_SYS_LOG] 'IMPORT ERROR' ,@session_id ,@import_id ,'CLEAN DAY',@sqlCommand  , @site_id
 		END CATCH;

        --------------------------------------------------------------------------------------------------------------------------
        --  INSERT TO DAY
        -------------------------------------------------------------------------------------

        SET @sqlCommand = ' INSERT INTO '+ @fact_day 
        +' ([date],activity_id,forecast_id,import_id,' + @fields_target + ',site_id) '+
       ' SELECT D.date, activity_id, ' + convert(varchar(10),@forecast_id) 
	+ ' as forecast_id, ' + convert(varchar(10),@import_id) + ','+
	+ @fields_source +',site_id FROM ( select S.*, d.' + @p2+', d.'+@p3+', d.'+@p4+',A.activity_set,A.domain,A.category'+
   		' FROM ' + @day_source +'  S'+
		' INNER JOIN [A_DIM_ACTIVITY] A on S.activity_id=A.activity_id' +
   		' INNER JOIN [A_TIME_DATE] d on S.[date]=d.[date]' +
   		' AND forecast_id=' + convert(varchar(10),@p1) + ' AND A.active=1 AND ' + @filter +') as SD'+
     	 ' INNER JOIN [A_TIME_DATE] D on D.date between ''' 
		 + convert(varchar(10),@date_import_from,126) + ''' and '''+ convert(varchar(10),@date_import_until,126) 
		 + ''' AND SD.' + @p2+'=D.' + @p2+' AND ((SD.'+@p3+'=D.'+@p3+' and SD.'+@p4+'=(D.'+@p4+'-' + convert(varchar(10),@p5)+ ')))'
        IF @commands like '%-PRINT%' PRINT @sqlCommand
        BEGIN TRY
            SET @output=@output+ '-- INSERTING DAY DATA <br>'+ @sqlCommand + '<br><br>';
			IF @commands not like '%-PRINT%'
            BEGIN
            IF @errors=0 BEGIN
                IF (@on_schedule=1) BEGIN
                    EXEC( @sqlCommand);
                    SET @rows= @@ROWCOUNT
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
   			SET @data=dbo.[A_FN_SYS_ErrorJson]() 
            SET @output=@output+ '<b>ERROR:' + @data+'</b><br>'
			EXEC dbo.[A_SP_SYS_LOG] 'IMPORT ERROR' ,@session_id ,@import_id ,'INSERT DAY',@sqlCommand, @site_id
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
    END
    -- END OF FETCHING IMPORTS

    CLOSE TAB_CURSOR
    DEALLOCATE TAB_CURSOR

    SET @data=DATEDIFF(second,@start_time,getdate())
    EXEC dbo.[A_SP_SYS_LOG] 'PROCEDURE FINISH' ,@session_id  ,null  , @procedure_name , @data , @site_id
    SET @output=@output + '<br> It took ' + @data + ' sec.'


    DECLARE @version nvarchar(max)='
    <br>
    -- version 20220711  <br>
    -- scheduling parameter added  <br>
    -- more error handling  <br>

    -- version 20220622  <br>
    -- default day and intraday tables are used if the source parameter left empty.  <br>

    -- version 20220603  <br>
    -- generic import of transactional data into time series/ MAIS data format  <br>
    -- this SP will generate queries and run/print them for every row from [A_IMPORT_RUN] view  <br>
    -- template stored procedure for loading data from source tables  <br>
'
    IF @commands like '%-VERSION%'  SET @output = @output + @version

    DECLARE @help nvarchar(max)='
	<H3>HELP INFORMATION </H3>
	Calculates historical parallel periods. It can run on the current acitivity or in a batch mode. 
	<br> Batch mode calculates a number of activities in a single query. This is done for easier configuration and performance considerations)
    <br> P1 - forecast from  
    <br> P2 - level; day_week (default, per week), day_month - per month  
    <br> P3 - filled in automatically based on P2   
    <br> P4 - idem aan P3  
    <br> P5 - lag years, 1 for last year, 2 for 2 years ago , etc. 

    <br> <br> Filter - Batch mode - any filter on the activity fields or use 11=11 for all activities. 
	<br> Single activity mode - If empty or shorter than 4 symbols, the current activity will go <br>
    Source - leave empty, A_FACT_DAY will be substituted automatically
'
    IF @commands like '%-HELP%'  SET @output = @output + @help

    IF @commands like '%-OUTPUT%'  select @output as SQL_OUTPUT

END
GO
