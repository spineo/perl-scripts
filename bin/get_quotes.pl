#!/usr/bin/perl -w

#------------------------------------------------------------------------------
# Name       : get_quotes.pl
# Author     : Stuart Pineo  <svpineo@gmail.com>
# Usage:     : $0 --url <quotes page> --quote-open <text or regex> --quote-close <text of regex> --author-open <text or regex> --author-close <text or regex> --context-open <text or regex> --context-close <text or regex> --block-end <text or regex> [ --num-pages <number of pages> --delim <text> --debug --verbose ] > output_file
# Description: Script parses data from a quotes author and optionally, pages through the results. The quote-open/quote-close and author-open/author-close as well as block-end command-line options must be provided but the context (i.e., book or other reference) is optional. The --delim command-line option can be used to override the default delimiter.
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
use lib qw(../lib);

use Getopt::Long;
use Carp qw(croak carp);
use Data::Dumper;

#use LWP::Simple;
use LWP::UserAgent;
use Cwd qw(cwd);

# These found in ../lib
#
use Util::GenericUtils qw(trim is_path);

# Global variables
#
our $COMMAND = `basename $0`;
chomp($COMMAND);

our $VERSION = "1.0";

# Generic variables
#
our $VERBOSE = 0;
our $DEBUG   = 0;

our ($URL, $QUOTE_OPEN, $QUOTE_CLOSE, $AUTHOR_OPEN, $AUTHOR_CLOSE, $CONTEXT_OPEN, $CONTEXT_CLOSE, $BLOCK_END, $NUM_PAGES);

our %QUOTE_SEEN;

use Getopt::Long;
GetOptions(
    'url=s'           => \$URL,
    'quote-open=s'    => \$QUOTE_OPEN,
    'quote-close=s'   => \$QUOTE_CLOSE,
    'author-open=s'   => \$AUTHOR_OPEN,
    'author-close=s'  => \$AUTHOR_CLOSE,
    'context-open=s'  => \$CONTEXT_OPEN,
    'context-close=s' => \$CONTEXT_CLOSE,
    'block-end=s'     => \$BLOCK_END,
    'num-pages=i'     => \$NUM_PAGES,
    'debug'           => \$DEBUG,
    'verbose'         => \$VERBOSE,
    'help|usage'      => \&usage,
);

! $URL          and usage("--url must be set");
! $QUOTE_OPEN   and usage("--quote-open must be set");
! $QUOTE_CLOSE  and usage("--quote-close must be set");
! $AUTHOR_OPEN  and usage("--author-open must be set");
! $AUTHOR_CLOSE and usage("--author-close must be set");
! $BLOCK_END    and usage("--block-end must be set");

# Retrieve all installations from root
#
my $ua = LWP::UserAgent->new();

# Is this a single get or more than one page?
#
if ($NUM_PAGES and ($NUM_PAGES >= 1)) {
    for (my $i=1; $i<=$NUM_PAGES; $i++) {
        print STDERR "Processing page $i...\n";
        my $page_url = $URL . $i;
        outputContent($page_url);
    }

# Single page
#
} else {
    outputContent($URL);
}

sub outputContent {
    my $url = shift;

    my $req = new HTTP::Request GET => $url;
    my $res = $ua->request($req);
    my $quotes_page = $res->content;

    die("Unable to retrieve content from '$url'") unless $quotes_page;

    $DEBUG and print STDERR $quotes_page;

    my @lines = split(/\n/, $quotes_page);
    my $qopen     = 0;
    my $aopen     = 0;
    my $copen     = 0;
    my $block_end = 0;
    my ($qtext, $atext, $print);
    my $ctext = "";
    foreach my $line (@lines) {
        if ($qopen) {
            if ($line =~ m/([^$QUOTE_CLOSE]*)</) {
                $qtext .= &cleanup($1);
                $qopen = 0;
    
            } else {
                $qtext .= &cleanup($line);
            }

        } elsif ($aopen) {
            if ($line =~ m/([^$AUTHOR_CLOSE]*)</) {
                $atext .= &cleanup($1);
                $aopen = 0;

            } else {
                $atext .= &cleanup($line);
            }

        } elsif ($copen) {
            if ($line =~ m/([^$CONTEXT_CLOSE]*)</) {
                $ctext .= &cleanup($1);
                $copen = 0;
    
            } else {
                $ctext .= &cleanup($line);
            }

        } elsif ($line =~ m/$QUOTE_OPEN(.*)/) {
            $qopen = 1;
            $qtext = &cleanup($1);
	        $print = 0;

            if ($qtext =~ m/^([^$QUOTE_CLOSE]+)$QUOTE_CLOSE/) {
                $qtext = $1;
                $qopen = 0;
            }

        } elsif ($line =~ m/$AUTHOR_OPEN(.*)/) {
            $aopen = 1;
            $atext = &cleanup($1);
	        $print = 0;

            if ($atext =~ m/^([^$AUTHOR_CLOSE]+)$AUTHOR_CLOSE/) {
                $atext = $1;
                $aopen = 0;
            }

        } elsif ($line =~ m/$CONTEXT_OPEN(.*)/) {
            $copen = 1;
            $ctext = &cleanup($1);
	        $print = 0;

            if ($ctext =~ m/^([^$CONTEXT_CLOSE]+)$CONTEXT_CLOSE/) {
                $ctext = $1;
                $copen = 0;
            }

        } elsif (($line =~ m/$BLOCK_END(.*)/) && $qtext && $atext && ! $print && ! $QUOTE_SEEN{$qtext}) {
	        print STDOUT "$qtext###$atext###$ctext\n";
            $QUOTE_SEEN{$qtext} = 1;
	        $qtext = "";
	        $atext = "";
            $ctext = "";
	        $print = 1;
        }
    }
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
# usage: Print usage when invoked with -help or -usage
#------------------------------------------------------------------------------

sub usage {
    my $err = shift;

    $err and print STDERR "$err\n";

    print STDERR <<_USAGE;
Usage:   ./$COMMAND --url <quotes page> --quote-open <text or regex> --quote-close <text of regex> --author-open <text or regex> --author-close <text or regex> --block-end <text or regex> [ --context-open <text or regex> --context-close <text or regex> --num-pages <number of pages> --delim <text> --debug --verbose ] > output_file
Example: ./$COMMAND --url https://www.goodreads.com/quotes/tag/love?page= --quote-open '"quoteText">' --quote-close '<' --author-open "\"authorOrTitle\">" --author-close '<' --context-open "\"authorOrTitle\"\s+href=[^>]+>" --context-close '<' --block-end "quoteDetails" --num-pages 5 > quotes.txt
_USAGE

    exit(1);
}


