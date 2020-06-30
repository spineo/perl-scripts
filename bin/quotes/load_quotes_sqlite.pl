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
use Util::Quotes qw(createSig getSeason);


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

# Date validation
#
our $MAX_YEAR  = 2025;
our $MIN_YEAR  = -1000;
our $MAX_MONTH = 12;
our $MIN_MONTH = 1;
our $MAX_DAY   = 31;
our $MIN_DAY   = 1;

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
#
our $KEYWORD_TBL   = qq|myquotes_keyword|;
our @KEYWORD_COLS  = ('keyword');

our $AUTHOR_TBL    = qq|myquotes_author|;
our @AUTHOR_COLS   = ('full_name', 'birth_year', 'birth_month', 'birth_day', 'death_year', 'death_month', 'death_day', 'description', 'bio_source_url');

our $QUOTE_TBL     = qq|myquotes_quotation|;
our @QUOTE_COLS    = ('quotation', 'source', 'author_id');

our $QUOTE_KW_TBL  = qq|myquotes_quotationkeyword_keyword|;
our @QUOTE_KW_COLS = ('quotationkeyword_id', 'keyword_id');

our $EVENT_TBL     = qq|myquotes_event|;
our @EVENT_COLS    = ('event', 'day', 'month', 'year', 'season');

our $EVENT_AU_TBL  = qq|myquotes_eventauthor|;
our @EVENT_AU_COLS = ('event_id', 'author_id');

our $EVENT_KW_TBL  = qq|myquotes_eventkeyword_keyword|;
our @EVENT_KW_COLS = ('eventkeyword_id', 'keyword_id');

# AutoCommit default to 0 in this API so must explicity commit (unless it is changed to 1)
my $dbObj = new Util::DB();
$dbObj->initialize($DB_CONF);
#$dbObj->setAttr('AutoCommit', 1);

$dbObj->no_exit_on_error;

my $sql_keyword_sel  = qq|SELECT * from $KEYWORD_TBL|;
my $sth_keyword_ins  = $dbObj->prepare("INSERT INTO $KEYWORD_TBL(keyword) VALUES (?)");

my $sql_author_sel   = qq|SELECT * from $AUTHOR_TBL|;
my $sth_author_ins   = $dbObj->prepare("INSERT INTO $AUTHOR_TBL(" . join(',', @AUTHOR_COLS) .  ") VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)");

my $sql_quote_sel    = qq|SELECT * from $QUOTE_TBL|;
my $sth_quote_ins    = $dbObj->prepare("INSERT INTO $QUOTE_TBL(" . join(',', @QUOTE_COLS) .  ") VALUES (?, ?, ?)");

my $sth_quote_kw_ins = $dbObj->prepare("INSERT INTO $QUOTE_KW_TBL(" . join(',', @QUOTE_KW_COLS) .  ") VALUES (?, ?)");

my $sql_event_sel    = qq|SELECT * from $EVENT_TBL|;
my $sth_event_ins    = $dbObj->prepare("INSERT INTO $EVENT_TBL(" . join(',', @EVENT_COLS) .  ") VALUES (?, ?, ?, ?, ?)");

my $sth_event_au_ins = $dbObj->prepare("INSERT INTO $EVENT_AU_TBL(" . join(',', @EVENT_AU_COLS) .  ") VALUES (?, ?)");

my $sth_event_kw_ins = $dbObj->prepare("INSERT INTO $EVENT_KW_TBL(" . join(',', @EVENT_KW_COLS) .  ") VALUES (?, ?)");

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
# Load the quotes
#------------------------------------------------------------------------------

our $SEL_QUOTES = {};
our $INS_QUOTES = {};

&queryQuotes();
&insertQuotes($authors_ref);


#------------------------------------------------------------------------------
# Load the quotes keywords
#------------------------------------------------------------------------------

&insertQuotesKeywords($authors_ref);


#------------------------------------------------------------------------------
# Load the events
#------------------------------------------------------------------------------

our $SEL_EVENTS = {};
our $INS_EVENTS = {};

&queryEvents();
&insertEvents($authors_ref);


#------------------------------------------------------------------------------
# Load the events authors
#------------------------------------------------------------------------------

&insertEventsAuthors($authors_ref);


#------------------------------------------------------------------------------
# Load the events keywords
#------------------------------------------------------------------------------

