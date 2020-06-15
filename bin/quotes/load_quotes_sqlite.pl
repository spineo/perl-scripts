#!/usr/bin/perl -w

#------------------------------------------------------------------------------
# Name       : load_quotes_sqlite.pl
# Author     : Stuart Pineo  <svpineo@gmail.com>
# Usage      : ./load_quotes_sqlite.pl --db-file <database file> [ --debug 
#              --verbose ] < <author JSON>
# Description: The quotes loader loads into the SQLite quotes database the Author, Events,
#              Keywords, and Quotes data parsed from the filter script output (as STDIN)
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
use JSON qw(from_json);;
use DBI;


# Global variables
#
our $COMMAND = `basename $0`;
chomp($COMMAND);

our $VERSION = "1.0";

# Generic variables
#
our $VERBOSE = 0;
our $DEBUG   = 0;

our $DB_FILE;
our $TAGS;

use Getopt::Long;
GetOptions(
    'db-file=s'  => \$DB_FILE,
    'debug'      => \$DEBUG,
    'verbose'    => \$VERBOSE,
    'help|usage' => \&usage,
);

# Validate the command-line options
#
! $DB_FILE and &usage("Command-line option --db-file must be set");
! -f $DB_FILE and die("File '$DB_FILE' not found or is not readable.");

my $authors_ref = from_json( <STDIN> );

$DEBUG and print STDERR Data::Dumper->Dump( [ $authors_ref ]);

#------------------------------------------------------------------------------
# Connect to the database
#------------------------------------------------------------------------------

my $dbh = DBI->connect("dbi:SQLite:dbname=$DB_FILE","","");


# Load the keywords
#
$TAGS = {};
&extractTags($authors_ref, $TAGS);
foreach my $key (sort keys %$TAGS) {
    print STDOUT "$key\n";
}


#------------------------------------------------------------------------------
# extractTags
#
# Extract tags (to be used for 'keyword' table)
#------------------------------------------------------------------------------

sub extractTags {
    my ($authors_ref, $TAGS) = @_;

    foreach my $auth_sig (keys %$authors_ref) {
        my $author_ref = $authors_ref->{$auth_sig};

        my $quotes_array = $author_ref->{'quotes'};
        foreach my $quote_ref (@$quotes_array) {

            my @tags = split(/,/, $quote_ref->{'tags'});
            foreach my $tag (@tags) {
                $TAGS->{$tag} = 1;
            }
        }
    }
}

#------------------------------------------------------------------------------
# usage: Print usage when invoked with -help or -usage
#------------------------------------------------------------------------------

sub usage {
    print STDERR <<_USAGE;
Usage:   ./$COMMAND --db-file <database file> [ --debug --verbose ] < <author JSON>
Example: ./$COMMAND --db-file myquotes.sqlite3 --debug --verbose < filter_quotes_output.json
_USAGE

    exit(1);
}


