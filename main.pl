#!/bin/env perl

use strict;
use warnings;
use File::Slurp;
use Config::Simple;

#get current date/time for timestamps 
my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime(time);
my $datestamp = sprintf("%4d_%02d_%02d", $year+1900, $mon+1, $mday);

#parse config file
my $cfg_file = "mars.cfg";
my $cfg = new Config::Simple();			#Config::Simple object 
$cfg->read($cfg_file) or die $cfg->error();  	#Exception handling 


my $zip_file = $cfg->param('ENV.ZIP_FILE'); 
my $report_dir = $cfg->param('ENV.REPORT_DIR');

#attempt to unzip -- mkDirs and handle reports only if dir doesn't already exist 
my $ret = &unzip($zip_file, $report_dir);
unless ($ret) 
{
	&sanitize_filenames($report_dir); 
	my @main_folders = ( "Archive", "Log" );								#located in $report_dir
	my @sub_folders = ( "Genre", "Misc", "School", "XLS" );							#located in $report_dir/$datestamp 
	my @school_folders = ( "LCSH", "NTAR", "MST", "MU", "MU_HSL", "MU_LAW", "UMKC", "UMKC_LAW", "UMSL" );	#located in $report_dir/$datestamp/School
	&mkDirs($report_dir, @main_folders);
	&mkDirs("$report_dir/$datestamp", @sub_folders);
	&mkDirs("$report_dir/$datestamp/School", @school_folders);
	&sort_reports($report_dir);
	&split_reports("$report_dir/$datestamp/School/NTAR");
}
exit(0);




#unzip($src_file, $dest_dir)
#param $src_file: full path of the zip file to extract
#param $dest_dir: full path of the directory to extract the zip file into 
#Takes src_file and dest_dir, unzips src_file into dest_dir 
sub unzip { 
	my ($src_file, $dest_dir) = @_;
	if(!(-f $src_file)) { die "File '$src_file' doesn't exist! Check ZIP_FILE entry in mars.cfg:$!"; } #Check that .zip file exists
	if(!(-d $dest_dir)) 
	{ 
		print `mkdir -v $dest_dir`; 	 	#create dir if doesn't exist 
		print `unzip -d $dest_dir $src_file`;   #unzip into new directory
		return 0; 				#EXIT_SUCCESS 
	}
	return 1; 					#Directory already exists -> skip unzipping
}

#sanitize_filenames($path_to_files) 
#param $path_to_files: the full path to the directory containing the reports (probably the same directory passed to unzip) 
#Removes problematic characters from filenames so that we don't have to escape them on *nix systems
sub sanitize_filenames {
	my $path_to_files = $_[0]; 	#directory w/ files is passed as argument 
	opendir(DIR, $path_to_files) || die ("Couldn't open $path_to_files: $!"); 
	#look at each file in the folder 
	while(my $file = readdir(DIR)) 
	{ 
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


#sort_reports($path_to_files)
#param $path_to_files: full path to the diretory containing report files 
sub sort_reports {
	my $path_to_files = $_[0]; 

	#Move excel files to their own folder to get them out of the way 
	if(-d $path_to_files) { print `mv -v $path_to_files/*.xls $path_to_files/$datestamp/XLS/`; }	#my $xls_re = /(.+)[.]xls$/;

	#%filename_hash is used to look up the destination folder for a given file, using the same string that we matched the file with. 
	my %filename_hash = ( 
		MESH => "$datestamp/School/MU_HSL",		#Any filename containing m/mesh/i goes in MU_HSL folder 
		GENRE => "$datestamp/Genre",   	 		#Any filename containing m/genre/i goes in Genre folder 
		CHILDRENS => "$datestamp/Misc", 		#Any filename containing m/childrens/i goes in Misc 
		LOCAL => "$datestamp/Misc", 			#Any filename containing m/local/i goes in Misc
		"LC-Subjects" => "$datestamp/School/LCSH",	#Any filename containing LC-Subjects goes into School/LCSH  
		R03 => "$datestamp/School/NTAR",		#Any other school reports go into School/NTAR 		
		R04 => "$datestamp/School/NTAR",
		R06 => "$datestamp/School/NTAR",
		R07 => "$datestamp/School/NTAR", 
		R31 => "$datestamp/School/NTAR",
	);
		
	#@ordered_keys is an ordered list of key strings to match filenames with. 
	#Mesh and Genre are done first because any file with that name goes into a specific folder. 
	#Childrens and local are the two filetypes that do not go with the rest of the reports with the same number (R07, R06) so we deal with those next
	#Then we can move anything with LC-Subjects into LCSH, and anything R03,04,06,07,31 into NTAR
	#Anything left in the root folder goes in MISC 
	my @ordered_keys = ( "MESH", "GENRE", "CHILDRENS", "LOCAL", "LC-Subjects", "R03", "R04", "R06", "R07", "R31" ); 	
	opendir(my $dh, $path_to_files) || die ("Couldn't open $path_to_files: $!"); 
	while(my $file = readdir($dh))         	#look at each file in the folder 
	{ 
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
			print `mkdir -pv $path/$folder`; 
		}
	}
}

#split_reports($path_to_files)
#param $path_to_files: full path to directory containing the reports that need split (E.g., NTAR,LCSH)
#
sub split_reports {
	#Putting these hashes here until I can figure out a good way to read them from a config file
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
	my $path_to_files = $_[0];							#assign input args
	my @files = read_dir($path_to_files); 						#get a list of files in the directory 
	my $delimiter = '<td class=\'rec-label\'>Old version of Record:</td>';
	my $search_string = quotemeta $delimiter; 					#quotemeta adds all the necessary escape characters to the string,
	for my $file (@files)								#for each file in the directory
	{	
		my $file_path = "$path_to_files/$file";					#full path to file
		#printf("Opening file: %s\n", $file_path); 
		my $txt = read_file( $file_path ); 					#load whole file into 1 string w/ file::slurp	
		my @records = split ( /$search_string/, $txt );
		my $header = shift @records; 						#assign the first element of the array to $header, remove it from the array and shift all entries down
		my $num_records = $#records+1; 						#number of records in @records	
		next if($num_records <= 0);   						#line-format; ignore for now
		my $rec_count = 0; 							#This variable is to keep track of the # records going to each school (per file) 
		my $j = 0;		        					#variable to keep track of position in @records	
		for my $key (keys %NTAR)						#for each key in the NTAR hash
		{	
			my $new_file_path = "$path_to_files/../$key/$key.$file";	#prepend key to each filename
			#printf("Writing header to file: %s\n", $new_file_path); 
			write_file($new_file_path, $header); 
			my $num_records_this_key = (($num_records)*($NTAR{$key}/100));	#number of records that should go to the current library (key)
			printf("Number of records required for $key is %f\n", $num_records_this_key);
			$rec_count += $num_records_this_key;				#add to total processed for this file
			for(my $i=0; $i<$num_records_this_key; $i++)			#starting at the beginning, process records until we reach the limit for this key
			{
				my $n = $i+1; #record number
				my $new_delimiter = "<td class=\'rec-label\'>($n) Old version of Record:</td>"; 
				$records[$j] = join('', $new_delimiter,$records[$j]);  #Add delimiter (w/ record number) to record array
				write_file($new_file_path, {append => 1}, $records[$j]);
				$j++;
				if($j >= $num_records)
				{
					last;
				}
			}
			if($j >= $num_records)
			{
				last;
			}
		}
		printf("Total Records written/Total Records in file: %d/%d\n", $rec_count, $num_records);
		print `rm -v $file_path`; 						#delete the original file (so we can verify all the side-by-side have been processed)

	}
}