&insertEventsKeywords($authors_ref);


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
        my $bneg;
        my ($byear, $bmonth, $bday);
        if (defined($author_ref->{'birth_date'})) {
            my $birth_date = $author_ref->{'birth_date'};
            $birth_date =~ s/\-0/-/g;
            $birth_date =~ m/^\-/ and ($birth_date =~ s/^\-//) and ($bneg = "-");

            ($byear, $bmonth, $bday) = split('-', $birth_date);
            $byear  = ($byear <= $MAX_YEAR and $byear >= $MIN_YEAR)     ? "$bneg$byear" : "";
            $bmonth = ($bmonth <= $MAX_MONTH and $bmonth >= $MIN_MONTH) ? $bmonth : "";
            $bday   = ($bday <= $MAX_DAY and $bday >= $MIN_DAY)         ? $bday : "";
        }

        my $dneg;
        my ($dyear, $dmonth, $dday);
        if (defined($author_ref->{'death_date'})) {
            my $death_date = $author_ref->{'death_date'};
            $death_date =~ s/\-0/-/g;
            $death_date =~ m/^\-/ and ($death_date =~ s/^\-//) and ($dneg = "-");
            
            ($dyear, $dmonth, $dday) = split('-', $death_date);
            $dyear  = ($dyear <= $MAX_YEAR and $dyear >= $MIN_YEAR)     ? "$dneg$dyear" : "";
            $dmonth = ($dmonth <= $MAX_MONTH and $dmonth >= $MIN_MONTH) ? $dmonth : "";
            $dday   = ($dday <= $MAX_DAY and $dday >= $MIN_DAY)         ? $dday : "";
        }
        my $description = defined($author_ref->{'description'}) ? $author_ref->{'description'} : "";
        my $url         = defined($author_ref->{'bio_url'})     ? $author_ref->{'bio_url'}     : "";

        $DEBUG and print STDOUT "Loading author: $name\n";

        my $stat = $dbObj->insert($sth_author_ins, ($name, $byear, $bmonth, $bday, $dyear, $dmonth, $dday, $description, $url));
        if (! $stat) {
            my $id = &getPk;
            $SEL_AUTHORS->{$name_sig} = $id;
        }
    }
    $sth_author_ins->finish();
}

#------------------------------------------------------------------------------
# queryQuotes: Query from quotes table to avoid inserting duplicates
#------------------------------------------------------------------------------

sub queryQuotes {

    my $values = $dbObj->select_hash($sql_quote_sel);

    foreach my $row (@$values) {
        my $id = $row->{'id'};
        my $sig = &createSig($row->{'quotation'});
        $SEL_QUOTES->{$sig} = $id;
    }

    $DEBUG and print STDERR Data::Dumper->Dump( [ $SEL_QUOTES ] );
}

#------------------------------------------------------------------------------
# insertQuotes: Load the quotes, storing the returned primary key as hash value.
#------------------------------------------------------------------------------

sub insertQuotes {
    my $authors_ref = shift;

    foreach my $name_sig (sort keys %$authors_ref) {

        my $author_ref  = $authors_ref->{$name_sig};
        my $quotes_ref  = $author_ref->{'quotes'};

        my $author_id   = $SEL_AUTHORS->{$name_sig};

        foreach my $quote_ref (@$quotes_ref) {
            my $quote = $quote_ref->{'quote'};
            my $sig   = createSig($quote);

            # Already inserted?
            #
            next if defined($SEL_QUOTES->{$sig});

            my $source = $quote_ref->{'source'};

            $DEBUG and print STDOUT "Loading quote: $quote\n";

            my $stat = $dbObj->insert($sth_quote_ins, ($quote, $source, $author_id));
            if (! $stat) {
                my $id = &getPk;
                $SEL_QUOTES->{$sig} = $id;
            }
        }
    }
    $sth_quote_ins->finish();
}

#------------------------------------------------------------------------------
# insertQuotesKeywords: Load the quotes keywords
#------------------------------------------------------------------------------

