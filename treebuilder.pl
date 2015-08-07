#!/bin/env perl

use strict;
use warnings;
use File::Slurp;
use Encode;
use HTML::TreeBuilder;
use Config::Simple;

#parse config file
my $cfg_file = "/home/zrrm74/src/mars/mars.cfg";
my $cfg = new Config::Simple();			#Config::Simple object 
$cfg->read($cfg_file) or die $cfg->error();  	#Exception handling 

my %LCSH = (
	MU => $cfg->param('LCSH.MU'),
	MU_LAW => $cfg->param('LCSH.MU_LAW'),
	UMKC => $cfg->param('LCSH.UMKC'),
	UMKC_LAW => $cfg->param('LCSH.UMKC_LAW'),
	MST => $cfg->param('LCSH.MST'),
	UMSL => $cfg->param('LCSH.UMSL')
);

my %NTAR = (
	MU => $cfg->param('NTAR.MU'), 
	MU_HSL => $cfg->param('NTAR.MU_HSL'),
	MU_LAW => $cfg->param('NTAR.MU_LAW'),
	UMKC => $cfg->param('NTAR.UMKC'),
	UMKC_LAW => $cfg->param('NTAR.UMKC_LAW'),
	MST => $cfg->param('NTAR.MST'),
	UMSL => $cfg->param('NTAR.UMSL')
);

#my $HOME = $ENV{"HOME"};
#my $file = "$HOME/r06.htm";
#unless(-e $file) 
#{
#	print "Error: $file not found\n";
#	die;
#}

#Declare global variables
#Variables used to store text that's not associated with tables (headings, etc.) 
my ($HeadingText, $ReportType, $CreatedFor, $CreatedOn, $Count, $ReportExplanation, $Legend);
my @SectionSubHeading; 
#@tables stores each of the raw tables (separated by SectionSubHeading) 
my @tables;
my @thead;
#Get the tables out of the file and put them in @td(); 
#NOTE: td() is an array of hashes AoH
#Each hash has 4 keys that point to an array reference, which contains the column data for that table
my @td = ();
my $tree;
#Print header info in same format as XLS files
#printHeader();

