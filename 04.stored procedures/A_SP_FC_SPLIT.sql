SET ANSI_NULLS OFF
GO
SET QUOTED_IDENTIFIER ON
GO



-- template stored procedure for loading data from source tables
ALTER  PROCEDURE [dbo].[A_SP_FC_SPLIT]
 @activity_id int = 0 
,@forecast_id int = 0 -- run imports for a forecast_id
,@session_id nvarchar(50)  = null -- session id for loging, keep empty for an autogenerated uid
,@commands varchar(2000)='-NODELTA' -- '-LOG_ROWCOUNT -LOG_INSERT -LOG_DELETE' --'-PRINT' -NOGROUPBY -SUMFIELDS -SET_IMPORT_ID
,@procedure_name nvarchar(200)='A_SP_FC_SPLIT'
,@site_id int =0
,@import_id int =0
,@category nvarchar(200) ='' -- procedure category to run; empty to run all
AS
BEGIN

    SET NOCOUNT ON;
    SET DATEFIRST 1
--  configuration
    DECLARE @sqlCommand NVARCHAR(MAX) =''-- 

--  source data parameters
	DECLARE @filter nvarchar(4000)=''           -- where filter for filtering source data
	DECLARE @date_import_from date='9999-01-01' -- calculated by the import query using imports and procedures fields
	DECLARE @date_import_until date='1900-01-01'
	DECLARE @fields_source varchar(2000)=''     -- source fields
	DECLARE @fields_target varchar(2000)=''     -- target fields value1
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

    IF @session_id is null BEGIN SET @session_id=newid() END
    
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
    WHERE (import_id=@import_id or @import_id=0) 
    AND  (site_id=@site_id or @site_id=0)   
    AND ([procedure_id] like @procedure_name or [procedure_name] like @procedure_name or procedure_code like @procedure_name or @import_id>0) 
	AND (activity_id=@activity_id or @activity_id=0)
    AND ([category] like @category or @category='')
    ORDER BY [sort_order], [procedure_name];
    
	EXEC dbo.[A_SP_SYS_LOG] 'PROCEDURE START' ,@session_id  ,@activity_id  , @procedure_name , @commands, @site_id;
	SET @start_time = GETDATE();

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

        DECLARE @errors int = 0 ;
        DECLARE @on_schedule bit=1;

        -- test parameters before running all
        IF @filter='' BEGIN
            SET @errors=@errors+1 
            SET @output=@output+'-- <b>Error: [filter] parameter should define a timeserie data. </b><br>';   
            EXEC dbo.[A_SP_SYS_LOG]  'IMPORT ERROR' ,@session_id ,@import_id , 'NO FILTER DEFINED', '' , @site_id;   
        END
        ELSE SET @filter=@filter + ' AND F.site_id='+convert(varchar(10),@site_id);

        IF @schedule>'' BEGIN
            SET @sqlCommand = N'SELECT @on_schedule =  CASE WHEN ' +@schedule + ' THEN 1 ELSE 0 END'
            EXEC sp_executesql @sqlCommand, N'@on_schedule bit OUTPUT', @on_schedule=@on_schedule OUTPUT
        END 

        -- if source or target fields are empty set it by default to all value fields
        IF @fields_source='' OR @fields_target=''  BEGIN 
            SET @fields_source='[value1]';
            SET @fields_target='[value1]';
            SET @output=@output+'<br>-- <i>WARNING: Source and/or target field are not specified. Setting defaults. </i>';
        END

        IF @commands NOT like '%-NODELTA%' BEGIN			
            DECLARE @dates varchar(30)
            SET @group_by='F.[date]';
            SET @sqlCommand = 'select @dates = convert(char(10),convert(date,isnull(min(' + @group_by 
                + '),''9999-12-31'')),126) + convert(char(10),convert(date,isnull(max(' + @group_by 
                + '),''1900-12-31'')),126) FROM A_TIME_DATE T INNER JOIN A_FACT_DAY F on F.date=T.date WHERE ' + @filter;
            BEGIN TRY
                EXEC sp_executesql @sqlCommand, N'@dates varchar(30) OUTPUT', @dates=@dates OUTPUT
                SET @date_source_min=left(@dates,10);
                SET @date_source_max=right(@dates,10);
            END TRY
     		BEGIN CATCH  
                SET @errors=@errors+1;
                SET @data=dbo.[A_FN_SYS_ErrorJson]();
                SET @output=@output+'<br>ERROR - DELTA DETECTION:'+@data+'<br>'+@sqlCommand+'<br>';
                EXEC dbo.[A_SP_SYS_LOG] 'IMPORT ERROR' ,@session_id ,@import_id ,'DELTA DETECTION',@data, @site_id;
     		END CATCH;   

            IF @date_import_from<@date_source_min BEGIN SET @date_import_from=@date_source_min; END
            IF @date_import_until>@date_source_max BEGIN SET @date_import_until=@date_source_max; END	

            SET @output=@output+'-- DETECTED SOURCE DATES RANGE '+@dates+'<br>';
        END	

        IF @activity_id=0 OR @forecast_id=0 SET @errors=@errors+1 
        IF @date_import_until<@date_import_from  BEGIN 
            SET @errors=@errors+1 
            SET @output=@output+'-- <b>ERROR: Source dates cannot be found. Queries will not be executed. 
            Please check if source exists and/or the dates parameters.</b><br>'   
            EXEC dbo.[A_SP_SYS_LOG]  'IMPORT ERROR' ,@session_id ,@import_id , 'Source dates cannot be found', @sqlCommand , @site_id   
        END
        IF @source='' BEGIN
            SET @errors=@errors+1 
            SET @output=@output+'-- <b>ERROR: [source] parameter should be a comma separated list of values (monthly totals) to be splitted. </b><br>';   
            EXEC dbo.[A_SP_SYS_LOG]  'IMPORT ERROR' ,@session_id ,@import_id , 'NO SOURCE DATA TO BE SPLITTED', '' , @site_id ;  
        END    

	----------------------------------------------------------------------------------------------------------------------
	--  CLEAN DAY
	--------------------------------------------------------------------------------
		SET @sqlCommand = 
 		' DELETE FROM '+ @fact_day +' WHERE activity_id =' +  convert(nvarchar(max),@activity_id) 
    + '	AND forecast_id = ' +  convert(varchar(10),@forecast_id)
    + '	AND site_id = ' +  convert(varchar(10),@site_id) 
    + ' AND [date] BETWEEN ''' + convert(char(10),@date_import_from,126)  + ''' AND ''' + convert(char(10),@date_import_until,126) + ''';';
        SET @output=@output+'<br>-- DELETING DAY DATA <br>'+@sqlCommand+'<br><br>';

        IF @commands like '%-PRINT%' PRINT @sqlCommand
        ELSE BEGIN TRY			 
                IF @errors=0 BEGIN 
                    IF (@on_schedule=1 OR @commands like '%-NOSCHEDUL%' ) BEGIN
                        EXEC( @sqlCommand); SET @rows= @@ROWCOUNT;
                        SET @output=@output+'-- Number of day records deleted ' + convert(varchar(10),@rows)+'<br><br>';
                        IF @commands like '%-LOG_ROWCOUNT%' EXEC dbo.[A_SP_SYS_LOG] 'LOG ROWS' ,@session_id ,@import_id ,'RECORDS DELETE DAY',@rows  , @site_id;
                        IF @commands like '%-LOG_DELETE%' EXEC dbo.[A_SP_SYS_LOG] 'LOG DELETE ROWS' ,@session_id ,@import_id ,'DELETE QUERY DAY',@sqlCommand , @site_id; 
                    END
                    ELSE SET @output=@output+'-- <b>WARNING: Delete query was not executed due to the schedule parameter.</b> <br>';
                END
                ELSE SET @output=@output+'-- <b>ERROR: Queries will not be executed due to errors. Please check the parameters.</b><br>';                      
 		END TRY
 		BEGIN CATCH  
            SET @data=JSON_MODIFY( @data,'$.error',dbo.[A_FN_SYS_ErrorJson]()) 
            SET @sqlCommand = @sqlCommand + '/* error information:' + @data + '*/';
            PRINT @sqlCommand;
            SET @output=@output+'<br>ERROR on delete day data.<br>'+@data+'<br><br>';
            EXEC dbo.[A_SP_SYS_LOG] 'IMPORT ERROR' ,@session_id ,@import_id ,'DELETE DAY DATA',@sqlCommand,@site_id;  
 		END CATCH;   

	--------------------------------------------------------------------------------------------------------------------------
	--  INSERT TO DAY
	-------------------------------------------------------------------------------------
 		 
		SET @sqlCommand = 'INSERT INTO '+ @fact_day 
        +' ([date],activity_id,forecast_id, import_id,' + @fields_target + ',site_id) 
        select D.date,' +  convert(nvarchar(max),@activity_id)  
   		+ ', ' +  convert(nvarchar(max),@forecast_id) + ','+ convert(nvarchar(max),@import_id) 
        + ',D.day_weight*M.total ,'+ convert(nvarchar(max),@site_id) + ' 
        FROM (
            SELECT F.date, T.year_month_char, '+@fields_source+' 
        , '+ @fields_source +' / sum(' + @fields_source + ') over (partition by T.year_month_char) day_weight
        , dense_rank() over (order by T.year_month_char ) as total_id
        FROM A_TIME_DATE T INNER JOIN '+ @fact_day +' F on F.date=T.date
        WHERE ' + @filter + ') D inner join 
        (SELECT TRY_CONVERT(real,value) total
        ,ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS total_id
        FROM STRING_SPLIT(''' + dbo.[A_FN_STRING_SPACES](replace(@source,',','.')) + ''','' '')) M on D.total_id=M.total_id;';

        SET @output=@output+ '-- INSERTING DAY DATA <br>'+ @sqlCommand + '<br><br>';
 		IF @commands like '%-PRINT%' PRINT @sqlCommand	
        ELSE BEGIN TRY			         
            IF @errors=0 BEGIN 
                IF (@on_schedule=1 OR @commands like '%-NOSCHEDUL%' ) BEGIN
                    EXEC( @sqlCommand); SET @rows= @@ROWCOUNT
                    IF @commands like '%-LOG_ROWCOUNT%' EXEC dbo.[A_SP_SYS_LOG] 'LOG ROWS' ,@session_id ,@import_id ,'RECORDS INSERT DAY',@rows  , @site_id
                    IF @commands like '%-LOG_INSERT%' EXEC dbo.[A_SP_SYS_LOG] 'LOG INSERT ROWS' ,@session_id ,@import_id ,'INSERT QUERY DAY',@sqlCommand , @site_id
                    SET @output=@output+'day records inserted ' + convert(varchar(10),@rows)+'<br><br>'  
                END
                ELSE SET @output=@output+'-- <b>WARNING: Delete query was not executed due to the schedule parameter.</b> <br>'
            END
            ELSE SET @output=@output+'-- <b>ERROR: Queries will not be executed due to errors. Please check the parameters.</b><br>'       
        END TRY
   		BEGIN CATCH  
   			SET @data=JSON_MODIFY( @data,'$.error',dbo.[A_FN_SYS_ErrorJson]()); 
            SET @output=@output+'<br>ERROR on insert day: <br>'+@data+'<br>'+@sqlCommand+'<br>';
            SET @sqlCommand = @sqlCommand + '/* error information:' + @data + '*/';
            PRINT @sqlCommand;
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
   		END -- END OF FETCHING IMPORTS

	CLOSE TAB_CURSOR 
	DEALLOCATE TAB_CURSOR

	SET @data=DATEDIFF(second,@start_time,getdate())
	EXEC dbo.[A_SP_SYS_LOG] 'PROCEDURE FINISH' ,@session_id  ,null  , @procedure_name , @data, @site_id
    SET @output=@output + '<br>Procedure finished. It took ' + @data + ' sec.'
    PRINT 'Procedure '+ @procedure_name+ 'finished. It took ' + @data + ' sec.';

    DECLARE @version nvarchar(max)='
    <br><i>VERSION INFORMATION </i>
    -- VERSION 221219 
    -- SPLIT FUNCTION switched to spaces, for easy copy paste from excel.
    -- new string function added for handling special characters from Excel
    -- NODELTA parameter is default for SP SPLIT
    --  VERSION 220727
    --  Order of where parameters set to activity first for index reusage.
'
    IF @commands like '%-VERSION%'  BEGIN SET @output = @output + @version; PRINT @version; END 

    DECLARE @help nvarchar(max)='<br><i>HELP INFORMATION</i>
    <br>
    <br>General import procedure for splitting comaseparated montly totals ([source] parameter) to days proportional to another timeseries determined by [filter].
   
    <br>
    <br>SP PARAMETERS
    <br>@activity_id int = 0    -- run imports for an activity_id.
    <br>@import_id int =0       -- run import_id.
    <br>@session_id nvarchar(50)  = null -- session id for loging, keep empty for an autogenerated uid.
    <br>@procedure_name nvarchar(200) -- the procedure name or an app name to run, use % to broaden the selection
    <br>@site_id int =0 -- site to run
    <br>@commands varchar(2000)
    
    <br><br>Inherited parameters from procedure or import configuration:
    <br>[Source] - a list , comma separated with totals per month. the first value will map with the first month, determined by the [Filter] parameter. To be used at import level, leave empty at the procedure level.
    <br>[Fields source] - a single column or an expression, by default value1 used. ( you can also use value1*value2 for example)
    <br>[Fields target] - a single value column name, value1 used as default
    <br>[Filter] - eg. [year]=2022 and activity_id=372 and forecast_id=4 
    <br>a serie filter including activity, forecast and the date range covered by the [source]. 
    <br>Months will be mapped in the order. You can use all fields from [a_time_date] table and a_fact_day table keys, 
    <br>(eg activity_id, forecast_id). if you use [date] field please use D.date to avoid a join ambiguity.
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
