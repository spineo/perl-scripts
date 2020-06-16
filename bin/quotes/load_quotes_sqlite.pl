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

use lib qw(../../lib);
use Util::Quotes qw(createSigs);


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
# Connect to the database and prepare the inserts
#------------------------------------------------------------------------------

# Tables
#
our $KEYWORD = qq|myquotes_keyword|;
our $AUTHOR  = qq|myquotes_author|;

my $dbh = DBI->connect("dbi:SQLite:dbname=$DB_FILE","","");

my $sth_keyword_sel = $dbh->prepare("SELECT id, keyword from $KEYWORD");
my $sth_keyword_ins = $dbh->prepare("INSERT INTO $KEYWORD(keyword) VALUES (?)");

my $sth_author_sel  = $dbh->prepare("SELECT id, full_name, birth_date, death_date, bio_extract, bio_source_url from $AUTHOR");
my $sth_author_ins  = $dbh->prepare("INSERT INTO $AUTHOR(full_name, birth_date, death_date, bio_extract, bio_source_url) VALUES (?, ?, ?, ?, ?)");

#------------------------------------------------------------------------------
# Load the keywords
#------------------------------------------------------------------------------

our $SEL_KEYWORDS = {};
our $INS_KEYWORDS = {};

&extractKeywords($authors_ref);
&queryKeywords();
&insertKeywords();


#------------------------------------------------------------------------------
# Load the authors
#------------------------------------------------------------------------------

our $SEL_AUTHORS = {};
our $INS_AUTHORS = {};

&queryAuthors();
&insertAuthors($authors_ref);


#------------------------------------------------------------------------------
# Cleanup
#------------------------------------------------------------------------------

$dbh->disconnect;

#------------------------------------------------------------------------------
# extractKeywords: Extract keywords (to be used for 'myquotes_keyword' table)
#------------------------------------------------------------------------------

sub extractKeywords {
    my $authors_ref = shift;

    foreach my $auth_sig (keys %$authors_ref) {
        my $author_ref = $authors_ref->{$auth_sig};

        my $quotes_array = $author_ref->{'quotes'};
        foreach my $quote_ref (@$quotes_array) {

            my @keywords = split(/,/, $quote_ref->{'keywords'});
            foreach my $keyword (@keywords) {
                $INS_KEYWORDS->{$keyword} = 1;
            }
        }
    }
}

#------------------------------------------------------------------------------
# queryKeywords: Query from keywords table to avoid inserting duplicates
#------------------------------------------------------------------------------

sub queryKeywords {

    my $stat = $sth_keyword_sel->execute() or die("Execute Failed: " . $sth_keyword_sel->errstr);

    while (my $row = $sth_keyword_sel->fetchrow_hashref()) {
        my $id = $row->{'id'};
        my $keyword = $row->{'keyword'};
        $SEL_KEYWORDS->{$keyword} = $id;
    }
    $sth_keyword_sel->finish();

    $DEBUG and print STDERR Data::Dumper->Dump( [ $SEL_KEYWORDS ] );
}

#------------------------------------------------------------------------------
# insertKeywords: Load the keywords, storing the returned primary key as hash value.
#------------------------------------------------------------------------------

sub insertKeywords {

    $DEBUG and print STDERR Data::Dumper->Dump( [ $INS_KEYWORDS ] );

    foreach my $keyword (sort keys %$INS_KEYWORDS) {

        next if defined($SEL_KEYWORDS->{$keyword});

        $DEBUG and print STDOUT "Loading keyword: $keyword\n";

        $sth_keyword_ins->bind_param(1, $keyword);
        $sth_keyword_ins->execute() or die("Execute Failed: " . $sth_keyword_ins->errstr);

        my $id = $dbh->sqlite_last_insert_rowid;
        $INS_KEYWORDS->{$keyword} = $id;
    }
    $sth_keyword_ins->finish();
}

#------------------------------------------------------------------------------
# queryAuthors: Query from authors table to avoid inserting duplicates
#------------------------------------------------------------------------------

sub queryAuthors {

    my $stat = $sth_author_sel->execute() or die("Execute Failed: " . $sth_author_sel->errstr);

    while (my $row = $sth_author_sel->fetchrow_hashref()) {
        my $id = $row->{'id'};
        my $name_sig = ( &createSigs($row->{'full_name'}) )[0];
        $SEL_AUTHORS->{$name_sig} = $id;
    }
    $sth_author_sel->finish();

    $DEBUG and print STDERR Data::Dumper->Dump( [ $SEL_AUTHORS ] );
}

#------------------------------------------------------------------------------
# insertAuthors: Load the authors, storing the returned primary key as hash value.
#------------------------------------------------------------------------------

sub insertAuthors {
    my $authors_ref = shift;

    foreach my $name_sig (sort keys %$authors_ref) {

        next if defined($SEL_AUTHORS->{$name_sig});

        my $author_ref  = $authors_ref->{$name_sig};
        my $name        = $author_ref->{'name'};
        my $birth_date  = defined($author_ref->{'birth_date'})  ? $author_ref->{'birth_date'}  : "";
        my $death_date  = defined($author_ref->{'death_date'})  ? $author_ref->{'death_date'}  : "";
        my $description = defined($author_ref->{'description'}) ? $author_ref->{'description'} : "";
        my $bio_url     = defined($author_ref->{'bio_url'})     ? $author_ref->{'bio_url'}     : "";

        $DEBUG and print STDOUT "Loading author: $name\n";

        $sth_author_ins->bind_param(1, $name);
        $sth_author_ins->bind_param(2, $birth_date);
        $sth_author_ins->bind_param(3, $death_date);
        $sth_author_ins->bind_param(4, $description);
        $sth_author_ins->bind_param(5, $bio_url);

        $sth_author_ins->execute() or die("Execute Failed: " . $sth_author_ins->errstr);

        my $id = $dbh->sqlite_last_insert_rowid;
        $author_ref->{'id'} = $id;
    }
    $sth_author_ins->finish();
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


