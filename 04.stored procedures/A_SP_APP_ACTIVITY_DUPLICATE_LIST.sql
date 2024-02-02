SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
 
CREATE OR ALTER PROCEDURE [dbo].[A_SP_APP_ACTIVITY_DUPLICATE_LIST]
    @activity_id_copy_list VARCHAR(2000)='', -- commaseparated list of activity ids
    @activity_name_substring_search VARCHAR(255), -- Substring for activity_name to search
    @activity_name_substring_replace VARCHAR(255), -- Substring for activity_name to replace
    @new_domain NVARCHAR(255) = NULL -- Parameter for domain, with default value NULL

AS
BEGIN
    SET NOCOUNT ON;
    -- Declare variables to store column values from A_DIM_ACTIVITY
    DECLARE @original_activity_id INT,
            @original_activity_name NVARCHAR(255), -- Replace with actual data type and column name for activity_name
            @original_domain NVARCHAR(255); -- Replace with actual data type and column name for domain
            -- Add more variables for each column in the A_DIM_ACTIVITY table

    DECLARE TAB_CURSOR CURSOR FOR 
    SELECT [activity_id],[activity_name],[domain] FROM [dbo].[A_DIM_ACTIVITY]
    WHERE   [activity_id] in (SELECT * FROM STRING_SPLIT(@activity_id_copy_list,','));

	----------------------------------------------
	--  FETCH ALL
	----------------------------------------------
	OPEN TAB_CURSOR 
	FETCH NEXT FROM TAB_CURSOR 
	INTO     @original_activity_id 
            ,@original_activity_name   
     		,@original_domain
	WHILE @@FETCH_STATUS = 0 
   	BEGIN 
    
        -- Retrieve the values from the original row in A_DIM_ACTIVITY
        SELECT @original_activity_name = activity_name,
            @original_domain = domain
            -- Assign values for each column in the A_DIM_ACTIVITY table
        FROM [dbo].[A_DIM_ACTIVITY]
        WHERE activity_id = @original_activity_id;

        -- Replace substring in activity_name if @activity_name_substring_search is not NULL
        IF @activity_name_substring_search IS NOT NULL
        BEGIN
            SET @original_activity_name = REPLACE(@original_activity_name, @activity_name_substring_search, @activity_name_substring_replace);
        END

        -- Replace domain if @new_domain is not NULL
        IF @new_domain IS NOT NULL
        BEGIN
            SET @original_domain = @new_domain;
        END

        -- Insert a new row with the modified values into A_DIM_ACTIVITY
        INSERT INTO [dbo].[A_DIM_ACTIVITY] ([activity_name]
        ,[activity_set]
        ,[activity_code]
        ,[description]
        ,[segment]
        ,[domain]
        ,[region]
        ,[template_id]
        ,[slicer1]
        ,[slicer2]
        ,[slicer3]
        ,[sort_order]
        ,[resource]
        ,[channel]
        ,[reference]
        ,[parent]
        ,[status]
        ,[plantype]
        ,[category]
        ,[site_id]
        ,[activity_guid]
        ,[active]
        ,[tags]
        ,[color]
        ,[font_awesome]
        ,[date_updated]
        ,[date_created])
        SELECT @original_activity_name
        ,[activity_set]
        ,[activity_code]
        ,[description]
        ,[segment]
        ,@original_domain
        ,[region]
        ,[template_id]
        ,[slicer1]
        ,[slicer2]
        ,[slicer3]
        ,[sort_order]
        ,[resource]
        ,[channel]
        ,[reference]
        ,[parent]
        ,[status]
        ,[plantype]
        ,[category]
        ,[site_id]
        ,newid()
        ,[active]
        ,[tags]
        ,[color]
        ,[font_awesome]
        ,getdate()
        ,getdate()
        from [dbo].[A_DIM_ACTIVITY] where activity_id=@original_activity_id
        
        -- Insert a new row into A_IMPORT with the same values and the new activity_id
        INSERT INTO [dbo].[A_IMPORT] (
            [import_code]
        ,[domain]
        ,[procedure_id]
        ,[procedure_code]
        ,[activity_id]
        ,[forecast_id]
        ,[source]
        ,[filter]
        ,[fields_source]
        ,[fields_target]
        ,[group_by]
        ,[category]
        ,[status]
        ,[version]
        ,[commands]
        ,[p1]
        ,[p2]
        ,[p3]
        ,[p4]
        ,[p5]
        ,[schedule]
        ,[days_back]
        ,[days_forward]
        ,[date_import_from]
        ,[date_import_until]
        ,[description]
        ,[sort_order]
        ,[active]
        ,[template_id]
        ,[site_id]
        ,[date_updated]
        ,[date_created]
        ,[import_guid])
        SELECT  
            [import_code]
        ,[domain]
        ,[procedure_id]
        ,[procedure_code]
        , SCOPE_IDENTITY()
        ,[forecast_id]
        ,[source]
        ,[filter]
        ,[fields_source]
        ,[fields_target]
        ,[group_by]
        ,[category]
        ,[status]
        ,[version]
        ,[commands]
        ,[p1]
        ,[p2]
        ,[p3]
        ,[p4]
        ,[p5]
        ,[schedule]
        ,[days_back]
        ,[days_forward]
        ,[date_import_from]
        ,[date_import_until]
        ,[description]
        ,[sort_order]
        ,[active]
        ,[template_id]
        ,[site_id]
        ,getdate()
        ,getdate()
        ,newid()
        from [dbo].[A_IMPORT]
        where activity_id=@original_activity_id

    FETCH NEXT FROM TAB_CURSOR 
	INTO     @original_activity_id 
            ,@original_activity_name   
     		,@original_domain

    END -- END OF FETCHING IMPORTS
    CLOSE TAB_CURSOR 
    DEALLOCATE TAB_CURSOR
END;

GO

/* testen / example 

EXECUTE [MAIS_ANWB_P].[A_SP_APP_ACTIVITY_DUPLICATE_LIST] 
   @activity_id_copy_list='837,845,849,929,1524,1526,1540,1571,1572,1573,1621'
  ,@activity_name_substring_search='TEXTTOREPLACE'
  ,@activity_name_substring_replace='REPLACEMENT TEXT'
  ,@new_domain='ANEWDOMAINNAME'
GO

*/
