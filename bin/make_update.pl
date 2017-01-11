#!/usr/bin/env perl -w

#------------------------------------------------------------------------------
# Name       : make_update.pl
# Author     : Stuart Pineo  <svpineo@gmail.com>
# Usage      : ./make_update.pl --db-file "path to db file" 
#                             [ --version-file "version file" ]
# Description: Create a new App database update, deploy it to GitHub, 
# and trigger the Jenkins build.
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
# Copyright (c) 2017 Stuart Pineo
#
#------------------------------------------------------------------------------

use strict;
use warnings;

# Use relative path or export PERL5LIB to include absolute path
#
use lib qw(../lib);

use Getopt::Long;
use Carp qw(croak carp);
use Data::Dumper;
use File::Copy qw(copy);
use Cwd;
use Util::GenericUtils qw(isFile isPath trim_all);

# Global variables
#
our $COMMAND = `basename $0`;
chomp($COMMAND);

our $VERSION = "1.0";

# Generic variables
#
our $VERBOSE = 0;
our $DEBUG = 0;

our ($DB_FILE, $DEST_DIR, $VERSION_FILE);
our $DEF_VERSION_FILE = 'version.txt';

use Getopt::Long;
GetOptions(
    'db-file=s'   => \$DB_FILE,
    'dest-dir=s'  => \$DEST_DIR,
    'vers-file=s' => \$VERSION_FILE,
    'debug'       => \$DEBUG,
    'verbose'     => \$VERBOSE,
    'help|usage'  => \&usage,
);

# Validation
#
# Check that database file is supplied and is valid
#
! $DB_FILE and &usage("Command-line argument --db-file must be supplied.");
! isFile($DB_FILE) and die("File '$DB_FILE' not found.");

# Check that destination directory is valid (if provided, else use the current directory)
#
($DEST_DIR and ! isPath($DEST_DIR)) and die("Destination directory '$DEST_DIR' not found.");
! $DEST_DIR and $DEST_DIR = getcwd();
$DEBUG and print STDERR "Destination Directory: $DEST_DIR\n";

# Copy the file (if --dest-dir not provided, current directory)
#
copy($DB_FILE, $DEST_DIR) or die("File copy '$DB_FILE' to '$DEST_DIR' failed.");

# Update the version file (use the default if not supplied)
#
my $version_file = $VERSION_FILE ? $VERSION_FILE : $DEF_VERSION_FILE;
my $version_path = qq|$DEST_DIR/$version_file|;
! isFile($version_path) and die("Version file '$version_path' not found.");
open(my $rfh, $version_path) or die("Unable to open '$version_path' for reading.");
my ($version, $update) = map{ trim_all($_); $_ } split('-', <$rfh>);
close $rfh;

$update+=1;
$DEBUG and print STDERR "Database Version=$version, New Update=$update\n";

open(my $wfh, '>', $version_path) or die("Unable to open '$version_path' for writting.");
print $wfh qq|$version-$update\n|;
close $wfh;


#------------------------------------------------------------------------------
# usage: Print usage when invoked with -help or -usage
#------------------------------------------------------------------------------

sub usage {
    my $error = shift;
    $error and print STDERR "Error: $error\n";

    print STDERR <<_USAGE;
Usage:   ./$COMMAND --db-file "Database File" [ --debug --verbose ]
Example: ./$COMMAND --db-file ""
_USAGE

    exit(1);
}
