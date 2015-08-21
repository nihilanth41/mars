# MARS Setup  
## Introduction 

This project is a continuation of the previous MARS RMO project, the purpose is to split MARS reports among the different libraries automatically. 
It consists of two perl scripts, mars_setup.pl and treebuilder.pl, and a config file: mars.cfg  

mars_setup.pl deals with the zip archives, creating directories, sorting files, and splitting the CHG/DEL reports. It also executes treebuilder.pl.

treebuilder.pl deals exclusively with line-format reports. It parses the html, splits it into known percentages, and writes the split data as CSV files (intermediate format).
It then parses the CSV files and rewrites the data as an Excel spreadsheet. 

mars.cfg contains data relevant to the splitting and sorting process, and any other values that may need changed by the user.


### Motivation
The process for splitting reports was originally to convert the supplied reports from html to pdf and split them as pdf files. 
Certain reports had issues with the html-to-pdf conversion, so manually splitting excel files became standard practice. 
This tool attempts to automate the process by parsing the source html, splitting it into known percentages, and rewriting it as html and xls files. 

## Requirements

### Packages 

- perl (Tested only with 5.10.1)
- zip/unzip 3.0 (Info-ZIP)

### Perl Modules 






