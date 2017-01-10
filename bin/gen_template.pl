#!/usr/bin/env perl -w

###############################################################################
# Name       : gen_template.pl
# Author     : Stuart Pineo <svpineo@gmail.com>
# Usage      : ./gen_template.pl my_script.pl
# Description:
#
# Copyright (c) 2017 Stuart Pineo
#
##############################################################################

our $SCRIPT  = shift @ARGV;

our $AUTHOR  = qq|Stuart Pineo|;
our $EMAIL   = qq|svpineo\@gmail.com|;
our $YEAR    = qq|2017|;
our $VERSION = qq|1.0|;

our $HEADER =<<_END;
#!/usr/bin/env perl -w
#------------------------------------------------------------------------------
# Name       : $SCRIPT
# Author     : $AUTHOR  <$EMAIL>
# Usage      :
# Description:
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
# Copyright (c) $YEAR $AUTHOR
#
#------------------------------------------------------------------------------
_END

our $BODY =<<_END;
use strict;
use warnings;

use Getopt::Long;

# Global variables
#
our \$COMMAND = `basename \$0`;
chomp(\$COMMAND);

our \$VERSION = "$VERSION";

# Generic variables
#
our \$VERBOSE = 0;
our \$DEBUG = 0;

use Getopt::Long;
GetOptions(
    'debug'      => \$DEBUG,
    'verbose'    => \$VERBOSE,
    'help|usage' => \&usage,
);

#------------------------------------------------------------------------------
# usage: Print usage when invoked with -help or -usage
#------------------------------------------------------------------------------

sub usage {
    print STDERR <<_USAGE;
Usage:   ./\$COMMAND --debug --verbose
Example: ./\$COMMAND --debug --verbose
_USAGE

    exit(1);
}

_END

# Create the script
#
open(my $fh, ">", $SCRIPT)
	or die "Can't open $SCRIPT for writting: $!";
print $fh <<_END;
$HEADER
$BODY
_END
close $fh;

# Make script executable
#
chmod 0770, $SCRIPT;
