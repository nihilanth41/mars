#!/bin/env perl
#Attempt to pull entries from a side-by-side record
#use strict;
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
	#printf("Size of array %d\n", $#records);
	my $header = shift @records; #assign the first element of the array to $header, remove it from the array and shift all entries down
	my $first_delimiter  = '<td class=\'rec-label\'>(1) Old version of Record:</td>';
	my $numbered_rec = join( '', $header,$first_delimiter,$records[0]); 
	#for each index in array (each record) 
	for(my $i=1; $i<=$#records; $i++)
	{
		#assign record number
		my $n = $i+1; 
		my $new_delimiter = "<td class=\'rec-label\'>($n) Old version of Record:</td>"; 
		$numbered_rec = join('', $numbered_rec, $new_delimiter, $records[$i]);
	}
	print $numbered_rec;

	exit;


