#!/bin/env perl 

use strict;
use warnings;
use Text::CSV;


my $csv = Text::CSV->new ({
		binary 	  => 1,
		#auto_diag => 1,
		sep_char  => '|' 
	}); 

my $filename = "/home/zrrm74/src/mars/r160.txt";
open(my $data, '<', $filename) or die "Could not open '$filename' $!\n";
my @controlno = ();
while(my $line = <$data>)
{
	chomp $line;
	print $line;
	if($csv->parse($line))
	{
		my @fields = $csv->fields();
		push @controlno, $fields[0];
	}
	else
	{
		warn "Line could not be parsed: $line\n";
		#my $diag = $csv->error_diag();
		#print "$diag","\n";
	}

}
foreach (@controlno)
{
	print "\n",$_;
}
my $num = $#controlno+1;
print "No control no: $num\n";


