#!/bin/env perl

use strict;
use warnings;
use File::Slurp;
use Config::Simple;

#get current date/time for timestamps 
my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime(time);
my $datestamp = sprintf("%4d_%02d_%02d", $year+1900, $mon+1, $mday);

#parse config file
my $cfg_file = "/home/zrrm74/src/mars/mars.cfg";
my $cfg = new Config::Simple();			#Config::Simple object 
$cfg->read($cfg_file) or die $cfg->error();  	#Exception handling 


my $zip_file = $cfg->param('ENV.ZIP_FILE'); 
my $report_dir = $cfg->param('ENV.REPORT_DIR');
my @main_folders = $cfg->param("ENV.MAINDIRS");
my @sub_folders = $cfg->param("ENV.SUBDIRS");
my @school_folders = $cfg->param("ENV.SCHOOLDIRS");

#attempt to unzip -- mkDirs and handle reports only if dir doesn't already exist 
my $ret = &unzip($zip_file, $report_dir);
unless ($ret) 
{
	&sanitize_filenames($report_dir); 
	&mkDirs($report_dir, @main_folders);
	&mkDirs("$report_dir/$datestamp", @sub_folders);
	&mkDirs("$report_dir/$datestamp/School", @school_folders);
	&sort_reports($report_dir);
	&split_reports("$report_dir/$datestamp/School/NTAR","NTAR", "HTML.CHG_DELIM");
	&split_reports("$report_dir/$datestamp/School/NTAR","NTAR", "HTML.DEL_DELIM");
	#So far none of the chg/delete reports have been in LCSH but we should check anyway: 
	&split_reports("$report_dir/$datestamp/School/LCSH","LCSH", "HTML.CHG_DELIM");
	&split_reports("$report_dir/$datestamp/School/LCSH","LCSH", "HTML.DEL_DELIM");

}
#temporary; testing line-format reports 
&get_table_array("/home/zrrm74/test.html");
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
		MESH => $cfg->param('FOLDER.MESH'),			#Any filename containing m/mesh/i goes in MU_HSL folder 
		GENRE => $cfg->param('FOLDER.GENRE'),   		#Any filename containing m/genre/i goes in Genre folder 
		CHILDRENS => $cfg->param('FOLDER.CHILDRENS'), 		#Any filename containing m/childrens/i goes in Misc 
		LOCAL => $cfg->param('FOLDER.LOCAL'),			#Any filename containing m/local/i goes in Misc
		"LC-Subjects" => $cfg->param('FOLDER.LC-SUBJECTS'),	#Any filename containing LC-Subjects goes into School/LCSH  
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
				print `mv -v $path_to_files/$file "$path_to_files/$datestamp/$filename_hash{$key}"`;
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


