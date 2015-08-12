#!/bin/env perl

use strict;
use warnings;
use File::Slurp;
use File::Basename;
use Encode qw(encode decode);
use HTML::TreeBuilder;
use Config::Simple;
use Spreadsheet::WriteExcel;
use Text::CSV;
use 5.10.1;

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


#Declare global variables
#Variables used to store text that's not associated with tables (headings, etc.) 
my ($Meta, $HeadingText, $ReportType, $ReportName, $CreatedFor, $CreatedOn, $Count, $ReportExplanation, $Legend, $Script);
my @Style; 
my @SectionSubHeading; 
#@tables stores each of the raw tables (separated by SectionSubHeading) 
my @tables;
my @thead;

#Get the tables out of the file and put them in @td(); 
#NOTE: td() is an array of hashes AoH
#Each hash has 4 keys that point to an array reference, which contains the column data for that table
my @td = ();
my $tree;

#split_line_reports("/home/zrrm74/extract/2015_08_12/School/LCSH", "LCSH");
#split_line_reports("/home/zrrm74/extract/2015_08_12/School/NTAR", "NTAR");

split_line_reports_CSV("/home/zrrm74/extract/2015_08_12/School/LCSH", "LCSH");
split_line_reports_CSV("/home/zrrm74/extract/2015_08_12/School/NTAR", "NTAR");

csv_to_xls("/home/zrrm74/extract/2015_08_12/School/LCSH/CSV");
csv_to_xls("/home/zrrm74/extract/2015_08_12/School/NTAR/CSV");

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
		for(my $i=0; $i<=$#td; $i++) #For each table in the file 
		{
			my $hashref = $td[$i]; #Point the reference at the hash  
			my $ar_temp = $hashref->{"CTL_NO"};
			my $size = @{$ar_temp};
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
			my $rp = 0;		        				#variable to keep track of position in @records	
			foreach my $key (@ordered_keys)						#for each key in the NTAR hash
			{
				printf("Number of records required for $key is %d (%.2f%%) \n", $RPK{$key}, (($RPK{$key}/$size)*100));
				next if($RPK{$key} <= 0);				#don't create the file/write header if there are no records to be written	
				my $new_file_path = "$PATH_TO_FILES/../$key/$key.$file";	#prepend key to each filename
				my $header = printHeader_HTML(); 
				unless(-e $new_file_path)
				{
					#write_file($new_file_path, {binmode=> ':utf8'}, $header);
					#Auto encoding on write 
					open(my $fh, '>:encoding(UTF-8)', $new_file_path) || die "Couldn't open file for write $new_file_path: $!";
					#	if($FILETYPE eq 'HTML')
						print $fh $header;
						close $fh;
				}
				

				#Open file for append 
				open(my $fh, '>>:encoding(UTF-8)', $new_file_path) || die "Couldn't open file for write $new_file_path: $!";
				if(defined $SectionSubHeading[$i])
				{
					my $ssh = join('', "\n", $SectionSubHeading[$i]->as_HTML, "\n");
					#write_file($new_file_path, {binmode=> ':utf8', append=>1}, $ssh);
					my $h = join("\n", '<div class=\'table-outer-container\'>', '<div class=\'table-container\'>', '<table>');
					$ssh = join("\n", $ssh, $h, $thead[$i]->as_HTML);
					print $fh $ssh;
				}
				for(my $j=0; $j<$RPK{$key}; $j++)
				{
					if($rp >= $size)
					{
						print "Exceeded records array (Inner)\n";
						last;
					}
					#Write HTML
					my $ctl =  $td[$i]->{"CTL_NO"}->[$rp]->as_HTML;
					my $tag =  $td[$i]->{"TAG"}->[$rp]->as_HTML; 
					my $ind = $td[$i]->{"IND"}->[$rp]->as_HTML;
					my $fd =  $td[$i]->{"FIELDDATA"}->[$rp]->as_HTML;  
					my $row = join("\n", "\n\<tr\>", $ctl, $tag, $ind, $fd, '</tr>' );
					#append_file($new_file_path, {binmode=> ':utf8'}, $row);
					print $fh $row;
					
					#Write XLS

					$rp++;
				}
				print $fh '</table></div></div>';
				print $fh $Script->as_HTML;
				close $fh;
			}#foreach key 
		}#foreach td()	
		#print `rm -v $file_path`;
	}#foreach $file 
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


