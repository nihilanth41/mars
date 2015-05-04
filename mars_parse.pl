#!/usr/local/bin/perl

=head1 NAME

mars_parse.pl

=head1 SYNOPSIS

B<mars_parse.pl> -d all

=head1 DESCRIPTION

B<mars_parse.pl>  
Utility for making the destination folders, deleting the destination folders, archiving the files, converting from html to pdf, breaking pdfs

=head1 OPTIONS

=over 4

=item B<-a> I<all>

Creates an archive of all the .pdf files and a master archive of all the .html files.

=item B<-b> I<all>

Breaks the pdfs and moves them to the appropriate folders.

=item B<-c> I<all>

Renames files to linux friendly.

=item B<-d> I<all>

Deletes all the following folders: MST, MU, MU_HSL, MU_LAW, UMKC, UMKC_LAW, UMLS, in the ~/mars folder.

=item B<-h>

Prints the man page, A shorter man page will appear if an incorrect number of arguments are entered.

=item B<-m> I<all>

Creates all the following folders: MST, MU, MU_HSL, MU_LAW, UMKC, UMKC_LAW, UMSL, in the ~/mars folder.

=back

=head1 REQUIRES

Getopt::Std, Pod::Usage 

=cut

use Getopt::Std;
use Pod::Usage;
#use warnings;

my $Opts;

if (@ARGV > 2) {
  pod2usage(  MSG=>'ERR: too many arguments (one at most).' , VERBOSE=>1);
} else {
  ParseArgs();
}

my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime(time);
my $datestamp = sprintf("%4d%02d%02d", $year+1900, $mon+1, $mday);

my $path = "/var2/mars/";
my @folders = ("MST","MU","MU_HSL","MU_LAW","UMKC","UMKC_LAW","UMSL");
my @folders_raw = ("LCSH","NTAR");
#my @folders_raw = ("MISC");

my %LCSH = ( 
  MU       => "42.4",
  MU_LAW     => "2.4",
  UMKC     => "26.4",
  UMKC_LAW   => "3.1",
  MST     => "7",
  UMSL     => "18.7"
);

my %NTAR = ( 
  MU      => "41.4",
  MU_HSL    => "2.4",
  MU_LAW    => "2.4",
  UMKC    => "25.7",
  UMKC_LAW  => "3",
  MST      => "6.9",
  UMSL    => "18.2"
);

# begin main routine

# call archive subroutine
if ($Opts{a} eq "all") {

  for my $folder (@folders) {
    chomp $folder;
    &mkArchive ($path, $folder);
  }

  for my $folder (@folders_raw) {
    chomp $folder;
    &mkArchive ($path, $folder);
  }

# call make directory subroutine
} elsif ($Opts{m} eq "all") {

  for my $folder (@folders) {
    chomp $folder;
    &mkDirs ($path, $folder);
    #print "$path, $folder\n";
  }

# call delete directory subroutine
} elsif ($Opts{d} eq "all") {

  for my $folder (@folders) {
    chomp $folder;
    &rmDirs ($path, $folder);
  }

#call the break pdf subroutine
} elsif ($Opts{b} eq "all") {

  for my $folder (@folders_raw) {
    chomp $folder;

    opendir(DIR, "$path$folder") || die ("Couldn't open $path$folder: $!");

  while(my $file = readdir(DIR)) {
      next if ($file !~ m/\.pdf/i);

      if ($folder eq "LCSH") {
        &breakPdf($path,$file,$folder,\%LCSH);
      } elsif ($folder eq "NTAR") {
        &breakPdf($path,$file,$folder,\%NTAR);
      } elsif ($folder eq "MESH") {
        print "cp $path$folder/$file $path"."MU_HSL/$file\n\n";

        print `cp $path$folder/$file /var2/mars/MU_HSL/$file`;
      } else {
        #print "MISC => $file\n";
      }
    }  
    closedir DIR;
  }
} elsif ($Opts{c} eq "all") { # rename routine
  for my $folder (@folders_raw) {
    chomp $folder;
    opendir(DIR , "$path$folder") || die ("Couldn't open $path$folder: $!");

    while(my $file = readdir(DIR)) {
      #next if ($file =~ m/^\./ || $file !~ m/\.htm/i);
      next if ($file =~ m/^\./);

      my $old_name = $file;

# remove all spaces and specials, rename files

      $file =~ s/new-//g;
      $file =~ s/ /-/g;
      $file =~ s/\[/-/g;
      $file =~ s/\]/-/g;
      $file =~ s/\(/-/g;
      $file =~ s/\)/-/g;
      $file =~ s/\$/-/g;
      $file =~ s/-\./\./g;
      $file =~ s/--/-/g;

      $file =~ m/(.*)\.htm/i;
      my $filename = $1;
      my $path_all = "$path$folder/";

      rename ("$path_all$old_name","$path_all$file") || die ("Couldn't rename $old_name:$!"); 
      print "$old_name\n $file\n\n";
      #&convertHtmlToPdf ($path_all,$file,$filename);
    }

    closedir DIR;
  }

# catchall subroutine
} else {
  pod2usage(VERBOSE=>1);
}

