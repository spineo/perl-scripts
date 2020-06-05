#!/usr/bin/perl -w

#------------------------------------------------------------------------------
# Name       : filter_quotes.pl
# Author     : Stuart Pineo  <svpineo@gmail.com>
# Usage      : ./filter_quotes.pl --quotes-file <quotes text file>
#                                 --authors-file <authors text file>
#                                 --delim <input file delimiter> 
# Description: Filter quotes by applying the list in the authors file.
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

our @QUOTE_FIELDS = ('quote', 'author', 'source', 'tags');
our @AUTHOR_FIELDS = ('name', 'origin', 'title', 'birth_date', 'death_date', 'bio_url');

our ($QUOTES_FILE, $AUTHORS_FILE, $DELIM);

use Getopt::Long;
GetOptions(
    'quotes-file=s'  => \$QUOTES_FILE,
    'authors-file=s' => \$AUTHORS_FILE,
    'delim=s'        => \$DELIM,
    'debug'          => \$DEBUG,
    'verbose'        => \$VERBOSE,
    'help|usage'     => \&usage,
);

# Validate the command-line options
#
! $QUOTES_FILE  and &usage("Command-line option --quotes-file must be set");
! -f $QUOTES_FILE and die("File '$QUOTES_FILE' not found or is not readable.");

! $AUTHORS_FILE and &usage("Command-line option --quotes-file must be set");
! -f $AUTHORS_FILE and die("File '$AUTHORS_FILE' not found or is not readable.");

! $DELIM       and &usage("Command-line option --delim must be set");


# Create the authors ref keyed on name signature
#
our $AUTHORS_REF = {};
open(AUTHORS, $AUTHORS_FILE) or die("Unable to open file '$AUTHORS_FILE' for reading.");
while(<AUTHORS>) {
    # Skip comments
    #
    next if m/^#/;

    # Skip empty lines
    #
    next if m/^\s*$/;

    chomp;

    my @comps = split(/$DELIM/, $_);
    if (@comps != @AUTHOR_FIELDS) {
        die("Data error found in line: $_\n");
    }

    my %author = ();
    @author{@AUTHOR_FIELDS} = @comps;


    my ($name_sig, $lname_sig) = &createSigs($author{'name'});

    $author{'lname_sig'} = $lname_sig;

    $AUTHORS_REF->{$name_sig} = \%author;
}


# Process the Quotes file
#
open(QUOTES, $QUOTES_FILE) or die("Unable to open file '$QUOTES_FILE' for reading.");
while(<QUOTES>) {

    # Skip comments
    #
    next if m/^#/;

    # Skip empty lines
    #
    next if m/^\s*$/;

    chomp;

    my @comps = split(/$DELIM/, $_);
    if (@comps != @QUOTE_FIELDS) {
        die("Data error found in line: $_\n");
    }

    my %quote = ();
    @quote{@QUOTE_FIELDS} = @comps;

    my ($name_sig, $lname_sig) = &createSigs($quote{'author'});

    # Check if this quote is associated with any of our authors
    #
    foreach my $auth_name_sig (keys %$AUTHORS_REF) {
        my $auth_ref = $AUTHORS_REF->{$auth_name_sig};
        my $auth_lname_sig = $auth_ref->{'lname_sig'};

        # Compare on full name signature or last name signature (additional filter may be needed)
        #
        if (($name_sig eq $auth_name_sig) or ($lname_sig eq $auth_lname_sig)) {
           push(@{$auth_ref->{'quotes'}}, \%quote);
        }
    }
}

$DEBUG and print STDERR Data::Dumper->Dump( [ $AUTHORS_REF ] );


#------------------------------------------------------------------------------
# createSigs: Construct the author signatures by removing all empty spaces, 
# lowercasing, removing common pre/suffixes, and removing non-alpha characters
# A separate signature on last name will also be returned.
#------------------------------------------------------------------------------

sub createSigs {
    
    my $name = shift;

    # Lower case
    #
    $name = lc($name);

    # Remove prefix/suffix
    #
    $name =~ s/\W(jr|sr)\.//;
    $name =~ s/^sir\W//;

    # Remove any extra/trailing spaces
    #
    $name = trim($name);

    # Get the presumed last name (or single name)
    #
    my $lname = pop [ split(/ /, $name) ];

    # Remove non-alpha characters
    #
    $name  =~ s/[^a-z]//g;
    $lname =~ s/[^a-z]//g;

    return ($name, $lname);
}

#------------------------------------------------------------------------------
# usage: Print usage when invoked with -help or -usage
#------------------------------------------------------------------------------

sub usage {
    print STDERR <<_USAGE;
Usage:   ./$COMMAND --quotes-file <quotes text file> --authors-file <authors text file> --delim <input file delimiter> [ --debug --verbose ]
Example: ./$COMMAND --quotes-file quotes.txt --authors-file authors.txt --delim '###' --debug
_USAGE

    exit(1);
}


