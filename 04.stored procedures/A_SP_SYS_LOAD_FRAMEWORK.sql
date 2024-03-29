SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
 ALTER    PROCEDURE [dbo].[A_SP_SYS_LOAD_FRAMEWORK]  
@commands varchar(255)=''
AS
BEGIN
-- SET NOCOUNT ON added to prevent extra result sets from
-- interfering with SELECT statements.
    SET NOCOUNT ON;

    DECLARE @sqlCommand NVARCHAR(MAX) ;
    DECLARE @procedure_code NVARCHAR(MAX);
	DECLARE @procedure_name NVARCHAR(MAX);
    DECLARE @schedule NVARCHAR(MAX);
	DECLARE @data NVARCHAR(MAX);
	DECLARE @start_time datetime=null
    
	DECLARE @session_id uniqueidentifier = newid()
	SET @start_time     = GETDATE()

	EXEC [dbo].[A_SP_SYS_LOG]  
		'ALC_MI SESSION START', --@category
		@session_id , --@session_id
		'' , --@object_id
		'' , --@step_id
		@data  

    DECLARE TAB_CURSOR1 CURSOR  FOR 
    SELECT   [procedure_code],[procedure_name],[schedule]
    FROM     [A_IMPORT_PROCEDURE] P 
    WHERE    [app] = 'SP' and [status] ='TEST' and active=1
    ORDER BY [sort_order];

	OPEN TAB_CURSOR1 
	FETCH NEXT FROM TAB_CURSOR1 INTO @procedure_code,@procedure_name, @schedule ;

	WHILE @@FETCH_STATUS = 0 
   		BEGIN 
			SET @sqlCommand = 'EXEC ' +  convert(nvarchar(max),@procedure_code) +' @procedure_name=''' + @procedure_name + ''' , @commands='''+ @commands + ''', @session_id='''+ convert(varchar(50),@session_id) +'''';
			PRINT    'RUNNING ' + @sqlCommand   			

			BEGIN TRY
				EXEC( @sqlCommand);
 			END TRY
 			BEGIN CATCH  
				select 1; -- this should kill any errors
			END CATCH;   
			
   			FETCH NEXT FROM TAB_CURSOR1 
   			INTO @procedure_code,@procedure_name, @schedule;
 		END 


	CLOSE TAB_CURSOR1 
	DEALLOCATE TAB_CURSOR1

	-- RUN YTM
	-- RUN PREVYEAR
	SET @data=DATEDIFF(second,@start_time,getdate())
	EXEC [dbo].[A_SP_SYS_LOG] 'ALC_MI LOADING COMMONS' ,@session_id  ,null  , null , @data
--	EXEC [dbo].[A_SP_IMPORT_PREVYEAR_WEEK] @forecast_id = 6, @forecast_actual_id = 1, @lag_years = 1;
--	EXEC [dbo].[A_SP_IMPORT_PREVYEAR_WEEK] @forecast_id = 29, @forecast_actual_id = 1, @lag_years = 2;
--	EXEC [dbo].[A_SP_IMPORT_PREVYEAR_MONTH] @forecast_id = 17, @forecast_actual_id = 1, @lag_years = 1;
--	EXEC [dbo].[A_SP_IMPORT_PREVYEAR_MONTH] @forecast_id = 30, @forecast_actual_id = 1, @lag_years = 2;
--	EXEC [dbo].[A_SP_IMPORT_YTM] @forecast_id = 25, @forecast_actual_id = 1  -- A  YTM
--    EXEC [dbo].[A_SP_IMPORT_YTM] @forecast_id = 26,@forecast_actual_id = 4  -- bfc  YTM
 --   EXEC [dbo].[A_SP_IMPORT_YTM] @forecast_id = 27,@forecast_actual_id = 3  -- ofc wr YTM
 --   EXEC [dbo].[A_SP_IMPORT_YTM] @forecast_id = 28,@forecast_actual_id = 17  -- A-1 YTM

	SET @data=DATEDIFF(second,@start_time,getdate())
	EXEC [dbo].[A_SP_SYS_LOG] 'ALC_MI SESSION FINISH' ,@session_id  ,null  , null , @data

	select 1;
END
 
 
GO
