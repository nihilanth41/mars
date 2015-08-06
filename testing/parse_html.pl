#!/bin/env perl

use strict; 
use warnings;
use HTML::TableExtract;


my $HOME = $ENV{"HOME"};
my $file = "$HOME/r06.htm";
if( -e $file ) #if file exists
{
	my @headers = ( 'Ctrl #', "Tag", "Ind", 'Field Data' );
	my $te = HTML::TableExtract->new(
		headers => \@headers,
		attribs => { id => 'myTable' },
	);

	$te->parse_file($file);

	my ($table) = $te->tables;
	print join("\t", @headers), "\n";

	foreach my $ts ($te->tables)
	{
		foreach my $row (@$ts) {
			print join(',', @$row), "\n";
		}
	}
}

