 
/****** Object:  View [dbo].[A_IMPORT_RUN]    Script Date: 16-11-2023 12:43:13 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



-- VIEW for running IMPORTs stored procedures
ALTER   VIEW [dbo].[A_IMPORT_RUN]
as
    SELECT I.import_id
     	
        , A.category as category
        , A.domain as domain
     	, isnull(ltrim(rtrim(P.[procedure_name])),'') [procedure_name]
        , isnull(ltrim(rtrim(P.[procedure_code])),'') procedure_code
        , isnull(ltrim(rtrim(P.app)),'') app
        , isnull(ltrim(rtrim(P.[status])),'') status
        , P.procedure_id
        
        , rtrim(ltrim(isnull(P.commands,'')))+ rtrim(ltrim(isnull(I.commands,'')))   as commands
        , isnull(I.[activity_id],0) activity_id
        , isnull(I.[forecast_id],0) forecast_id
     	, isnull(case when isnull(I.[p1],'')>'' then ltrim(rtrim(I.[p1])) else ltrim(rtrim(P.[p1])) end,'') as [p1]
        , isnull(case when isnull(I.[p2],'')>'' then ltrim(rtrim(I.[p2])) else ltrim(rtrim(P.[p2])) end,'') as [p2]
        , isnull(case when isnull(I.[p3],'')>'' then ltrim(rtrim(I.[p3])) else ltrim(rtrim(P.[p3])) end,'') as [p3]
        , isnull(case when isnull(I.[p4],'')>'' then ltrim(rtrim(I.[p4])) else ltrim(rtrim(P.[p4])) end,'') as [p4]
        , isnull(case when isnull(I.[p5],'')>'' then ltrim(rtrim(I.[p5])) else ltrim(rtrim(P.[p5])) end,'') as [p5]
        , isnull(P.[sort_order],1) *1000+ isnull(A.[sort_order],1) * 100 + isnull(I.[sort_order],1) sort_order
        , isnull(P.description,'') as description
     	, try_convert(date,case when try_convert(date,I.[date_import_from]) is not null then I.[date_import_from]
          when try_convert(int, I.[days_back] ) is not null and ltrim(I.[days_back])>'' then dateadd(D,-1 * I.[days_back],getdate()) 
          when try_convert(date,P.[date_import_from]) is not null then P.[date_import_from]
          when try_convert(int, P.[days_back] ) is not null and ltrim(P.[days_back])>'' then dateadd(D,-1 * P.[days_back],getdate())
          else '1900-01-01' end ) 		  date_import_from
        , try_convert(date,case when try_convert(date,I.[date_import_until]) is not null then I.[date_import_until]
          when try_convert(int, I.[days_forward] ) is not null and ltrim(I.[days_forward])>'' then dateadd(D, 1 * I.[days_forward],getdate()) 
          when try_convert(date,P.[date_import_until]) is not null then P.[date_import_until]
          when try_convert(int, P.[days_forward] ) is not null and ltrim(P.[days_forward])>'' then dateadd(D,1 * P.[days_forward],getdate())
          else '9999-01-01' end) date_import_until
        , case when isnull(I.[fields_source],'') >'' then ltrim(rtrim(I.[fields_source])) else isnull(ltrim(rtrim(P.fields_source)),'value1') end fields_source
        , case when isnull(I.[fields_target],'') >'' then ltrim(rtrim(I.[fields_target])) else isnull(ltrim(rtrim(P.fields_target)),'value1') end fields_target
        , case when isnull(I.[schedule],'')>'' then ltrim(rtrim(I.[schedule])) else ltrim(rtrim(isnull(P.[schedule],''))) end as [schedule]
        , case when rtrim(ltrim(isnull(P.[filter],'')))>'' or rtrim(ltrim(isnull(I.[filter],'')))>'' then ltrim(rtrim(concat(P.[filter]
            , case when rtrim(ltrim(isnull(P.[filter],'')))>'' and rtrim(ltrim(isnull(I.[filter],'')))>'' then ' AND ' 
			else '' end , case when rtrim(ltrim(isnull(I.[filter],'')))>'' then  concat('(',isnull(ltrim(rtrim(I.[filter])),''),')') end ) ))
			else '' end [filter]
        , case when isnull(I.source,'') >'' then ltrim(rtrim(I.source)) else ltrim(rtrim(isnull(P.[source],''))) end [source]
        , case when isnull(I.[group_by],'')>'' then ltrim(rtrim(I.[group_by])) else ltrim(rtrim(isnull(P.[group_by],''))) end group_by
        , isnull(ltrim(rtrim(A.activity_name)),'') activity_name
        , isnull(ltrim(rtrim(A.activity_set)),'') activity_set
        , isnull(ltrim(rtrim(A.parent)),'') parent
        , isnull(ltrim(rtrim(A.resource)),'') resource
        , isnull(ltrim(rtrim(A.channel)),'') channel
        , isnull(ltrim(rtrim(A.segment)),'') segment
        , isnull(ltrim(rtrim(A.slicer1)),'') slicer1
        , isnull(ltrim(rtrim(A.slicer2)),'') slicer2
        , isnull(ltrim(rtrim(A.slicer3)),'') slicer3
        , F.forecast_name as forecast_name
        , I.site_id
        , case when I.active=1 and P.active=1 and A.active=1 and F.active=1  then 1 else 0 end as active
        , case when isnull(I.date_updated,'1900-01-01')>isnull(P.date_updated,'1900-01-01') then I.date_updated else P.date_updated end as date_updated
        , rtrim(ltrim(isnull(P.version,'')))+' '+rtrim(ltrim(isnull(I.version,'')))   as [version]
    ,I.[days_back] import_days_back
    ,I.[days_forward] import_days_forward
    ,I.[date_import_from] import_date_import_from
    ,I.[date_import_until] import_date_import_until
    ,P.[days_back] procedure_days_back
    ,P.[days_forward] procedure_days_forward
    ,P.[date_import_from] procedure_date_import_from
    ,P.[date_import_until] procedure_date_import_until
    ,I.domain as import_domain
    ,P.domain as procedure_domain
    ,I.category as import_category
    ,P.category as procedure_category
    FROM dbo.[A_IMPORT] I WITH (NOLOCK) 
        inner join dbo.[A_IMPORT_PROCEDURE] P WITH (NOLOCK)  on I.procedure_id=P.procedure_id
        inner join dbo.[A_DIM_ACTIVITY] A WITH (NOLOCK)  on I.activity_id=A.activity_id
        inner join dbo.[A_DIM_FORECAST] F WITH (NOLOCK)  on I.forecast_id=F.forecast_id
    where isnull(I.[activity_id],0)>0 and isnull(I.[forecast_id],0)>0 and I.site_id>0

-- version 20231116 date_import_from/until with time stamp fix (extra date conversions were added)
-- version 20230403
-- improved date_import_from / until calculations with aligned priority
-- import.import_date_from -> import.days_back -> procedure.import_date_from -> procedure.days_back
-- idem for the forward date calculations

-- version 20230104
-- removed active where filter
-- extra fields added
-- the view is now usefull for both processing jobs and applications as it has a merge of the imports the procedures attributes

-- version 20220908
-- domain from the activity is made leading
-- default/null priority set to 1 to enable push desired rows in front by setting their prio to 0.

-- VERSION 20220729
-- Filter default is ''
-- trimming and managing NULLs

--  VERSION 20220722 
--  take care of emtpty values
--  Category field of procedure added for filtering
--  Extra A_IMPORT where checks

--  VERSION 20220705 
--  Parent field from activity added for corelation forecasts



GO


