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
my ($title) = $tree->look_down( '_tag' , 'title' );

print $title->as_text, "\n";
print $title->as_HTML, "\n";

#$tree->dump; #print a representation of the tree


$tree->delete;