#get_record_array($file_path, $delimiter)
#param $file_path: Full path to report file that contains records 
#param $delimiter: The string we will use in conjunction with split()/join() to separate the file into records 
#return @records: An array of records retrieved from file $file_path, index[0] is the header of the file (not a record)
sub get_record_array {
	my ($file_path, $delimiter) = @_;
	my $search_string = quotemeta $delimiter; 
	my $txt = read_file($file_path);
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
	#Get percentages from config file interface and add them to local hash
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
	
	my ($REPORT_DIR, $HASH_NAME, $DELIM_CFG_STR) = @_; 
	#We specify the key order so that we can check if records_written == total_records whenever $key == ordered_keys[$#ordered_keys]; 
	my @ordered_keys;
	if($HASH_NAME eq "NTAR") { @ordered_keys = $cfg->param('NTAR.ORDERED_KEYS'); }
	elsif($HASH_NAME eq "LCSH") { @ordered_keys = $cfg->param('LCSH.ORDERED_KEYS'); }
	
	my $path_to_files = $REPORT_DIR;						#assign input args
	my @files = read_dir($path_to_files); 						#get a list of files in the directory 
	my $delimiter = $cfg->param("$DELIM_CFG_STR");

	for my $file (@files)								#for each file in the directory
	{
		my $file_path = "$path_to_files/$file";					#full path to file
		my @records = &get_record_array($file_path, $delimiter);	
		next if($#records <= 0);
		my $num_records_file = $#records; 					#last index will be eq to #records after we shift off the first element
		printf("Opening file: %s\n", $file_path); 				#print only if there are records in the file
		printf("Number of records in file %s: %d\n", $file, $num_records_file);
		my $header = shift @records; 						#assign the first element of the array to $header, remove it from the array and shift all entries down
		my %records_per_key = ();
		my $rpk_per_file=0;
		foreach my $key (@ordered_keys)
		{	
			if($HASH_NAME eq "NTAR") { $records_per_key{$key} = int($num_records_file*($NTAR{$key}/100)); }
			elsif($HASH_NAME eq "LCSH") { $records_per_key{$key} = int($num_records_file*($LCSH{$key}/100)); }
 			$rpk_per_file += $records_per_key{$key};
		}
		my $rec_difference = ($num_records_file - $rpk_per_file);
		if($rec_difference > 0)
		{
			printf("Records to be written (%d) does not match records in file (%d) ", $rpk_per_file, $num_records_file);
			printf("Adding %d records to %s key\n", $rec_difference, $ordered_keys[$#ordered_keys]);
			#add any missing records to last key
			$records_per_key{$ordered_keys[$#ordered_keys]} += $rec_difference;
		}
		my $records_written_file = 0; 						#This variable is to keep track of the # records going to each school (per file) 
		my $records_pos = 0;		        				#variable to keep track of position in @records	
		foreach my $key (@ordered_keys)						#for each key in the NTAR hash
		{
			printf("Number of records required for $key is %d (%.2f%%) \n", $records_per_key{$key}, (($records_per_key{$key}/$num_records_file)*100));
			next if($records_per_key{$key} <= 0);				#don't create the file/write header if there are no records to be written	
			my $new_file_path = "$path_to_files/../$key/$key.$file";	#prepend key to each filename
			#printf("Writing header to file: %s\n", $new_file_path); 
			write_file($new_file_path, $header); 
			for(my $i=0; $i<$records_per_key{$key}; $i++)			#starting at the beginning, process records until we reach the limit for this key
			{	
				if($records_pos >= $num_records_file)
				{
					print "Exceeded records array(inner)\n";
					last;
				}

				my $n = $i+1; #record number
				my $new_delimiter = &number_delimiter($delimiter, $n); 
				$records[$records_pos] = join('', $new_delimiter,$records[$records_pos]);  #Add delimiter (w/ record number) to record array
				write_file($new_file_path, {append => 1}, $records[$records_pos]);
				$records_written_file++;
				$records_pos++;
			}
			if($records_pos >= $num_records_file)
			{
				last;
				print "Exceeded records array (outer)\n"
			}
		}
		printf("Total Records written/Total Records in file: %d/%d\n", $records_written_file, $num_records_file);
		print `rm -v $file_path`; 						#delete the original file (so we can verify all the side-by-side have been processed)
	}
}


#get_table_array
#param $file_path
sub get_table_array {
	my ($file_path) = $_[0]; 
	my $subject_delim = "<div class='SectionSubHeading'>"; 	#this line contains the SubHeading for each table 
	my $row_delim = "<td class='ctl_no'"; 		#this line is the identifier for each row in a table 
	$subject_delim = quotemeta $subject_delim;
	$row_delim = quotemeta $row_delim;
	my $txt = read_file($file_path);
	my @subj_temp = split(/($subject_delim)/, $txt); 	#parenthesis add the delimiter to their own index 
	my $file_header = shift @subj_temp;			#assign all html up until first SectionSubHeading to $subject_header
	my $num_elements_pre_join = $#subj_temp+1;
	print "Num elements pre: $num_elements_pre_join\n";
	my $i=0;
	my $j = (($#subj_temp)-1); #second to last element 
	my @subjects = ();
	for($i=0; $i<=$j; $i+=2)
	{
		my $subj = join('', $subj_temp[$i], $subj_temp[$i+1]);
		push @subjects, $subj;
	}

	my $num_elements_post_join = $#subjects+1;
	print "Num elements post: $num_elements_post_join\n";
	for my $element (@subjects)
	{
		print "$element\n";
	}



	



}






