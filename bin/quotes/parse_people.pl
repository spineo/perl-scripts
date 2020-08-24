#!/usr/bin/perl -w

#------------------------------------------------------------------------------
# Name       : parse_people.pl
# Author     : Stuart Pineo  <svpineo@gmail.com>
# Usage      : ./parse_people.pl --people-file <people text file> > events-file
#
# Description: Parse dates/event associated with a profiled person. Generate a text
# output file sorted by month/day followed by year, event, and associated person
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

use Getopt::Long;
use Carp qw(croak carp);
use Data::Dumper;


# These found in ../lib
#
use lib qw(../../lib);
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

our $PEOPLE_FILE;

use Getopt::Long;
GetOptions(
    'people-file=s'  => \$PEOPLE_FILE,
    'debug'          => \$DEBUG,
    'verbose'        => \$VERBOSE,
    'help|usage'     => \&usage,
);

# Validate the command-line options
#
! $PEOPLE_FILE and &usage("Command-line option --people-file must be set");
! -f $PEOPLE_FILE and die("File '$PEOPLE_FILE' not found or is not readable.");

open(PEOPLE, $PEOPLE_FILE) or die("Unable to open file '$PEOPLE_FILE' for reading.");

my $person;
while(<PEOPLE>) {
    # Skip comments
    #
    next if m/^#/;

    # Skip empty lines
    #
    next if m/^\s*$/;

    chomp;

    if (m/^Name:\s+/) {
        $person = $';
        $DEBUG and print STDERR "Person: $person\n";
    }
}

#------------------------------------------------------------------------------
# usage: Print usage when invoked with -help or -usage
#------------------------------------------------------------------------------

sub usage {
    print STDERR <<_USAGE;
Usage:   ./$COMMAND --people-file <people text file> > events-file
Example: ./$COMMAND --people-file people.txt > people_events.txt
_USAGE

    exit(1);
}

