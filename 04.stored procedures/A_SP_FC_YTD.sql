SET ANSI_NULLS OFF
GO
SET QUOTED_IDENTIFIER ON
GO

-- template stored procedure for loading data from source tables
CREATE OR ALTER  PROCEDURE [dbo].[A_SP_FC_YTD]
 @activity_id int = 0 
,@forecast_id int = 0 -- run imports for a forecast_id
,@session_id uniqueidentifier   = null
,@commands varchar(2000)='' -- '-LOG_ROWCOUNT -LOG_INSERT -LOG_DELETE' --'-PRINT' -NOGROUPBY -SUMFIELDS -SET_IMPORT_ID
,@procedure_name nvarchar(200)=''
,@site_id int = 0
,@import_id int =0
,@category nvarchar(200) ='' -- procedure category to run; empty to run all
AS
BEGIN

    SET NOCOUNT ON;
    SET DATEFIRST 1
--  configuration
    DECLARE @sqlCommand NVARCHAR(MAX) =''-- 

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

	-- login parameters
	DECLARE @data  varchar(4000)=''  -- log data
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
      ,category
    FROM   dbo.[A_IMPORT_RUN]
    WHERE   (import_id=@import_id or @import_id=0) 
    AND (site_id=@site_id or site_id is null or @site_id=0)
    AND ([procedure_id] = try_convert (int, @procedure_name) or [procedure_name] like @procedure_name or @procedure_name='')  
    AND (activity_id=@activity_id or @activity_id=0)
    AND ([category] like @category or @category='')
    AND procedure_code='A_SP_FC_YTD'
    ORDER BY [sort_order], [procedure_name]
    
	EXEC dbo.[A_SP_SYS_LOG] 'PROCEDURE START' ,@session_id  ,@activity_id  , @procedure_name ,@commands, @site_id
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
        DECLARE @errors int = 0; 
        DECLARE @on_schedule bit=1;

        -- if source or target fields are empty set it by default to all value fields
        IF @fields_source='' OR @fields_target=''  BEGIN 
            SET @fields_source='[value1],[value2],[value3],[value4],[value5],[value6],[value7],[value8],[value9],[value10]';
            SET @fields_target='[value1],[value2],[value3],[value4],[value5],[value6],[value7],[value8],[value9],[value10]';
            SET @output=@output+'-- <b>WARNING: Source or target fields are not specified. Setting defaults. <b>';
        END
        IF @schedule>'' BEGIN
            SET @sqlCommand = N'SELECT @on_schedule =  CASE WHEN ' +@schedule + ' THEN 1 ELSE 0 END';
            EXEC sp_executesql @sqlCommand, N'@on_schedule bit OUTPUT', @on_schedule=@on_schedule OUTPUT
        END 
        SET @day_source= case when @source>'' then @source else @fact_day end;
        SET @p1=TRY_CONVERT(INT,@p1);
 		IF @p1=0 BEGIN
            SET @errors=@errors+1;  -- forecast from id must be specified
            SET @output=@output+'-- <b>ERROR: p1 - forecast_id from  - must be specified. Setting defaults. <b>';
        END
        IF LEN(@filter)<4 SET @filter='S.activity_id='+convert(varchar(10),@activity_id);
        IF @p2 like '%w%' BEGIN 
            -- procedure is per week
            SET @p2 = '[year_week]'; 
            SET @p3 = '[year52]'; 
        END
        ELSE BEGIN -- DEFAULT per month, overwrite parameters in case garbadge in
            SET @p2 = '[year_month_char]';	--	DAY LEVEL FIELD (FROM TIME_DATE)
            SET @p3 = '[year]';		--	SEAZON LEVEL
        END

        SET @date_import_from=isnull(@date_import_from,[dbo].[A_FN_TI_FirstDayCurrentYear](NULL));
 		SET @date_import_until=isnull(@date_import_until,[dbo].[A_FN_TI_LastDayCurrentYear](NULL));

		-- we skip source delta check , there are no requirements
        -- test parameters before running all
        IF @activity_id=0 OR @forecast_id=0 SET @errors=@errors+1 
        IF @date_import_until<@date_import_from BEGIN 
            SET @errors=@errors+1 
            SET @output=@output+'-- <b>ERROR: Source dates cannot be found. Queries will not be executed due to errors. 
            Please check if source exists and/or the dates parameters.</b><br>'   
            EXEC dbo.[A_SP_SYS_LOG] 'IMPORT ERROR' ,@session_id ,@procedure_name,@import_id , @sqlCommand , @site_id;   
        END

	----------------------------------------------------------------------------------------------------------------------
	--  CLEAN DAY

 	-- this SP supports batch loading, so several activities passed in the @filter parameter, 
	-- so we deviate from the standard import delete here
	--------------------------------------------------------------------------------	
		SET @sqlCommand =' DELETE S FROM [A_FACT_DAY] S'+ 
		' INNER JOIN [A_DIM_ACTIVITY] A on S.activity_id=A.activity_id' +
        ' WHERE ' + @filter + ' AND S.forecast_id=' + convert(varchar(10),@forecast_id) 
        + ' AND site_id=' + convert(varchar(10),@site_id)
        + ' AND [date] between '''	+ convert(varchar(10),@date_import_from,126) + ''' AND '''+ convert(varchar(10),@date_import_until,126) + ''';';
		IF @commands like '%-PRINT%' PRINT @sqlCommand   

 		BEGIN TRY
            IF @errors=0 BEGIN 
                IF (@on_schedule=1) BEGIN     
                    SET @output=@output+'-- DELETING DAY DATA <br>'+@sqlCommand+'<br><br>';
			        EXEC( @sqlCommand); SET @rows= @@ROWCOUNT;
                    SET @output=@output+'day records deleted ' + convert(varchar(10),@rows)+'<br><br>'
                    IF @commands like '%-LOG_ROWCOUNT%' EXEC dbo.[A_SP_SYS_LOG] 'LOG ROWS DELETED DAY' ,@session_id ,@procedure_name,@import_id ,@rows, @site_id  
                    IF @commands like '%-LOG_DELETE%' EXEC dbo.[A_SP_SYS_LOG] 'LOG DELETE ROWS QUERY' ,@session_id ,@procedure_name,@import_id ,@sqlCommand , @site_id  
                END
                ELSE SET @output=@output+'-- <b>WARNING: Delete query was not executed due to the schedule parameter.</b> <br>'
            END
            ELSE SET @output=@output+'-- <b>ERROR: Queries will not be executed due to errors. Please check the parameters.</b><br>'       
 		END TRY
 		BEGIN CATCH  
			SET @data=JSON_MODIFY( @data,'$.error',dbo.[A_FN_SYS_ErrorJson]()) 
            SET @output=@output+@data+'<br><br>';
            SET @sqlCommand = @sqlCommand + '/* error information:' + @data + '*/';
            PRINT @sqlCommand;
			EXEC dbo.[A_SP_SYS_LOG] 'ERROR IMPORT CLEAN DAY' ,@session_id ,@procedure_name ,@import_id ,@sqlCommand , @site_id 
 		END CATCH;   

	--------------------------------------------------------------------------------------------------------------------------
	--  INSERT TO DAY
	--------------------------------------------------------------------------------------------------------------------------		
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
, ' +  convert(nvarchar(max),@site_id) + ' as site_id'+
' FROM [A_FACT_DAY] S INNER JOIN [A_TIME_DATE] D on S.Date=D.Date '+
' INNER JOIN [A_DIM_ACTIVITY] A on S.activity_id=A.activity_id' +
' WHERE ' + @filter + ' AND forecast_id=' + convert(varchar(10),@p1) + ' AND site_id=' + convert(varchar(10),@site_id)  
+ ' AND S.date between '''+ convert(varchar(10),@date_import_from,126) + ''' and '''+ convert(varchar(10),@date_import_until,126)
+ ''' GROUP BY S.activity_id, D.'+@p2+',D.'+@p3+'
) AS T'

		IF @commands like '%-PRINT%' PRINT @sqlCommand  
 		BEGIN TRY			
            SET @output=@output+ '-- INSERT QUERY DAY DATA <br>'+ @sqlCommand + '<br><br>';
            IF @errors=0 BEGIN 
                IF (@on_schedule=1) BEGIN  
                    EXEC( @sqlCommand); SET @rows= @@ROWCOUNT
                    IF @commands like '%-LOG_ROWCOUNT%' EXEC dbo.[A_SP_SYS_LOG] 'LOG ROWS INSERT DAY' ,@session_id ,@procedure_name,@import_id ,@rows, @site_id;  
                    IF @commands like '%-LOG_INSERT%' EXEC dbo.[A_SP_SYS_LOG] 'LOG INSERT ROWS DAY QUERY' ,@session_id ,@procedure_name,@import_id ,@sqlCommand, @site_id; 
                    SET @output=@output+'day records inserted ' + convert(varchar(10),@rows)+'<br><br>';  
                END
                ELSE SET @output=@output+'-- <b>WARNING: Delete query was not executed due to the schedule parameter.</b> <br>';
            END
            ELSE SET @output=@output+'-- <b>ERROR: Queries will not be executed due to errors. Please check the parameters.</b><br>';
        END TRY
   		BEGIN CATCH  
   			SET @data=JSON_MODIFY( @data,'$.error',dbo.[A_FN_SYS_ErrorJson]()) ;
            SET @output=@output+@data+'<br><br>';
            SET @sqlCommand = @sqlCommand + '/* error information:' + @data + '*/';
            PRINT @sqlCommand;
			EXEC dbo.[A_SP_SYS_LOG] 'ERROR IMPORT INSERT DAY' ,@session_id ,@procedure_name,@import_id ,@sqlCommand,@site_id
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
	EXEC dbo.[A_SP_SYS_LOG] 'PROCEDURE FINISH' ,@session_id  ,@procedure_name , null, @data,@site_id
    IF @commands like '%-OUTPUT%'  select @output as SQL_OUTPUT

END
GO
