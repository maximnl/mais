

  CREATE      FUNCTION [dbo].[A_FN_TI_LastDayCurrentYear] 
(
	@date date  = null
)
RETURNS  datetime
AS
BEGIN
	set @date = coalesce( @date , getdate() ) 
	DECLARE @ResultVar datetime 
	SELECT @ResultVar  = DATEADD (dd, -1, DATEADD(yy, DATEDIFF(yy, 0, @date) +1, 0))
	RETURN @ResultVar 
END

GO
