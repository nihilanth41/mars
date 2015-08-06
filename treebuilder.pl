#!/bin/env perl

use strict;
use warnings; 
use HTML::TreeBuilder;

my $HOME = $ENV{"HOME"};
my $file = "$HOME/r06.htm";
unless(-e $file) 
{
	print "Error: $file not found\n";
	die;
}

my $tree = HTML::TreeBuilder->new();
$tree->parse_file($file);
#Do stuff w/ tree here
my ($HeadingText, $ReportType, $CreatedFor, $CreatedOn, $Count, $ReportExplanation);
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

#Get count 
my @ctl_tag = $tree->look_down(
	_tag => "td",
	class => "ctl_no",
);
$Count = $#ctl_tag+1;

$ReportExplanation = $tree->look_down(
	_tag => "div",
	class => "ReportExplanation",
);

#Get node of legend 
my $Legend = $tree->look_down(
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


#foreach (@ctl_tag)
#{
#	print $ctlno->as_text, "\n";
#}
#print $title->as_text, "\n";
#print $title->as_HTML, "\n";

#$tree->dump; #print a representation of the tree


$tree->delete;
