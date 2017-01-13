#!/usr/bin/env perl -w

#------------------------------------------------------------------------------
# Name       : make_update.pl
# Author     : Stuart Pineo  <svpineo@gmail.com>
# Usage      : ./make_update.pl --db-dir "path to db directory" 
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
use Util::GenericUtils qw(isFile isPath trim);

# Global variables
#
our $COMMAND = `basename $0`;
chomp($COMMAND);

our $VERSION = "1.0";

# Generic variables
#
our $VERBOSE = 0;
our $DEBUG = 0;

our ($DB_DIR, $DEST_DIR, $VERSION_FILE);
our $DEF_VERSION_FILE = 'version.txt';

use Getopt::Long;
GetOptions(
    'db-dir=s'    => \$DB_DIR,
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
! $DB_DIR and &usage("Command-line argument --db-dir must be supplied.");
! isPath($DB_DIR) and die("DB directory '$DB_DIR' not found.");

# Check that destination directory is valid (if provided, else use the current directory)
#
($DEST_DIR and ! isPath($DEST_DIR)) and die("Destination directory '$DEST_DIR' not found.");
! $DEST_DIR and $DEST_DIR = getcwd();
$DEBUG and print STDERR "Destination Directory: $DEST_DIR\n";

# Process the version file (use the default if not supplied)
#
my $version_file = $VERSION_FILE ? $VERSION_FILE : $DEF_VERSION_FILE;
my $version_path = qq|$DEST_DIR/$version_file|;
! isFile($version_path) and die("Version file '$version_path' not found.");
open(my $rfh, $version_path) or die("Unable to open '$version_path' for reading.");
my ($db_name, $db_ext, $version, $update) = map{ trim($_); $_ } split('-', <$rfh>);
close $rfh;

# Copy the file (if --dest-dir not provided, current directory)
#
my $db_file_name = qq|$db_name\.$db_ext|;
my $db_file = qq|$DB_DIR/$db_file_name|;
! isFile($db_file) and die("DB File '$db_file' not found.");
copy($db_file, $DEST_DIR) or die("File copy '$db_file' to '$DEST_DIR' failed.");

# Update the version
#
$update+=1;
$DEBUG and print STDERR "DB Name=$db_name, DB Ext=$db_ext, DB Version=$version, New Update=$update\n";

# Re-construct the version file
#
open(my $wfh, '>', $version_path) or die("Unable to open '$version_path' for writting.");
print $wfh qq|$db_name-$db_ext-$version-$update\n|;
close $wfh;

# Compute the MD5
#
my $db_dest_name = qq|$DEST_DIR/$db_file_name|;
$db_dest_name =~ s| |\\ |g;
my $md5 = `md5 $db_dest_name`;
($? > 0) and die "md5 calculation for '$db_dest_name' failed.";
chomp $md5;
$md5 =~ s|^.* ||;


#------------------------------------------------------------------------------
# usage: Print usage when invoked with -help or -usage
#------------------------------------------------------------------------------

sub usage {
    my $error = shift;
    $error and print STDERR "Error: $error\n";

    print STDERR <<_USAGE;
Usage:   ./$COMMAND --db-dir "Database directory" [ --debug --verbose ]
Example: ./$COMMAND --db-file ""
_USAGE

    exit(1);
}
