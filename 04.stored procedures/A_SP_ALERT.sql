    -- fields_source => value1 (source field)  
    -- fields_target => value1 (target field)
    -- 
    -- group_by  => year_week  (year_month, )
    -- source => A where
    -- filter => F where
    -- p1 => activity_set
    -- p2 => activity_id list
    -- p3 test condition (test)
    -- p4 threshold > 0.20 , between 0 and 0.5

    WITH S AS (
    SELECT year_week , sum(value1) S
    FROM MAIS_ANWB_P.[A_FACT_DAY] D
    inner join MAIS_ANWB_P.[A_DIM_ACTIVITY] A on D.[activity_id]=A.[activity_id]
    inner join MAIS_ANWB_P.[A_TIME_DATE] T on D.date=T.date
    where A.activity_set='bezetting/contract/sub' and D.forecast_id=1
    group by year_week)
    , 
    T as (
    SELECT year_week , sum(value1) T   
    FROM MAIS_ANWB_P.[A_FACT_DAY] D
    inner join MAIS_ANWB_P.[A_DIM_ACTIVITY] A on D.[activity_id]=A.[activity_id]
    inner join MAIS_ANWB_P.[A_TIME_DATE] T on D.date=T.date
    where A.activity_set='bezetting/contract/sub' and D.forecast_id=6  
    group by year_week
    )
    , 
    D as (
        select min(date) date, year_week, count(*) as days 
        from MAIS_ANWB_P.[A_TIME_DATE]
        where year=2023 and date<getdate()
        group by year_week
    ) 
  , 
  C as (  
  select D.date, D.year_week, S, T 
  , case when S<>0 and S is not null and T is not null then ((S-T)/S) else null end test
  from D left join S on D.year_week=S.year_week
  left join T on D.year_week=T.year_week
  )

  select *
  from C
  where test > 0.20 or test is null

