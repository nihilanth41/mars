#!/bin/env perl 
# Testing Config::Simple 

use strict;
use warnings;
use Config::Simple;

my $cfg_file = "simple.cfg";
my %cfg_hash = ();

Config::Simple->import_from($cfg_file, \%cfg_hash); 

for my $key (keys %cfg_hash)
{
	#print $key=$value
	print "$key=$cfg_hash{$key}\n";
}


