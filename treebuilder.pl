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
#Deal with file as one big table 
my @fields = ( "Ctrl #", "Tag", "Ind", "Field Data" );
my ($HeadingText, $ReportType, $CreatedFor, $CreatedOn, $Count, $ReportExplanation, $Legend);
my @SectionSubHeading; 

#deal with each table individually
my @tables;
my @thead;


open(my $fh, '<:encoding(utf8)', $file) or die "Could not open '$file' $!\n";
my $tree = HTML::TreeBuilder->new();
$tree->parse_file($fh);
#Do stuff w/ tree here

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

#Debugging:
#print "Size of tablebody: $#table_body \n";
my @td = ();
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
#Print the number of tables (number of indicies)
print "Size of td: $#td\n";
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

#tree->delete; #This is called when the program dies
#print $td[0]->{"CTL_NO"}->[0]->as_text, "\n";


	



	##########
	#Old stuff -- for if we are processing each file as one big table#


##Get HeadingText 
#($HeadingText) = $tree->look_down( 
#	_tag => "div",
#	id => "HeadingText",
#);
##Get ReportType
#($ReportType) = $tree->look_down(
#	_tag => "div", 
#	id => "ReportType",
#);
#
##CreatedFor and CreatedOn have same tag and id, so we capture all matches and assign them manually
#my @CreatedInfo = $tree->look_down(
#	_tag => "div",
#	class => "CreatedInfo",
#);
#$CreatedFor = $CreatedInfo[0];
#$CreatedOn = $CreatedInfo[1];
#
#@SectionSubHeading = $tree->look_down(
#	_tag => "div",
#	class => "SectionSubHeading",
#);
#
##get ctl_no(s)
#@ctl_no = $tree->look_down(
#	_tag => "td",
#	class => "ctl_no",
#);
#
#@tag = $tree->look_down(
#	_tag => "td",
#	class => "tag",
#);
#
#@ind = $tree->look_down( 
#	_tag => "td",
#	class => "ind",
#);
#
#@fielddata = $tree->look_down(
#	_tag => "td",
#	class => "fielddata",
#);
#
##Get count 
#$Count = $#ctl_no+1;
#
#$ReportExplanation = $tree->look_down(
#	_tag => "div",
#	class => "ReportExplanation",
#);
#
##Get node of legend 
# $Legend = $tree->look_down(
#	_tag => "fieldset",
#	class => "legend_set",
#);
##Remove legend node (child node of ReportExplaination) 
#$Legend->delete;
#

#print $HeadingText->as_text, "\n";
#print $ReportType->as_text, "\n";
#print $CreatedFor->as_text, "\n";
#print $CreatedOn->as_text, "\n";
#print "Count: $Count\n";
#print $ReportExplanation->as_text, "\n";
#for (@fields) { print $_, "\t\t"; }
#for (my $i=0; $i<$Count; $i++)
#{
#	print "\n", $ctl_no[$i]->as_text, "\t";
#	print $tag[$i]->as_text, "\t";
#	print $ind[$i]->as_text, "\t";
#	print $fielddata[$i]->as_text;
#}





#foreach (@ctl_tag)
#{
#	print $ctlno->as_text, "\n";
#}
#print $title->as_text, "\n";
#print $title->as_HTML, "\n";

#$tree->dump; #print a representation of the tree



