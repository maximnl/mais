SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
 
-- =============================================
-- Author:		PLANSIS
-- Create date: 2020-11-25
-- Description: first day of the current year
-- =============================================
  CREATE      FUNCTION [dbo].[A_FN_TI_FirstDayCurrentYear] 
(
	@date date  = null
)
RETURNS  datetime
AS
BEGIN
	set @date = coalesce( @date , getdate() ) 
	DECLARE @ResultVar datetime 
	SELECT @ResultVar  =  DATEADD(yy, DATEDIFF(yy, 0, @date), 0)
	RETURN @ResultVar 
END
GO
