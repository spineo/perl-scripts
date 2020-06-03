#!/usr/bin/perl -w

#------------------------------------------------------------------------------
# Name       : parse_authors.pl
# Author     : Stuart Pineo  <svpineo@gmail.com>
# Usage      : ./parse_authors.pl --delim <input file delimiter> < <authors text file>
# Description: Parse an "authors" text file. Fields include author full name, nationality,
#              occupation, birth date, death date (if deceased), and optionally link to bio.
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
use lib qw(../lib);
use Util::GenericUtils qw(trim);

# Global variables
#
our $COMMAND = `basename $0`;
chomp($COMMAND);

our $VERSION = "1.0";

# Generic variables
#
our $VERBOSE = 0;
our $DEBUG   = 0;

our $DELIM;
our @FIELDS = ('name', 'origin', 'title', 'birth_date', 'death_date', 'bio_url');

use Getopt::Long;
GetOptions(
    'delim=s'    => \$DELIM,
    'debug'      => \$DEBUG,
    'verbose'    => \$VERBOSE,
    'help|usage' => \&usage,
);

! $DELIM and &usage("Command-line option --delim must be set");


our $REF = [];
while(<STDIN>) {
    # Skip comments
    #
    next if m/^#/;

    # Skip empty lines
    #
    next if m/^\s*$/;

    chomp;

    my @comps = split(/$DELIM/, $_);
    if (@comps != @FIELDS) {
        die("Data error found in line: $_\n");
    }

    my %author = ();
    @author{@FIELDS} = @comps;

    push(@$REF, \%author);
}

$DEBUG and print STDERR Data::Dumper->Dump( [ $REF ] );

#------------------------------------------------------------------------------
# usage: Print usage when invoked with -help or -usage
#------------------------------------------------------------------------------

sub usage {
    print STDERR <<_USAGE;
Usage:   ./$COMMAND --debug --verbose [ --delim <delimiter> ] < <authors input text file>
Example: ./$COMMAND --debug --verbose --delim '###' < ./authors.txt
_USAGE

    exit(1);
}


