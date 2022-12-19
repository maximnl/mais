SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- replaces double spaces and tab by single spaces
  CREATE      FUNCTION [dbo].[A_FN_STRING_SPACES] 
(
	@str varchar(max)  = null
)
RETURNS  varchar(max)
AS
BEGIN
SET @str=replace(replace(replace(replace(@str,char(32),' '),char(13),' '),char(9),' '),char(10),' ')
	WHILE CHARINDEX('  ', @str) > 0 
        SET @str = REPLACE(@str, '  ', ' ')
    RETURN @str
END
GO
