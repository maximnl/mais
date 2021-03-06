 
GO
/****** Object:  UserDefinedFunction [dbo].[A_FN_TI_FirstDayCurrentYear]    Script Date: 27-9-2021 16:56:43 ******/
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
-- =============================================
-- Author:		PLANSIS
-- Create date: 2020-11-25
-- Description: first day of the current year week based
-- =============================================
  CREATE      FUNCTION [dbo].[A_FN_TI_FirstDayCurrentYearWeek] 
(
	@date date  = null
)
RETURNS  datetime
AS
BEGIN

	DECLARE @ResultVar datetime 
	DECLARE @wk int  
	DECLARE @yr int  
	
	SET @date = coalesce( @date , getdate() ) 
	SET @yr = year(getdate())
	SET @wk = 1

	SELECT @ResultVar  =  dateadd (week, @wk, dateadd (year, @yr-1900, 0)) - 4 -
         datepart(dw, dateadd (week, @wk, dateadd (year, @yr-1900, 0)) - 4) + 2 -- +2 for europe, +1 for US
	-- Return the result of the function
	RETURN @ResultVar 

END

GO
/****** Object:  UserDefinedFunction [dbo].[A_FN_TI_FirstDayNextYear]    Script Date: 27-9-2021 16:56:43 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

 CREATE    FUNCTION [dbo].[A_FN_TI_FirstDayNextYear] 
(
	@date date  = null
)
RETURNS  datetime
AS
BEGIN
	set @date = coalesce( @date , getdate() ) 
	DECLARE @ResultVar datetime 
	SELECT @ResultVar  = DATEADD(yy, DATEDIFF(yy, 0, @date) + 1, 0)
	RETURN @ResultVar 
END

GO
/****** Object:  UserDefinedFunction [dbo].[A_FN_TI_FirstDayPreviousYear]    Script Date: 27-9-2021 16:56:43 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

 CREATE    FUNCTION [dbo].[A_FN_TI_FirstDayPreviousYear] 
(
	@date date  = null
)
RETURNS  datetime
AS
BEGIN
	set @date = coalesce( @date , getdate() ) 
	DECLARE @ResultVar datetime 
	SELECT @ResultVar  =   DATEADD(yy, DATEDIFF(yy, 0, @date) - 1, 0)
	RETURN @ResultVar 

END

GO
/****** Object:  UserDefinedFunction [dbo].[A_FN_TI_LastDayCurrentYear]    Script Date: 27-9-2021 16:56:43 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		PLANSIS
-- Create date: 2020-11-25
-- Description: last day of the current year
-- =============================================
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
/****** Object:  UserDefinedFunction [dbo].[A_FN_TI_LastDayNextYear]    Script Date: 27-9-2021 16:56:43 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		PLANSIS
-- Create date: 2020-11-25
-- Description: last day of the next year
-- =============================================
  CREATE      FUNCTION [dbo].[A_FN_TI_LastDayNextYear] 
(
@date date  = null
)
RETURNS  datetime
AS
BEGIN
    set @date = coalesce( @date , getdate() ) 
	DECLARE @ResultVar datetime 
	SELECT @ResultVar  =DATEADD (dd, -1, DATEADD(yy, DATEDIFF(yy, 0,@date) +2, 0))
	RETURN @ResultVar 
END


GO
/****** Object:  UserDefinedFunction [dbo].[A_FN_TI_LastDayPreviousYear]    Script Date: 27-9-2021 16:56:43 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		PLANSIS
-- Create date: 2020-11-25
-- Description: last day of the previous year:
-- =============================================
 CREATE   FUNCTION [dbo].[A_FN_TI_LastDayPreviousYear] 
(
	@date date  = null
)
RETURNS  datetime
AS
BEGIN

	set @date = coalesce( @date , getdate() ) 
	-- Declare the return variable here
	DECLARE @ResultVar datetime 

	-- Add the T-SQL statements to compute the return value here
	SELECT @ResultVar  =   DATEADD(dd, -1, DATEADD(yy, DATEDIFF(yy, 0, @date), 0))
	-- Return the result of the function
	RETURN @ResultVar 

END
