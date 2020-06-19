package Util::Quotes;

#------------------------------------------------------------------------------
# Name       : Util::Quotes.pm
# Author     : Stuart Pineo  <svpineo@gmail.com>
# Description: Utilities used by the Quotes/Authors Scraping and Filtering Scripts.
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

use Carp qw(croak carp confess);
use File::Copy qw(copy);

require Exporter;

use vars    qw($VERSION @ISA @EXPORT_OK);


$VERSION = 0.01;


@ISA = qw( Exporter );

@EXPORT_OK = qw(parseConfig cleanupTagsText createSig inASCIISet validateKeywords);


#------------------------------------------------------------------------------
# parseConfig
#
# Parse the configuration file, return a nested reference structure
#------------------------------------------------------------------------------

sub parseConfig {
    my $config = shift;

    my $ref = {};

    open CONFIG, $config or die("Unable to open file '$config' for reading: $!");
    while(<CONFIG>) {

        # Skip lines starting with comments
        #
        next if m/^#/;

        # Skip empty lines
        #
        next if m/^\s*$/;

        chomp;

        # Remove potentially trailing comments
        #
        s/\s+#.*//;

        m/^([^=]+)=(.*)/;
        
        my $key = $1;
        my $val = $2;

        ($key and $val) and $ref->{$key} = $val;
    }
    close CONFIG;

    return $ref;
}

#------------------------------------------------------------------------------
# cleanupTagsText
#
# Cleanup tags text
#------------------------------------------------------------------------------

sub cleanupTagsText {
    my $text = shift;

    $text =~ s/\n/ /g;
    $text =~ s/\&[a-z]+\;//g;
    $text =~ s/,$//;
    $text =~ s/^\s+//;
    $text =~ s/\s+$//;
    $text =~ s/\s+/ /g;

    return $text;
}

#------------------------------------------------------------------------------
# createSig

# Construct the text signature by removing all empty spaces, lowercasing, 
# removing common pre/suffixes (for authors), and removing non-alpha characters.
#------------------------------------------------------------------------------

sub createSig {

    my $text = shift;

    # Lower case
    #
    $text = lc($text);

    # Remove prefix/suffix (author)
    #
    $text =~ s/\W(jr|sr)\.//;
    $text =~ s/^sir\W//;

    # Remove any extra spaces
    #
    $text =~ s/^\s+//;
    $text =~ s/\s+$//;
    $text =~ s/\s+/ /g;

    # Remove non-alpha, non-space characters
    #
    $text =~ s/[^a-z ]//g;

    # Change space to dash
    #
    $text =~ s/ /-/g;

    return $text;
}

#------------------------------------------------------------------------------
# inASCIISet
#
# Ignore quote if it does not include the valid set of ASCII charaters
# expressed in the octal range \040-\176
#------------------------------------------------------------------------------

sub inASCIISet {
    my $text = shift;

    return 0 if ($text =~ m/[^\040-\176]/);

    return 1; 
}

#------------------------------------------------------------------------------
# validateKeywords
#
# Validate a list of comma-separated keywords
#------------------------------------------------------------------------------

sub validateKeywords {
    my $keywords = shift;

    my @keywords = split(/\s*,\s*/, $keywords);

    my @accepted = ();
    foreach my $keyword (@keywords) {
        &_isKeywordValid($keyword) and push @accepted, $keyword;
    }

    return @accepted;
}

#------------------------------------------------------------------------------
# _isKeywordValid
#
# Ignore keyword if it does not include only lowercase letters, numbers, and dashes
#------------------------------------------------------------------------------

sub _isKeywordValid {
    my $text = shift;

    return 0 if ($text =~ m/[^a-z0-9\-]/);

    return 1; 
}

1;
