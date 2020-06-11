#!/usr/bin/perl -w

#------------------------------------------------------------------------------
# Name       : scrape_author_info.pl
# Author     : Stuart Pineo  <svpineo@gmail.com>
# Usage:     : $0 --config <absolute or relative path to config file> --authors-file <file with list of authors (one per line)> 
#              [ --debug --verbose ] > output_file
# Description: This script takes a list of authors and a site-specific config file and scrapes addition author information.
#              This additional information being scraped includes birth date, death date, title (or short description), and bio url.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# Copyright (c) 2020 Stuart Pineo
#
#------------------------------------------------------------------------------

use strict;
use warnings;

# Include the /bin path in the PATH var
# Use relative path below or export PERL5LIB var to include the /lib path
#
# Example:
# export PATH=/home/svpineo/perl-scripts/bin:$PATH
# export PERL5LIB=/home/svpineo/perl-scripts/lib
#
# If needed, handle SSL gets:
# export PERL_LWP_SSL_VERIFY_HOSTNAME=0
#
use lib qw(../../lib);

use Getopt::Long;
use Carp qw(croak carp);
use Data::Dumper;

#use LWP::Simple;
use LWP::UserAgent;
use Cwd qw(cwd);

# These found in ../lib
#
use Util::GenericUtils qw(trim trim_all);

# Global variables
#
our $COMMAND = `basename $0`;
chomp($COMMAND);

our $VERSION = "1.0";

# Generic variables
#
our $VERBOSE = 0;
our $DEBUG   = 0;

our ($CONFIG, $AUTHORS_FILE);

use Getopt::Long;
GetOptions(
    'config=s'        => \$CONFIG,
    'authors-file=s'  => \$AUTHORS_FILE,
    'debug'           => \$DEBUG,
    'verbose'         => \$VERBOSE,
    'help|usage'      => \&usage,
);

# Verify the authors file
#
! $AUTHORS_FILE and usage("--authors-file must be set.");
! -f $AUTHORS_FILE and usage("File '$AUTHORS_FILE' not found or is not readable.");


# Parse the configuration file
#
! $CONFIG and usage("--config must be set.");
! -f $CONFIG and usage("File '$CONFIG' not found or is not readable.");

my $ref = &parseConfig($CONFIG);
$DEBUG and print STDERR Data::Dumper->Dump([$ref]);

# Mandatory fields
#
our $URL            = defined($ref->{'URL'})            ? $ref->{'URL'}            : die("The 'URL' key is missing (or not defined) in the config file.");
our $DELIM          = defined($ref->{'DELIM'})          ? $ref->{'DELIM'}          : die("The 'DELIM' key is missing (or not defined) in the config file.");
our $BIRTH_DAY_OPEN = defined($ref->{'BIRTH_DAY_OPEN'}) ? $ref->{'BIRTH_DAY_OPEN'} : die("The 'BIRTH_DAY_OPEN' key is missing (or not defined) in the config file.");
our $BIRTH_DAY_TEXT = defined($ref->{'BIRTH_DAY_TEXT'}) ? $ref->{'BIRTH_DAY_TEXT'} : die("The 'BIRTH_DAY_TEXT' key is missing (or not defined) in the config file.");
our $DEATH_DAY_OPEN = defined($ref->{'DEATH_DAY_OPEN'}) ? $ref->{'DEATH_DAY_OPEN'} : die("The 'DEATH_DAY_OPEN' key is missing (or not defined) in the config file.");
our $DEATH_DAY_TEXT = defined($ref->{'DEATH_DAY_TEXT'}) ? $ref->{'DEATH_DAY_TEXT'} : die("The 'DEATH_DAY_TEXT' key is missing (or not defined) in the config file.");
our $TITLE_OPEN     = defined($ref->{'TITLE_OPEN'})     ? $ref->{'TITLE_OPEN'}     : die("The 'TITLE_OPEN' key is missing (or not defined) in the config file.");
our $TITLE_TEXT     = defined($ref->{'TITLE_TEXT'})     ? $ref->{'TITLE_TEXT'}     : die("The 'TITLE_TEXT' key is missing (or not defined) in the config file.");

