# MARS   
## Introduction 

This project is a continuation of the previous MARS project, the purpose is to split MARS reports among the different libraries automatically.  
It consists of two perl scripts, mars_setup.pl and treebuilder.pl, and a config file: mars.cfg  

- mars_setup.pl deals with the zip archives, creating directories, sorting files, and splitting the CHG/DEL reports. It also executes treebuilder.pl.
- treebuilder.pl deals exclusively with line-format reports. It parses the html, splits it into known percentages, It writes the HTML files directly, but for Excel it  writes the split data as CSV files (intermediate format).
It then parses the CSV files and rewrites the data as an Excel spreadsheet. 
- mars.cfg contains data relevant to the splitting and sorting process, and any other values that may need changed. 


### Motivation
The process for splitting reports was originally to convert the supplied reports from html to pdf and split them as pdf files. 
Certain reports had issues with the html-to-pdf conversion, so manually splitting excel files became standard practice. 
This tool attempts to automate the process by parsing the source html, splitting it into known percentages, and rewriting it as html and xls files. 

## Requirements

### Packages 

- Perl (Tested only with 5.10.1)
- Zip/Unzip (Info-ZIP 3.0)

### Perl Modules 

#### Core Modules 

- Encode
- File::Basename
- Cwd

#### From CPAN 

- Config::Simple
- File::Slurp
- HTML::Entities
- HTML::Restrict
- HTML::TreeBuilder
- Spreadsheet::WriteExcel
- Text::CSV

## Installation 

```
cd /usr/local/lso/src
git clone https://github.com/nihilanth41/mars.git
cd mars
./setup_mars.sh 
./mars.pl
```

## Configuration 

- Uses mars.cfg as the configuration file 
- Make sure ZIP_FILE is configured (full path to report archive) 
- Make sure REPORT_DIR is configured (full path of directory to extract into)
 - NOTE: The last directory in REPORT_DIR will be created/deleted by the script. 

## Maintainers/Sponsors 

- Created by Zachary Rump

