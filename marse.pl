#!/bin/env perl
#Attempt to pull entries from a side-by-side record
use strict;
use warnings;

#### Check command line arguments ####
{
	#Get number of command line args
	my $argc = @ARGV;
	#Check for proper number of arguments
	if($argc != 1)
	{
		#if args != 1 print usage information
		printf("Usage is: %s <filename.html> \n", $0);
	}
}


	#attempt to extract records from report 
	#filename is 1st argument
	my $filename = $ARGV[0];
	#attempt to open file
	printf("Attempting to open: %s\n", $filename);
	open(my $fp, $filename)
		or die "Could not open file '$filename': $!";
	
	

	my $on = 0;
	my $record_count = 0;
	my $record_percentage = 44;
	#or each line in the file	
	while(my $row = <$fp>) 
	{
		#remove newline from $row string (we will add it when printing)
		chomp $row;
		#This is the string as it appears in the html (not including the escaped single quotes)
		my $delimiter = '<td class=\'rec-label\'>Old version of Record:</td>';
		#quotemeta adds all the necessary escape characters to the string, so we can use it in a regexp. 
		my $search_string = quotemeta $delimiter;
		#if we are in the middle of a record and we find a delimiter that indicates the end of the record
		if($on == 1)
		{
			if($row =~ /$search_string/)
			{
				$on = 0;
			}
		}
		#if we are NOT in the middle of a record and we find the delimiter that indicates the beginning of the record
		if($on == 0) 
		{	#if $on == 0 and the current line contains the delimiter -> beginning of record
			if($row =~ /$search_string/)
			{
				$on = 1;
				$record_count++;
			}
		}
		if($on == 1)	
		{
			print "$row\n";
		}
	}
	printf("Record count is: %d\n", $record_count);
	print "done!\n";


exit;


