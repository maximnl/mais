
/****** Object:  StoredProcedure [dbo].[A_SP_IMPORT_PARALLELPERIOD]    Script Date: 30-5-2022 16:35:50 ******/
SET ANSI_NULLS OFF
GO
SET QUOTED_IDENTIFIER ON
GO



-- template stored procedure for loading data from source tables
CREATE  PROCEDURE [dbo].[A_SP_IMPORT_PARALLELPERIOD]
 @activity_id int = 0 
,@session_id uniqueidentifier   = null
,@commands varchar(2000)='' -- '-LOG_ROWCOUNT -LOG_INSERT -LOG_DELETE' --'-PRINT' -NOGROUPBY -SUMFIELDS -SET_IMPORT_ID
,@procedure_name nvarchar(200)='A_SP_IMPORT_PARALLELPERIOD'
,@site_id int =1
,@import_id int =0
AS
BEGIN

    SET NOCOUNT ON;

	
--  configuration
	DECLARE @fact_day nvarchar(200)='[A_FACT_DAY]' -- data per day stored here
	DECLARE @fact_intraday nvarchar(200)='[A_FACT_INTRADAY]' -- data per day/interval_id is stored here. conform a_time_interval dimension
    DECLARE @sqlCommand NVARCHAR(MAX) -- 

