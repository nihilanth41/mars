#!/bin/env perl
#Attempt to pull entries from a side-by-side record
use strict;
use warnings;
use File::Slurp;

#### Check command line arguments ####
{
	#Get number of command line args
	my $argc = @ARGV;
	#Check for proper number of arguments
	if($argc != 1)
	{
		#if args != 1 print usage information
		printf("Usage is: %s <filename.html> \n", $0);
		die; 
	}
}

my %NTAR = ( 
	MU => "41.4",
	MU_HSL => "2.4",
	MU_LAW => "2.4",
	UMKC => "25.7",
	UMKC_LAW => "3",
	MST => "6.9",
	UMSL => "18.2",
);
	#attempt to extract records from report 
	#filename is 1st argument
	my $filename = $ARGV[0];
	#This is the string as it appears in the html (not including the escaped single quotes)
	my $delimiter = '<td class=\'rec-label\'>Old version of Record:</td>';
	#quotemeta adds all the necessary escape characters to the string, so we can use it in a regexp. 
	my $search_string = quotemeta $delimiter;
	#use File::Slurp to load entire file into $utf8_txt
	my $txt = read_file( $filename ); 
	my @records = split ( /$search_string/, $txt );
	my $header = shift @records; #assign the first element of the array to $header, remove it from the array and shift all entries down
	my $num_records = $#records; #gives the last index of the array, since we removed the header it should be equal to the number of records also
	my $first_delimiter  = '<td class=\'rec-label\'>(1) Old version of Record:</td>'; #manually create first numbered entry 
	my $num_records_MU = ($NTAR{"MU"})/100;
	$num_records_MU *= $num_records;
	printf("Number of MU records: %d\n", $num_records_MU);
	my $numbered_rec = join( '', $header,$first_delimiter,$records[0]); #add our header, first numbered entry, and first record to the string  
	#for each index in array (each record) 
	for(my $i=1; $i<=$#records; $i++)
	{
		#joins the current string with each new numbered delimiter and each record
		#assign record number
		my $n = $i+1; 
		my $new_delimiter = "<td class=\'rec-label\'>($n) Old version of Record:</td>"; 
		$numbered_rec = join('', $numbered_rec, $new_delimiter, $records[$i]);
	}
	print $numbered_rec;

	exit;