# Optional fields
#
our ($SUBS_PAT_1, $SUBS_PAT_2);
$ref->{'URL_SUBSTITUTE'} and ($SUBS_PAT_1, $SUBS_PAT_2) = split /:/, $ref->{'URL_SUBSTITUTE'};

# Retrieve all installations from root
#
my $ua = LWP::UserAgent->new();


# Open the authors file
#
open AUTHORS, $AUTHORS_FILE or die("Unable to open file '$AUTHORS_FILE' for reading: $!");
while(<AUTHORS>) {
    chomp;

    my $url = $URL;
    $url =~ s/<NAME>/$_/;
    ($SUBS_PAT_1 and $SUBS_PAT_2) and $url =~ s/$SUBS_PAT_1/$SUBS_PAT_2/g;

    &outputContent($url);
}
close AUTHORS;


sub outputContent {
    my $url = shift;

    my $req = new HTTP::Request GET => $url;
    my $res = $ua->request($req);
    my $info_page = $res->content;

    die("Unable to retrieve content from '$url'") unless $info_page;

    my @lines = split(/\n/, $info_page);
    my $bdaytext  = '';
    my $ddaytext  = '';
    my $titletext = '';
    foreach my $line (@lines) {
        if ($line =~ m/$BIRTH_DAY_OPEN($BIRTH_DAY_TEXT)/) {
            $bdaytext = &cleanup($1);
        }

        if ($line =~ m/$DEATH_DAY_OPEN($DEATH_DAY_TEXT)/) {
            $ddaytext = &cleanup($1);
        }

        if ($line =~ m/$TITLE_OPEN($TITLE_TEXT)/) {
            $titletext = &cleanup($1);
        }
    }
	print STDOUT qq|$bdaytext$DELIM$ddaytext$DELIM$titletext$DELIM$url\n|;
}

#------------------------------------------------------------------------------
# parseConfig: Parse the configuration file, return a nested reference structure
#------------------------------------------------------------------------------

sub parseConfig {
    my $config = shift;

    my $ref = {};

    open(CONFIG, $config) or die("Unable to open file '$config' for reading: $!");
    while(<CONFIG>) {

        # Skip lines starting with comments
        #
        next if m/^#/;

        # Skip empty lines
        #
        next if m/^\s*$/;

        chomp;

        # Remove potentially trailing comments
        #
        s/\s+#.*//;

        m/^([^=]+)=(.*)/;
        
        my $key = $1;
        my $val = $2;

        ($key and $val) and $ref->{$key} = $val;
    }
    close CONFIG;

    return $ref;
}

#------------------------------------------------------------------------------
# cleanup: Cleanup quotes text
#------------------------------------------------------------------------------

sub cleanup {
    my $text = shift;

    $text =~ s/\n/ /g;
    $text =~ s/\&[a-z]+\;//g;
    $text =~ s/,$//;

    return trim($text);
}

#------------------------------------------------------------------------------
# urlCleanup: Remove URL references
#------------------------------------------------------------------------------

sub urlCleanup {
    my $text = shift;

    $text =~ s|<a href=[^>]+>||g;
    $text =~ s|</a>||g;

    return trim_all($text);
}

#------------------------------------------------------------------------------
# usage: Print usage when invoked with -help or -usage
#------------------------------------------------------------------------------

sub usage {
    my $err = shift;

    $err and print STDERR "$err\n";

    print STDERR <<_USAGE;
Usage:   ./$COMMAND --config <absolute or relative path to config file> --authors-file <file with list of authors (one per line)> 
                  [ --debug --verbose ] > output_file
Example: ./$COMMAND --config ../../conf/quotes/scrape_author_info.somequotesite --authors-file authors.txt --debug > authors_info.txt
_USAGE

    exit(1);
}