# begin subroutines
sub breakPdf {
  my ($path,$file,$folder,$hashref) = @_;
  my $page_count = &getPageCount("/var2/mars/$folder/$file");
  my $folder_count = keys(%$hashref);

  if ($page_count < 8) {
    print "cp $path$folder/$file $path"."MU/$file\n\n";
    print `cp $path$folder/$file /var2/mars/MU/$file`;
  } else {
    my $counter = 1;
    my $page_start = 1;
    my $page_end = 1;
    my $filename = $file;
    $filename =~ m/(.*)\.pdf/g;
    $filename = $1;

    while ( my ($key, $value) = each (%$hashref) ) {

      if ($counter == $folder_count) {
        print "pdftk $path$folder/$file cat $page_start-end output $path$folder/$filename.$page_start-end.pdf\n";
        print "mv $path$folder/$filename.$page_start-end.pdf $path$key/$filename.$page_start-end.pdf\n\n";

        print `pdftk $path$folder/$file cat $page_start-end output $path$folder/$filename.$page_start-end.pdf`;
        print `mv $path$folder/$filename.$page_start-end.pdf $path$key/$filename.$page_start-end.pdf`;
      } else {
        my $interval = int($value * .01 * $page_count);
        my $page_end = $interval + $page_start;

        print "pdftk $path$folder/$file cat $page_start-$page_end output $path$folder/$filename.$page_start-$page_end.pdf\n";
        print "mv $path$folder/$filename.$page_start-$page_end.pdf $path$key/$filename.$page_start-$page_end.pdf\n";

        print `pdftk $path$folder/$file cat $page_start-$page_end output $path$folder/$filename.$page_start-$page_end.pdf`;
        print `mv $path$folder/$filename.$page_start-$page_end.pdf $path$key/$filename.$page_start-$page_end.pdf`;

        $page_start = $page_end;
      }
      $counter++;
    }
  }
}

sub compressPdf {
  my ($file) = @_;
  my $out = `pdftk $file dump_data | grep NumberOfPages`;
  $out =~ m/numberofpages: (.*)/gi;
  return $1;
}

sub getPageCount {
  my ($file) = @_;
  my $out = `pdftk $file dump_data | grep NumberOfPages`;
  $out =~ m/numberofpages: (.*)/gi;
  return $1;
}

sub mkArchive {
  my ($path,$folder) = @_;
  print `zip -r $path$folder/$folder $path$folder`;
  print "Creating: $path$folder.zip\n";
}

sub ParseArgs {
  getopts('a:b:c:d:h:m:', \%Opts);
  $Opts{h} and
  pod2usage(VERBOSE=>1);
}

sub mkDirs {
  my ($path,$folder) = @_;
  print `mkdir $path$folder`;
  print "Creating: $path$folder\n";
}

sub rmDirs {
  my ($path,$folder) = @_;
  print `rm -Rf $path$folder`;
  print "Deleting: $path$folder\n";
}

