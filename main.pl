#!/bin/env perl
###############
# 
use strict;
use warnings;
use Env qw(HOME);
#use IO::Uncompress::Unzip qw(unzip $UnzipError);


#Check for proper number of command line args (at least 1)
if($#ARGV < 0)
{
	print "Error: not enough arguments\n";
	printf("Usage is: %s <filename>.zip [config_file]\n", $0);
}
my $config_file = "mars.cfg";
#hash containing config keys/values
my %Config = ();
#call parse_config()
#&parse_config($config_file, \%Config);
#print a list of keys and their values from the Config hash
#foreach my $Config_key (keys %Config) {
#	print "$Config_key = $Config{$Config_key}\n"
#}
&sanitize_filenames("/home/zrrm74/src/reports/2014-04/");

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



#sanitize_filenames($directory_with_files) 
#
sub sanitize_filenames {
my $path_to_files = $_[0]; 	#directory w/ files is passed as argument 
printf("Path to files: %s\n", $path_to_files);
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
	$old_path = "$path_to_files$old_file";
	$new_path = "$path_to_files$file";
	rename("$old_path","$new_path") || die ("Couldn't rename $old_file:$!");
}
closedir(DIR); 
}
	#rename file
	
#if file has some kind of .htm extension => rename it  
#if($file =~ m/(.*)\.htm/i) {    #. - any character except newline 
			         #* - match 0 or more times
				 #/i - case insensitive matching

#unzip($src_file, $dest_dir) 
#$src_file - full path to .zip file to unzip 
#$dest_dir - directory which the contents of the zip file will be placed 
#sub unzip { 
	#local variables
	#my ($src_file, $dest_dir); 




