package Util::DB;

#------------------------------------------------------------------------------
# Name       : Util::DB.pm
# Author     : Stuart Pineo  <svpineo@gmail.com>
# Description: Object Oriented wrapper to DBI implementing generic database 
# utilities. Use 'perldoc' to extract POD documentation (i.e., perldoc Util::DB)
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

use Carp qw(carp confess);

use DBI;

our $VERSION = 0.01;


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Methods
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# new
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

sub new($;$) {

	my $class = shift;
	my $db_config_file = shift;

	my $self = {};


	# Defaults
	#
	$self->{dbh} = undef;
	$self->{server} = undef;
	$self->{username} = undef;
	$self->{password} = undef;
	$self->{database} = undef;
	$self->{filename} = undef;


	# Output messages to STDERR if set to 1 (use methods msg and no_msg)
	#
	$self->{msg} = 0;


	# DBI trace
	#
	$self->{trace} = 0;


	# Exit on error
	#
	$self->{exit_on_error} = 1;


	bless $self;


	$db_config_file and $self->initialize($db_config_file);


	return $self;
}


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# msg and no_msg
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

sub msg($) {

	my $self = shift;

	$self->{msg} = 1;
}

sub no_msg($) {

	my $self = shift;

	$self->{msg} = 0;
}


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# exit_on_error
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

sub exit_on_error {

	my $self = shift;

	$self->{exit_on_error} = 1;
}

sub no_exit_on_error {

	my $self = shift;

	$self->{exit_on_error} = 0;
}


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# initialize
#
# Get the database parameters and connect
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

sub initialize($$) {

	my ($self, $db_config_file) = @_;


	# Initialization already took place
	#
	return undef if defined($self->{dbh});


	# Make sure that file exists and/or is readable
	#
	! -f $db_config_file and confess("Property file '$db_config_file' does not exist and/or is not readable: $!");

	my $propRef = &_parseConfig($db_config_file);


	# Extract the properties
	#
	$self->{conn_str} = $propRef->{'conn_str'};
	$self->{server}   = $propRef->{'server'};
	$self->{host}     = $propRef->{'host'};
	$self->{username} = $propRef->{'username'};
	$self->{password} = $propRef->{'password'};
	$self->{database} = $propRef->{'database'};
	$self->{sid}      = $propRef->{'sid'};
	$self->{filename} = $propRef->{'filename'};


	# Establish the database connection
	#
	$self->_db_connect();
}


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# _db_connect
#
# Connect to the database
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

sub _db_connect($) {

	my $self = shift;

	my $connect_string;

    # Option to pass the full connection string directly
    #
    my $cstring  = $self->{conn_str};

	my $server   = $self->{server};
	my $host     = $self->{host};
	my $username = $self->{username};
	my $password = $self->{password};
    my $database = $self->{database};
	my $sid      = $self->{sid};

    if ($cstring) {
        $connect_string = $cstring;

    } elsif ($server =~ m/sqlite/i) {
        my $filename    = $self->{filename};
        $connect_string = "dbi:SQLite:dbname=$filename";

	} elsif ($server =~ m/mysql/i) {
		$connect_string = "dbi:mysql:database=$database;host=$host";

	} elsif ($server =~ m/postgresql/i) {
        $connect_string = "dbi:Pg:dbname=$database;host=$host";

	} elsif ($server =~ m/oracle/i) {
		$connect_string = "dbi:Oracle:host=$host;sid=$sid";

	} else {
		$connect_string = "dbi:$server:$sid";
	}


	eval {
		$self->{dbh} = DBI->connect($connect_string, $username, $password,
		{ AutoCommit => 0, RaiseError => 0, PrintError => 0 });

	};
	if ($@ and $@ =~ /TNS:/ ) {
		$self->{dbh} = DBI->connect($connect_string, $username, $password,
		{ AutoCommit => 0, RaiseError => 0, PrintError => 0 });
	}
	if (not defined $self->{dbh}) {
		confess "Unable to connect to database $sid: " . $DBI::errstr . "\n";
	}

	if ($self->{msg}) {
		print STDERR "Successfully connected to '$sid'\n";
		print STDERR "AutoCommit attribute default: " . $self->getAttr('AutoCommit') . "\n";
		print STDERR "RaiseError attribute default: " . $self->getAttr('RaiseError') . "\n";
		print STDERR "PrintError attribute default: " . $self->getAttr('PrintError') . "\n";
	}
}


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# setAttr/getAttr
#
# Set/get database handle attributes
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

