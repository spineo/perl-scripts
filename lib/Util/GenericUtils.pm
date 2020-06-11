package Util::GenericUtils;

#------------------------------------------------------------------------------
# Name       : Util::GenericUtils.pm
# Author     : Stuart Pineo  <svpineo@gmail.com>
# Description: Generic utilities
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

use Carp qw(croak carp confess);
use File::Copy qw(copy);

require Exporter;

use vars    qw($VERSION @ISA @EXPORT_OK);


$VERSION = 0.01;


@ISA = qw( Exporter );

@EXPORT_OK = qw(trim trim_all trim_ctrl has_carriage_return datestamp date2comps get_env is_file is_path send_mail exec_script safe_copy logger deep_copy compute_md5);



# ********************************************************************************
#
# Data Cleanup
#
# ********************************************************************************
#------------------------------------------------------------------------------
# trim
#
# Remove preceding/ending and excess spaces from a string
#------------------------------------------------------------------------------

sub trim {
    my $string = shift;

    $string =~ s/^\s+//;
    $string =~ s/\s+$//;
    $string =~ s/\s+/ /g;

    return $string;
}


#------------------------------------------------------------------------------
# trim_all
#
# Remove all spaces from a string
#------------------------------------------------------------------------------

sub trim_all {
    my $string = shift;

    $string =~ s/\s+//g;

    return $string;
}


#------------------------------------------------------------------------------
# trim_ctrl
#
# Remove control characters outside of [ -~] range from text.
#------------------------------------------------------------------------------

sub trim_ctrl {
    my $string = shift;

    $string =~ s/[^ -~\t]$/\n/;        # Replace trailing control characters for newline
    $string =~ s/[^ -~\t]//g;        # Global removal of remaining control characters

    return $string;
}


#------------------------------------------------------------------------------
# has_carriage_return
#
# Test if string has embedded carriage returns
#------------------------------------------------------------------------------

sub has_carriage_return {
    my $string = shift;

    return 1 if ($string =~ m/\r/);

        return 0;
}


# ********************************************************************************
#
# Date 
#
# ********************************************************************************
#------------------------------------------------------------------------------
# datestamp
#
# Generate a datestamp using the YYYYMMDD format (useful for sorting).
# The datestamp is a component in the error log name.
#------------------------------------------------------------------------------

sub datestamp {
    my ($time, $format) = @_;

    # Get today's date and create a date stamp (YYYYMMDD format) or user specified format
    #
    my @datetime;
    if (defined($time) && $time && ($time =~ m/^\d+$/)) {
        @datetime = localtime ($time);    # If time omitted, returns current time
    } else {
        @datetime = localtime ();    # If time omitted, returns current time
    }

    my $year = 1900 + $datetime[5];
    my $month = 1 + $datetime[4];   # Convert to 1-12 range
    $month =~ s/^\d$/0$&/;          # ...and '0' pad single digits
    my $day = $datetime[3];
    $day =~ s/^\d$/0$&/;         # '0' pad single digits


    my $hour = $datetime[2];
    $hour =~ s/^\d$/0$&/;         # '0' pad single digits
    my $min = $datetime[1];
    $min =~ s/^\d$/0$&/;         # '0' pad single digits
    my $sec = $datetime[0];
    $sec =~ s/^\d$/0$&/;         # '0' pad single digits

    my $formatted_date;

    if (defined($format) && $format) {
        ($format =~ s/Y{4}/$year/) or ($format =~ s/Y+/substr($year,2)/e);
        $format =~ s/M+/$month/;
        $format =~ s/D+/$day/;

        $format =~ s/h+/$hour/;
        $format =~ s/m+/$min/;
        $format =~ s/s+/$sec/;

        $formatted_date = $format;

    } else {
        $formatted_date = "$year$month$day";
    }
    return $formatted_date;
}

#------------------------------------------------------------------------------
# date2format
#
# Parse the year, month, and day components of a date.
#------------------------------------------------------------------------------

sub date2comps {
    my $date_str = shift;

    my %month_num = ( 'january',   '01',
                      'february',  '02',
                      'march',     '03',
                      'april',     '04',
                      'may',       '05',
                      'june',      '06',
                      'july',      '07',
                      'august',    '08',
                      'september', '09',
                      'october',   '10',
                      'november',  '11',
                      'december',  '12');

    $date_str =~ s/[^0-9a-zA-Z]/ /g;
    $date_str = lc(trim($date_str));

    my @comps = split(/ /, $date_str);
    my $year  = '';
    my $month = '';
    my $day   = '';
    my $ct = 0;
    foreach my $comp (@comps) {
        if ($comp =~ m/^\d{3,4}$/) {
            $year = $comp;
            $ct++;

        } elsif ($comp =~ m/^[a-z]+$/) {
            $month = $month_num{$comp};
            $ct++;

        } elsif ($comp =~ m/^\d{1,2}$/) {
            if ($ct == 1 and ! $month) {
                $month = $comp;
                $month =~ s/^\d$/0$&/;
            } else {
                $day = $comp;
                $day =~ s/^\d$/0$&/;
            }
            $ct++;
        }
    }

    my @ret_comps = ();
    $year  and  push @ret_comps, $year;
    $month and push @ret_comps, $month;
    $day   and push @ret_comps, $day;

    return @ret_comps;
}

