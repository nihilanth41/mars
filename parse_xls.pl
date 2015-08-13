#!/bin/env perl 

use strict;
use warnings;
use Spreadsheet::ParseExcel;

my $HOME = $ENV{"HOME"};
my $file = "$HOME/test.xls";

my $parser = SpreadSheet::ParseExcel->new();
my $workbook = $parser->parse("$file");

if ( !defined $workbok ) {
	die $parser->error(), ".\n";
}

my ($row_min, $row_max) = $worksheet->row_range();
my ($col_min, $col_max) = $worksheet->col_range();


#Construct AoA
my @rows;
my @columns;

