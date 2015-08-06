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
my ($HeadingText) = $tree->look_down( 
	_tag => "div",
	id => "HeadingText",
);

my ($ReportType) = $tree->look_down(
	_tag => "div", 
	id => "ReportType",
);

my @CreatedInfo = $tree->look_down(
	_tag => "div",
	class => "CreatedInfo",
);

my $CreatedFor = $CreatedInfo[0];
my $CreatedOn = $CreatedInfo[1];

print $HeadingText->as_text, "\n";
print $ReportType->as_text, "\n";
print $CreatedFor->as_text, "\n";
print $CreatedOn->as_text, "\n";

my @ctl_tag = $tree->look_down(
	_tag => "td",
	class => "ctl_no",
);

#foreach (@ctl_tag)
#{
#	print $ctlno->as_text, "\n";
#}
#print $title->as_text, "\n";
#print $title->as_HTML, "\n";

#$tree->dump; #print a representation of the tree


$tree->delete;
