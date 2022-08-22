# Source/file import

Configure raw file import

Fields

**File Name **
Select filename to upload to your site repository

**Source identity**
Source name associated with the file, it is used for filtering, can be = file name

**Field Date**
Column name (in Excel A-Z notation, as in file preview) with the date field, for example A

**Date Format**
For CSV files dates are stored as text and you need to set proper formating, such as Y M d. (see examples from the tab selector)
For imports from excel choose Excel if your date field is formatted as date in Excel. 

**Rows to Skip **
Usually =1 if the first row is the header, and the second row is data

**Records**
Not yet used

**Tab number (0-99)**
Tab index for tabbed sources. For excel sources use 0 - for the first tab, 1 for the second etc.


# File import
File import functionality allows users to upload any excel or csv file to MAIS database, table A_SOURCE_FILE. This table has a similar to Excel structure limited to 78 columns from A, B, ..., AA,AB,...BZ. Using one generic table is practical for gathering various forecasting data or other regular files that need to be consolidated. So we started call it Forecast table to gather various excels from the forecasters. MAIS framework has an stored procedure A_IMPORT_EXCEL that supports import from the forecast table. By configuring source name and date fields, all  imported raw files can be filtered and aggregated to MAIS activities. (see more later)

LOG
2022-01-20
File import - improved stability as some column names could cross standard sql server names and crash the import
Added automated truncation for all columns. (majority of fields is 256 characters)

2021-12-14
File import - added support for Excel date. Excel dates can be shown in various formats in Excel. Under the motor it is a integer number when a date field is formatted as text (during the import). By choosing Excel type, the import does necessary conversion. 

