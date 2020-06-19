#!/usr/bin/perl -w

#------------------------------------------------------------------------------
# Name       : load_quotes_sqlite.pl
# Author     : Stuart Pineo  <svpineo@gmail.com>
# Usage      : ./load_quotes_sqlite.pl --db-conf <database config file> [ --debug 
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
use Util::Quotes qw(createSig);


# Database wrapper, uses the database configuration file supplied as command-line option
# For SQLite, either the 'conn_str' property can be supplied directly or include
# the 'server' (i.e., sqlite) and 'filename' (i.e., /somepath/myquotes.sqlite3)
# properties. If authentication required, also 'username' and 'password' must be added. 
#
use Util::DB;


# Global variables
#
our $COMMAND = `basename $0`;
chomp($COMMAND);

our $VERSION = "1.0";

# Generic variables
#
our $VERBOSE = 0;
our $DEBUG   = 0;

our $DB_CONF;

use Getopt::Long;
GetOptions(
    'db-conf=s'  => \$DB_CONF,
    'debug'      => \$DEBUG,
    'verbose'    => \$VERBOSE,
    'help|usage' => \&usage,
);

# Validate the command-line options
#
! $DB_CONF and &usage("Command-line option --db-conf must be set");
! -f $DB_CONF and die("File '$DB_CONF' not found or is not readable.");

my $authors_ref = from_json( <STDIN> );

$DEBUG and print STDERR Data::Dumper->Dump( [ $authors_ref ]);

#------------------------------------------------------------------------------
# Connect to the database and prepare the inserts
#------------------------------------------------------------------------------

# Tables/columns
#
our $KEYWORD_TBL  = qq|myquotes_keyword|;
our @KEYWORD_COLS = ('keyword');

our $AUTHOR_TBL   = qq|myquotes_author|;
our @AUTHOR_COLS  = ('full_name', 'birth_date', 'death_date', 'bio_extract', 'bio_source_url');

# AutoCommit default to 0 in this API so must explicity commit (unless it is changed to 1)
my $dbObj = new Util::DB();
$dbObj->initialize($DB_CONF);
#$dbObj->setAttr('AutoCommit', 1);
#$dbObj->no_exit_on_error;

my $sql_keyword_sel = qq|SELECT * from $KEYWORD_TBL|;
my $sth_keyword_ins = $dbObj->prepare("INSERT INTO $KEYWORD_TBL(keyword) VALUES (?)");

my $sql_author_sel  = qq|SELECT * from $AUTHOR_TBL|;
my $sth_author_ins  = $dbObj->prepare("INSERT INTO $AUTHOR_TBL(" . join(',', @AUTHOR_COLS) .  ") VALUES (?, ?, ?, ?, ?)");

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

$dbObj->commit;
$dbObj->disconnect;

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

    my $values = $dbObj->select_hash($sql_keyword_sel);

    foreach my $row (@$values) {
        my $id = $row->{'id'};
        my $keyword = $row->{'keyword'};
        $SEL_KEYWORDS->{$keyword} = $id;
    }

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

        my $stat = $dbObj->insert($sth_keyword_ins, ( $keyword ));
        if (! $stat) {
            my $id = &getPk;
            $INS_KEYWORDS->{$keyword} = $id;
        }
    }
    $dbObj->finish($sth_keyword_ins);
}

#------------------------------------------------------------------------------
# queryAuthors: Query from authors table to avoid inserting duplicates
#------------------------------------------------------------------------------

sub queryAuthors {

    my $values = $dbObj->select_hash($sql_author_sel);

    foreach my $row (@$values) {
        my $id = $row->{'id'};
        my $name_sig = &createSig($row->{'full_name'});
        $SEL_AUTHORS->{$name_sig} = $id;
    }

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

        my $stat = $dbObj->insert($sth_author_ins, ($name, $birth_date, $death_date, $description, $bio_url));
        if (! $stat) {
            my $id = &getPk;
            $SEL_AUTHORS->{$name_sig} = $id;
        }
    }
    $sth_author_ins->finish();
}

#------------------------------------------------------------------------------
# getPk: Returns the primary key value inserted
#------------------------------------------------------------------------------

sub getPk {
    return $dbObj->{'dbh'}->sqlite_last_insert_rowid;
}

#------------------------------------------------------------------------------
# usage: Print usage when invoked with -help or -usage
#------------------------------------------------------------------------------

sub usage {
    print STDERR <<_USAGE;
Usage:   ./$COMMAND --db-conf <database config file> [ --debug --verbose ] < <author JSON>
Example: ./$COMMAND --db-conf myquotes.conf --debug --verbose < filter_quotes_output.json
_USAGE

    exit(1);
}


