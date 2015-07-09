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
	
	
	my $line_count = 0;
	#or each line in the file	
	while(my $row = <$fp>) {
	#remove newline from $row string (we will add it when printing)
	chomp $row;
	#This is the string as it appears in the html (not including the escaped single quotes)
	my $delimiter = '<td class=\'rec-label\'>Old version of Record:</td>';
	#quotemeta adds all the necessary escape characters to the string, so we can use it in a regexp. 
	my $search_string = quotemeta $delimiter;
	#if the current line contains the search string, add it to the total record count
		if($row =~ /$search_string/)
		{
			$line_count++;
			print "$row\n";
		}
	}
	print "done!\n";
	printf("Line count is: %d\n", $line_count);


exit;


