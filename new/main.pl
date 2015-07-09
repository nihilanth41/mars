#!/bin/env perl

#use strict;
use warnings;
use Env qw(HOME);
#use IO::Uncompress::Unzip qw(unzip $UnzipError);

sub parse_config {
#local variables
local ($row, $Option, $Value, $Config);
($File, $Config) = @_;
#open cfg file
open(my $fp, $File)
	or die "Could not open file '$File': $!";
while( $row = <$fp>)				#For each line in file
{
	chomp $row;				#Remove trailing newline 
	$row =~ s/^\s*//;			#Remove spaces at the start of the line
	$row =~ s/\s*$//;			#Remove space(s) at the end of the line
	if(($row !~ /^#/) && ($row ne "")) 	#Ignore blank lines and lines starting with #
	{
		($Option, $Value) = split (/=/, $row);	#split each line into name/value pairs
		$$Config{$Option} = $Value;		#create hash of name/value pairs
	}
}
close($fp);
}

#Check for proper number of command line args (at least 1)
if($#ARGV < 0)
{
	print "Error: not enough arguments\n";
	printf("Usage is: %s <filename>.zip [config_file]\n", $0);
}

#config file is located at ~/.marsrc
my $cfg_file = "$HOME/.marsrc";
#hash containing config keys/values
my %Config = ();
#call parse_config()
&parse_config($cfg_file, \%Config);

foreach $Config_key (keys %Config) {
	print "$Config_key = $Config{$Config_key}\n"
}















