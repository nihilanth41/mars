#!/bin/env perl

use strict;
use warnings;
use Config::Simple;
use Cwd 'abs_path';
use File::Slurp;
use File::Basename;
use Log::Message::Simple;
use 5.10.1;

#parse config file
my $ABS_PATH = dirname( abs_path($0) );
my $cfg_file = "$ABS_PATH/mars.cfg";
my $cfg = new Config::Simple();			#Config::Simple object 
$cfg->read($cfg_file) or die $cfg->error();  	#Exception handling 

my %LCSH = (
	MU => $cfg->param('LCSH.MU'),
	MU_LAW => $cfg->param('LCSH.MU_LAW'),
	UMKC => $cfg->param('LCSH.UMKC'),
	UMKC_LAW => $cfg->param('LCSH.UMKC_LAW'),
	MST => $cfg->param('LCSH.MST'),
	UMSL => $cfg->param('LCSH.UMSL')
);
my %NTAR = (
	MU => $cfg->param('NTAR.MU'), 
	MU_HSL => $cfg->param('NTAR.MU_HSL'),
	MU_LAW => $cfg->param('NTAR.MU_LAW'),
	UMKC => $cfg->param('NTAR.UMKC'),
	UMKC_LAW => $cfg->param('NTAR.UMKC_LAW'),
	MST => $cfg->param('NTAR.MST'),
	UMSL => $cfg->param('NTAR.UMSL')
);


my $zip_file = $cfg->param('ENV.ZIP_FILE'); 
my $report_dir = $cfg->param('ENV.REPORT_DIR');
my @main_folders = $cfg->param("ENV.MAINDIRS");
my @sub_folders = $cfg->param("ENV.SUBDIRS");
my @school_folders = $cfg->param("ENV.SCHOOLDIRS");
	
#get current date/time for timestamps 
my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime(time);
my $datestamp = sprintf("%4d_%02d_%02d", $year+1900, $mon+1, $mday);

#Setup logging interface
print "Initializing log file..."; 
my $log_dir = $report_dir;
$log_dir =~ s/extract/Log/g;
#Create log dir if doesn't exist 
unless(-e -d $log_dir) { print `mkdir -v $log_dir`; } 
my $log_file = "$log_dir/$datestamp.log";
open(my $log_fh, '>:encoding(UTF-8)', $log_file) ||  die "Couldn't open log file for write $log_file: $!";
#Redirect all log output to log file
local $Log::Message::Simple::MSG_FH = $log_fh;
local $Log::Message::Simple::ERROR_FH = $log_fh;
local $Log::Message::Simple::DEBUG_FH = $log_fh;
print "DONE\n";

