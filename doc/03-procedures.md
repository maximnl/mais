# 
## Parameters
### -DELTA
This parameter forces begin and end date of the date range to be adjusted to the source date range. Data will be refreshed only for the range between min and max dates of the source. 
* TIP1. If the source goes far back in history and this data is not changed, you may want to experience performance issues as more and more data will be refreshed each load. 
* TIP2. Handy parameter to be used as the standard for the small sources
* TIP3. When using DELTA take extra care of the date data quality in your source. in some cases empty dates may resolve into default dates such as 1899-12-12 , the will lead to the total refresh of the import serie.

From may 2022 -DELTA is default, you do not have to include it. In case you need hard overload of data use -NODELTA

### -NODELTA
This parameter will turn of min and max dates detection from the source. all data within date_from  and date_until specified via a procedure and or an import, will be deleted and inserted. if your source has a shorter date range, more records will be deleted than inserted. 

### -SUMFIELDS
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


### -PRINT 
Allows output of the generated queries as a text message in Management Studio for debug purposes. The queries are not executed.
