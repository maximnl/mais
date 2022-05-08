SET ANSI_NULLS OFF
GO
SET QUOTED_IDENTIFIER ON
GO



-- template stored procedure for loading data from source tables
CREATE  PROCEDURE [A_SP_IMPORT_TOTAL_SPLIT]
 @activity_id int = 0 
,@session_id uniqueidentifier   = null
,@commands varchar(2000)='' -- '-LOG_ROWCOUNT -LOG_INSERT -LOG_DELETE' --'-PRINT' -NOGROUPBY -SUMFIELDS -SET_IMPORT_ID
,@procedure_name nvarchar(200)='A_SP_IMPORT_TOTAL_SPLIT'
,@site_id int =0
,@import_id int =0
AS
BEGIN

    SET NOCOUNT ON;
	DECLARE @fact_day nvarchar(200)='A_FACT_DAY'
    DECLARE @sqlCommand NVARCHAR(MAX) -- 
	DECLARE @forecast_id int = 0
	DECLARE @filter nvarchar(4000)='' --serrie='HACOBU' and LandGroepCode='BLG'
	DECLARE @date_import_from date='1900-01-01' -- calculated by the import query using imports and procedures fields
	DECLARE @date_import_until date='9999-01-01'
	DECLARE @fields_source varchar(2000)='' -- source fields
	DECLARE @fields_target varchar(2000)=''  -- target fields value1
	DECLARE @schedule varchar(2000)=''
	DECLARE @source varchar(2000)=''
	DECLARE @group_by varchar(2000)=''
	DECLARE @p1 varchar(2000)=''  -- parameters
	DECLARE @p2 varchar(2000)=''
	DECLARE @p3 varchar(2000)=''
	DECLARE @p4 varchar(2000)=''
	DECLARE @p5 varchar(2000)=''
	DECLARE @data  varchar(4000)=''  -- log data
	DECLARE @rows INT   -- keep affected rows
	DECLARE @start_time datetime=null
	DECLARE @groupby varchar(2000)=''
	DECLARE @date_source_min date='9999-01-01' -- calculated by the import query using imports and procedures fields
	DECLARE @date_source_max date='1900-01-01'
	DECLARE @intraday_join varchar(2000)=''
	DECLARE @intraday_duration varchar(5)=''
    DECLARE @output nvarchar(max)='';
    
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
    FROM   [A_IMPORT_RUN]
    WHERE   (import_id=@import_id or @import_id=0) 