#attempt to unzip 
print "Extracting archive...";
my $ret = unzip($zip_file, $report_dir);
#Only work with a fresh directory structure. if dir exists -> error & die 
if($ret == 1) {
	error( "Directory already exists: $report_dir", 1 );
	my $msg = Log::Message::Simple->stack_as_string; 
	die "$msg";
}
else {
	print "DONE\n";
	
	#Remove characters from filenames that need escaped on *nix systems
	print "Renaming files...";
	sanitize_filenames($report_dir); 
	print "DONE\n";

	#Make (most of) the directory structure 
	print "Creating directory structure...";
	mkDirs($report_dir, @main_folders);
	mkDirs("$report_dir/$datestamp", @sub_folders);
	mkDirs("$report_dir/$datestamp/School", @school_folders);
	print "DONE\n";
	
	#Move files into the proper directories 
	print "Sorting report files...";
	sort_reports($report_dir);
	print "DONE\n";
	
	#Split Side-by-side reports (CHG and DEL)
	print "Splitting NTAR CHG reports...";
	split_reports("$report_dir/$datestamp/School/NTAR","NTAR", "HTML.CHG_DELIM");
	print "DONE\n";
	
	print "Splitting NTAR DEL reports...";
	split_reports("$report_dir/$datestamp/School/NTAR","NTAR", "HTML.DEL_DELIM");
	print "DONE\n";

	#So far none of the chg/delete reports have been in LCSH but we should check anyway:
	
	print "Splitting LCSH CHG reports...";
	split_reports("$report_dir/$datestamp/School/LCSH","LCSH", "HTML.CHG_DELIM");
	print "DONE\n";

	print "Splitting LCSH DEL reports...";
	split_reports("$report_dir/$datestamp/School/LCSH","LCSH", "HTML.DEL_DELIM");
	print "DONE\n";

	#Split Line-format reports 
	print "Calling treebuilder.pl... (This may take a while)\n";
	do "$ABS_PATH/treebuilder.pl";
	print "DONE\n";
	
	#Make archives of directories
	print "Creating archives...";
	&archive_folders();
	print "DONE\n";

	#Move Archive, Log, and Datestamp folders up one directory 
	#Unless Archive exists and is a directory
	unless ( -d -e "$report_dir/../Archive")
	{
		#Create Archive folder 
		`mkdir -v $report_dir/../Archive`;
	}
	#Move datestamped archive into Archive/ 
		`cp -v $report_dir/Archive/* $report_dir/../Archive/.`;
	
	unless ( -d -e "$report_dir/../Log")
	{
		#Create Log folder
		`mkdir -v $report_dir/../Log`;
	}
	#Move log files into Log/ folder
	#unless(is_folder_empty("$report_dir/Log"))
	#{
	#		`cp -v $report_dir/Log/* $report_dir/../Log/.`;
	#}
	#if datestamp already exists in directory 
	if( -d -e "$report_dir/../$datestamp")
	{
		print "Warning folder: $datestamp already exists. Skipping move.\n";
	}
	else
	{
		#Move datestamp into public_http
		`mv -v $report_dir/$datestamp $report_dir/../$datestamp`;
	}
	#Delete extract folder
	print "Cleaning up..."
	`rm -rf $report_dir`;
	print "DONE\n";
	exit(0);
}

sub is_folder_empty {
	my $dirname = shift;
	opendir(my $dh, $dirname) or die "$dirname: $!";
	return scalar(grep { $_ ne "." && $_ ne ".." } readdir($dh)) == 0;
}


sub archive_folders()
{
	#Construct list of folders to archive 
	my $prefix = "$report_dir/$datestamp";
	my $school = "$prefix/School";
	my @folder_list = (
		"$prefix/Genre",
		"$prefix/Misc",
		"$school/MST",
		"$school/MU",
		"$school/MU_HSL",
		"$school/MU_LAW",
		"$school/UMKC",
		"$school/UMKC_LAW",
		"$school/UMSL",
		"$prefix",
		);
	foreach (@folder_list)
	{
		my $ret = mkArchive($_);
	}
	if($ret == 0)
	{
		#move datestamped archive to Archive folder
		my $zip = "$prefix/$datestamp.zip";
		`mv -v $zip $prefix/../Archive/`;
	}
}

	


#mkArchive($src_dir) 
#param $src_dir: Directory to archive in a *.zip file 
#Makes a .zip archive of $src_dir, and puts it in $src_dir. 
#NOTE: It will include the directory in the archive 
#E.g., CSV.zip will expand to CSV/my_csv_files.txt
sub mkArchive {
	#print "Making archive\n";
	my $src_dir = $_[0];
	my ($filename, $dirs, $suffix) = fileparse($src_dir); 
	#Change to directory containing folder 
	chdir($dirs);
	if(-d $dirs)
	{
		#printf("Directory $src_dir exists! Creating archive...\n");
		my $zipfile = "$filename.zip";
		`zip -rv $zipfile $filename`; 
		`mv -v $zipfile "$dirs$filename/"`;
		return 0;
	}
	else { return -1; }
}


#unzip($src_file, $dest_dir)
#param $src_file: full path of the zip file to extract
#param $dest_dir: full path of the directory to extract the zip file into 
#Takes src_file and dest_dir, unzips src_file into dest_dir 
sub unzip { 
	my ($src_file, $dest_dir) = @_;
	if(!(-f $src_file)) { 
		error( "File $src_file doesn't exist! Check ZIP_FILE entry in mars.cfg." , 1 );
		my $msg = Log::Message::Simple->stack_as_string; 
		die "$msg";
	}
	if(!(-d $dest_dir)) { 
		`mkdir $dest_dir`; 	 		#create dir if doesn't exist 
		print `unzip -q -d $dest_dir $src_file`;   	#unzip into new directory
		return 0; 					#EXIT_SUCCESS 
	}
	return 1; 						#Directory already exists -> skip unzipping
}

