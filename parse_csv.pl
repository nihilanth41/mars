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

my $header_str = '"Control No"|Tag|Ind|"Field Data"';
$header_str = quotemeta $header_str;
my @lines = ();
my $header_index;
my @subj_index = (); #Array to store the index(es) in the array where the Subject lines are stored
my $no_lines=0;

while(my $line = <$data>)
{	
	$no_lines++;
	chomp $line;
	push @lines, $line;
	if($line =~ /(\|)\1\1/) #Match '|' character that occurs 3 times in a row 
	{	
		#next if($line eq "|||"); #ignore empty line
		if ($line =~ /Subject /) #trailing space 
		{
			push @subj_index, $no_lines;	
		}
	}
	if($line =~ /$header_str/)
	{
		$header_index = $no_lines; 
	}
	#if($csv->parse($line))
	#{
	#	my @fields = $csv->fields();
	#	push @controlno, $fields[0];
	#	push @tag, $fields[1];
	#	push @ind, $fields[2];
	#	push @fielddata, $fields[3];
	#}
	#else
	#{	
	#	warn "Line could not be parsed: $line\n";
	#	#my $diag = $csv->error_diag();
	#	#print "$diag","\n";
	#}
}
$csv->eof or $csv->error_diag();
close $data;
push @subj_index, $#lines+1; #Last entry in @subj_index is the last valid index in the array

my @ORDERED_KEYS = ("MU_LAW", "UMKC_LAW", "MST", "UMSL", "UMKC", "MU");
my %LCSH = ( 
	"MU"=>42.4,
	"MU_LAW"=>2.4,
	"UMKC"=>26.4,
	"UMKC_LAW"=>3.1,
	"MST"=>7,
	"UMSL"=>18.7
);

my %records_per_key = ();
for(my $i=0; $i<$#subj_index; $i++) #for the number of subjects
{
	printf("Subject[%d]: Last index: %d, First Index: %d\n", $i, $subj_index[$i+1], $subj_index[$i]);
	my $num_records_this_subject = ($subj_index[$i+1] - $subj_index[$i]);
	if($i != $#subj_index-1)
	{
		$num_records_this_subject -= 1;
	}
	print "num records subj[$i]: $num_records_this_subject\n", $;
	#foreach my $key (@ORDERED_KEYS)
	#{
#		%records_per_key{$key} = int(
}
#Create new CSV file as single string
my @new_lines = ();
for(my $i=0; $i<$subj_index[0]; $i++)
{
	push @new_lines, $lines[$i];
}

#For the number of subjects that exist in the file
#for(my $i=0; $i<=$#subj_index; i++);
#{
	#push @new_lines, $subj_index[$i] #push subj line
	#for(my $j=$subj_index[$i]+1; $j<$subj_index

#	}	
#Create single-string record list for each subject 
#for(my $i=0; $i<=$#subj_index; $i++) #for the number of subject headings 
#{
	



	#
	#my $num = $#controlno+1;
	#print "No control no: $num\n";
	#
	#my $output_file = "$filename.xls";
	#my $workbook = Spreadsheet::WriteExcel->new($output_file);
	#
	##Configure cell format
	#my $format = $workbook->add_format();
	#$format->set_align('left');
	#
	##Create worksheet
	#my $worksheet = $workbook->add_worksheet();
	#
	##The following widths are taken from the existing XLS files
	#$worksheet->keep_leading_zeros(1);
	#$worksheet->set_column(0, 0, 15); 	#Column A width set to 15
	#$worksheet->set_column(1, 1, 8.43);	#Column B width set to 8.43
	#$worksheet->set_column(2, 2, 8.43);	#Column C wdith set to 8.43
	#$worksheet->set_column(3, 3, 75);       #Column D width set to 75
	#for(my $i=0; $i<$num; $i++)
	#{
	#	$worksheet->write_string($i, 0, $controlno[$i], $format);
	#	$worksheet->write_string($i, 1, $tag[$i], $format);
	#	$worksheet->write_string($i, 2, $ind[$i], $format);
	#	$worksheet->write_string($i, 3, $fielddata[$i], $format);
	#}
	#
	#$workbook->close();
	#






