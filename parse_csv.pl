#!/bin/env perl

use strict;
use warnings;
use Text::CSV;
use Spreadsheet::WriteExcel;
use utf8::all;	#Closest thing to "use utf8 everywhere" 

#Initialize arrays to store values from each column 
my @controlno = ();
my @tag = ();
my @ind = ();
my @fielddata = ();
my $csv = Text::CSV->new ({
		binary 	  => 1,
		auto_diag => 1,	 #call error_diag() automatically (in void context) upon errors 
		sep_char  => '|' 
	}); 
my $filename = "/home/zrrm74/src/mars/r160.txt";



#TODO:
#Get lines that can't be parsed and store them as headers
#TITLE
#FILENAME
#REPORT TYPE
#CREATED FOR
#CREATED ON 
#COUNT
#DESC
#COLUMN HEADERS
#SUBJECT EXAMPLE (###) (Maybe more than one of these)
open(my $data, '<:encoding(utf8)', $filename) or die "Could not open '$filename' $!\n";
while(my $line = <$data>)
{
	chomp $line;
	#print $line;
	if($csv->parse($line))
	{
		#print $line, "\n";
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

#for(my $i=0; $i<=$#controlno; ++$i)
#{
#	print "\n$i: $controlno[$i], $tag[$i], $ind[$i], $fielddata[$i]";
#}
my $num = $#controlno+1;
print "No control no: $num\n";

#References to arrays which we will pass to $worksheet->write_col()
#my $controlno_ref = \@controlno;
#my $tag_ref = \@tag;
#my $ind_ref = \@ind;
#my $fielddata_ref = \@fielddata;

my $output_file = "$filename.xls";
my $workbook = Spreadsheet::WriteExcel->new($output_file);

#Configure cell format
my $format = $workbook->add_format();
$format->set_align('left');

#Create worksheet
my $worksheet = $workbook->add_worksheet();

#The following widths are taken from the existing XLS files
$worksheet->keep_leading_zeros(1);
$worksheet->set_column(0, 0, 15); 	#Column A width set to 15
$worksheet->set_column(1, 1, 8.43);	#Column B width set to 8.43
$worksheet->set_column(2, 2, 8.43);	#Column C wdith set to 8.43
$worksheet->set_column(3, 3, 75);       #Column D width set to 75
for(my $i=0; $i<$num; $i++)
{
	$worksheet->write_string($i, 0, $controlno[$i], $format);
	$worksheet->write_string($i, 1, $tag[$i], $format);
	$worksheet->write_string($i, 2, $ind[$i], $format);
	$worksheet->write_string($i, 3, $fielddata[$i], $format);
}

#$worksheet->write_col(0, 0, $controlno_ref, $format);
#$worksheet->write_col(0, 1, $tag_ref, $format);
#$worksheet->write_col(0, 2, $ind_ref, $format);
#$worksheet->write_col(0, 3, $fielddata_ref, $format);

$workbook->close();