#mkZip($src_file, $dest_file)
#param @src_files: full path to file (OR DIRECTORY) to be archived
#param $dest_file: a list containing full path (filename) of .zip file to be created 
sub mkZip {
	my ($src_file, $dest_file) = @_;
	#cd to diretory containing $src_file
	my $dir = dirname($src_file);
	my $file = basename($src_file);
	print $dir;
	print $file;
	chdir($dir);
	if(-d $src_file) {
		print `zip -r $dest_file $file`;
	}
	elsif(-f $src_file) {
		print `zip $dest_file $file`;
	}
	else {
		die "$file doesn't exist (or is not a file or folder): $!"; 
	}
}	


#sanitize_filenames($path_to_files) 
#param $path_to_files: the full path to the directory containing the reports (probably the same directory passed to unzip) 
#Removes problematic characters from filenames so that we don't have to escape them on *nix systems
sub sanitize_filenames {
	my $path_to_files = $_[0]; 	#directory w/ files is passed as argument 
	opendir(DIR, $path_to_files) || do { 
		error( "Couldn't open directory $path_to_files in sanitize_filenames()" );
		my $msg = Log::Message::Simple->stack_as_string();
		die "$msg"; 
	};
	#look at each file in the folder 
	while(my $file = readdir(DIR)) 
	{
		unless( -r -w "$path_to_files/$file" ) 	#file is r/w by effective uid/gid
		{
			error( "Couldn't rename file $file in sanitize_filenames() $!" );
			my $msg = Log::Message::Simple->stack_as_string();
			die ("$msg");
		}
		next if ($file =~ m/^\./); 	#ignore hidden files 
		my $old_file = $file;		#copy filename for rename at the end
		$file =~ s/new-//g;		#delete any instance of 'new-' in filename
		$file =~ s/ /-/g;		#replace spaces with dashes 
		$file =~ s/\[/-/g;		#replace open bracket w/ dash
		$file =~ s/\]/-/g;		#replace close bracket w/ dash
		$file =~ s/\(/-/g;		#replace open paren. w/ dash
		$file =~ s/\)/-/g;		#replace close paren. w/ dash 
		$file =~ s/\$/-/g;		#replace $ w/ dash
		$file =~ s/-\./\./g;		#remove any dashes immediately before the .ext(ension) 
		$file =~ s/--/-/g;		#replace any double-dash with single-dash.
		my ($old_path, $new_path);
		$old_path = "$path_to_files/$old_file";
		$new_path = "$path_to_files/$file";
		msg( sprintf("Renaming %s to %s\n", $old_path, $new_path) ); 
		rename("$old_path","$new_path") || die;

	}
	closedir(DIR);
}


