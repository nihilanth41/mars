#!/bin/env perl 

use strict;
use warnings;
use Text::CSV;
use utf8::all;


my $csv = Text::CSV->new ({
		binary 	  => 1,
		#auto_diag => 1,
		sep_char  => '|' 
	}); 

my $filename = "/home/zrrm74/src/mars/r160.txt";
open(my $data, '<:encoding(utf8)', $filename) or die "Could not open '$filename' $!\n";
my @controlno = ();
my @tag = ();
my @ind = ();
my @fielddata = ();
while(my $line = <$data>)
{
	chomp $line;
	print $line;
	if($csv->parse($line))
	{
		my @fields = $csv->fields();
		push @controlno, $fields[0];
		push @tag, $fields[1];
		push @ind, $fields[2];
		push @fielddata, $fields[3];
	}
	else
	{
		warn "Line could not be parsed: $line\n";
		#my $diag = $csv->error_diag();
		#print "$diag","\n";
	}

}
$csv->eof or $csv->error_diag();
close $data;

for(my $i=0; $i<=$#controlno; ++$i)
{
	print "$i: $controlno[$i], $tag[$i], $ind[$i], $fielddata[$i]\n";
}
my $num = $#controlno+1;
print "No control no: $num\n";