AND site_id=@site_id 
AND ([procedure_name] like @procedure_name or procedure_code like @procedure_name or @import_id>0) 
and (activity_id=@activity_id or @activity_id=0)
    ORDER BY [sort_order]
    
	EXEC [A_SP_SYS_LOG] 'PROCEDURE START' ,@session_id  ,@activity_id  , @procedure_name ,@commands
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

	WHILE @@FETCH_STATUS = 0 

   		BEGIN 
			
		SET @sqlCommand = 'select @date_source_min = isnull(min(F.date),''9999-12-31'') 
        FROM A_TIME_DATE T INNER JOIN A_FACT_DAY F on F.date=T.date WHERE (' + @filter +')'

		EXEC sp_executesql @sqlCommand, N'@date_source_min date OUTPUT', @date_source_min=@date_source_min OUTPUT

        SET @sqlCommand = 'select @date_source_max = isnull(max(F.date),''1900-12-31'') 
        FROM A_TIME_DATE T INNER JOIN A_FACT_DAY F on F.date=T.date WHERE (' + @filter +')'

		EXEC sp_executesql @sqlCommand, N'@date_source_max date OUTPUT', @date_source_max=@date_source_max OUTPUT
				
        SET @date_import_from=@date_source_min
        SET @date_import_until=@date_source_max	 
	----------------------------------------------------------------------------------------------------------------------
	--  CLEAN DAY
	--------------------------------------------------------------------------------
 		
		SET @sqlCommand = 
 		'DELETE FROM '+ @fact_day +' WHERE [date] BETWEEN ''' + convert(char(10),@date_import_from,126)  + ''' AND ''' + convert(char(10),@date_import_until,126) + ''' AND activity_id =' +  convert(nvarchar(max),@activity_id) 
+ '	AND forecast_id = ' +  convert(nvarchar(max),@forecast_id)
+ '	AND site_id = ' +  convert(nvarchar(max),@site_id)  ;
  
 		BEGIN TRY
			IF @commands like '%-PRINT%' PRINT @sqlCommand 
            SET @output=@output+'-- DELETING DAY DATA <br>'+@sqlCommand+'<br><br>';
			IF @commands not like '%-PRINT%' AND @date_import_until>=@date_import_from 
            BEGIN
                EXEC( @sqlCommand)
                SET @rows= @@ROWCOUNT
               
                IF @date_import_until<@date_import_from AND  @commands like '%-LOG_ROWCOUNT%' EXEC [A_SP_SYS_LOG]  'IMPORT WARNING' ,@session_id ,@import_id ,'NODATA ON DELETE', @sqlCommand  
                SET @output=@output+'day records deleted ' + convert(varchar(10),@rows)+'<br><br>'
                IF @commands like '%-LOG_ROWCOUNT%' EXEC [A_SP_SYS_LOG] 'LOG ROWS' ,@session_id ,@import_id ,'RECORDS DELETE DAY',@rows  
                IF @commands like '%-LOG_DELETE%' EXEC [A_SP_SYS_LOG] 'LOG DELETE ROWS' ,@session_id ,@import_id ,'DELETE QUERY DAY',@sqlCommand  
            END
 		END TRY
 		BEGIN CATCH  
			SET @data=JSON_MODIFY( @data,'$.error',[A_FN_SYS_ErrorJson]()) 
            SET @output=@output+[A_FN_SYS_ErrorJson]()+'<br><br>'
			EXEC [A_SP_SYS_LOG] 'IMPORT ERROR' ,@session_id ,@import_id ,'CLEAN DAY',@sqlCommand  
 		END CATCH;   

	--------------------------------------------------------------------------------------------------------------------------
	--  INSERT TO DAY
	-------------------------------------------------------------------------------------
 		 
		SET @sqlCommand = 'INSERT INTO '+ @fact_day 
        +' ([date],activity_id,forecast_id,import_id,' + @fields_target + ',site_id) 

        select D.date,' +  convert(nvarchar(max),@activity_id)  
   		+ ', ' +  convert(nvarchar(max),@forecast_id) + ','+ convert(nvarchar(max),@import_id) 
        + ',D.day_weight*M.total ,'+ convert(nvarchar(max),@site_id) + ' 
        from (
            SELECT F.date, T.year_month_char, value1 
        , value1 / sum(value1) over (partition by T.year_month_char) day_weight
        , dense_rank() over (order by T.year_month_char ) as total_id
        FROM A_TIME_DATE T INNER JOIN A_FACT_DAY F on F.date=T.date
        WHERE ' + @filter + ') D inner join 
        (SELECT TRY_CONVERT(real,value) total
        ,ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS total_id
        from STRING_SPLIT(''' + @source + ''','','')  ) M on D.total_id=M.total_id'

 		BEGIN TRY
			IF @commands like '%-PRINT%' PRINT @sqlCommand 
            SET @output=@output+ '-- INSERTING DAY DATA <br>'+ @sqlCommand + '<br><br>';
			IF @commands not like '%-PRINT%' AND @date_import_until>=@date_import_from 
            BEGIN 
                EXEC( @sqlCommand)
                SET @rows= @@ROWCOUNT
                IF @date_import_until<@date_import_from AND @commands like '%-LOG_ROWCOUNT%'  EXEC [A_SP_SYS_LOG] 'IMPORT WARNING' ,@session_id ,@import_id ,'NODATA ON INSERT', @sqlCommand  
                IF @commands like '%-LOG_ROWCOUNT%' EXEC [A_SP_SYS_LOG] 'LOG ROWS' ,@session_id ,@import_id ,'RECORDS INSERT DAY',@rows  
                IF @commands like '%-LOG_INSERT%' EXEC [A_SP_SYS_LOG] 'LOG INSERT ROWS' ,@session_id ,@import_id ,'INSERT QUERY DAY',@sqlCommand 
                SET @output=@output+'day records inserted ' + convert(varchar(10),@rows)+'<br><br>'  
            END
        END TRY
   		BEGIN CATCH  
   			SET @data=JSON_MODIFY( @data,'$.error',[A_FN_SYS_ErrorJson]()) 
            SET @output=@output+[A_FN_SYS_ErrorJson]()+'<br><br>'
			EXEC [A_SP_SYS_LOG] 'IMPORT ERROR' ,@session_id ,@import_id ,'INSERT DAY',@sqlCommand
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
   		END -- END OF FETCHING IMPORTS

	CLOSE TAB_CURSOR 
	DEALLOCATE TAB_CURSOR

	SET @data=DATEDIFF(second,@start_time,getdate())
	EXEC [A_SP_SYS_LOG] 'PROCEDURE FINISH' ,@session_id  ,null  , @procedure_name , @data
    IF @commands like '%-OUTPUT%'  select @output as SQL_OUTPUT

END

GO