#sort_reports($path_to_files)
#param $path_to_files: full path to the diretory containing report files 
sub sort_reports {
	my $path_to_files = $_[0]; 

	#Move excel files to their own folder to get them out of the way 
	if(-d $path_to_files) 
	{
		my @files = read_dir($path_to_files);
		foreach (@files)
		{
			if(/(.+)[.]xls$/)
			{
				`mv -v $path_to_files/$_ $path_to_files/$datestamp/XLS/`;
			}
			elsif(/(.+)[.]MRC$/)
			{
				`mv -v $path_to_files/$_ $path_to_files/$datestamp/MRC/`;
			}
		}

		#Delete Original XLS files 
		`rm -rf $path_to_files/$datestamp/XLS`;
		#Delete MRC files 
		`rm -rf $path_to_files/$datestamp/MRC`;
	}
	#%filename_hash is used to look up the destination folder for a given file, using the same string that we matched the file with. 
	my %filename_hash = ( 
		MESH => $cfg->param('FOLDER.MESH'),			#Any filename containing m/mesh/i goes in MU_HSL folder 
		GENRE => $cfg->param('FOLDER.GENRE'),   		#Any filename containing m/genre/i goes in Genre folder 
		CHILDRENS => $cfg->param('FOLDER.CHILDRENS'), 		#Any filename containing m/childrens/i goes in Misc 
		LOCAL => $cfg->param('FOLDER.LOCAL'),			#Any filename containing m/local/i goes in Misc
		SUBJECTS => $cfg->param('FOLDER.SUBJECTS'),	#Any filename containing LC-Subjects goes into School/LCSH  
		R03 => $cfg->param('FOLDER.R03'),			#Any other school reports go into School/NTAR 		
		R04 => $cfg->param('FOLDER.R04'), 
		R06 => $cfg->param('FOLDER.R06'),
		R07 => $cfg->param('FOLDER.R07'),
		R31 => $cfg->param('FOLDER.R31')
	);

	#@ordered_keys is an ordered list of key strings to match filenames with. 
	#Mesh and Genre are done first because any file with that name goes into a specific folder. 
	#Childrens and local are the two filetypes that do not go with the rest of the reports with the same number (R07, R06) so we deal with those next
	#Then we can move anything with LC-Subjects into LCSH, and anything R03,04,06,07,31 into NTAR
	#Anything left in the root folder goes in MISC 
	my @ordered_keys = $cfg->param('FOLDER.ORDERED_KEYS');
	opendir(my $dh, $path_to_files) || die ("Couldn't open $path_to_files: $!"); 
	while(my $file = readdir($dh))         	#look at each file in the folder 
	{ 
		next if ($file =~ m/^\./); 	#ignore hidden files 
		next if !($file =~ /\./); 	#ignore files that don't have a . somewhere (used to ignore directories in this case) 
		foreach my $key (@ordered_keys)
		{
			if( $file =~ m/$key/i )
			{
				`mv -v $path_to_files/$file "$path_to_files/$datestamp/$filename_hash{$key}"`;
				last; 		#break inner loop when we find the first matching key 
			}
		} 
	}
	closedir $dh;
	#When we get to this point, everything that is left in $path_to_files should go in MISC 
	if(-d $path_to_files) { `mv -v $path_to_files/*.htm $path_to_files/$datestamp/Misc/`; }
}


#mkDirs($path, @folders)
#param $path: full path to directory that we will create directories in 
#param @folders: list of directories to create   
#checks if directories already exist in path -> creates if not 
sub mkDirs
{
	my ($path, @folders) = @_;		#assign input args
	for my $folder (@folders) 
	{
		chomp $folder; 			#remove trailing \n
		my $newdir = "$path/$folder"; 
		if(!(-d "$path/$folder")) 	#if directory doesn't exist
		{
			`mkdir -p $path/$folder`;
		}
	}
}


#get_record_array($file_path, $delimiter)
#param $file_path: Full path to report file that contains records 
#param $delimiter: The string we will use in conjunction with split()/join() to separate the file into records 
#return @records: An array of records retrieved from file $file_path, index[0] is the header of the file (not a record)
sub get_record_array {
	my ($file_path, $delimiter) = @_;
	my $search_string = quotemeta $delimiter; 
	my $txt = read_file( $file_path, binmode => ':encoding(UTF-8)' ) || die "Failed to read_file() in get_record_array() - $!";
	my @records = split(/$search_string/, $txt);
	return @records;
}


#number_delimiter($delimiter, $number) 
#param $delimiter: The string that we are adding numbers to (Same as the delimiter for CHG/DELETE reports) 
#param $number: The number to add in the string 
#This function takes a string and a number as args, and inserts the number into the string. It tries to match the string in order to determine the location to insert the number. 
sub number_delimiter {
	my ($delimiter, $number) = @_;
	my $split_loc; 
	if( $delimiter =~ /Old/)
	{
		$split_loc = "Old";
	}
	elsif( $delimiter =~ /Deleted/)
	{
		$split_loc = "Deleted";
	}
	my @lines = split(/$split_loc/, $delimiter);	#split delimiter into two whenver it matches $split_loc
	my $n = "($number)";
	my $new_delimiter = join('',$lines[0],"$n $split_loc",$lines[1]);
	#printf("Old delim: %s\n", $delimiter);
	#printf("New delim: %s\n", $new_delimiter);
}


