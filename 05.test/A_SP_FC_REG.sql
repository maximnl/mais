
/*/*/*

    Name:               TEST SQL FOR A_SP_FC_REG
    Author:             PLANSIS
    Written:            2023-08-23
    Purpose:            A linear (ARIMA) regression model automation. Transforms input timeserie (value1 per day) into output timeserie based on time lagged categories, day of week and regression parameters from file_source table 
    Comments:           Timelag is organized in time categories : 0 - today, 1 - yesterday, 2 - two days ago, 3- 3 to 6 days ago, 4 - 7 - 2 weeks ago
                        Test sql to be wrapped into EXEC of SQL string , the commented parameters are to be passed as string
    Affected table(s):  [A_FACT_DAY]
    Parameter(s):       @param1 - description and usage
                        @param2 - description and usage
    Edit History:    

*/*/*/

DECLARE @date_min date = '2023-01-01' -- compute date from 
DECLARE @date_max date = '2023-12-31' -- compute date from 
DECLARE @timelag_max int = 30 -- max of time lag to stretch @date_min
-- file_id=417 and A = 639  -- source file filter ; B is a text filter, can be used instead of numeric A
-- forecast_id=3 and activity_id in (664,688,697)  -- input time series parameter
-- value1 input column name with data
-- value1 output column name 
-- parameters file with file_id 417; it has more parametersets tf. we need to filter on a right on using A field.
-- C is the lag category
-- d1 = 1 means it is monday; d1=d2=...=d6=0 means sunday
-- L is a exp addition param = 1
/*{  
    "A": "ACT_ID",
    "B": "ACT_NAME",
    "C": "Parameterset",
    "D": "offset",
    "E": "lnc",
    "F": "d1",
    "G": "d2",
    "H": "d3",
    "I": "d4",
    "J": "d5",
    "K": "d6",
    "L": "formula"
}*/

;
with D as 
(select date, sum(value1) value1 from [dbo].[A_FACT_DAY] 
where forecast_id=3 and activity_id in (664,688,697)  -- input time series parameter 
and date between dateadd(day,-@timelag_max,@date_min) and @date_max
group by date
)
, T as (
select date 
, case when day_week=1 then 1 else 0 end d1
, case when day_week=2 then 1 else 0 end d2
, case when day_week=3 then 1 else 0 end d3
, case when day_week=4 then 1 else 0 end d4
, case when day_week=5 then 1 else 0 end d5
, case when day_week=6 then 1 else 0 end d6
from [dbo].[A_TIME_DATE]  
where date between @date_min and @date_max
),

D_CAT as (
 select date
, 0 as cat
, isnull(value1,0) val 
 from D 
 union all 
 select date
, 1 as cat
, sum(isnull(value1,0)) OVER(ORDER BY D.Date 
  ROWS BETWEEN 1 PRECEDING AND 1 PRECEDING )  as val
from D
union all 
select date
, 2 as cat
, sum(isnull(value1,0)) OVER(ORDER BY D.Date 
  ROWS BETWEEN 2 PRECEDING AND 2 PRECEDING )  as val
from D
union all 
select date
, 3 as cat
, sum(isnull(value1,0)) OVER(ORDER BY D.Date 
  ROWS BETWEEN 6 PRECEDING AND 3 PRECEDING )  as val
from D
union all 
select date
, 4 as cat
, sum(isnull(value1,0)) OVER(ORDER BY D.Date 
  ROWS BETWEEN 13 PRECEDING AND 7 PRECEDING ) as val
  from D 
)

, P as (
select try_convert (smallint,right(C,1))  cat 
, try_convert(int,A) activity_id
, try_convert(real,D) offset 
, try_convert(real,E) inc 
, try_convert(real,F) d1 
, try_convert(real,G) d2 
, try_convert(real,H) d3 
, try_convert(real,I) d4 
, try_convert(real,J) d5 
, try_convert(real,K) d6
, try_convert(real,L) f      
from [dbo].[A_SOURCE_FILE] 
where file_id=417 and A = 639  -- source file filter  
)
, D_LOG as (
 select date,D_CAT.cat,LOG(val+P.f) val_log, val
 from D_CAT inner join P on D_CAT.cat=P.cat
)

select T.date
, sum(EXP(P.offset + D_LOG.val_log*P.inc + T.d1*P.d1+T.d2*P.d2+ T.d3*P.d3+T.d4*P.d4+T.d5*P.d5+T.d6*P.d6)-P.f) value1
from D_LOG inner join T on D_LOG.date=T.date
inner join P on D_LOG.cat=P.cat
group by T.date



--select * from D_CAT where date='2023-08-01';
-- select * from [dbo].[A_SOURCE_FILE] where file_id=417

