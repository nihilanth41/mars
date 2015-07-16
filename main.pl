#!/bin/env perl

use strict;
use warnings;

#get current date/time for timestamps 
my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime(time);
my $datestamp = sprintf("%4d_%02d_%02d", $year+1900, $mon+1, $mday);

my $config_file = "mars.cfg";
#hash to store key/value pairs from config file 
my %Config = ();
&parse_config($config_file, \%Config);
my $zip_file = $Config{ZIP_FILE}; 
my $report_dir = $Config{REPORT_DIR};

&unzip($zip_file, $report_dir);
&sanitize_filenames($report_dir);
#Make datestamp folder inside report_dir and make subdirectories inside datestamp
my @main_folders = ( "Archive", "Log" );						#located in $report_dir
my @sub_folders = ( "Genre", "Misc", "New", "School", "XLS", "Ignore" );		#located in $report_dir/$datestamp 
my @school_folders = ( "MST", "MU", "MU_HSL", "MU_LAW", "UMKC", "UMKC_LAW", "UMSL" );	#located in $report_dir/$datestamp/School
&mkDirs($report_dir, @main_folders);
&mkDirs("$report_dir/$datestamp", @sub_folders);
&mkDirs("$report_dir/$datestamp/School", @school_folders);
&sort_nosplit($report_dir);
exit(0);


#parse_config($config_file, %config_hash) 
#$config_file - full path to config file 
#%config_hash - an empty hash to fill with key/value pairs from the config file 
#Fills the hash and returns 
sub parse_config {
my ($row, $fp, $File, $Option, $Value, $Config);
($File, $Config) = @_;
open($fp, $File) or die "Could not open file '$File': $!";
while($row = <$fp>)					#For each line in file
{
	chomp $row;					#Remove trailing newline 
	$row =~ s/^\s*//;				#Remove spaces at the start of the line
	$row =~ s/\s*$//;				#Remove space(s) at the end of the line
	if(($row !~ /^#/) && ($row ne "")) 		#Ignore blank lines and comments
	{
		($Option, $Value) = split (/=/, $row);	#split each line into name/value pairs
		$$Config{$Option} = $Value;		#create hash of name/value pairs
	}
}
close($fp);						#close file
}

#unzip(src_file, dest_dir)
#src_file is *FULL PATH* to .zip file to extract
#dest_dir is the directory to extract the .zip file into 
sub unzip { 
my ($src_file, $dest_dir); 
($src_file, $dest_dir) = @_;
if(!(-f $src_file)) { die "File '$src_file' doesn't exist! Check ZIP_FILE entry in mars.cfg:$!"; } #Check that .zip file exists
if(!(-d $dest_dir)) { print `mkdir -v $dest_dir`; }						   #Check if dest_dir exists, if not => create it. 
print `unzip -d $dest_dir $src_file`;
}

#sanitize_filenames($directory_with_files) 
#Takes directory as argument, renames all files in the directory according to the following rules
sub sanitize_filenames {
my $path_to_files = $_[0]; 	#directory w/ files is passed as argument 
opendir(DIR, $path_to_files) || die ("Couldn't open $path_to_files: $!"); 
#look at each file in the folder 
while(my $file = readdir(DIR)) { 
next if ($file =~ m/^\./); 	#ignore hidden files 
	my $old_file = $file;	#copy filename for rename at the end
	$file =~ s/new-//g; 	#delete any instance of 'new-' in filename
	$file =~ s/ /-/g;	#replace spaces with dashes 
	$file =~ s/\[/-/g; 	#replace open bracket w/ dash
	$file =~ s/\]/-/g;	#replace close bracket w/ dash
	$file =~ s/\(/-/g;	#replace open paren. w/ dash
	$file =~ s/\)/-/g; 	#replace close paren. w/ dash 
	$file =~ s/\$/-/g;	#replace $ w/ dash
	$file =~ s/-\./\./g;	#remove any dashes immediately before the .ext(ension) 
	$file =~ s/--/-/g;	#replace any double-dash with single-dash.
	my ($old_path, $new_path);
	$old_path = "$path_to_files/$old_file";
	$new_path = "$path_to_files/$file";
	printf("Renaming %s to %s\n", $old_path, $new_path); 
	rename("$old_path","$new_path") || die ("Couldn't rename $old_path:$!");
}
closedir(DIR); 
}


#sort_nosplit($path_to_files, %filename_hash) 
sub sort_nosplit {
my $path_to_files = $_[0]; 

#Move excel files to their own folder to get them out of the way 
if(-d $path_to_files) { print `mv -v $path_to_files/*.xls $path_to_files/$datestamp/XLS/`; }	#my $xls_re = /(.+)[.]xls$/;

#%filename_hash is used to look up the destination folder for a given file, using the same string that we matched the file with. 
my %filename_hash = ( 
	MESH => "$datestamp/School/MU_HSL",		#Any filename containing m/mesh/i goes in MU_HSL folder 
	GENRE => "$datestamp/Genre",   	 		#Any filename containing m/genre/i goes in Genre folder 
	CHILDRENS => "$datestamp/Misc", 		#Any filename containing m/childrens/i goes in Misc 
	LOCAL => "$datestamp/Misc", 			#Any filename containing m/local/i goes in Misc 
	R03 => "$datestamp/School",
	R04 => "$datestamp/School",
	R06 => "$datestamp/School",
	R07 => "$datestamp/School", 
	R31 => "$datestamp/School",
);
	
#@ordered_keys is an ordered list of key strings to match filenames with. 
#Mesh and Genre are done first because any file with that name goes into a specific folder. 
#Childrens and local are the two filetypes that do not go with the rest of the reports with the same number (R07, R06) so we deal with those next
#Then we can move anything with R06/R07 into School, and anything left in the root folder goes in MISC 
my @ordered_keys = ( "MESH", "GENRE", "CHILDRENS", "LOCAL", "R03", "R04", "R06", "R07", "R31" ); 	
											
opendir(my $dh, $path_to_files) || die ("Couldn't open $path_to_files: $!"); 
#look at each file in the folder 
while(my $file = readdir($dh)) { 
next if ($file =~ m/^\./); 	#ignore hidden files 
next if !($file =~ /\./); 	#ignore files that don't have a . somewhere (used to ignore directories in this case) 

foreach my $key (@ordered_keys)
{
	if( $file =~ m/$key/i )
	{
		print `mv -v $path_to_files/$file $path_to_files/$filename_hash{$key}`;
		last; 		#break inner loop when we find the first matching key 
	}
} 
}
closedir $dh;
#When we get to this point, everything that is left in $path_to_files should go in MISC 
if(-d $path_to_files) { print `mv -v $path_to_files/*.htm $path_to_files/$datestamp/Misc/`; }
}


#mkDirs($path, @folders)
#takes a path and a list of directories to create 
#checks if directories already exist in path -> creates if not 
sub mkDirs
{
	my ($path, @folders) = @_;	#assign input args
	for my $folder (@folders) 
	{
		chomp $folder; 		#remove trailing \n
		my $newdir = "$path/$folder"; 
		if(!(-d "$path/$folder")) #if directory doesn't exist
		{
			print `mkdir -pv $path/$folder`; 
		}
	}
}