#split_reports($REPORT_DIR, $HASH_NAME, $DELIM_CFG_STR)
#param $REPORT_DIR: full path to directory containing reports to be split
#param $HASH_NAME: One of [LCSH/NTAR] - Uses this parameter to determine the percentages to use to split the report  
#param $DELIM_CFG_STR: The name of the config file entry that contains the delimiter we want to use. (This gets passed directly to $cfg->param()) 
sub split_reports {
	my ($REPORT_DIR, $HASH_NAME, $DELIM_CFG_STR) = @_; 
	#We specify the key order so that we can check if records_written == total_records whenever $key == ordered_keys[$#ordered_keys]; 
	my @ordered_keys;
	my $href;
	if($HASH_NAME eq "NTAR") { 
		@ordered_keys = $cfg->param('NTAR.ORDERED_KEYS'); 
		$href = \%NTAR;
	}
	elsif($HASH_NAME eq "LCSH") { 
		@ordered_keys = $cfg->param('LCSH.ORDERED_KEYS'); 
		$href = \%LCSH;
	}
	
	my $path_to_files = $REPORT_DIR;						#assign input args
	my @files = read_dir($path_to_files); 						#get a list of files in the directory 
	my $delimiter = $cfg->param("$DELIM_CFG_STR");

	for my $file (@files)								#for each file in the directory
	{
		my $file_path = "$path_to_files/$file";					#full path to file
		my @records = get_record_array($file_path, $delimiter);	
		next if($#records <= 0);
		my $num_records_file = $#records; 					#last index will be eq to #records after we shift off the first element
		#printf("Opening file: %s\n", $file_path); 				#print only if there are records in the file
		#printf("Number of records in file %s: %d\n", $file, $num_records_file);
		my $header = shift @records; 						#assign the first element of the array to $header, remove it from the array and shift all entries down
		my %records_per_key = ();
		my $rpk_per_file=0;
		foreach my $key (@ordered_keys)
		{	
			$records_per_key{$key} = int($num_records_file*($href->{$key}/100)); 
 			$rpk_per_file += $records_per_key{$key};
		}
		my $rec_difference = ($num_records_file - $rpk_per_file);
		if($rec_difference > 0)
		{
			#printf("Records to be written (%d) does not match records in file (%d) ", $rpk_per_file, $num_records_file);
			#printf("Adding %d records to %s key\n", $rec_difference, $ordered_keys[$#ordered_keys]);
			#add any missing records to last key
			$records_per_key{$ordered_keys[$#ordered_keys]} += $rec_difference;
		}
		my $records_written_file = 0; 						#This variable is to keep track of the # records going to each school (per file) 
		my $records_pos = 0;		        				#variable to keep track of position in @records	
		foreach my $key (@ordered_keys)						#for each key in the NTAR hash
		{
			#printf("Number of records required for $key is %d (%.2f%%) \n", $records_per_key{$key}, (($records_per_key{$key}/$num_records_file)*100));
			next if($records_per_key{$key} <= 0);				#don't create the file/write header if there are no records to be written	
			my $new_file_path = "$path_to_files/../$key/$key.$file";	#prepend key to each filename
			#printf("Writing header to file: %s\n", $new_file_path); 
			write_file($new_file_path, { binmode => ':encoding(UTF-8)' }, $header); 
			for(my $i=0; $i<$records_per_key{$key}; $i++)			#starting at the beginning, process records until we reach the limit for this key
			{	
				if($records_pos >= $num_records_file)
				{
					#print "Exceeded records array(inner)\n";
					last;
				}

				my $n = $i+1; #record number
				my $new_delimiter = &number_delimiter($delimiter, $n); 
				$records[$records_pos] = join('', $new_delimiter,$records[$records_pos]);  #Add delimiter (w/ record number) to record array
				write_file($new_file_path, { append => 1, binmode => ':encoding(UTF-8)' }, $records[$records_pos]);
				$records_written_file++;
				$records_pos++;
			}
			if($records_pos >= $num_records_file)
			{
				last;
				#print "Exceeded records array (outer)\n"
			}
		}
		#printf("Total Records written/Total Records in file: %d/%d\n", $records_written_file, $num_records_file);
		`rm -v $file_path`; 						#delete the original file (so we can verify all the side-by-side have been processed)
	}
}


		




