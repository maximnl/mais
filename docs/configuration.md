# Import configuration
Import configuration is a generic structure that controls data import from a source to a time serie format in MAIS. The structure has two layers made of transitory parameters to support import of data from any table/view source:
- Procedure level - sets parameters at the source level. Do not confuse it with the SQL stored procedures. The same SQL stored procedure can be used in multiple import procedures. 
- Import level - refiness parameters of the above procedure for a specific time serie.
Parameters such as [source], [filter] from the import are merged with the parameters from the procedure level such that only a few parameters per time serie need to be modified. The procedure level specifies with SQL stored procedure will be called and passed the parameters. The stored procedure share the same parameters. 

All parameters can be written in sql expressions syntax. 

Parameters are premerged in the view [A_IMPORT_RUN] and are accessed within MAIS stored procedures directly from data. 
'''SQL
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

	-- log parameters
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
    '''
    

## Parameters

### Commands
#### -DELTA
This parameter forces begin and end date of the date range to be adjusted to the source date range. Data will be refreshed only for the range between min and max dates of the source. 
* TIP1. If the source goes far back in history and this data is not changed, you may want to experience performance issues as more and more data will be refreshed each load. 
* TIP2. Handy parameter to be used as the standard for the small sources
* TIP3. When using DELTA take extra care of the date data quality in your source. in some cases empty dates may resolve into default dates such as 1899-12-12 , the will lead to the total refresh of the import serie.

From may 2022 -DELTA is default, you do not have to include it. In case you need hard overload of data use -NODELTA

#### -NODELTA
This parameter will turn of min and max dates detection from the source. all data within date_from  and date_until specified via a procedure and or an import, will be deleted and inserted. if your source has a shorter date range, more records will be deleted than inserted. 

#### -SUMFIELDS
This parameter will force following:
* add SUM function to every source column 
*  force group by clause (cancel -NOGROUPBY if it was used) 
Consider an example:
Import from file source (Excel) uses  -NOGROUPBY at the procedure level, all underlying imports inherit this command. Data is imported without grouping as we have mostly situation that one row is one date. 
Suddenly we get Excel from the Business with more rows per date because data per day is split according to contracts of the employees. 
We cannot simply remove  -NOGROUPBY command as it will solve the last request but will brake all existing imports with one row per day. 
By adding a command -SUMFIELDS to the new imports , we force sum for the new imports and keep integrity of the rest. 

BEFORE the command:

 INSERT INTO [dbo].[A_FACT_DAY] 
 ([date],activityid,forecastid,importid,Value1)
 SELECT date,460, 4,4354,H FROM [S_1_W].[A_SOURCE_FILE] 
 WHERE (source='BFC/KRIMP/ZABI') AND date BETWEEN '2022-01-03' AND '2023-01-01';

AFTER the command:

 INSERT INTO [dbo].[A_FACT_DAY] ([date],activityid,forecastid,importid,Value1)
 SELECT date,460, 4,4354,SUM(convert(float,H)) FROM [S_1_W].[A_SOURCE_FILE] 
 WHERE (source='BFC/KRIMP/ZABI') AND date BETWEEN '2022-01-03' AND '2023-01-01' GROUP BY date;


#### -PRINT 
Allows output of the generated queries as a text message in Management Studio for debug purposes. The queries are not executed.
