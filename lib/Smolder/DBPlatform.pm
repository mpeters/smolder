package Smolder::DBPlatform;
use strict;
use warnings;
use Carp qw(croak);

use File::Spec::Functions qw(catdir catfile canonpath);

# these are needed for Class::DBI to recognize the db handle properly
our %CONNECT_OPTIONS = (
    RaiseError         => 1,
    PrintError         => 0,
    AutoCommit         => 0,
    FetchHashKeyName   => 'NAME_lc',
    ShowErrorStatement => 1,
    ChopBlanks         => 1,
    RootClass          => 'DBIx::ContextualFetch'
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
    my ($class, $type) = @_;
    # get the type from the config if we don't already have it
    unless( $type ) {
        require Smolder::Conf;
        $type = Smolder::Conf->get('DBPlatform');
    };

    # load the class if we can
    my $subclass = 'Smolder::DBPlatform::' . $type;
    eval "require $subclass";
    if( $@ ) {
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

    $platform->verify_dependencies(mode => 'install')

=cut

sub verify_dependencies { 
    my $class = shift;
    die "verify_dependencies() must be implemented in the $class";
}

=head2 verify_admin

=cut

sub verify_admin { 
    my $class = shift;
    die "verify_admin() must be implemented in the $class";
}

=head2 run_sql_file

=cut

sub run_sql_file { 
    my $class = shift;
    die "run_sql_file() must be implemented in the $class";
}

=head2 dbh

=cut

sub dbh { 
    my $class = shift;
    die "dbh() must be implemented in the $class";
}

=head2 dbi_driver

=cut

sub dbi_driver { 
    my $class = shift;
    die "dbi_driver() must be implemented in the $class";
}

=head2 cdbi_class

=cut

sub cdbi_class { 
    my $class = shift;
    die "cdbi_class() must be implemented in the $class";
}

=head2 dump_database

=cut

sub dump_database { 
    my $class = shift;
    die "dump_database() must be implemented in the $class";
}

=head2 drop_database

=cut

sub drop_database {
    my $class = shift;
    die "drop_database() must be implemented in the $class";
}

=head2 create_database

=cut

sub create_database {
    my $class = shift;
    die "create_database() must be implemented in the $class";
}

=head2 create_user

=cut

sub create_user { 
    my $class = shift;
    die "create_user() must be implemented in the $class";
}

=head2 sql_create_dir

=cut

sub sql_create_dir { 
    my $class = shift;
    die "sql_create_dir() must be implemented in the $class";
}

=head2 sql_upgrade_dir

=cut

sub sql_upgrade_dir { 
    my $class = shift;
    die "sql_upgrade_dir() must be implemented in the $class";
}

=head2 get_enum_values

=cut

sub get_enum_values { 
    my $class = shift;
    die "get_enum_values() must be implemented in the $class";
}



1;
