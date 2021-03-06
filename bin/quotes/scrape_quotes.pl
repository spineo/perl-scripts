#!/usr/bin/perl -w

#------------------------------------------------------------------------------
# Name       : scrape_quotes.pl
# Author     : Stuart Pineo  <svpineo@gmail.com>
# Usage:     : $0 --config <absolute or relative path to config file> [ --debug --verbose ] > output_file
# Description: Script parses data from a quotation block (which should include at the very least the quote and author). The required command-line option is the 
#              site specific configuration file where the url, tag open/close patterns, and block end (i.e., end of a quotation section) can be specified. This
#              file can be created by modifying the scrape_quotes.site.template file checked into the "conf" directory.
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
# Copyright (c) 2017,2020 Stuart Pineo
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
use Util::GenericUtils qw(trim_all);
use Util::Quotes qw(parseConfig cleanupTagsText);

# Global variables
#
our $COMMAND = `basename $0`;
chomp($COMMAND);

our $VERSION = "1.0";

# Generic variables
#
our $VERBOSE = 0;
our $DEBUG   = 0;

our $CONFIG;

our %QUOTE_SEEN;

use Getopt::Long;
GetOptions(
    'config=s'        => \$CONFIG,
    'debug'           => \$DEBUG,
    'verbose'         => \$VERBOSE,
    'help|usage'      => \&usage,
);

# Parse the configuration file
#
! $CONFIG and usage("--config must be set.");
! -f $CONFIG and usage("File '$CONFIG' not found or is not readable.");

my $ref = &parseConfig($CONFIG);
$DEBUG and print STDERR Data::Dumper->Dump([$ref]);

# Mandatory fields
#
our $URL          = defined($ref->{'URL'}) ? $ref->{'URL'} : die("The 'URL' key is missing (or not defined) in the config file.");
our $BLOCK_END    = defined($ref->{'BLOCK_END'}) ? $ref->{'BLOCK_END'} : die("The 'BLOCK_END' key is missing (or not defined) in the config file.");
our $DELIM        = defined($ref->{'DELIM'}) ? $ref->{'DELIM'} : die("The 'DELIM' key is missing (or not defined) in the config file.");
our $QUOTE_OPEN   = defined($ref->{'QUOTE_OPEN'}) ? $ref->{'QUOTE_OPEN'} : die("The 'QUOTE_OPEN' key is missing (or not defined) in the config file.");
our $QUOTE_CLOSE  = defined($ref->{'QUOTE_CLOSE'}) ? $ref->{'QUOTE_CLOSE'} : die("The 'QUOTE_CLOSE' key is missing (or not defined) in the config file.");
our $AUTHOR_OPEN  = defined($ref->{'AUTHOR_OPEN'}) ? $ref->{'AUTHOR_OPEN'} : die("The 'AUTHOR_OPEN' key is missing (or not defined) in the config file.");
our $AUTHOR_CLOSE = defined($ref->{'AUTHOR_CLOSE'}) ? $ref->{'AUTHOR_CLOSE'} : die("The 'AUTHOR_CLOSE' key is missing (or not defined) in the config file.");

# Optional fields
#
our @URL_PATTERNS = ();
$ref->{'URL_PATTERNS'} and @URL_PATTERNS = split /,/, &trim_all($ref->{'URL_PATTERNS'});
our $NUM_PAGES    = $ref->{'NUM_PAGES'} || '';
our $SOURCE_OPEN  = $ref->{'SOURCE_OPEN'} || '';
our $SOURCE_CLOSE = $ref->{'SOURCE_CLOSE'} || '';
our $TAGS_OPEN  = $ref->{'TAGS_OPEN'} || '';
our $TAGS_CLOSE = $ref->{'TAGS_CLOSE'} || '';


# Retrieve all installations from root
#
my $ua = LWP::UserAgent->new();

if (@URL_PATTERNS) {

    foreach my $pattern (@URL_PATTERNS) {    

        my $url = $URL;
        $url =~ s/<PATTERN>/$pattern/;

        &processURL($url);
    }

} else {
    &processURL($URL);
}

