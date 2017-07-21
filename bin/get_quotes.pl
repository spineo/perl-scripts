#!/usr/bin/perl -w

#------------------------------------------------------------------------------
# Name       : get_quotes.pl
# Author     : Stuart Pineo  <svpineo@gmail.com>
# Usage      : $0 --url <source url>
# Description: Script parses data from a quotes sources (embed this script
# in a wrapper to page through topics, results sets, etc.)
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
# Copyright (c) 2017 Stuart Pineo
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
use lib qw(../lib);

use Getopt::Long;
use Carp qw(croak carp);
use Data::Dumper;

use LWP::Simple;
use Cwd qw(cwd);

# These found in ../lib
#
use Util::GenericUtils qw(is_path);

# Global variables
#
our $COMMAND = `basename $0`;
chomp($COMMAND);

our $VERSION = "1.0";

# Generic variables
#
our $VERBOSE = 0;
our $DEBUG   = 0;

our ($URL, $QUOTE_OPEN, $QUOTE_CLOSE);

use Getopt::Long;
GetOptions(
    'url=s'         => \$URL,
    'quote-open=s'  => \$QUOTE_OPEN,
    'quote-close=s' => \$QUOTE_CLOSE,
    'debug'         => \$DEBUG,
    'verbose'       => \$VERBOSE,
    'help|usage'    => \&usage,
);

! $URL         and usage("--url must be set");
! $QUOTE_OPEN  and usage("--quote-open must be set");
! $QUOTE_CLOSE and usage("--quote-close must be set");

# Retrieve all installations from root
#
my $quotes_page = get $URL;
die("Unable to retrieve content from '$URL'") unless $quotes_page;

my @lines = split(/\n/, $quotes_page);
my $qopen = 0;
my $qtext;
foreach my $line (@lines) {
    if ($qopen) {
	if ($line =~ m/([^<]*)</) {
		$qtext .= &cleanup($1);
    		print STDOUT "$qtext\n";
		$qtext = "";
		$qopen = 0;

	} else {
		$qtext .= &cleanup($line);
	}

    } elsif ($line =~ m/$QUOTE_OPEN(.*)/) {
	$qopen = 1;
	$qtext = &cleanup($1);
    }
}

#------------------------------------------------------------------------------
# cleanup: Cleanup quotes text
#------------------------------------------------------------------------------

sub cleanup {
	my $text = shift;

	$text =~ s/\n/ /g;
	$text =~ s/\&[a-z]+\;//g;
	$text =~ s/ +/ /g;

	return $text;
}

#------------------------------------------------------------------------------
# usage: Print usage when invoked with -help or -usage
#------------------------------------------------------------------------------

sub usage {
    my $err = shift;

    $err and print STDERR "$err\n";

    print STDERR <<_USAGE;
Usage:   ./$COMMAND --url <quotes page> [ --debug --verbose ] > output_file
Example: ./$COMMAND --url http://www.goodreads.com/quotes/tag/love?page=1 --quote-open '"quoteText">' --quote-close '<' > quotes.txt
_USAGE

    exit(1);
}


