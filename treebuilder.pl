#!/bin/env perl

use strict;
use warnings;
use utf8::all;
use HTML::TreeBuilder;

my $HOME = $ENV{"HOME"};
my $file = "$HOME/r06.htm";
unless(-e $file) 
{
	print "Error: $file not found\n";
	die;
}
#Declare global variables
#Variables used to store text that's not associated with tables (headings, etc.) 
my ($HeadingText, $ReportType, $CreatedFor, $CreatedOn, $Count, $ReportExplanation, $Legend);
my @SectionSubHeading; 
#@tables stores each of the raw tables (separated by SectionSubHeading) 
my @tables;
my @thead;

#Manually create filehandle so we can specify the encoding, and pass it to HTML::TreeBuilder
open(my $fh, '<:encoding(utf8)', $file) or die "Could not open '$file' $!\n";
my $tree = HTML::TreeBuilder->new();
$tree->parse_file($fh);
### Do stuff w/ tree here ###

#Assign our global vars to nodes 
tree_init();

#Get the tables out of the file and put them in @td(); 
#NOTE: td() is an array of hashes AoH
#Each hash has 4 keys that point to an array reference, which contains the column data for that table
my @td = ();
get_tables();

#Get the number of records (from all tables) in the file, store in global $Count
get_total_count();

#Print header info in same format as XLS files
#printHeader();










for(my $i=0; $i<=$#td; $i++) #For each table in the file 
{
	print("\n", " ----------------- Table: $i -----------------", "\n");
	my $hashref = $td[$i]; #Point the reference at the hash  
	my $ar_temp = $hashref->{"CTL_NO"};
	my $size = @{$ar_temp};
	print "Size: $size\n";
	for(my $j=0; $j<$size; $j++) #For each row 
	{
		my @ordered_keys = ("CTL_NO", "TAG", "IND", "FIELDDATA" );
		for my $key (@ordered_keys) #For each column 
		{
			print $td[$i]->{$key}->[$j]->as_text, "\t";
		}
		print "\n";
	}
}

sub printHeader
{
	print $HeadingText->as_text, "\n";
	print $ReportType->as_text, "\n";
	print $CreatedFor->as_text, "\n";
	print $CreatedOn->as_text, "\n";
	print "Count: $Count\n";
	print $ReportExplanation->as_text, "\n";
}

#Get count of all the records in the file
sub get_total_count
{
	for(my $i=0; $i<=$#td; $i++) #For each table in the file 
	{
		my $hr = $td[$i];
		my $ar = $hr->{"CTL_NO"};
		my $size = @{$ar};
		$Count += $size;
	}
}

sub get_tables
{
	foreach my $table (@tables)
	{
		#Construct local arrays of table data 
		my @ctl_no;
		my @tag;
		my @ind;
		my @fielddata; 
		my $ctl_ref = \@ctl_no;
		my $tag_ref = \@tag;
		my $ind_ref = \@ind;
		my $fd_ref = \@fielddata;
		my %table_data = (
			"CTL_NO" => $ctl_ref,
			"TAG" => $tag_ref,
			"IND" => $ind_ref,
			"FIELDDATA" => $fd_ref,
		);
		my $td_ref = \%table_data;
		@ctl_no = $table->look_down(
			_tag => "td",
			class => "ctl_no",
		);
		@tag = $table->look_down(
			_tag => "td",
			class => "tag",
		);
		@ind = $table->look_down( 
			_tag => "td",
			class => "ind",
		);
		@fielddata = $table->look_down(
			_tag => "td",
			class => "fielddata",
		);
		push @td, $td_ref; 
	}
}


sub tree_init 
{
	#Get HeadingText 
	($HeadingText) = $tree->look_down( 
		_tag => "div",
		id => "HeadingText",
	);

	#Get node of legend & remove legend from ReportExplanation  
	$Legend = $tree->look_down(
		_tag => "fieldset",
		class => "legend_set",
	);
	##Remove legend node (child node of ReportExplanation) 
	$Legend->delete;

	#Get ReportType
	($ReportType) = $tree->look_down(
		_tag => "div", 
		id => "ReportType",
	);

	#CreatedFor and CreatedOn have same tag and id, so we capture all matches and assign them manually
	my @CreatedInfo = $tree->look_down(
		_tag => "div",
		class => "CreatedInfo",
	);
	$CreatedFor = $CreatedInfo[0];
	$CreatedOn = $CreatedInfo[1];

	$ReportExplanation = $tree->look_down(	
		_tag => "div",
		class => "ReportExplanation",
	);

	#Match each table and put it in @table_body 
	@tables = $tree->look_down(
		_tag => "table",
		class => qr/field-info table-autosort table-autostripe table-autofilter table-rowshade-EvenRow/,
	);

	#Match each table header (later remove from @table_body)
	@thead = $tree->look_down(
		_tag => "thead",
	);
	#Delete thead from each @table_body
	foreach my $th (@thead)
	{
		$th->delete;
	}

	#Get SectionSubHeading and store -- Index of correct heading will be same as the index of the table 
	@SectionSubHeading = $tree->look_down(
		_tag => "div",
		class => "SectionSubHeading",
	);
}
