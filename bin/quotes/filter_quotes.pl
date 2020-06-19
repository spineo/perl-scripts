#!/usr/bin/perl -w

#------------------------------------------------------------------------------
# Name       : filter_quotes.pl
# Author     : Stuart Pineo  <svpineo@gmail.com>
# Usage      : ./filter_quotes.pl --quotes-file <quotes text file>
#                                 --authors-file <authors text file>
#                                 --events-file <events text file>
#                                 --delim <input file delimiter> 
#                                 --max-size <maximum number of characters in quote>
#                                 --print-sigs <sig separator>
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


# To use this module may need to first install with the cpan installer
# Then add i.e. "export PERL5LIB=/Users/stuartpineo/perl5/lib/perl5/" to the ~/.bashrc
# Also make sure, if needed, to run "source ~/.bashrc" before executing the script
#
use JSON qw(to_json);;

# These found in ../lib
#
use lib qw(../../lib);
use Util::Quotes qw(createSig inASCIISet validateKeywords);
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

our @QUOTE_FIELDS  = ('quote', 'author', 'source', 'keywords');
our @AUTHOR_FIELDS = ('name', 'birth_date', 'death_date', 'description', 'bio_url');
our @EVENT_FIELDS  = ('author', 'event_date', 'event', 'keywords');

our ($QUOTES_FILE, $AUTHORS_FILE, $EVENTS_FILE, $DELIM, $MAX_SIZE, $PRINT_SIGS);

use Getopt::Long;
GetOptions(
    'quotes-file=s'  => \$QUOTES_FILE,
    'authors-file=s' => \$AUTHORS_FILE,
    'events-file=s'  => \$EVENTS_FILE,
    'delim=s'        => \$DELIM,
    'max-size=i'     => \$MAX_SIZE,
    'print-sigs=s'   => \$PRINT_SIGS,
    'debug'          => \$DEBUG,
    'verbose'        => \$VERBOSE,
    'help|usage'     => \&usage,
);

# Validate the command-line options
#
! $AUTHORS_FILE and &usage("Command-line option --authors-file must be set");
! -f $AUTHORS_FILE and die("File '$AUTHORS_FILE' not found or is not readable.");

! $EVENTS_FILE and &usage("Command-line option --events-file must be set");
! -f $EVENTS_FILE and die("File '$EVENTS_FILE' not found or is not readable.");

! $DELIM       and &usage("Command-line option --delim must be set");


# Create the authors ref keyed on author name signature
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


    my $name_sig = &createSig($author{'name'});

    $AUTHORS_REF->{$name_sig} = \%author;
}

# Print list of author sigs? (can be used as tags)
#
if ($PRINT_SIGS) {
    my @sigs = sort keys %$AUTHORS_REF;
    print STDERR join($PRINT_SIGS, @sigs);

    exit(0);
}


# Create the events ref keyed on name signature
#
our $EVENTS_REF = {};
open(EVENTS, $EVENTS_FILE) or die("Unable to open file '$EVENTS_FILE' for reading.");
while(<EVENTS>) {
    # Skip comments
    #
    next if m/^#/;

    # Skip empty lines
    #
    next if m/^\s*$/;

    chomp;

    my @comps = split(/$DELIM/, $_);
    if (@comps != @EVENT_FIELDS) {
        die("Data error found in line: $_\n");
    }

    my %event = ();
    @event{@EVENT_FIELDS} = @comps;

    my $event_author = $event{'author'};
    delete($event{'author'});


    my $name_sig = &createSig($event_author);

    push(@{$AUTHORS_REF->{$name_sig}->{'events'}}, \%event);
}


# Process the Quotes file, validating command-line option
#
! $QUOTES_FILE  and &usage("Command-line option --quotes-file must be set");
! -f $QUOTES_FILE and die("File '$QUOTES_FILE' not found or is not readable.");

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

    # Validate the quote before continuing
    #
    # Is character set valid?
    #
    next if not &inASCIISet($quote{'quote'});

    # Is length within specified requirements?
    #
    my $quote_len = length($quote{'quote'});
    next if ($MAX_SIZE and ($quote_len > $MAX_SIZE));

    # Remove keywords that do not include the valid character set
    #
    my $keywords = $quote{'keywords'};
    if (defined($keywords)) {
        my @keywords = &validateKeywords($keywords);

        if (@keywords) {
            $quote{'keywords'} = join(',', @keywords);

        } else {
            delete($quote{'keywords'});
        }
    }

    # Validate the source
    #
    my $source = $quote{'source'};
    if (! ($quote{'source'} and &inASCIISet($source))) {
        delete($quote{'source'});
    }


    my $name_sig = &createSig($quote{'author'});

    # Check if this quote is associated with any of our authors
    #
    foreach my $auth_name_sig (sort keys %$AUTHORS_REF) {
        my $auth_ref = $AUTHORS_REF->{$auth_name_sig};

        # Compare on full name signature (additional filter may be needed)
        #
        if ($name_sig eq $auth_name_sig) {
           push(@{$auth_ref->{'quotes'}}, \%quote);
        }
    }
}

$DEBUG and print STDERR Data::Dumper->Dump( [ $AUTHORS_REF ] );

# Out as JSON so it can be used by the loader script
#
print STDOUT to_json( $AUTHORS_REF );


#------------------------------------------------------------------------------
# usage: Print usage when invoked with -help or -usage
#------------------------------------------------------------------------------

sub usage {
    print STDERR <<_USAGE;
Usage:   ./$COMMAND --quotes-file <quotes text file> --authors-file <authors text file> 
         --events-file <events text file> --delim <input file delimiter> 
         [ --max-size <maximum number of characters in quote> --print-sigs <sigs separator> --debug --verbose ]
Example: ./$COMMAND --quotes-file quotes.txt --authors-file authors_info_all.txt --events-file events.txt --delim '###' --max-size 100 --debug
         ./$COMMAND --authors-file authors.txt --delim '###' --max-size 100 --print-sigs ','
_USAGE

    exit(1);
}


