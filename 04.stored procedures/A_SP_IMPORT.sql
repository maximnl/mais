/****** Object:  StoredProcedure [dbo].[A_SP_IMPORT]    Script Date: 22-12-2021 11:07:15 ******/
SET ANSI_NULLS OFF
GO
SET QUOTED_IDENTIFIER ON
GO

-- template stored procedure for loading data from source tables
ALTER PROCEDURE [dbo].[A_SP_IMPORT]
 @activity_id int = 0 
,@session_id uniqueidentifier   = null
,@commands varchar(2000)='' -- '-LOG_ROWCOUNT -LOG_INSERT -LOG_DELETE' --'-PRINT' -NOGROUPBY -SUMFIELDS -SET_IMPORT_ID
,@procedure_name nvarchar(200)='A_SP_ALC_IMPORT'
AS
BEGIN

    SET NOCOUNT ON;
	DECLARE @fact_day nvarchar(200)='[dbo].[A_FACT_DAY]'
	DECLARE @fact_intraday nvarchar(200)='[dbo].[A_FACT_INTRADAY]'

    DECLARE @sqlCommand NVARCHAR(MAX) -- 
    DECLARE @import_id int
	DECLARE @forecast_id int = 0
	DECLARE @filter nvarchar(4000)='' --serrie='HACOBU' and LandGroepCode='BLG'
	DECLARE @date_import_from date='1900-01-01' -- calculated by the import query using imports and procedures fields
	DECLARE @date_import_until date='9999-01-01'
	DECLARE @fields_source varchar(2000)='' -- source fields
	DECLARE @fields_target varchar(2000)=''  -- target fields value1,value2...
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
	  ,procedure_name
    FROM     [dbo].[A_IMPORT_RUN] 
    WHERE    ([procedure_name] like @procedure_name or procedure_code like @procedure_name) and (activity_id=@activity_id or @activity_id=0)
    ORDER BY [sort_order]
    
	EXEC [dbo].[A_SP_SYS_LOG] 'PROCEDURE START' ,@session_id  ,@activity_id  , @procedure_name ,@commands
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

			IF @commands  like '%-DELTA%' BEGIN 

				
				SET @sqlCommand = 'select @date_source_min = isnull(min(' + @group_by + '),''9999-12-31'') FROM ' + @source +' WHERE ' + @filter
				EXEC sp_executesql @sqlCommand, N'@date_source_min date OUTPUT', @date_source_min=@date_source_min OUTPUT

				SET @sqlCommand = 'select @date_source_max = isnull(max(' + @group_by + '),''1900-12-31'') FROM ' + @source +' WHERE ' + @filter
				EXEC sp_executesql @sqlCommand, N'@date_source_max date OUTPUT', @date_source_max=@date_source_max OUTPUT


				SET @date_import_from=@date_source_min
				SET @date_import_until=@date_source_max
			END

			IF @commands like '%-SUMFIELDS%' set @fields_source= concat('SUM(convert(float,',replace(@fields_source,',',')),SUM(convert(float,('),'))')

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
		EXEC [dbo].[A_SP_SYS_LOG] 'IMPORT RUN' ,@session_id  ,@import_id  , @procedure_name ,@data  
	----------------------------------------------------------------------------------------------------------------------
	--  CLEAN DAY
	--------------------------------------------------------------------------------
 		
		SET @sqlCommand = 
 		'DELETE
 		FROM '+ @fact_day +'  
 		WHERE [date] BETWEEN ''' + convert(char(10),@date_import_from,126)  + ''' AND ''' + convert(char(10),@date_import_until,126) +''' 
 		AND activity_id = ' +  convert(nvarchar(max),@activity_id) + ' 
 		AND forecast_id = ' +  convert(nvarchar(max),@forecast_id) ;
  
 		BEGIN TRY
			IF @commands like '%-PRINT%' PRINT @sqlCommand ELSE EXEC( @sqlCommand);
			SET @rows= @@ROWCOUNT
			IF @commands like '%-LOG_ROWCOUNT%' EXEC [dbo].[A_SP_SYS_LOG] 'LOG ROWS' ,@session_id ,@import_id ,'RECORDS DELETE DAY',@rows  
			IF @commands like '%-LOG_DELETE%' EXEC [dbo].[A_SP_SYS_LOG] 'LOG DELETE ROWS' ,@session_id ,@import_id ,'DELETE QUERY DAY',@sqlCommand  

 		END TRY
 		BEGIN CATCH  
			SET @data=JSON_MODIFY( @data,'$.error',[dbo].[A_FN_SYS_ErrorJson]()) 
			EXEC [dbo].[A_SP_SYS_LOG] 'IMPORT ERROR' ,@session_id ,@import_id ,'CLEAN DAY',@sqlCommand  
 		END CATCH;   

	--------------------------------------------------------------------------------------------------------------------------
	--  INSERT TO DAY
	-------------------------------------------------------------------------------------
 		IF @commands not like '%-NOGROUPBY%' OR @commands like  '%-SUMFIELDS%' BEGIN SET @groupby=concat(' GROUP BY ',@group_by) END

		SET @sqlCommand = 'INSERT INTO '+ @fact_day +' (
 		[date],activity_id,forecast_id,import_id,' + @fields_target + ')
   		SELECT ' + @group_by + ',' +  convert(nvarchar(max),@activity_id)  
   		+ ', ' +  convert(nvarchar(max),@forecast_id) + ','+ convert(nvarchar(max),@import_id)
   		+ ',' + @fields_source + 
 		' FROM '+ @source +' WHERE ' + @filter  
		+ ' AND ' + @group_by + ' BETWEEN ''' + convert(char(10),@date_import_from,126)  + ''' AND ''' + convert(char(10),@date_import_until,126) + '''' + @groupby +';'
            
 		BEGIN TRY
			IF @commands like '%-PRINT%' PRINT @sqlCommand ELSE EXEC( @sqlCommand);
			SET @rows= @@ROWCOUNT
			IF @commands like '%-LOG_ROWCOUNT%' EXEC [dbo].[A_SP_SYS_LOG] 'LOG ROWS' ,@session_id ,@import_id ,'RECORDS INSERT DAY',@rows  
			IF @commands like '%-LOG_INSERT%' EXEC [dbo].[A_SP_SYS_LOG] 'LOG INSERT ROWS' ,@session_id ,@import_id ,'INSERT QUERY DAY',@sqlCommand 
 		END TRY
   		BEGIN CATCH  
   			SET @data=JSON_MODIFY( @data,'$.error',[dbo].[A_FN_SYS_ErrorJson]()) 
			EXEC [dbo].[A_SP_SYS_LOG] 'IMPORT ERROR' ,@session_id ,@import_id ,'INSERT DAY',@sqlCommand
	END CATCH;   

	IF @commands  like '%-SET_IMPORT_ID%' BEGIN 
		SET @sqlCommand = 'UPDATE '+ @source +' SET import_id='+ convert(nvarchar(max),@import_id) +' WHERE ' + @filter  
		+ ' AND ' + @group_by + ' BETWEEN ''' + convert(char(10),@date_import_from,126)  + ''' AND ''' + convert(char(10),@date_import_until,126) + '''' 
		BEGIN TRY
			EXEC( @sqlCommand)
 		END TRY
   		BEGIN CATCH  
   			SET @data=JSON_MODIFY( @data,'$.error',[dbo].[A_FN_SYS_ErrorJson]()) 
			EXEC [dbo].[A_SP_SYS_LOG] 'IMPORT SET ERROR' ,@session_id ,@import_id ,'UPDATE import_id',@sqlCommand
		END CATCH;   
	END

	 
	  

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
	EXEC [dbo].[A_SP_SYS_LOG] 'PROCEDURE FINISH' ,@session_id  ,null  , @procedure_name , @data

END
