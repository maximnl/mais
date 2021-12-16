 

/****** Object:  View [dbo].[A_IMPORT_RUN]    Script Date: 16-12-2021 12:37:02 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE or ALTER view [S_1_W].[A_IMPORT_RUN] as 
SELECT  I.import_id
     	,case when isnull(I.[domain],'')>'' then I.[domain] else P.[domain] end as [domain]     
     	,P.[procedure_name]
		,P.[procedure_code] 
	  	,P.app
	 	,case when isnull(I.commands,'')>'' then I.commands else P.commands end as commands     
     	,I.[activity_id]
     	,[forecast_id]
     	,case when isnull(I.[p1],'')>'' then I.[p1] else P.[p1] end as [p1]
     	,case when isnull(I.[p2],'')>'' then I.[p2] else P.[p2] end as [p2]
		,case when isnull(I.[p3],'')>'' then I.[p3] else P.[p3] end as [p3]
		,case when isnull(I.[p4],'')>'' then I.[p4] else P.[p4] end as [p4]
		,case when isnull(I.[p5],'')>'' then I.[p5] else P.[p5] end as [p5]
     	,isnull(P.[sort_order],1) *1000+ isnull(I.[sort_order],0) sort_order
     	,coalesce(I.[description],P.description) as description
     	,case when P.[days_back] >'' then dateadd(D,-1* case when isnull(I.[days_back],'')>'' then I.[days_back] else P.[days_back] end ,getdate()) else
			isnull(I.[date_import_from], '1900-01-01') end date_import_from
     	,case when P.[days_forward] >'' then dateadd(D, 1 * case when isnull(I.[days_forward],'')>'' then I.[days_forward] else P.[days_forward] end,getdate()) else 
			isnull(I.[date_import_until],'9999-01-01') end date_import_until
     	,case when isnull(I.[fields_source],'') >'' then I.[fields_source] else P.fields_source end fields_source
	  	,case when isnull(I.[fields_target],'') >'' then I.[fields_target] else P.fields_target end fields_target
	  	,case when isnull(I.[schedule],'')>'' then I.[schedule] else P.[schedule] end as [schedule]
	  	,case when isnull(P.[filter],'')>'' or isnull(I.[filter],'')>'' then concat(P.[filter]
			,case when isnull(P.[filter],'')>'' and isnull(I.[filter],'')>'' then ' AND ' 
			else '' end , case when isnull(I.[filter],'')>'' then  concat('(',I.[filter],')') end ) 
			else '1=1' end [filter]
	  	,case when isnull(I.source,'') >'' then I.source else P.[source] end [source]
	  	,case when isnull(I.[group_by],'')>'' then I.[group_by] else P.[group_by] end group_by
 		,A.activity_name
		,A.activity_set
  FROM [S_1_W].[A_IMPORT] I
	  inner join [S_1_W].[A_IMPORT_PROCEDURE] P on I.procedure_id=P.procedure_id
	  inner join [S_1_W].[A_DIM_ACTIVITY] A on I.activity_id=A.activity_id
 

GO


