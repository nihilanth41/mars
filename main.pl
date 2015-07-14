#!/bin/env perl
###############
#
#
#
####################################################
use strict;
use warnings;
use Env qw(HOME);
#use IO::Uncompress::Unzip qw(unzip $UnzipError);


#Check for proper number of command line args (at least 1)
#if($#ARGV < 0)
#{
#	print "Error: not enough arguments\n";
#	printf("Usage is: %s <filename>.zip [config_file]\n", $0);
#}

#get current date/time for timestamps 
my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime(time);
my $datestamp = sprintf("%4d%02d%02d", $year+1900, $mon+1, $mday);


my $config_file = "mars.cfg";
#hash to store key/value pairs from config file 
my %Config = ();
&parse_config($config_file, \%Config);
my $zip_file = $Config{ZIP_FILE}; 
my $report_dir = $Config{REPORT_DIR};
#foreach my $Config_key (keys %Config) {
#	print "$Config_key = $Config{$Config_key}\n"
#}
&unzip($zip_file, $report_dir);
&sanitize_filenames($report_dir);
&sort_reports($report_dir);

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
#printf("Path to files: %s\n", $path_to_files);
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
	
sub sort_reports {
my $path_to_files = $_[0];		#directory containing reports is passed as argument
opendir(DIR, $path_to_files) || die ("Couldn't open $path_to_files: $!"); 
#deal with reports that don't get split first. Put them in proper directories.
#if path is valid => make directories 
my $genre_path = "$path_to_files/Genre";
my $mesh_path = "$path_to_files/Mesh";
my $misc_path = "$path_to_files/Misc";
#Create directories only if they don't already exist (Should be a clean directory every time, but will suppress errors while testing) 
if(!(-d $genre_path)) { print `mkdir -v $genre_path`; }	#For files containing "genre" 
if(!(-d $mesh_path))  { print `mkdir -v $mesh_path`; } 	#For files containing "MeSH" 
if(!(-d $misc_path))  { print `mkdir -v $misc_path`; } 	#For files containing "Other" or none 

#look at each file in the folder
while(my $file = readdir(DIR)) {
next if ($file =~ m/^\./);			#ignore hidden files
next if !($file =~ /\./); 			#ignore files that don't have a . somewhere (used to ignore directories in this case) 	
my $full_path = "$path_to_files/$file"; 
	if($file =~ m/mesh/i)			
	{				
		print `mv -v "$full_path" "$mesh_path/\."`;
	}
	elsif($file =~ m/genre/i)
	{
		print `mv -v "$full_path" "$genre_path/\."`;
	}
	elsif($file =~ m/other/i) 
	{
		print `mv -v "$full_path" "$misc_path/\."`;
	}
	#"none" files also go into misc folder. How to determine "none"? -- Or just wait until after all other files have been split/sorted
}
closedir(DIR);
}






