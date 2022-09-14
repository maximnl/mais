SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- VIEW for running IMPORTs stored procedures
CREATE OR ALTER       VIEW [dbo].[A_IMPORT_RUN]
as
    SELECT I.import_id
     	, case  when isnull(A.[domain],'')>'' then A.[domain] 
                when isnull(I.[domain],'')>'' then I.[domain] else P.[domain] end as [domain]     
     	, isnull(ltrim(rtrim(P.[procedure_name])),'') procedure_name
        , isnull(ltrim(rtrim(P.[procedure_code])),'') procedure_code
        , isnull(ltrim(rtrim(P.app)),'') app
        , isnull(ltrim(rtrim(P.[status])),'') status
        , P.procedure_id
        , isnull(ltrim(rtrim(P.category)),'') category 
        , rtrim(ltrim(isnull(P.commands,'')))+rtrim(ltrim(isnull(I.commands,'')))   as commands
        , isnull(I.[activity_id],0) activity_id
        , isnull(I.[forecast_id],0) forecast_id
     	, isnull(case when isnull(I.[p1],'')>'' then ltrim(rtrim(I.[p1])) else ltrim(rtrim(P.[p1])) end,'') as [p1]
        , isnull(case when isnull(I.[p2],'')>'' then ltrim(rtrim(I.[p2])) else ltrim(rtrim(P.[p2])) end,'') as [p2]
        , isnull(case when isnull(I.[p3],'')>'' then ltrim(rtrim(I.[p3])) else ltrim(rtrim(P.[p3])) end,'') as [p3]
        , isnull(case when isnull(I.[p4],'')>'' then ltrim(rtrim(I.[p4])) else ltrim(rtrim(P.[p4])) end,'') as [p4]
        , isnull(case when isnull(I.[p5],'')>'' then ltrim(rtrim(I.[p5])) else ltrim(rtrim(P.[p5])) end,'') as [p5]
        , isnull(P.[sort_order],1) *1000+ isnull(A.[sort_order],1) * 100 + isnull(I.[sort_order],1) sort_order
        , isnull(P.description,'') as description
     	, case when isnull(P.[days_back],0)+isnull(I.[days_back],0) > 0 then dateadd(D,-1* case when isnull(I.[days_back],0)>0 then I.[days_back] else P.[days_back] end ,getdate()) else
			isnull(I.[date_import_from], isnull(P.date_import_from, '1900-01-01')) end date_import_from
        , case when isnull(P.[days_forward],0)+isnull(I.[days_forward],0) >0 then dateadd(D, 1 * case when isnull(I.[days_forward],0)>0 then I.[days_forward] else P.[days_forward] end,getdate()) else 
			isnull(I.[date_import_until],isnull(P.date_import_until, '9999-01-01')) end date_import_until
        , case when isnull(I.[fields_source],'') >'' then ltrim(rtrim(I.[fields_source])) else isnull(ltrim(rtrim(P.fields_source)),'value1') end fields_source
        , case when isnull(I.[fields_target],'') >'' then ltrim(rtrim(I.[fields_target])) else isnull(ltrim(rtrim(P.fields_target)),'value1') end fields_target
        , case when isnull(I.[schedule],'')>'' then ltrim(rtrim(I.[schedule])) else ltrim(rtrim(isnull(P.[schedule],''))) end as [schedule]
        , case when isnull(P.[filter],'')>'' or isnull(I.[filter],'')>'' then ltrim(rtrim(concat(P.[filter], case when isnull(P.[filter],'')>'' and isnull(I.[filter],'')>'' then ' AND ' 
			else '' end , case when isnull(I.[filter],'')>'' then  concat('(',isnull(ltrim(rtrim(I.[filter])),''),')') end ) ))
			else '' end [filter]
        , case when isnull(I.source,'') >'' then ltrim(rtrim(I.source)) else ltrim(rtrim(isnull(P.[source],''))) end [source]
        , case when isnull(I.[group_by],'')>'' then ltrim(rtrim(I.[group_by])) else ltrim(rtrim(isnull(P.[group_by],''))) end group_by
        , isnull(ltrim(rtrim(A.activity_name)),'') activity_name
        , isnull(ltrim(rtrim(A.activity_set)),'') activity_set
        , isnull(ltrim(rtrim(A.parent)),'') parent
        , isnull(ltrim(rtrim(A.resource)),'') resource
        , isnull(ltrim(rtrim(A.channel)),'') channel
        , I.site_id
    FROM dbo.[A_IMPORT] I
        inner join dbo.[A_IMPORT_PROCEDURE] P on I.procedure_id=P.procedure_id
        inner join dbo.[A_DIM_ACTIVITY] A on I.activity_id=A.activity_id
        inner join dbo.[A_DIM_FORECAST] F on I.forecast_id=F.forecast_id
    where I.active=1 and P.active=1 and A.active=1 and F.active=1 and isnull(I.[activity_id],0)>0 and isnull(I.[forecast_id],0)>0 and I.site_id>0

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
