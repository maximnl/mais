2022-02-04 Import files
Support of multiple files data view added. 
This is usefull when several files are aggregated into one activity import. Such import requires the date range be matched by multiple files. By sorting on date the user can do the check if the data for the same date is present in the multiple files. 

2021-12-15 Import files
Import of 1000+ records raw files were causing issues at sql server (limitations)
We splitted the insert transactions into 500 rows batches. 
