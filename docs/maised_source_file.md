# Files

Menu Sources/Files allows importing of raw files (csv, excel and few other common data formats). 
Raw data is imported into a dedicated framework table [A_SOURCE_FILE]. This table has generic column names similar to Excel - A , B, C etc. Source fields will be automatically mapped in the corresponding columns in the layout order (the first field is imported into the column A). the file name is stored in the [Source] column. The last one can be made different from the [File Name] as files may vary overtime, the 
new uploaded version can have slightly different names. Therefore field [Source] can be filled in as a fixed shorter version of the file name to be used in filtering when we will be connecting #activity or #activities daily data to files.

<img width="706" alt="image" src="https://user-images.githubusercontent.com/33482502/164969801-e4350ca5-8745-49d4-b2da-b28b7850dd7e.png">


# File example: Import temperature data KNMI (dutch weather site)

1. download a proper KNMI dataset. 
<img width="662" alt="image" src="https://user-images.githubusercontent.com/33482502/162950965-f8031611-d32d-4c4a-bcde-db84c6c93d94.png">
[KNMI download page](https://www.knmi.nl/nederland-nu/klimatologie/daggegevens)

For this example we download data for de Bilt weather station. Please open it and notice the file begins with the columns description. 

<img width="1245" alt="image" src="https://user-images.githubusercontent.com/33482502/162951355-fbb11eaa-b378-4373-b354-5d8779b32c03.png">
  
Open file in Excel to prepare the data. We remove the column descriptions such that the fields row is the first row. 
The data has 40K rows. This cannot be imported yet, so we remove old years of data and the first row is 2020 jan 01. Save a new file with extension xlsx.  

Here is a link to the resulting excel file [excel file](https://github.com/maximnl/maised/blob/main/wiki/assets/etmgeg_260.xlsx)

Now We are ready go to MAISED menu source/files, to create a new file registration and upload data we just prepared and saved in Excel. 

<img width="780" alt="image" src="https://user-images.githubusercontent.com/33482502/162951644-608466a9-4672-4f15-a4b8-6cdc28d0d7a9.png">

We drag and drop the file into the file name field. Do not worry about the other fields , we will setup them in a second after clicking Add button. 

<img width="985" alt="image" src="https://user-images.githubusercontent.com/33482502/162951882-1f50eac7-7c53-4fce-8f88-b10bae4256bd.png">

Click on Preview button to see the data. Data has 821 rows. 

<img width="1429" alt="image" src="https://user-images.githubusercontent.com/33482502/162973750-887c0b7d-93b4-48d5-9bc8-711a958c67f5.png">

Notice that date field is in the column B. Date data has format YYYYMMDD. We need to set it in the file settings. 
Go back to file and set up date field. 

<img width="1303" alt="image" src="https://user-images.githubusercontent.com/33482502/162974891-a8e843c7-f0db-445e-848e-280392a56455.png">

Field date is set to B (column name), Date format is set to Ymd.
Click on Run Import. 

<img width="559" alt="image" src="https://user-images.githubusercontent.com/33482502/162975256-0637ea6d-f5bf-4bcd-8160-372085cf9caf.png">

The import detected 41 columns and imported 832 records. Notice that records skipped is 0. If data value does not fit formatting, a row would be skipped. 
Now we can go back to file tab and view the imported data, click on [Imported data] button.

<img width="1602" alt="image" src="https://user-images.githubusercontent.com/33482502/162975715-3f072598-9d6b-43bd-b6b3-0e2153665623.png">

Notice that we see not all imported columns. Even if you scroll data page to the right, columns will stop at column S. You can go to the File page settings (via the button Settings) and drag more columns from left to right. After you have done it, scroll down to find [Apply] button. 

<img width="1114" alt="image" src="https://user-images.githubusercontent.com/33482502/162994288-6380d1e4-28b3-4538-8c4f-c18e4365705e.png">

Notice additional columns [Date Created] and column [Source] which is empty at this point. The reason for that is that we did not filled in the [Source identity] in the [file] tab. [Source] field is essential for importing data to activities as we will typically include [Source='your source'] into the import. It has a number of practical reasons:
1. Activity data originates from one source. 
2. We can have multiple files (with different file names) combined into one activity serie.
3. File names can change while having the same meaning. By filtering on [Source], our configuration will be more stable. 

After setting up [Source identity] in the file tab, we rerun [Run import]. This time [Source] in [data] tab will be filled. 

<img width="1895" alt="image" src="https://user-images.githubusercontent.com/33482502/162996260-c4afad9e-67d9-412f-8845-2be0dccf2a4e.png">

A few practical remarks:
* The date is still stored in column [B] in the original format, which is NOT date format but simple text. We do have Date column, which has true date data format. This was achieved by setting up proper date format [Ymd] in the [file] tab. In case you do have an excel formatted date column, there is a format called Excel. Excel stores dates as integers once you format a column as Date in Excel. (however you will not see it in Excel, as Excel does its best to show dates in a human readable form).

* It is essential to keep the same order of columns if you change files. Activities are typically connected to column names (A, B, C etc). 
In our example, minimum temperature ([TN] source field) is stored in column [M]. In an upcoming import of an activity, this column will be used in the [source fields] expression, eg [M]. It can be handy to make a screenshot of the file preview (as above) to quickly access fields mapping to columns.  
<img width="1429" alt="image" src="https://user-images.githubusercontent.com/33482502/162973750-887c0b7d-93b4-48d5-9bc8-711a958c67f5.png">


* Notice that in this example we have one record per day, which means we have aggregation required (activity data is stored per day). Imagine we would have more than one station in one file. In this case we would have two options:
- extend the import where condition with a station code , for instance, [A]=260. (given that the station code is kept in the column A)
- aggregate values, the source field would be [avg(M)]. 


# File formats
Currently, MAISED supports the following File Types for Reading:

Xlsx
Microsoft Excel™ 2007 shipped with a new file format, namely Microsoft Office Open XML SpreadsheetML, and Excel 2010 extended this still further with its new features such as sparklines. These files typically have an extension of .xlsx. This format is based around a zipped collection of eXtensible Markup Language (XML) files. Microsoft Office Open XML SpreadsheetML is mostly standardized in ECMA 376 and ISO 29500.

Excel spreadsheets may contain functions which are not supported by the import library of MAIS. In case your data is not loading, please copy
all cells and paste it as values. This will exclude the formulas. (the same applies to Xls format)

Xls
The Microsoft Excel™ Binary file format (BIFF5 and BIFF8) is a binary file format that was used by Microsoft Excel™ between versions 95 and 2003. The format is supported (to various extents) by most spreadsheet programs. BIFF files normally have an extension of .xls. Documentation describing the format can be read online or downloaded as PDF.

Xml
Microsoft Excel™ 2003 included options for a file format called SpreadsheetML. This file is a zipped XML document. It is not very common, but its core features are supported. Documentation for the format can be read online though it’s sadly rather sparse in its detail.

Ods
aka Open Document Format (ODF) or OASIS, this is the OpenOffice.org XML file format for spreadsheets. It comprises a zip archive including several components all of which are text files, most of these with markup in the eXtensible Markup Language (XML). It is the standard file format for OpenOffice.org Calc and StarCalc, and files typically have an extension of .ods. The published specification for the file format is available from the OASIS Open Office XML Format Technical Committee web page. Other information is available from the OpenOffice.org XML File Format web page, part of the OpenOffice.org project.

Slk
This is the Microsoft Multiplan Symbolic Link Interchange (SYLK) file format. Multiplan was a predecessor to Microsoft Excel™. Files normally have an extension of .slk. While not common, there are still a few applications that generate SYLK files as a cross-platform option, because (despite being limited to a single worksheet) it is a simple format to implement, and supports some basic data and cell formatting options (unlike CSV files).

Gnumeric
The Gnumeric file format is used by the Gnome Gnumeric spreadsheet application, and typically files have an extension of .gnumeric. The file contents are stored using eXtensible Markup Language (XML) markup, and the file is then compressed using the GNU project's gzip compression library.

Csv
Comma Separated Value (CSV) file format is a common structuring strategy for text format files. In CSV files, each line in the file represents a row of data and (within each line of the file) the different data fields (or columns) are separated from one another using a comma (,). If a data field contains a comma, then it should be enclosed (typically in quotation marks ("). Sometimes tabs \t, or the pipe symbol (|), or a semi-colon (;) are used as separators instead of a comma, although other symbols can be used. Because CSV is a text-only format, it doesn't support any data formatting options.

"CSV" is not a single, well-defined format (although see RFC 4180 for one definition that is commonly used). Rather, in practice the term "CSV" refers to any file that:

* is plain text using a character set such as ASCII, Unicode, EBCDIC, or Shift JIS,
* consists of records (typically one record per line),
* with the records divided into fields separated by delimiters (typically a single reserved character such as comma, semicolon, or tab,
* where every record has the same sequence of fields.

Within these general constraints, many variations are in use. Therefore "CSV" files are not entirely portable. Nevertheless, the variations are fairly small, and many implementations allow users to glance at the file (which is feasible because it is plain text), and then specify the delimiter character(s), quoting rules, etc.

**If you csv data file has extension .txt, please change the extension to .csv otherwise you will not be able to upload it. **

Html
HyperText Markup Language (HTML) is the main markup language for creating web pages and other information that can be displayed in a web browser. Files typically have an extension of .html or .htm. HTML markup provides a means to create structured documents by denoting structural semantics for text such as headings, paragraphs, lists, links, quotes and other items. Since 1996, the HTML specifications have been maintained, with input from commercial software vendors, by the World Wide Web Consortium (W3C). However, in 2000, HTML also became an international standard (ISO/IEC 15445:2000). HTML 4.01 was published in late 1999, with further errata published through 2001. In 2004 development began on HTML5 in the Web Hypertext Application Technology Working Group (WHATWG), which became a joint deliverable with the W3C in 2008. 
