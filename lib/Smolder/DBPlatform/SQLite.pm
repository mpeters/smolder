package Smolder::DBPlatform::SQLite;
use strict;
use warnings;
use base 'Smolder::DBPlatform';
use File::Spec::Functions qw(catdir catfile);
use Carp qw(croak);
use File::Temp;

=head1 NAME

Smolder::DBPlatform::SQLite - SQLite specific implementation of Smolder::DBPlatform

=head1 SYNOPSIS

  # in smolder.conf
  DBPlatform SQLite

  # in code
  use Smolder::DBPlatform;
  my $db_platform = Smolder::DBPlatform->load();
  # $db_platform is now 'Smolder::DBPlatform::SQLite'

=head1 DESCRIPTION

This module implements the L<Smolder::DBPlatform> interface for SQLite.

=cut

sub verify_dependencies { 
    my ($class, %args) = @_;
    # no deps since we build SQLite ourselves
    return 1;
}

=head2 verify_admin

=cut

sub verify_admin {
    my ($class, %args) = @_;
    # nothing special here
    return 1;
}

=head2 run_sql_file

=cut

sub run_sql_file { 
    my ($class, %args) = @_;
    my ($db_name, $file) = @args{qw(db_name file)};
    my $sqlite_bin  = $class->_get_sqlite_bin();
    my $sqlite_file = $class->_get_db_file($db_name);

    my $cmd .= "$sqlite_bin $sqlite_file < $file";
    # run it
    system($cmd) == 0
        or croak "Could not run SQL file '$file' for DB '$db_name': $!";

}

=head2 dbh

=cut

sub dbh {
    my ($class, %args) = @_;
    my $db_name = $args{db_name};
    my $dsn = "dbi:SQLite:dbname=" . $class->_get_db_file($db_name);
    require DBI;
    return DBI->connect_cached( 
        $dsn, 
        '',
        '', 
        \%Smolder::DBPlatform::CONNECT_OPTIONS,
    );
}

=head2 dbi_driver

=cut

sub dbi_driver { 
    my $class = shift;
    return 'DBD::SQLite';
}

=head2 cdbi_class

=cut

sub cdbi_class { 
    my $class = shift;
    return 'Class::DBI::SQLite';
}

=head2 dump_database

=cut

sub dump_database { 
    my ($class, $file) = @_;

    require Smolder::Conf;
    my $db_name = Smolder::Conf->get('DBName');
    my $sqlite_bin  = $class->_get_sqlite_bin();
    my $sqlite_file = $class->_get_db_file($db_name);

    my $dump_bin .= "$sqlite_bin $sqlite_file '.dump' > $file";
    # run it
    system($dump_bin) == 0
        or croak "Could not dump database to file '$file' $!";
}

=head2 drop_database

=cut

sub drop_database {
    my ($class, %args) = @_;
    my $db_name = $args{db_name};
    my $file = $class->_get_db_file($db_name);
    # just delete the file
    if( -e $file ) {
        unlink($file)
            or croak "Could not unlike DB file '$file': $!";
    }
}

=head2 create_database

=cut

sub create_database {
    my ($class, %args) = @_;
    my $db_name = $args{db_name};
    my $file = $class->_get_db_file($db_name);
    # just create the empty file if it's not already there
    unless( -e $file ) {
        open(FH, ">$file") or die "Could not open file '$file' for writing: $!";
        close(FH) or die "Could not close file '$file': $!";
    }
}

=head2 create_user

=cut

sub create_user {
    my ($class, %args) = @_;
    # no op
}


=head2 sql_create_dir

=cut

sub sql_create_dir {
    my $class = shift;
    return catdir($ENV{SMOLDER_ROOT}, 'sql', 'sqlite');
}

=head2 sql_upgrade_dir

=cut

sub sql_upgrade_dir {
    my ($class, $version) = @_;
    return catdir($ENV{SMOLDER_ROOT}, 'upgrades', 'sql', 'sqlite', $version);
}

=head2 get_enum_values

=cut

sub get_enum_values { 
    my ($class, $table, $column) = @_;
    # SQLite doesn't support enums, so we just have to maintain this table
    my $enums = {
        preference   => {
            email_type  => [qw(full summary link)],
            email_freq  => [qw(on_new on_fail never)],
        },
        project      => {
            graph_start => [qw(project year month week day)],
        },
        smoke_report => {
            format      => [qw(XML YAML)],
        },
    };
    return $enums->{$table}->{$column} || [];
}

=head2 unique_failure_msg

=cut

sub unique_failure_msg {
    my ($class, $msg) = @_;
    return $msg =~ /not unique\(1\)/i;
}


sub _get_db_file {
    my ($class, $db_name) = @_;
    return catfile($ENV{SMOLDER_ROOT}, 'data', "$db_name.sqlite");
}

sub _get_sqlite_bin {
    my $class = shift;
    return catfile($ENV{SMOLDER_ROOT}, 'sqlite', 'bin', 'sqlite3');
}

1;
