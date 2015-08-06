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

my @fields = ( "Ctrl #", "Tag", "Ind", "Field Data" );
my ($HeadingText, $ReportType, $CreatedFor, $CreatedOn, $Count, $ReportExplanation, $Legend);
my @SectionSubHeading; 
my @ctl_no;
my @tag;
my @ind;
my @fielddata;



open(my $fh, '<:encoding(utf8)', $filename) or die "Could not open '$filename' $!\n";
my $tree = HTML::TreeBuilder->new();
$tree->parse_file($fh);
#Do stuff w/ tree here

#Get HeadingText 
($HeadingText) = $tree->look_down( 
	_tag => "div",
	id => "HeadingText",
);
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

@SectionSubHeading = $tree->look_down(
	_tag => "div",
	class="SectionSubHeading",
);

#get ctl_no(s)
@ctl_no = $tree->look_down(
	_tag => "td",
	class => "ctl_no",
);

@tag = $tree->look_down(
	_tag => "td",
	class => "tag",
);

@ind = $tree->look_down( 
	_tag => "td",
	class => "ind",
);

@fielddata = $tree->look_down(
	_tag => "td",
	class => "fielddata",
);

#Get count 
$Count = $#ctl_no+1;

$ReportExplanation = $tree->look_down(
	_tag => "div",
	class => "ReportExplanation",
);

#Get node of legend 
 $Legend = $tree->look_down(
	_tag => "fieldset",
	class => "legend_set",
);
#Remove legend node (child node of ReportExplaination) 
$Legend->delete;



print $HeadingText->as_text, "\n";
print $ReportType->as_text, "\n";
print $CreatedFor->as_text, "\n";
print $CreatedOn->as_text, "\n";
print "Count: $Count\n";
print $ReportExplanation->as_text, "\n";
for (@fields) { print $_, "\t"; }
for (my $i=0; $i<$Count; $i++)
{
	print $ctl_no[$i]->as_text, "\t";
	print $tag[$i]->as_text, "\t";
	print $ind[$i]->as_text, "\t";
	print $fielddata[$i]->as_text, "\n";
}





#foreach (@ctl_tag)
#{
#	print $ctlno->as_text, "\n";
#}
#print $title->as_text, "\n";
#print $title->as_HTML, "\n";

#$tree->dump; #print a representation of the tree


$tree->delete;