split_line_reports("/home/zrrm74/extract/2015_08_07/School/LCSH", "LCSH");
#split_line_reports($REPORT_DIR, $HASH_NAME)
#param $REPORT_DIR: full path to directory containing reports 
#param $HASH_NAME: One of [LCSH/NTAR]. Used to specify the percentage split and the @ordered_keys list from the cfg file
sub split_line_reports
{
	my ($REPORT_DIR, $HASH_NAME) = @_;
	my @ordered_keys;
	if($HASH_NAME eq "LCSH")
	{
		@ordered_keys = $cfg->param("LCSH.ORDERED_KEYS");
	}
	elsif($HASH_NAME eq "NTAR")
	{
		@ordered_keys = $cfg->param("NTAR.ORDERED_KEYS");
	}
	my $PATH_TO_FILES = $REPORT_DIR;
	my @files = read_dir($PATH_TO_FILES);
	foreach my $file (@files)
	{
		@tables = ();
		@td = ();
		my $file_path = "$PATH_TO_FILES/$file";
		printf("Opening file %s\n", $file_path);
		parse_html($file_path);
		next if($#td < 0);
		#print $td[0]->{"CTL_NO"}->[0]->as_text, "\n";
		for(my $i=0; $i<=$#td; $i++) #For each table in the file 
		{
			my $hashref = $td[$i]; #Point the reference at the hash  
			my $ar_temp = $hashref->{"CTL_NO"};
			my $size = @{$ar_temp};
			print "File: $file_path\n";
			print "Number of records in td[$i] = $size\n";
			if(defined $SectionSubHeading[$i])
			{
				print $SectionSubHeading[$i]->as_text, "\n";
			}
			my %RPK = ();
			my $rpk_total=0;
			foreach my $key (@ordered_keys)
			{
				if($HASH_NAME eq "LCSH")
				{
					$RPK{$key} = int($size*($LCSH{$key}/100)); 
				}
				elsif($HASH_NAME eq "NTAR")
				{
					$RPK{$key} = int($size*($NTAR{$key}/100));

				}
				$rpk_total += $RPK{$key};
			}
			my $rec_difference = $size - $rpk_total;
			if($rec_difference > 0)
			{
				printf("Records to be written (%d) does not match records in file (%d) ", $rpk_total, $size);
				printf("Adding %d records to %s key\n", $rec_difference, $ordered_keys[$#ordered_keys]);
				#add any missing records to last key
				$RPK{$ordered_keys[$#ordered_keys]} += $rec_difference;
			}
			###START WRITING RECORDS###
			my $records_written_file = 0; 						#This variable is to keep track of the # records going to each school (per file) 
			my $rp = 0;		        				#variable to keep track of position in @records	
			foreach my $key (@ordered_keys)						#for each key in the NTAR hash
			{
				printf("Number of records required for $key is %d (%.2f%%) \n", $RPK{$key}, (($RPK{$key}/$size)*100));
				next if($RPK{$key} <= 0);				#don't create the file/write header if there are no records to be written	
				my $new_file_path = "$PATH_TO_FILES/../$key/$key.$file";	#prepend key to each filename
				#manually create filehandle -- set encoding
				my $header = printHeader(); 
				write_file($new_file_path, {binmode=> ':utf8'}, $header);
				if(defined $SectionSubHeading[$i])
				{
					my $ssh = join('', "\n", $SectionSubHeading[$i]->as_text, "\n"); 
					write_file($new_file_path, {binmode=> ':utf8', append=>1}, $ssh);
				}
				for(my $j=0; $j<$RPK{$key}; $j++)
				{
					if($rp >= $size)
					{
						print "Exceeded records array (Inner)\n";
						last;
					}
					my $ctl =  $td[$i]->{"CTL_NO"}->[$rp]->as_text;
					my $tag =  $td[$i]->{"TAG"}->[$rp]->as_text; 
					my $ind = $td[$i]->{"IND"}->[$rp]->as_text;
					my $fd =  $td[$i]->{"FIELDDATA"}->[$rp]->as_text;  
					my $row = $ctl;
					$row = join('|', $tag, $ind, $fd, "\n");
					append_file($new_file_path, {binmode=> ':utf8'}, $row);
					$rp++;
				}
			}
		}	
	}
}



#parse_html($file)
sub parse_html
{
	my $file = $_[0];
	#Manually create filehandle so we can specify the encoding, and pass it to HTML::TreeBuilder
	open(my $fh, '<:encoding(utf8)', $file) or die "Could not open '$file' $!\n";
	$tree = HTML::TreeBuilder->new();
	$tree->parse_file($fh);
	### Do stuff w/ tree here ###

	#Assign our global vars to nodes 
	tree_init();
	
	#store in td();
	get_tables();
	
	#Get the number of records (from all tables) in the file, store in global $Count
	get_total_count();
}


sub printHeader
{
	my $header;
	$header = join("\n", $HeadingText->as_text,$ReportType->as_text,$CreatedFor->as_text,$CreatedOn->as_text,$ReportExplanation->as_text);
	#if(defined $Legend)
	#{
#		$header = join("", $header, $Legend->as_HTML);
#	}
#
	#print $HeadingText->as_text, "\n";
	#print $ReportType->as_text, "\n";
	#print $CreatedFor->as_text, "\n";
	#print $CreatedOn->as_text, "\n";
	#print "Count: $Count\n";
	#print $ReportExplanation->as_text, "\n";
	return $header;
}

#getCount($arrayref)
#param $arrayref: reference to an array that contains the number of elements as that of the table
#return $count: scalar size of array (NOTE: NOT THE LAST INDEX)
sub getCount
{
	my $arrayref = $_[0];
	my $count = @{$arrayref};
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
	if(defined $Legend)
	{
		$Legend->detach;
	}

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
