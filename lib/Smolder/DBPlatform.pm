package Smolder::DBPlatform;
use strict;
use warnings;
use Carp qw(croak);

use File::Spec::Functions qw(catdir catfile canonpath);

# these are needed for Class::DBI to recognize the db handle properly
our %CONNECT_OPTIONS = (
    RaiseError         => 1,
    PrintError         => 0,
    Warn               => 0,
    PrintWarn          => 0,
    AutoCommit         => 1,
    FetchHashKeyName   => 'NAME_lc',
    ShowErrorStatement => 1,
    ChopBlanks         => 1,
    RootClass          => 'DBIx::ContextualFetch',
);

=head1 NAME

Smolder::DBPlatform - base class for Database platform build modules

=head1 SYNOPSIS

  package Smolder::DBPlatform::MySQL;
  use base 'Smolder::DBPlatform';

=head1 DESCRIPTION

This module serves as a base class for the Database platform modules
which help to abstract away the database dependent constructs so
that Smolder can just operate without DB specific knowledge.
See F<docs/db_abstraction.pod> for more details on how the DB abstraction
works.

=head1 METHODS

This module is meant to be used as a base class, so the interface
consists of methods which should be overridden. Unless otherwise specified
each method is abstract.

All methods are called as class methods.  DB Platform modules are free to
use package variables to hold information between calls.

=head2 load

This method will look at the C<DBPlatform> configuration directive in
smolder.conf and determine which subclass to use, load it and return it.

    my $db_platform = Smolder::DBPlatform->load();

Or if you know the specific DB platform that you want you can just pass it
in.

    my $mysql_platform = Smolder::DBPlatform->load('MySQL');

=cut

sub load {
    my ( $class, $type ) = @_;

    # get the type from the config if we don't already have it
    unless ($type) {
        require Smolder::Conf;
        $type = Smolder::Conf->get('DBPlatform');
    }

    # load the class if we can
    my $subclass = 'Smolder::DBPlatform::' . $type;
    eval "require $subclass";
    if ($@) {
        croak "Failed to load $subclass. $@\n\nMaybe '$type' isn't a supported database?";
    }
    return $subclass;
}

=head2 verify_dependencies

Makes sure all required dependencies are in place before starting the
build, and before beginning installation.  The C<mode> parameter will
be either "build" or "install" depending on when the method is called.

This method should either succeed or die() with a message for the
user.

This should search for any required shared object files and header files
using L<Smolder::Platform>'s <check_libs()> method.

    $db_platform->verify_dependencies(mode => 'install')

=cut

sub verify_dependencies {
    my $class = shift;
    die "verify_dependencies() must be implemented in $class";
}

=head2 verify_admin

Given the password, hostname and database name, returns true if those credentials
can be used for administrative access to the database.

    $db_platform->verify_admin(
        passwd  => $pw,
        host    => 'localhost',
        db_name => 'smolder',
    );

=cut

sub verify_admin {
    my $class = shift;
    die "verify_admin() must be implemented in $class";
}

=head2 run_sql_file

Given the DB username, password, hostname, database name and full file name, runs the SQL
contained in the file.

    $db_platform->run_sql_file(
        user    => $user,
        passwd  => $pw,
        host    => $host,
        db_name => 'smolder',
        file    => '/usr/local/smolder/foo.sql',
    );

=cut

sub run_sql_file {
    my $class = shift;
    die "run_sql_file() must be implemented in $class";
}

=head2 dbh

Given the username, password, database name and host name will return the appropriate 
database handle.

    my $dbh = $db_platform->dbh(
        user    => 'smolder',
        passwd  => 's3cr3t',
        db_name => 'smolder',
        host    => 'localhost',
    );

=cut

sub dbh {
    my $class = shift;
    die "dbh() must be implemented in $class";
}

=head2 dbi_driver

Returns the class name of the C<DBI> driver that this DBPlatform module uses.

=cut

sub dbi_driver {
    my $class = shift;
    die "dbi_driver() must be implemented in $class";
}

=head2 cdbi_class

Returns the class name of the C<Class::DBI> driver that this DBPlatform module uses.

=cut

sub cdbi_class {
    my $class = shift;
    die "cdbi_class() must be implemented in $class";
}

=head2 dump_database

Given the filename of where to put the dump, this method will create the SQL necessary
to restore the database to it's present state including all schema creationg statements.

    $db_platform->dump_database('/usr/local/smolder/dump.sql');

=cut

sub dump_database {
    my $class = shift;
    die "dump_database() must be implemented in $class";
}

=head2 drop_database

Given the password of the database admin user, the hostname and database name, will drop the
existing database.

    $db_platform->drop_database(
        admin_password => 's3cr3t',
        host           => 'localhost',
        db_name        => 'smolder',
    );

=cut

sub drop_database {
    my $class = shift;
    die "drop_database() must be implemented in $class";
}

=head2 create_database

Given the password of the database admin user, the hostname and database name, will create 
the initial database.

    $db_platform->create_database(
        admin_password => 's3cr3t',
        host           => 'localhost',
        db_name        => 'smolder',
    );

=cut

sub create_database {
    my $class = shift;
    die "create_database() must be implemented in $class";
}

=head2 create_user

Given the password of the database admin user, the hostname, the database name, the new user's
username and password, will create a new database user with access to the database.

    $db_platform->create_user(
        admin_passwd => $admin_password,
        host         => $db_host,
        db_name      => $db_name,
        user         => $db_user,
        passwd       => $db_pass,
    );

=cut

sub create_user {
    my $class = shift;
    die "create_user() must be implemented in $class";
}

=head2 sql_create_dir

Returns the full path to the directory containing the SQL files for the creation
of the database for the particular DB driver being used.

=cut

sub sql_create_dir {
    my $class = shift;
    die "sql_create_dir() must be implemented in $class";
}

=head2 sql_upgrade_dir

Returns the full path to the directory containing the SQL files for the upgrade
of the database for the particular DB driver being used.

=cut

sub sql_upgrade_dir {
    my $class = shift;
    die "sql_upgrade_dir() must be implemented in $class";
}

=head2 get_enum_values

Given the table and column names will return all legal values if that column
is an ENUM type as an arrayref.

    my $values = $db_platform->get_enum_values(
        table  => $table,
        column => $column,
    );

=cut

sub get_enum_values {
    my $class = shift;
    die "get_enum_values() must be implemented in $class";
}

=head2 unique_failure_msg 

Given a DB failure message, will return true if the message was a failure due to a
failed UNIQUE contstraint, else will return false.

    eval { $class->create(%args) };
    if( $@ ) {
        die unless $db_platform->unique_failure_msg($@);
    }

=cut

sub unique_failure_msg {
    my $class = shift;
    die "unique_failure_msg() must be implemented in $class";
}

1;