sub printHeader_HTML
{
	my $head = "<html>\n<head>";	
	$Meta = '<meta http-equiv=\'Content-Type\' content=\'text/html; charset=UTF-8\'/>';
	my $title = join('', '<title>', $ReportName->as_text, '</title>');
	my $header = join("\n", $head, $Meta, $title, $Style[0]->as_HTML, $Style[1]->as_HTML, '</head>');
	$header = join("\n", $header, '<body>', '<div id=\'container\'>', '<div id=\'Heading\' class=\'clearfix\'>');
	$header = join("\n", $header, $HeadingText->as_HTML, $ReportType->as_HTML);
	$header = join("\n", $header, '<div id=\'Created\'><div class=\'CreatedLabel\'>Created for: </div>', $CreatedFor->as_HTML, '</div>');
	$header = join("\n", $header, '<div id=\'CreatedRight\'><div class=\'CreatedLabel\'>Created on: </div>', $CreatedOn->as_HTML,'</div></div>');
	$header = join("\n", $header, $ReportExplanation->as_HTML);
	if(defined $Legend)
	{
		$header = join("\n", $header, $Legend->as_HTML);
	}
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
	$Count = 0;
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

	#Get style tags 
	@Style = $tree->look_down(
		_tag => "style"
	);

	($Script) = $tree->look_down(
		_tag => "script"
	);

	($ReportName) = $tree->look_down(
		_tag => "span",
		id => "ReportName",
	);

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
		$th->detach;
	}

	#Get SectionSubHeading and store -- Index of correct heading will be same as the index of the table 
	@SectionSubHeading = $tree->look_down(
		_tag => "div",
		class => "SectionSubHeading",
	);
}

sub split_line_reports_CSV
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
		for(my $i=0; $i<=$#td; $i++) #For each table in the file 
		{
			my $hashref = $td[$i]; #Point the reference at the hash  
			my $ar_temp = $hashref->{"CTL_NO"};
			my $size = @{$ar_temp};
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
			my $rp = 0;		        				#variable to keep track of position in @records	
			foreach my $key (@ordered_keys)						#for each key in the NTAR hash
			{
				printf("Number of records required for $key is %d (%.2f%%) \n", $RPK{$key}, (($RPK{$key}/$size)*100));
				next if($RPK{$key} <= 0);				#don't create the file/write header if there are no records to be written	
				my ($filename, $dirs, $suffix) = fileparse($file_path); 
				my $CSV_DIR = "$dirs"."CSV";
				unless(-d $CSV_DIR)
				{
					print `mkdir -v $CSV_DIR`;
				}
				my @CSV_FILE = split("htm", $filename); 
				$CSV_FILE[0] = join('', $CSV_FILE[0], "csv");
				my $csvf = $CSV_FILE[0];
				#my $new_file_path = "$PATH_TO_FILES/../$key/$key.$filename.csv"; #prepend key to each filename
				my $new_file_path = "$CSV_DIR/$key.$csvf";
				my $header = printHeader_CSV(); 
				unless(-e $new_file_path)
				{
					#write_file($new_file_path, {binmode=> ':utf8'}, $header);
					#Auto encoding on write 
					open(my $fh, '>:encoding(UTF-8)', $new_file_path) || die "Couldn't open file for write $new_file_path: $!";
					#	if($FILETYPE eq 'HTML')
						print $fh $header;
						close $fh;
				}
				

				#Open file for append 
				open(my $fh, '>>:encoding(UTF-8)', $new_file_path) || die "Couldn't open file for write $new_file_path: $!";
				if(defined $SectionSubHeading[$i])
				{
					my $ssh = join('', $SectionSubHeading[$i]->as_text, '|||', "\n");
					print $fh $ssh;
				}
				for(my $j=0; $j<$RPK{$key}; $j++)
				{
					if($rp >= $size)
					{
						print "Exceeded records array (Inner)\n";
						last;
					}
					#Write CSV
					my $ctl =  $td[$i]->{"CTL_NO"}->[$rp]->as_text;
					my $tag =  $td[$i]->{"TAG"}->[$rp]->as_text; 
					my $ind = $td[$i]->{"IND"}->[$rp]->as_text;
					$ind =~ s/^\s+|\s+$//g; #Remove whitespace from both sides
					my $fd =  $td[$i]->{"FIELDDATA"}->[$rp]->as_text; 
					$fd = "\"$fd\"";
					my $row = join("|", $ctl, $tag, $ind, $fd);
					print $fh $row;
					print $fh "\n";
					$rp++;
				}
				close $fh;
			}#foreach key 
		}#foreach td()	
		print `rm -v $file_path`;
	}#foreach $file 
}


