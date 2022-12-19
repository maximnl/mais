SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
 
-- =============================================
-- Author:		PLANSIS
-- Create date: 2020-11-25
-- Description: first day of the current year week based (monday of the first week)
-- =============================================
  CREATE        FUNCTION [dbo].[A_FN_TI_FirstDayCurrentYearWeek] 
(
	@date date  = null
)
RETURNS  datetime
AS
BEGIN
	set @date = coalesce( @date , getdate() ) 
	
	DECLARE @ResultVar datetime 
    DECLARE @wk int  
	DECLARE @yr int  

	SET @yr = year(@date)
	SET @wk = 1

	SELECT @ResultVar  =  dateadd (week, @wk, dateadd (year, @yr-1900, 0)) - 4 -
         datepart(dw, dateadd (week, @wk, dateadd (year, @yr-1900, 0)) - 4) + 2 -- +2 for europe, +1 for US
	-- Return the result of the function
	RETURN @ResultVar 
END
GO
