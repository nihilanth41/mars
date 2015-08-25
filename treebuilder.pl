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
use HTML::Restrict;
use HTML::Entities;
use Cwd 'abs_path';
use 5.10.1;

#get current date/time for timestamps 
my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime(time);
my $datestamp = sprintf("%4d_%02d_%02d", $year+1900, $mon+1, $mday);

#parse config file
my $ABS_PATH = dirname( abs_path($0) );
my $cfg_file = "$ABS_PATH/mars.cfg"; 
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

my $report_dir = $cfg->param('ENV.REPORT_DIR');

split_line_reports("$report_dir/$datestamp/School/LCSH", "LCSH");
split_line_reports("$report_dir/$datestamp/School/NTAR", "NTAR");

split_line_reports_CSV("$report_dir/$datestamp/School/LCSH", "LCSH");
split_line_reports_CSV("$report_dir/$datestamp/School/NTAR", "NTAR");

csv_to_xls("$report_dir/$datestamp/School/LCSH/CSV");
csv_to_xls("$report_dir/$datestamp/School/NTAR/CSV");

#split_line_reports($REPORT_DIR, $HASH_NAME)
#param $REPORT_DIR: full path to directory containing reports 
#param $HASH_NAME: One of [LCSH/NTAR]. Used to specify the percentage split and the @ordered_keys list from the cfg file
sub split_line_reports
{
	my ($REPORT_DIR, $HASH_NAME) = @_;
	my @ordered_keys;
	my $href;
	if($HASH_NAME eq "LCSH") {
		@ordered_keys = $cfg->param("LCSH.ORDERED_KEYS");
		$href = \%LCSH;
	}
	elsif($HASH_NAME eq "NTAR") {
		@ordered_keys = $cfg->param("NTAR.ORDERED_KEYS");
		$href = \%NTAR;
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
				$RPK{$key} = int($size*($href->{$key}/100));
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
	open(my $fh, '<:encoding(UTF-8)', $file) or die "Could not open '$file' $!\n";
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
	my $href;
	if($HASH_NAME eq "LCSH") {
		@ordered_keys = $cfg->param("LCSH.ORDERED_KEYS");
		$href = \%LCSH;
	}
	elsif($HASH_NAME eq "NTAR") {
		@ordered_keys = $cfg->param("NTAR.ORDERED_KEYS");
		$href = \%NTAR;
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
		#Records per file (new file) for calculating the number of reocrds (Count) for each split file
		my %RPF = ();
		foreach(@ordered_keys)
		{
			$RPF{$_} = 0;
		}
		#loop once to get the number of records to be written for each file	
		for(my $i=0; $i<=$#td; $i++)
		{

			my $hashref = $td[$i]; #Point the reference at the hash  
			my $ar_temp = $hashref->{"CTL_NO"};
			my $size = @{$ar_temp};
			my %RPK = ();
			my $rpk_total=0;
			foreach my $key (@ordered_keys)
			{
				$RPK{$key} = int($size*($href->{$key}/100)); 
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
			#Populate RPF hash
			foreach my $key (@ordered_keys)
			{
				$RPF{$key} += $RPK{$key};
			}
		}
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
				$RPK{$key} = int($size*($href->{$key}/100));
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
				my $header = printHeader_CSV($RPF{$key}); 
				unless(-e $new_file_path)
				{
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
					my $fd =  $td[$i]->{"FIELDDATA"}->[$rp]->as_HTML; 
					my $hr = HTML::Restrict->new(
						rules => {
							span => [qw(class)],
							wbr => [],
							b => [],
						}
					);	
					my $processed = $hr->process( $fd ); 
					##Remove span tags w/ submark but keep content
					$processed =~ s{<span class="submark">(.*?)</span>}{$1}gi;
					$processed = decode_entities($processed);
					$fd = "\"$processed\"";
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

#printHeader_CSV($record_count)
sub printHeader_CSV
{
	my $record_count = $_[0];
	my @tmp = split(':', $HeadingText->as_text);
	$tmp[1] =~ s/^\s+//; #Remove leading white space from left side of string 
	my $head = join('|||', "\"$tmp[0]\"", "\"$tmp[1]\""); #Join the header with '|||' as the delimiter and each string in double quotes " "
	
	@tmp = split(':', $ReportType->as_text);
	$tmp[1] =~ s/^\s+//; #Remove whitespace from left side 
	my $type = join('|||', "\"$tmp[0]:\"", "\"$tmp[1]\"");

	my $cft = $CreatedFor->as_text;
	my $cf = "\"Created For:\"|||\"$cft\"";

	my $cot = $CreatedOn->as_text;
	my $co = "\"Created On:\"|||\"$cot\"";

	#Original file count:
	#my $ct = "Count:|||$Count";
	#Count for new file:
	my $ct = "Count:|||$record_count";

	my $header = join("\n", $head, $type, $cf, $co, $ct);
	
	my $re_txt = $ReportExplanation->as_text;
	my $re = "\"$re_txt\"|||";
	$header = join("\n", $header, '|||', $re, '|||');
	$header = join("\n", $header, "\"Control No\"|Tag|Ind|\"Field Data\"\n");
	return $header;
}

#csv_to_xls($PATH_TO_FILES)
sub csv_to_xls {
	my $csv = Text::CSV->new({
			binary => 1,
			auto_diag => 1,
			sep_char => '|',
			quote_char => undef,
			escape_char => undef,
		});

	my $PATH_TO_FILES = $_[0];
	my @files = read_dir($PATH_TO_FILES);
	foreach my $file (@files)
	{
		my @controlno;
		my @tag;
		my @ind;
		my @fielddata;
		#Parse CSV File
		my $fpath = "$PATH_TO_FILES/$file";
		open(my $fh, '<encoding(UTF-8)', $fpath) or die "Could not open '$fpath' $!\n";
		while(my $line = <$fh>)
		{
			chomp $line;
			if($csv->parse($line))
			{
				my @fields = $csv->fields();
				push @controlno, $fields[0];
				push @tag, $fields[1];
				push @ind, $fields[2];
				push @fielddata, $fields[3];
			}
			else
			{
				warn "Line could not be parsed: $line\n";
			}
		}
		$csv->eof or $csv->error_diag();
		close $fh;
		
		#Begin writing excel file
		my @fname = split(/\./, $file);
		my $key = $fname[0];
		my $name = $fname[1].".xls"; 
		my $output_file = "$PATH_TO_FILES/../../$key/$key.$name";
		#open($fh, '>:encoding(UTF-8)', $output_file) or die "Could not open '$file' $!\n";
		#print "XLS Output file $output_file\n";
		my $workbook = Spreadsheet::WriteExcel->new($output_file);
		#Configure cell format
		my $fmt_red = $workbook->add_format(
			align => 'left',
			color => 10,
		);
		my $fmt_green = $workbook->add_format(
			align => 'left',
			color => 17,
		);
		my $fmt_brown = $workbook->add_format(
			align => 'left',
			color => 16,
		);
		my $fmt_bold = $workbook->add_format(
			align => 'left',
			color => 8,
			bold => 1,
		);
		my $fmt_subject = $workbook->add_format(
			align => 'left',
			color => 'blue',
			bold => 1,
		);
		my $fmt_headerb = $workbook->add_format(
			align => 'left',
			color => 'black',
			bold => 1,
		);
		my $fmt_headeri = $workbook->add_format(
			align => 'left',
			color => 'black',
			italic => 1,
		);
		my $fmt_header = $workbook->add_format(
			align => 'center',
			valign => 'top',
			text_wrap => 1,
			color => 'black',
			bold => 0,
		);
		my $format = $workbook->add_format(
			align => 'left',
			color => 8,
		);
		
		#Create worksheet
		my $worksheet = $workbook->add_worksheet();                       	                                                             
		#The following widths are taken from the existing XLS files       	
		$worksheet->keep_leading_zeros(1);
		$worksheet->set_column(0, 0, 15); 	#Column A width set to 15	
		$worksheet->set_column(1, 1, 8.43);	#Column B width set to 8.43	
		$worksheet->set_column(2, 2, 8.43);	#Column C wdith set to 8.43	
		$worksheet->set_column(3, 3, 75);       #Column D width set to 75 
		$worksheet->set_column(4, 4, 25);	#Column E width set to 25
		$worksheet->set_column(5, 5, 25);       #Column F width set to 25
		$worksheet->set_column(6, 6, 25);	#Column G width set to 25
		$worksheet->set_row(6, 75);		#Row 8 height set to 75
		$worksheet->freeze_panes(9, 0); 	#Freeze panes 0-9
		
		my $B;
		my $C;
		#Write A1
		my $A1 = shift @controlno;
		$A1 =~ s/^"(.*)"$/$1/;
		$B = shift @tag;
		$C = shift @ind;
		#merge_range(first_row, first_col, last_row, last_col, token, format, ...)
		$worksheet->merge_range(0, 0, 0, 2, $A1, $fmt_headerb);
		#Write D1
		my $D1 = shift @fielddata;
		$D1 =~ s/^"(.*)"$/$1/;
		$worksheet->write_string(0, 3, $D1, $format);
		#Write A2
		my $A2 = shift @controlno;
		$A2 =~ s/^"(.*)"$/$1/;
		$B = shift @tag;
		$C = shift @ind;
		$worksheet->merge_range(1, 0, 1, 2, $A2, $fmt_headeri);
		#Write D2
		my $D2 = shift @fielddata;
		$D2 =~ s/^"(.*)"$/$1/;
		$worksheet->write_string(1, 3, $D2, $format);
		#Write A3	
		my $A3 = shift @controlno;
		$A3 =~ s/^"(.*)"$/$1/;
		$B = shift @tag;
		$C = shift @ind;
		$worksheet->merge_range(2, 0, 2, 2, $A3, $fmt_headeri);
		##Write D3
		my $D3 = shift @fielddata;
		$D3 =~ s/^"(.*)"$/$1/;
		$worksheet->write_string(2, 3, $D3, $format);
		#Write A4
		my $A4 = shift @controlno;
		$A4 =~ s/^"(.*)"$/$1/;
		$B = shift @tag;
		$C = shift @ind;
		$worksheet->merge_range(3, 0, 3, 2, $A4, $fmt_headeri);
		##Write D4
		my $D4 = shift @fielddata;
		$D4 =~ s/^"(.*)""?/$1/;
		$worksheet->write_string(3, 3, $D4, $format);
		##Write A5
		my $A5 = shift @controlno;
		$B = shift @tag;
		$C = shift @ind;
		$worksheet->merge_range(4, 0, 4, 2, $A5, $fmt_headeri);
		##Write D5
		my $D5 = shift @fielddata;
		$worksheet->write_string(4, 3, $D5, $format);
		#Write A6
		my $A6 = shift @controlno;
		$B = shift @tag;
		$C = shift @ind;
		$worksheet->merge_range(5, 0, 5, 3, undef, $fmt_headeri); #Use format that is used with merge_range
		##Write D6
		my $D6 = shift @fielddata;
		#$worksheet->write_string(5, 3, $D6, $format);
		#Write A7
		my $A7 = shift @controlno;
		$A7 =~ s/^"(.*)"$/$1/;
		$B = shift @tag;
		$C = shift @ind;
		$worksheet->merge_range(6, 0, 6, 7, $A7, $fmt_header);
		##Write D7
		my $D7 = shift @fielddata;
		##Ignore $D7
		##Write A8
		my $A8 = shift @controlno;
		$B = shift @tag;
		$C = shift @ind;
		$worksheet->merge_range(7, 0, 7, 3, undef, $fmt_headeri);
		##Write D8
		my $D8 = shift @fielddata;
		#$worksheet->write_string(7, 3, $D8, $format);
		#Write A9-D9
		##A9
		my $A9 = shift @controlno;
		$A9 =~ s/^"(.*)"$/$1/;
		$worksheet->write_string(8, 0, $A9, $fmt_bold);
		##B9
		$B = shift @tag;
		$worksheet->write_string(8, 1, $B, $fmt_bold);
		#C9
		$C = shift @ind;
		$worksheet->write_string(8, 2, $C, $fmt_bold);
		#D9
		my $D9 = shift @fielddata;
		$D9 =~ s/^"(.*)"$/$1/;
		$worksheet->write_string(8, 3, $D9, $fmt_bold);
		### End writing Header ##
	
		my $num_rows = $#controlno+1;
		#For each row in the file
		for(my $i=0; $i<$num_rows; $i++)
		{
			#Write SectionSubHeading in Blue Bold
			if($controlno[$i] =~ m/Subject /) {
				#$worksheet->write_string($i, 0, $controlno[$i], $fmt_subject);
				##NOTE: Should only use $fmt_subject w/ merge_range() ##
				$worksheet->merge_range($i+9, 0, $i+9, 3, $controlno[$i], $fmt_subject);
			}
			else {	
				$worksheet->write_string($i+9, 0, $controlno[$i], $format); 
			}
			#Write tag and ind columns
			$worksheet->write_string($i+9, 1, $tag[$i], $format);
			$worksheet->write_string($i+9, 2, $ind[$i], $format);

			#Remove double quotes from beginning and end:
			$fielddata[$i] =~ s/^"(.*)"$/$1/;
			#Insert space after $submark in fielddata column
			$fielddata[$i] =~ s/(?<=[a-z])(?=[A-Z0-9\$])/ /g;
			#Split fielddata string on <wbr> tag
			my @fd = split('<wbr \/>', $fielddata[$i]);
			
			#If there's no <wbr> tag then $fd[0] is the whole string
			
			my @columns = ();
			my @classes = ();
			#First submark is always bold
			my $first = shift @fd;
			#Check for bold tags & remove if found 
			if(defined $first)
			{	if($first =~ /<b>/)
				{
					$first =~ s{<b>(.*?)</b>}{$1}gi;
					$columns[0] = $first;
					$classes[0] = "bold";

				}
				else
				{
					$columns[0] = $first;
					$classes[0] = "none";
				}
			}
			my $col=1;
			#foreach string in split fielddata
			for my $j (0..$#fd)
			{
				my $class;
				my $content;
				my $str = $fd[$j];
				###################################
				#If the string has a class attribute
				if($str =~ /class/) 
				{
					$str =~ /"(.+?)"/;
					if(defined $1)
					{
						$class = $1;
					}
					$str =~ />(.+?)<\/span>/;
					if(defined $1)
					{
						$content = $1;
					}
				}
				elsif ($str =~ /<b>/)
				{
					$class = "bold";
					#Remove bold tag 
					$str =~ s{<b>(.*?)</b>}{$1}gi;
					$content = $str;
				}
				else
				{
					#No bold or class attr
					$class = "none";
					$content = $str;
				}
				##################################
				#If previous class eq current class 
				if($classes[$col-1] eq $class) {
					#Join current string w/ previous string
					$columns[$col-1] = join(' ', $columns[$col-1], $content);
				}
				else {
					#Put current string in class into current column
					$columns[$col] = $content;
					$classes[$col] = $class; 
					#Iterate column
					$col++;
				}
			}#endfor $j (each string in fielddata split)
			####( Strings should be in their proper column, write to XLS: ) ###
			for my $k (0..$#columns)
			{
				my $content = $columns[$k];
				my $class = $classes[$k];
				if($class eq "bold") {
					$worksheet->write_string($i+9, 3+$k, $content, $fmt_bold);
				}
				elsif($class eq "valid") {
					$worksheet->write_string($i+9, 3+$k, $content, $fmt_green);
				}
				elsif($class eq "invalid") {
					$worksheet->write_string($i+9, 3+$k, $content, $fmt_red);
				}
				elsif($class eq "partly_valid") {
					$worksheet->write_string($i+9, 3+$k, $content, $fmt_brown);
				}
				elsif($class eq "none") {
					$worksheet->write_string($i+9, 3+$k, $content, $format);
				}
				else {
					print "Warning: no text class attribute identified\n";
					$worksheet->write_string($i+9, 3+$k, $content, $format);
				}
			}
		}#foreach $row 
		$workbook->close();
	}#foreach file
}#endsub