--  source data parameters
	DECLARE @forecast_id int = 0
	DECLARE @filter nvarchar(4000)='' -- where filter for filtering source data
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
	DECLARE @groupby varchar(2000)=''

	-- login parameters
	DECLARE @data  varchar(4000)=''  -- log data
	DECLARE @rows INT   -- keep affected rows
	DECLARE @start_time datetime=null
    DECLARE @output nvarchar(max)='';

	-- source data analysis
	DECLARE @date_source_min date='9999-01-01' -- calculated by the import query using imports and procedures fields
	DECLARE @date_source_max date='1900-01-01'

	-- intraday parameters
	DECLARE @intraday_join varchar(2000)=''
	DECLARE @intraday_interval_id varchar(200)='interval_id'
	DECLARE @intraday_duration varchar(5)='15' -- default intraday interval duration in min

    
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
    WHERE   (import_id=@import_id or @import_id=0) 
		AND (site_id=@site_id or site_id is null or @site_id=0)
		AND ([procedure_name] like @procedure_name or procedure_code like @procedure_name or @import_id>0) 
		and (activity_id=@activity_id or @activity_id=0)
    ORDER BY [sort_order]
    
	EXEC dbo.[A_SP_SYS_LOG] 'PROCEDURE START' ,@session_id  ,@activity_id  , @procedure_name ,@commands
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

		 
 		IF TRY_CONVERT(INT,@p1)=0 SET @p1 = 1  -- forecast from id 
 		IF TRY_CONVERT(INT,@p5)=0 SET @p5 = 1  -- LAG YEARS
		
		 IF @p2 like '%m%' BEGIN
			-- procedure is per maand
			 SET @p2 = '[day_month]'	--	DAY LEVEL FIELD (FROM TIME_DATE)
			 SET @p3 = '[month]'		--	SEAZON LEVEL
			 SET @p4 = '[year]' 		--	YEAR LEVEL
		 END
		 ELSE BEGIN -- DEFAULT per week, overwrite parameters in case garbadge in
			 SET @p2 = '[day_week]'
			 SET @p3 = '[week]'
			 SET @p4 = '[year52]' 
		 END

		 
		 SET @date_import_from=isnull(@date_import_from,[dbo].[A_FN_TI_FirstDayCurrentYear](NULL));
 		 SET @date_import_until=isnull(@date_import_until,[dbo].[A_FN_TI_LastDayCurrentYear](NULL));

		-- we skip source delta check , there are no requirements
		 
	----------------------------------------------------------------------------------------------------------------------
	--  CLEAN DAY

 	-- this SP supports batch loading, so several activities passed in the @filter parameter, 
	-- so we deviate from the standard import delete here
	--------------------------------------------------------------------------------	
		SET @sqlCommand ='DELETE
		  from [dbo].[A_FACT_DAY] 
		  where forecast_id=' + convert(varchar(10),@forecast_id) + ' and ' + @filter + ' and date between ''' 
		 + convert(varchar(10),@date_import_from,126) + ''' and '''+ convert(varchar(10),@date_import_until,126) + '''' + '	AND site_id = ' +  convert(nvarchar(max),@site_id)  ;
		  
 		BEGIN TRY
			IF @commands like '%-PRINT%' PRINT @sqlCommand 
            SET @output=@output+'-- DELETING DAY DATA <br>'+@sqlCommand+'<br><br>';
			IF @commands not like '%-PRINT%' AND @date_import_until>=@date_import_from 
            BEGIN
                EXEC( @sqlCommand)
                SET @rows= @@ROWCOUNT
               
                IF @date_import_until<@date_import_from AND  @commands like '%-LOG_ROWCOUNT%' EXEC dbo.[A_SP_SYS_LOG]  'IMPORT WARNING' ,@session_id ,@import_id ,'NODATA ON DELETE', @sqlCommand  
                SET @output=@output+'day records deleted ' + convert(varchar(10),@rows)+'<br><br>'
                IF @commands like '%-LOG_ROWCOUNT%' EXEC dbo.[A_SP_SYS_LOG] 'LOG ROWS' ,@session_id ,@import_id ,'RECORDS DELETE DAY',@rows  
                IF @commands like '%-LOG_DELETE%' EXEC dbo.[A_SP_SYS_LOG] 'LOG DELETE ROWS' ,@session_id ,@import_id ,'DELETE QUERY DAY',@sqlCommand  
            END
 		END TRY
 		BEGIN CATCH  
			SET @data=JSON_MODIFY( @data,'$.error',dbo.[A_FN_SYS_ErrorJson]()) 
            SET @output=@output+dbo.[A_FN_SYS_ErrorJson]()+'<br><br>'
			EXEC dbo.[A_SP_SYS_LOG] 'IMPORT ERROR' ,@session_id ,@import_id ,'CLEAN DAY',@sqlCommand  
 		END CATCH;   

	--------------------------------------------------------------------------------------------------------------------------
	--  INSERT TO DAY
	-------------------------------------------------------------------------------------
 		 
		SET @sqlCommand = 'INSERT INTO '+ @fact_day 
        +' ([date],activity_id,forecast_id,import_id,' + @fields_target + ',site_id) 
       SELECT D.date, activity_id, ' + convert(varchar(10),@forecast_id) 
	+ ' as forecast_id, '+ @fields_source +',site_id 
	from ( select S.*, d.' + @p2+', d.'+@p3+', d.'+@p4+',A.activity_set,A.domain,A.category
   		from [a_fact_day] S
		INNER JOIN [a_dim_activity] A on S.activity_id=A.activity_id
   		INNER JOIN [a_time_date] d on S.[date]=d.[date]
   		and forecast_id=' + convert(varchar(10),@p1) + ' and ' + @filter +') as SD
     	 INNER JOIN [a_time_date] D on D.date between ''' 
		 + convert(varchar(10),@date_import_from,126) + ''' and '''+ convert(varchar(10),@date_import_until,126) 
		 + ''' and  SD.' + @p2+'=D.' + @p2+' and ((SD.'+@p3+'=D.'+@p3+' and SD.'+@p4+'=(D.'+@p4+'-' + convert(varchar(10),@p5)+ '))  
	 )'


 		BEGIN TRY
			IF @commands like '%-PRINT%' PRINT @sqlCommand 
            SET @output=@output+ '-- INSERTING DAY DATA <br>'+ @sqlCommand + '<br><br>';
			IF @commands not like '%-PRINT%' AND @date_import_until>=@date_import_from 
            BEGIN 
                EXEC( @sqlCommand)
                SET @rows= @@ROWCOUNT
                IF @date_import_until<@date_import_from AND @commands like '%-LOG_ROWCOUNT%'  EXEC dbo.[A_SP_SYS_LOG] 'IMPORT WARNING' ,@session_id ,@import_id ,'NODATA ON INSERT', @sqlCommand  
                IF @commands like '%-LOG_ROWCOUNT%' EXEC dbo.[A_SP_SYS_LOG] 'LOG ROWS' ,@session_id ,@import_id ,'RECORDS INSERT DAY',@rows  
                IF @commands like '%-LOG_INSERT%' EXEC dbo.[A_SP_SYS_LOG] 'LOG INSERT ROWS' ,@session_id ,@import_id ,'INSERT QUERY DAY',@sqlCommand 
                SET @output=@output+'day records inserted ' + convert(varchar(10),@rows)+'<br><br>'  
            END
        END TRY
   		BEGIN CATCH  
   			SET @data=JSON_MODIFY( @data,'$.error',dbo.[A_FN_SYS_ErrorJson]()) 
            SET @output=@output+dbo.[A_FN_SYS_ErrorJson]()+'<br><br>'
			EXEC dbo.[A_SP_SYS_LOG] 'IMPORT ERROR' ,@session_id ,@import_id ,'INSERT DAY',@sqlCommand
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
	EXEC dbo.[A_SP_SYS_LOG] 'PROCEDURE FINISH' ,@session_id  ,null  , @procedure_name , @data
    IF @commands like '%-OUTPUT%'  select @output as SQL_OUTPUT

END