sub printHeader_CSV
{	my @tmp = split(':', $HeadingText->as_text);
	$tmp[1] =~ s/^\s+//; #Remove leading white space from left side of string 
	my $head = join('|||', "\"$tmp[0]\"", "\"$tmp[1]\""); #Join the header with '|||' as the delimiter and each string in double quotes " "
	
	@tmp = split(':', $ReportType->as_text);
	$tmp[1] =~ s/^\s+//; #Remove whitespace from left side 
	my $type = join('|||', "\"$tmp[0]:\"", "\"$tmp[1]\"");

	my $cft = $CreatedFor->as_text;
	my $cf = "\"Created For:\"|||\"$cft\"";

	my $cot = $CreatedOn->as_text;
	my $co = "\"Created On:\"|||\"$cot\"";

	my $ct = "Count:|||$Count";

	my $header = join("\n", $head, $type, $cf, $co, $ct);
	
	my $re_txt = $ReportExplanation->as_text;
	my $re = "\"$re_txt\"|||";
	$header = join("\n", $header, '|||', $re, '|||');
	$header = join("\n", $header, "\"Control No\"|Tag|Ind|\"Field Data\"\n");
	return $header;
}

#csv_to_xls($PATH_TO_FILES)
sub csv_to_xls {
	my $PATH_TO_FILES = $_[0];
	my @files = read_dir($PATH_TO_FILES);
	foreach my $file (@files)
	{
		my @fname = split(/\./, $file);
		my $key = $fname[0];
		my $name = $fname[1].".xls"; 
		my $output_file = "$PATH_TO_FILES/../../$key/$name";
		print "XLS Output file $output_file\n";
		#my $workbook = Spreadsheet::WriteExcel->new($output_file);
	}
}
	#
	##Configure cell format
	#my $format = $workbook->add_format();
	#$format->set_align('left');
	#
	##Create worksheet
	#my $worksheet = $workbook->add_worksheet();
	#
	##The following widths are taken from the existing XLS files
	#$worksheet->keep_leading_zeros(1);
	#$worksheet->set_column(0, 0, 15); 	#Column A width set to 15
	#$worksheet->set_column(1, 1, 8.43);	#Column B width set to 8.43
	#$worksheet->set_column(2, 2, 8.43);	#Column C wdith set to 8.43
	#$worksheet->set_column(3, 3, 75);       #Column D width set to 75
	#for(my $i=0; $i<$num; $i++)
	#{
	#	$worksheet->write_string($i, 0, $controlno[$i], $format);
	#	$worksheet->write_string($i, 1, $tag[$i], $format);
	#	$worksheet->write_string($i, 2, $ind[$i], $format);
	#	$worksheet->write_string($i, 3, $fielddata[$i], $format);
	#}
	#
	#$workbook->close();
	#
