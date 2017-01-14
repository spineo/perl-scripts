#!/usr/bin/perl -w

#------------------------------------------------------------------------------
# Name       : get_jenkins.pl
# Author     : Stuart Pineo  <svpineo@gmail.com>
# Usage      : ./get_jenkins.pl [ --all --filter "pattern" '
#                                 --dest-path "downloads location" ]
# Description: Scrape the Jenkins Updates repo for latest version of plugins,
# download the plugins, and create an archive.
# Notes:
# * In order to get anything, the --all or --filter options must be used.
# * Using --dest-path recommended (this were the *hpi files are dumped)
# * Ensure that LWP::Simple installed/compatible on the Mac OS
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

# Include the /bin path in the PATH var
# Use relative path below or export PERL5LIB var to include the /lib path
#
# Example:
# export PATH=/home/svpineo/perl-scripts/bin:$PATH
# export PERL5LIB=/home/svpineo/perl-scripts/lib
#
use lib qw(../lib);

use Getopt::Long;
use Carp qw(confess);
use Data::Dumper;

use LWP::Simple;
use Cwd qw(cwd);

# These found in ../lib
#
use Util::GenericUtils qw(is_path);

# Global variables
#
our $COMMAND = `basename $0`;
chomp($COMMAND);

our $VERSION = "1.0";

# Generic variables
#
our $VERBOSE       = 0;
our $DEBUG         = 0;

our ($ALL, $FILTER, $DEST_PATH);

our $ROOT_URL      = qq|https://updates.jenkins-ci.org|;
our $DOWNLOADS_URL = qq|$ROOT_URL/download/plugins|;
our $PLUGINS_URL   = qq|$ROOT_URL/latest|;

use Getopt::Long;
GetOptions(
    'all'         => \$ALL,        # Get latest versions for *ALL* plugins
    'filter=s'    => \$FILTER,     # Filter plugins that match the pattern (case insensitive)
    'dest-path=s' => \$DEST_PATH,  # Destination path (if not specified, uses current!)
    'debug'       => \$DEBUG,
    'verbose'     => \$VERBOSE,
    'help|usage'  => \&usage,
);

# Set the dest path
#
if (! $DEST_PATH) {
    $DEST_PATH = cwd();
}
! is_path($DEST_PATH) and die("Path '$DEST_PATH' not found.");
chdir $DEST_PATH;

# Retrieve all installations from root
#
my $updates = get $DOWNLOADS_URL;
die("Unable to retrieve content from '$DOWNLOADS_URL'") unless $updates;

my @updates = split(/<\/tr>/, $updates);
my $count = 0;
foreach my $line (@updates) {
    if ($line =~ m{href="([^"]+)/}) {
        my $plugin = $1;

        # Don't perform any additional handling unless --all or --filter used
        #
        next if ! ($ALL or $FILTER);

        # Filter? Skip if plugin does not contain the selected pattern (case insensitive)
        #
        next if ($FILTER and ($plugin !~ m|$FILTER|i));


        # Plugin url, at least for now, always points to the latest version
        #
        my $plugin_url = qq|$PLUGINS_URL/$plugin.hpi|;
        $DEBUG and print STDERR "$plugin_url\n";

        # Using curl, follow redirect for actual download
        #
        `curl -OL $plugin_url`;
        if ($? > 0) {
            confess("Download of plugin '$plugin_url' failed.");
            next;
        }

        $count++;
    }
}
print STDERR "$count plugins successfully downloaded.\n";


#------------------------------------------------------------------------------
# usage: Print usage when invoked with -help or -usage
#------------------------------------------------------------------------------

sub usage {
    print STDERR <<_USAGE;
Usage:   ./$COMMAND [ --all --filter "pattern" --dest-path "downloads dir" --debug --verbose ]
Example: ./$COMMAND --filter "pipeline" --debug
Note: In order to download anything, the --all or --filter (case insensitive) options must be used.
_USAGE

    exit(1);
}