sub insertQuotesKeywords {
    my $authors_ref = shift;

    foreach my $name_sig (sort keys %$authors_ref) {

        my $author_ref  = $authors_ref->{$name_sig};
        my $quotes_ref  = $author_ref->{'quotes'};

        foreach my $quote_ref (@$quotes_ref) {
            my $quote = $quote_ref->{'quote'};
            my $sig   = createSig($quote);

            # Already inserted?
            #
            my $quote_id = $SEL_QUOTES->{$sig};
            next if ! $quote_id;

            my @keywords = split(/\s*,\s*/, $quote_ref->{'keywords'});
            foreach my $keyword (@keywords) {
                my $keyword_id = $SEL_KEYWORDS->{$keyword};

                next if ! $keyword_id;

                $DEBUG and print STDOUT "Loading quote keyword. Quote Id: $quote_id, Keyword Id: $keyword_id\n";

                $dbObj->insert($sth_quote_kw_ins, ($quote_id, $keyword_id));
            }
        }
    }
    $sth_quote_kw_ins->finish();
}

#------------------------------------------------------------------------------
# queryEvents: Query from events table to avoid inserting duplicates
#------------------------------------------------------------------------------

sub queryEvents {

    my $values = $dbObj->select_hash($sql_event_sel);

    foreach my $row (@$values) {
        my $id = $row->{'id'};
        my $sig = &createSig($row->{'event'});
        $SEL_EVENTS->{$sig} = $id;
    }

    $DEBUG and print STDERR Data::Dumper->Dump( [ $SEL_EVENTS ] );
}

#------------------------------------------------------------------------------
# insertEvents: Load the events, storing the returned primary key as hash value.
#------------------------------------------------------------------------------

sub insertEvents {
    my $authors_ref = shift;

    foreach my $name_sig (sort keys %$authors_ref) {

        my $author_ref  = $authors_ref->{$name_sig};
        my $events_ref  = $author_ref->{'events'};

        foreach my $event_ref (@$events_ref) {
            my $event = $event_ref->{'event'};
            my $sig   = createSig($event);

            # Already inserted?
            #
            next if defined($SEL_EVENTS->{$sig});

            my $event_date = $event_ref->{'event_date'};
            $event_date =~ s/\-0/-/g;
            my ($year, $month, $day) = split('-', $event_date);

            # Compute the season
            #
            my $season = "";
            $season = &getSeason($month, $day) if ($month and $day);

            $DEBUG and print STDOUT "Loading event: $event\n";

            my $stat = $dbObj->insert($sth_event_ins, ($event, $day, $month, $year, $season));
            if (! $stat) {
                my $id = &getPk;
                $SEL_EVENTS->{$sig} = $id;
            }
        }
    }
    $sth_event_ins->finish();
}

#------------------------------------------------------------------------------
# insertEventsAuthors: Load the events authors
#------------------------------------------------------------------------------

sub insertEventsAuthors {
    my $authors_ref = shift;

    foreach my $name_sig (sort keys %$authors_ref) {

        my $author_id  = $SEL_AUTHORS->{$name_sig};
        next if ! $author_id;

        my $author_ref  = $authors_ref->{$name_sig};
        my $events_ref  = $author_ref->{'events'};

        foreach my $event_ref (@$events_ref) {
            my $event = $event_ref->{'event'};
            my $sig   = createSig($event);

            # Already inserted?
            #
            my $event_id = $SEL_EVENTS->{$sig};
            next if ! $event_id;

            $DEBUG and print STDOUT "Loading event author. Event Id: $event_id, Author Id: $author_id\n";

            $dbObj->insert($sth_event_au_ins, ($event_id, $author_id));
        }
    }
    $sth_quote_kw_ins->finish();
}

#------------------------------------------------------------------------------
# insertEventsKeywords: Load the events keywords
#------------------------------------------------------------------------------

sub insertEventsKeywords {
    my $authors_ref = shift;

    foreach my $name_sig (sort keys %$authors_ref) {

        my $author_ref  = $authors_ref->{$name_sig};
        my $events_ref  = $author_ref->{'events'};

        foreach my $event_ref (@$events_ref) {
            my $event = $event_ref->{'event'};
            my $sig   = createSig($event);

            # Already inserted?
            #
            my $event_id = $SEL_EVENTS->{$sig};
            next if ! $event_id;

            my @keywords = split(/\s*,\s*/, $event_ref->{'keywords'});
            foreach my $keyword (@keywords) {
                my $keyword_id = $SEL_KEYWORDS->{$keyword};

                next if ! $keyword_id;

                $DEBUG and print STDOUT "Loading event keyword. Event Id: $event_id, Keyword Id: $keyword_id\n";

                $dbObj->insert($sth_event_kw_ins, ($event_id, $keyword_id));
            }
        }
    }
    $sth_event_kw_ins->finish();
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