sub outputContent {
    my $url = shift;

    $DEBUG && print STDERR "URL: $url\n";

    my $req = new HTTP::Request GET => $url;
    my $res = $ua->request($req);
    my $quotes_page = $res->content;

    die("Unable to retrieve content from '$url'") unless $quotes_page;

    my @lines = split(/\n/, $quotes_page);
    my $qopen     = 0;
    my $aopen     = 0;
    my $sopen     = 0;
    my $topen     = 0;
    my $block_end = 0;
    my ($qtext, $atext, $print);
    my $stext = "";
    my $ttext = "";
    foreach my $line (@lines) {
        if ($qopen) {
            if ($line =~ m/([^$QUOTE_CLOSE]*)</) {
                $qtext .= &cleanupTagsText($1);
                $qopen = 0;
    
            } else {
                $qtext .= &cleanupTagsText($line);
            }

        } elsif ($aopen) {
            if ($line =~ m/([^$AUTHOR_CLOSE]*)</) {
                $atext .= &cleanupTagsText($1);
                $aopen = 0;

            } else {
                $atext .= &cleanupTagsText($line);
            }

        } elsif ($sopen) {
            if ($line =~ m/([^$SOURCE_CLOSE]*)</) {
                $stext .= &cleanupTagsText($1);
                $sopen = 0;
    
            } else {
                $stext .= &cleanupTagsText($line);
            }

        } elsif ($topen) {
            if ($line =~ m/$TAGS_CLOSE/) {
                $topen = 0;
                $ttext .= $`;
                $ttext = &urlCleanup($ttext);
    
            } else {
                $ttext .= $line;
            }

        } elsif ($line =~ m/$QUOTE_OPEN(.*)/) {
            $qopen = 1;
            $qtext = &cleanupTagsText($1);
	        $print = 0;

            if ($qtext =~ m/^([^$QUOTE_CLOSE]+)$QUOTE_CLOSE/) {
                $qtext = $1;
                $qopen = 0;
            }

        } elsif ($line =~ m/$AUTHOR_OPEN(.*)/) {
            $aopen = 1;
            $atext = &cleanupTagsText($1);
	        $print = 0;

            if ($atext =~ m/^([^$AUTHOR_CLOSE]+)$AUTHOR_CLOSE/) {
                $atext = $1;
                $aopen = 0;
            }

        } elsif ($line =~ m/$SOURCE_OPEN(.*)/) {
            $sopen = 1;
            $stext = &cleanupTagsText($1);
	        $print = 0;

            if ($stext =~ m/^([^$SOURCE_CLOSE]+)$SOURCE_CLOSE/) {
                $stext = $1;
                $sopen = 0;
            }

        } elsif ($line =~ m/$TAGS_OPEN(.*)/) {
            $topen = 1;
            $ttext = $1;
	        $print = 0;

            if ($ttext =~ m/$TAGS_CLOSE/) {
                $ttext = &cleanupTagsText($`);
                $topen = 0;
            }

        } elsif (($line =~ m/$BLOCK_END(.*)/) && $qtext && $atext && ! $print && ! $QUOTE_SEEN{$qtext}) {
	        print STDOUT "$qtext$DELIM$atext$DELIM$stext$DELIM$ttext\n";
            $QUOTE_SEEN{$qtext} = 1;
	        $qtext = "";
	        $atext = "";
            $stext = "";
            $ttext = "";
	        $print = 1;
        }
    }
}

#------------------------------------------------------------------------------
# processURL: Encode URL based on number of pages
#------------------------------------------------------------------------------

sub processURL {
    my $url = shift;

    # Is this a single get or more than one page?
    #
    if ($NUM_PAGES and ($NUM_PAGES >= 1)) {
        for (my $i=1; $i<=$NUM_PAGES; $i++) {
            my $page_url = $url;
            $page_url =~ s/<PAGE>/$i/;
            print STDERR "Processing page $i...\n";
            outputContent($page_url);
        }

    # Single page
    #
    } else {
        outputContent($url);
    }
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
Usage:   ./$COMMAND --config <absolute or relative path to config file> [ --debug --verbose ] > output_file
Example: ./$COMMAND --config ../../conf/quotes/scrape_quotes.somequotesite --debug --verbose > quotes.txt
_USAGE

    exit(1);
}


