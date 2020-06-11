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

@EXPORT_OK = qw(parseConfig cleanupTagsText);


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
# cleanup
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

1;