# ********************************************************************************
#
# Validation
#
# ********************************************************************************
#------------------------------------------------------------------------------
# get_env
#
# Extract the environment variable. Log a message if not defined.
#------------------------------------------------------------------------------

sub get_env {
    my $key = shift;
    my $value = $ENV{$key};

    ! defined($value) and croak("Environment variable '$key' is not defined: $!");

    return $value;
}

#------------------------------------------------------------------------------
# is_file
#
# Validate a file
#------------------------------------------------------------------------------

sub is_file {
    my $file = shift;

    $file =~ s/^\s+//;
    $file =~ s/\s+$//;

    ! -f $file and croak("The specified file '$file' does not exist or is not readable: $!");

    return $file;
}


#------------------------------------------------------------------------------
# is_path
#
# Validate a path
#------------------------------------------------------------------------------

sub is_path {
    my $path = shift;

    $path =~ s/^\s+//;
    $path =~ s/\s+$//;

    ! -d $path and croak("The specified directory '$path' does not exist: $!");

    return $path;
}


#------------------------------------------------------------------------------
# send_mail
#
# Send an email message using the /usr/bin/mailx utility. The email body is
# extracted from a file.
#------------------------------------------------------------------------------

sub send_mail {
    croak("Bad call to send_mail - expect a single hash ref")
    unless @_ == 1 and ref $_[0] eq "HASH";    

    my $params = shift;

    my $subject = $params->{Subject};
    my $to = $params->{To};
    my $file = $params->{File};
    my $body = $params->{Body};

    # Slurp the error log file
    #
    my @email_body;
    if ($file) {
        open (BODY, $file) or croak("Cannot open '$file': $!");
        @email_body = <BODY>;
        close(BODY);

    # ...or use a string
    #
    } else {
        @email_body = split(/$/, $body);
    }

    # Send notification
    #
    open(MAIL, qq{|/bin/mail -s "$subject" $to }) or croak("Couldn't fork: $!");
    print MAIL qq{@email_body};
    close(MAIL) or croak("Couldn't close: $!");
}

#------------------------------------------------------------------------------
# exec_script
#
# Check that the executable bit is set and execute the script. Return specific
# errors and/or output from the execution.
#------------------------------------------------------------------------------

sub exec_script {
    my $sys_call = shift;

    # (1) Make sure that the executable bit is set
    #
    my @comps = split(/\s+/, $sys_call);
    my $script = $comps[0];

    if ( not -x $script ) {
        return ("$script is not executable.", undef);
    }


    # (2) Execute the system call
    #
    # Invoke system call trapping any output
    #
    my $output;
    my $pid = open(PROG_OUTPUT, "$sys_call|") or return("Cannot fork '$sys_call': $!", undef);
    while (<PROG_OUTPUT>) {
        $output .= $_;
    }
    close(PROG_OUTPUT);

    if ($? > 0) {
        return ("System call '$sys_call' exited with error: $!", $output);
    }

    return (undef, $output);
}


#------------------------------------------------------------------------------
# safe_copy
#
# Perform a 'safe' copy: Ensure that the last mod time (seconds) hasn't changed.
#------------------------------------------------------------------------------

sub safe_copy {
    my ($source, $target) = @_;

    # Make sure that the source file exists
    #
    not -f $source and croak("Source file '$source' not found");

    # Check the last mod timestamp (in seconds since the epoch)
    #
    my $pre_ts = (stat($source))[9];
    copy($source, $target) or croak("Copy '$source' to '$target' failed");
    my $post_ts = (stat($source))[9];

    ($pre_ts != $post_ts) and croak("Source file '$source' last modification time stamp has changed during the copy");

    return 0;
}


#------------------------------------------------------------------------------
# logger
#
# Log messages to specified log file and optionally, standard error
#------------------------------------------------------------------------------

sub logger {
    my ($log_file_handle, $err_msg, $level) = @_;

    if (not $level) {
        print STDERR "$err_msg";
    }
    print $log_file_handle "$err_msg";
}


#------------------------------------------------------------------------------
# deep_copy
#
# Recursively make a copy of a perl reference structure
#------------------------------------------------------------------------------

sub deep_copy {
    my ($self, $this) = @_;
    if (not ref $this) {
        $this;
    } elsif (ref $this eq "ARRAY") {
        [map $self->deep_copy($_), @$this];
    } elsif (ref $this eq "HASH") {
        +{map { $_ => $self->deep_copy($this->{$_}) } keys %$this};
    } else { croak "what type is $_?" }
}

#------------------------------------------------------------------------------
# compute_md5
#
# Compute md5 checksum for a file
#------------------------------------------------------------------------------

sub compute_md5 {
    my $file_name = shift;

    # Escape any spaces
    #
    $file_name =~ s| |\\ |g;
    my $md5 = `md5 $file_name`;
    ($? > 0) and die "md5 checksum for '$file_name' failed.";
    chomp $md5;

    # Remove any prefix
    #
    $md5 =~ s|^.* ||;

    return $md5
}

1;