sub setAttr($$$) {

	my ($self, $key, $value) = @_;

	my $dbh = $self->{dbh};

	not $dbh and confess("Method 'initialize' must be called first to establish a connection: $!");

	$self->{msg} and print STDERR "Attribute '$key' set to '$value'\n";

	$dbh->{$key} = $value;
}


sub getAttr($$) {

	my ($self, $key) = @_;

	my $dbh = $self->{dbh};

	not $dbh and confess("Method 'initialize' must be called first to establish a connection: $!");

	my $value = $dbh->{$key} || 0;

	return $value;
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# setLongReadLen and setLOB
#
# Set 'LongReadLen' to handle clobs. Default is maximum buffer.
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

sub setLOB {

	my ($self, $value, $trunc_ok) = @_;

	my $dbh = $self->{dbh};

	not $dbh and confess("Method 'initialize' must be called first to establish a connection: $!");

	if ($value) {
		$dbh->{'LongReadLen'} = $value;

		if ($trunc_ok) {
			$dbh->{'LongTruncOk'} = 1;
		}

	} else {

		$dbh->{'LongReadLen'} = 1024 * 4096;
	}
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# setTrace/getTrace
#
# Set/get DBI trace
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

sub setTrace($$;$) {

	my ($self, $value, $log_file) = @_;

	$self->{trace} = $value;

	if ($log_file) {

		! -f $log_file and confess("Log file is not readable and/or doesn't exist: $!");

		DBI->trace($value, $log_file);

	} else {

		DBI->trace($value);
	}

	$self->{msg} and print STDERR "DBI Trace set to '$value'\n";
}

sub getTrace($) {

	my $self = shift;

	return $self->{trace};
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# getDatabaseName
#
# Retrieve the database name (uppercased) as specified in the configuration file.
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

sub getDatabaseName {

	my $self = shift;

	return uc($self->{'database'});
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# select
#
# Select one or more values
# Input: SQL statement and optionally one or more place holders
# Output: Nested array of arrays (with each subarray representing an instance)
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

sub select($$;@) {

	my $self = shift;
	my $context_param = shift;

	# For now, not returning what gets assigned to this variable
	#
	my $err_msg;
	my $dbh = $self->{dbh};


	# Can pass a SQL string or a statement handle
	#
	my ($sth, $sql);
	if (ref $context_param eq 'DBI::st') {
		$sth = $context_param;
	} else {
		$sth = $dbh->prepare($context_param) or $err_msg = $self->_cleanup("Prepare failed for operation: $context_param " . $dbh->errstr);
	}


	# Bind any parameters
	#
	my $bind_ct = 1;
	foreach my $param (@_) {
		$sth->bind_param($bind_ct, $param);
		$bind_ct++;
	}

	my $stat = $sth->execute() or $err_msg = $self->_cleanup("Execute Failed: " . $sth->errstr);

	my $values = [];
	while (my @row = $sth->fetchrow_array()) {
		push(@$values, \@row);
	}

	(ref $context_param ne 'DBI::st') and $sth->finish;

	return $values;
}


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# select_hash
#
# Select one or more values as key value pairs
# Input: SQL statement and optionally one or more place holders
# Output: Nested array of hashes (with each subhash representing an instance)
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

sub select_hash($$;@) {

	my $self = shift;
	my $context_param = shift;

	# For now, not returning what gets assigned to this variable
	#
	my $err_msg;
	my $dbh = $self->{dbh};


	# Can pass a SQL string or a statement handle
	#
	my ($sth, $sql);
	if (ref $context_param eq 'DBI::st') {
		$sth = $context_param;
	} else {
		$sth = $dbh->prepare($context_param) or $err_msg = $self->_cleanup("Prepare failed for operation: $context_param " . $dbh->errstr);
	}


	# Bind any parameters
	#
	my $bind_ct =1;
	foreach my $param (@_) {
		$sth->bind_param($bind_ct, $param);
		$bind_ct++;
	}

	my $stat = $sth->execute() or $err_msg = $self->_cleanup("Execute Failed: " . $sth->errstr);

	my $values = [];
	while (my $row = $sth->fetchrow_hashref()) {
		push(@$values, \%$row);
	}

	(ref $context_param ne 'DBI::st') and $sth->finish;

	return $values;
}


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# tie_hash_select
#
# Select one or more key-value paris into a tie hash (with value set to 1)
# Input: SQL statement and optionally one or more place holders
# Output: Key-value pairs
# Limitation: Only useful for selecting a single column.
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

sub tie_hash_select($$$;%) {

	my $self = shift;
	my $context_param = shift;
	my $tie_hash = shift;

	# For now, not returning what gets assigned to this variable
	#
	my $err_msg;
	my $dbh = $self->{dbh};


	# Can pass a SQL string or a statement handle
	#
	my ($sth, $sql);
	if (ref $context_param eq 'DBI::st') {
		$sth = $context_param;
	} else {
		$sth = $dbh->prepare($context_param) or $err_msg = $self->_cleanup("Prepare failed for operation: $context_param " . $dbh->errstr);
	}


	# Bind any parameters
	#
	my $bind_ct =1;
	foreach my $param (@_) {
		$sth->bind_param($bind_ct, $param);
		$bind_ct++;
	}

	my $stat = $sth->execute() or $err_msg = $self->_cleanup("Execute Failed: " . $sth->errstr);

	while (my @row = $sth->fetchrow_array()) {
		$tie_hash->{$row[0]} = 1;
	}

	(ref $context_param ne 'DBI::st') and $sth->finish;

	return %$tie_hash;
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# single_select
#
# Select a single item
# Input: SQL statement and optionally one or more place holders
# Output: Single item returned
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

sub single_select ($$;@) {

	my $self = shift;
	my $context_param = shift;

	my $values = $self->select($context_param, @_);

	if (@$values) {

		return $values->[0]->[0];
	}

	return undef;
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# insert/update/delete/exec_sql
#
# Insert/Update/Delete/generic exec
# Input: SQL statement and optionally one or more place holders
# Output: Status of operation (i.e., number of rows affected)
# Note: Current behaviour is the same for all so all run '_exec_statement'
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

sub insert($$;@) { return _exec_statement(@_); }

sub update($$;@) { return _exec_statement(@_); }

sub delete($$;@) { return _exec_statement(@_); }

sub exec_sql($$;@) { return _exec_statement(@_); }

sub _exec_statement($$;@) {

	my $self = shift;
	my $context_param = shift;

	my $dbh = $self->{dbh};
	my $err_msg;

	# Can pass a SQL string or a statement handle
	#
	my ($sth, $sql);
	if (ref $context_param eq 'DBI::st') {
		$sth = $context_param;
	} else {
		$sth = $dbh->prepare($context_param) or $err_msg = $self->_cleanup("Prepare failed for operation: $context_param " . $dbh->errstr);
	}


	# Bind any parameters
	#
	my $bind_ct = 1;
	foreach my $param (@_) {

		$sth->bind_param($bind_ct, $param) or $err_msg = $self->_cleanup("Bind failed for parameter '$param':" . $dbh->errstr);
		$bind_ct++;
	}

	my $stat = $sth->execute() or $err_msg = $self->_cleanup("Execute Failed: " . $sth->errstr);

	(ref $context_param ne 'DBI::st') and $sth->finish;

	my @params = caller(1);
	($params[3] =~ m/delete/i) and return ($stat, $err_msg);

	return $err_msg;
}

sub prepare($$) {

	my ($self, $sql) = @_;

	my $dbh = $self->{dbh};
	my $sth = $dbh->prepare($sql) or confess("Unable to prepare" . $dbh->errstr);

	return $sth;
}

sub commit {

	my $self = shift;

	my $dbh = $self->{dbh};

	$dbh->commit;
}

sub rollback {

	my $self = shift;

	my $dbh = $self->{dbh};

	$dbh->rollback;
}

sub finish {

	my ($self, $sth) = @_;

	(ref $sth eq 'DBI::st') and $sth->finish;
}


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# disconnect
#
# Disconnect from the database
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

sub disconnect($) {

	my $self = shift;

	my $dbh = $self->{dbh};
	my $database = $self->{sid};

	# Disconnect from the database
	#
	if (defined $dbh) {

		$self->{msg} and print STDERR "Disconnecting from '$database'\n";

		$dbh->disconnect;
	}
}


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# _cleanup
#
# confess or carp in case of error. Return error (if carp).
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

sub _cleanup {

	my ($self, $err_msg) = @_;

	if ($self->{'exit_on_error'}) {
		confess($err_msg);

	} else {
		carp($err_msg);
		return $err_msg;
	}
}


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# get_sql
#
# Substitute placeholders with actual values. Numeric values get quoted since
# type determination is more involved (this is the DBI 'execute' behaviour).
# Embedded quotes are escaped with quotes by using the 'quote' method.
#
# WARNING: For now, no type checking for CLOBS and other 'reference' data types
# that may cause problems in selects using placeholders.
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

sub get_sql {

	my ($self, $sql, @values) = @_;

	my $dbh = $self->{dbh};
	return undef if ! defined($dbh);


	# If no values supplied, simply return quoted sql
	#
	! @values and return $sql;


	# Verify that number of values matches the number of placeholders
	#
	my $count1 = @values;
	my @count2 = split(/\?/,"$sql");
	my $count2 = @count2 - 1;

	if ($count1 != $count2) {
		carp("Number of values must match number of placeholders");
		return undef;
	}


	foreach my $value (@values) {

		my $new_value = $dbh->quote($value);

		$sql =~ s/\?/$new_value/;
	}

	return $sql;
}


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# cleanup
#
# Rollback or commit, depending on the error status, and finish/disconnect.
# Print optional error message and exit with supplied error status.
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

sub cleanup {

	# Enforce correct usage
	#
	die("Bad usage: 'cleanup' needs at minimum a db handle followed by a numeric error status:")
	unless ( ( ref(\$_[0]) eq 'REF' ) and ( $_[1] =~ m/^\d+$/ ) );

	my ($self, $err_stat, $err_msg) = @_;

	if ($err_stat == 0) {
		$self->commit;
		print STDERR "Committing any open transactions.\n";

	} else {
		$self->rollback;
		print STDERR "Rolling back any unfinished transactions.\n";
	}
	$self->finish;
	$self->disconnect;

	print STDERR "$err_msg\n";

	exit($err_stat);
}


#------------------------------------------------------------------------------
# _parseConfig
#
# Parse the configuration file, return a nested reference structure
#------------------------------------------------------------------------------

sub _parseConfig {
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

1;

__END__

=head1 NAME

Util::DB.pm

=head1 SYNOPSIS

=head2 Usage Examples

=over

=item I<Instantiation and Initialization>

   use Util::DB;
   my $dbObj = new Util::DB();

   $dbObj->msg;
   $dbObj->initialize($DB_CONFIG_FILE);     # This can be passed as a command-line argument
   $dbObj->setAttr('AutoCommit', 1);
   $dbObj->setTrace(2);
   $dbObj->no_exit_on_error;

   print STDERR "Current setting for RaiseError is: " . $dbObj->getAttr('RaiseError') . "\n";

=item I<Select>

   my $sql =<<_END;
   select id, keyword
   from myquotes_keyword
   where keyword = ?
   _END

   my $values = $dbObj->select($sql, $keyword);

   # Alternatively, for this and other operations
   # a statement handle can first be created and
   # passed instead of the SQL string
   #
   my $sth = $dbObj->prepare($sql);
   my $values = $dbObj->select($sth, $keyword);
   $dbObj->finish($sth);


   # Single select
   #
   my $name = 'Albert Einstein';
   my $sql = <<_END;

   select * from myquotes_author
   where lower(full_name) = lower(?)
   _END

   my $values = $dbObj->single_select($sql, $name);


   # Select hash
   # Returns and array of hash elements where key is the
   # table column name
   #
   my $values = $dbObj->select_hash($sql, $name);


=item I<Insert>

   my @values = ( 'Albert Einsten', '1879-03-14', '1955-04-18', 'German-born physicist', 'https://en.wikipedia.org/wiki/Albert_Einstein');

   my $sql_ins =<<_END;
   insert into myquotes_author
   values (?,?,?,?)
   _END

   my $stat = $dbObj->insert($sql_ins, @values);

=item I<Update>

   my $sql_upd =<<_END;
   update myquotes_author
   set bio_entract = ?
   where id = ?
   _END

   my $stat = $dbObj->update($sql_upd, 5, 'German-born physicist and developer of the Theory of Relativity');

=item I<Delete>

   my $name = 'Albert Einstein';
	
   my $sql_del =<<_END;
   delete myquotes_author
   where full_name = ?
   _END

   my $stat = $dbObj->delete($sql_del, $name);

   print STDERR "Number of Rows Affected: $stat\n";

=item I<Retrieve SQL>

	my @values = ('30099999999999', 'SOME_STATUS', 1);

	my $sql = <<_END;

	insert into SOME_TABLE
	(id, status, type, virtual, create_date)
	values
	(?, ?, 10, ?, sysdate)

	_END

	# Useful for verifying what the actual SQL looks like
	# (i.e., return with placeholders filled and print)
	#
	my $new_sql = $dbObj->get_sql($sql, @values);

	print STDERR "$new_sql\n";

	$dbObj->insert($sql, @values);

	$dbObj->disconnect;

=item I<Other Operations>

   $dbObj->commit;
   $dbObj->rollback;
   $dbObj->disconnect();

=back

=head1 DESCRIPTION

Object Oriented Wrapper to generic database utilities.


=head2 Public Methods

=over

=item I<new>

Instantiate Util::DB.pm. Takes a database ("=" delimiter) property file containing any required lower-cased properties such as 'database', 'filename' (if SQLite), 'username', 'password', and other Database properties including the full connection string 'conn_str' short-cut (see 'initialize' below)

=item I<msg>

Enable verbose output

=item I<no_msg>

Disable verbose output (default behaviour)

=item I<initialize>

Same as new, returns undef if $dbh already set. Calls the _db_connect private method with one or more properties below:

    $self->{conn_str} = $propRef->{'conn_str'};
    $self->{server}   = $propRef->{'server'};
    $self->{host}     = $propRef->{'host'};
    $self->{username} = $propRef->{'username'};
    $self->{password} = $propRef->{'password'};
    $self->{database} = $propRef->{'database'};
    $self->{sid}      = $propRef->{'sid'};
    $self->{filename} = $propRef->{'filename'};

Tested on SQLite and Oracle (but not others such as MySQL and PostgreSQL)

=item I<setAttr>

Takes as argument a database attribute and value. Valid database attributes include AutoCommit, RaiseError, and PrintError. Default settings for each is 0.

=item I<getAttr>

Return the current value of a database attribute.

=item I<setTrace>

Enable DBI tracing if the value is greater than 0. The higher the value the more verbose the tracing. By default, DBI tracing is disabled. Optionally, tracing can be redirected to a log file (second argument of I<setTrace>)

=item I<exit_on_error>

Exit the program whenever an error occurs (default behaviour). Calls 'confess' for verbose output.

=item I<no_exit_on_error>

Do not exit the program when an error occurs. Call 'carp' with warning output to STDERR. This feature is useful when batches of data need to be processed and exiting a program is undesirable.

=item I<prepare>

Wrapper to DBI->prepare(). The explicit prepare is recommended when a single invocation is preferred (i.e., when executing the same SQL multiple times multiple prepares can turn out to be costly and unnecessary).

=item I<select>

Takes as argument a SQL select string and if defined, one or more placeholders. Return value is a nested array reference with each sub-array containing number of elements corresponding to number of columns queried. Alternatively, a statement handle can be passed instead of the SQL string and the program determines what course of action to take based on context.

=item I<single_select>

Takes as argument a SQL select string and if defined, one or more placeholders.  It differs from select in that it returns a single scalar value (rather than array ref). Like I<select>, a statement handle can be passed instead of the SQL string.

=item I<insert>

Takes as argument a SQL insert string and if defined, one or more placeholders. A statement handle can be supplied instead of the SQL string.

=item I<update>

Takes as argument a SQL update string and if defined, one or more placeholders. A statement handle can be supplied instead of the SQL string.

=item I<delete>

Takes as argument a SQL delete string and if defined, one or more placeholders. A statement handle can be supplied instead of the SQL string.

=item I<get_sql>

Return the SQL statement with placeholders filled.

=item I<commit>

Explicitly commit a transaction. Works only when the 'AutoCommit' attribute is set to zero.

=item I<rollback>

Explicitly rollback a transaction. Works only when the 'AutoCommit' attribute is set to zero. The explicit rollback is also required since DBI automatically commits when a program dies or exits.

=item I<finish>

Explicitly destroy a statement handle. Takes as argument a pre-defined statement handle.

=item I<disconnect>

Close the DBI connection.

=back

=head1 AUTHOR

Stuart Pineo <svpineo@gmail.com>

=cut


