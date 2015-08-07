#!/bin/env perl

use strict;
use warnings;
use LWP::Simple;

my $URL = 'http://ac.bslw.com/ftpdir/mars_download/ZM@/Curcat/';
my $content = get $URL;
die "Couldn't get $URL" unless defined $content;
while($content =~ m/<a href=\"(.*?)\"/g ) {
	print "$1\n";
}
