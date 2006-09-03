package Smolder::DBPlatform::MySQL;
use strict;
use warnings;
use base 'Smolder::DBPlatform';
use File::Spec::Functions qw(catdir);
use Carp qw(croak);

=head1 NAME

Smolder::DBPlatform::MySQL - MySQL specific implementation of Smolder::DBPlatform

=head1 SYNOPSIS

  # in smolder.conf
  DBPlatform MySQL

  # in code
  use Smolder::DBPlatform;
  my $db_platform = Smolder::DBPlatform->load();
  # $db_platform is now 'Smolder::DBPlatform::MySQL'

=head1 DESCRIPTION

This module implements the L<Smolder::DBPlatform> interface for MySQL.

=cut

sub verify_dependencies {
    my $class     = shift;
    my $mysql_bin = $class->_get_mysql_bin();

    # look for MySQL command shell
    die <<END unless $mysql_bin;

MySQL not found. Smolder requires MySQL v4.0.13 or later.  If MySQL is
installed, ensure that the 'mysql' client is in your PATH and try again.

END

    # check the version of MySQL
    no warnings qw(exec);
    my $mysql_version = `$mysql_bin -V 2>&1`;
    die "\n\nUnable to determine MySQL version using 'mysql -V'.\n" . "Error was '$!'.\n\n"
      unless defined $mysql_version
      and length $mysql_version;
    chomp $mysql_version;
    my ( $major_version, $minor_version ) = $mysql_version =~ /\s(4|5)\.(\d+\.\d+)/;
    die "\n\nMySQL version 4 or 5 not found.  'mysql -V' returned:" . "\n\n\t$mysql_version\n\n"
      unless defined $major_version;
    if ( $major_version == 4 && $minor_version < 0.13 ) {
        die "\n\nMySQL version too old. Smolder requires v4.0.13 or higher.\n"
          . "'$mysql_bin -V' returned:\n\n\t$mysql_version\n\n";
    }
}

sub _get_mysql_bin {
    require Smolder::Platform;
    my $platform = Smolder::Platform->load();
    return $platform->find_bin( bin => 'mysql' );
}

=head2 verify_admin

=cut

sub verify_admin {
    my ( $class, %args ) = @_;
    my ( $pw,    $host ) = @args{qw(passwd host)};
    my $dsn = "dbi:mysql:database=mysql;host=" . ( $host || 'localhost' );
    require DBI;
    my $dbh = DBI->connect_cached( $dsn, 'root', $pw, \%Smolder::DBPlatform::CONNECTION_OPTIONS, );
    return $dbh ? 1 : 0;
}

=head2 run_sql_file

=cut

sub run_sql_file {
    my ( $class, %options ) = @_;
    my ( $admin_pw, $file, $user, $pw, $host, $db_name ) =
      @options{qw(admin_pw file user passwd host db_name)};

    if ($admin_pw) {
        $pw   = $admin_pw;
        $user = 'root';
    }

    my $cmd = _get_mysql_bin . " -u$user ";
    $cmd .= " -h$host" if ($host);
    $cmd .= " -p$pw"   if ($pw);
    system("$cmd $db_name < $file") == 0
      or die $!;
}

=head2 dbh

=cut

sub dbh {
    my ( $class, %args ) = @_;
    my ( $user, $pw, $host, $db_name ) = @args{qw(user passwd host db_name)};
    my $dsn = "dbi:mysql:database=" . ($db_name || '') . ";host=" . ( $host || 'localhost' );
    return DBI->connect_cached( $dsn, $user, $pw, \%Smolder::DBPlatform::CONNECT_OPTIONS, );
}

=head2 dbi_driver

=cut

sub dbi_driver {
    my $class = shift;
    return 'DBD::mysql';
}

=head2 cdbi_class

=cut

sub cdbi_class {
    my $class = shift;
    return 'Class::DBI::mysql';
}

=head2 dump_database

=cut

sub dump_database {
    my ( $class, $file ) = @_;
    require Smolder::Platform;
    my $platform = Smolder::Platform->load();
    my $dump_bin = $platform->find_bin( bin => 'mysqldump' );

    # add the specific flags
    require Smolder::Conf;
    $dump_bin .= " -u" . Smolder::Conf->get('DBUser');
    $dump_bin .= " -p" . Smolder::Conf->get('DBPass');
    $dump_bin .= " -h" . Smolder::Conf->get('DBHost') if ( Smolder::Conf->get('DBHost') );
    $dump_bin .= " " . Smolder::Conf->get('DBName');

    # make sure we can load foreign keys after the dump
    $dump_bin = "echo 'SET foreign_key_checks=0;' > $file; $dump_bin >> $file";

    # run it
    system($dump_bin) == 0
      or croak "Could not dump database to file '$file' $!";
}

=head2 drop_database

=cut

sub drop_database {
    my ( $class, %args ) = @_;
    my ( $admin_pw, $db_name, $host ) = @args{qw(admin_passwd db_name host)};
    my $dbh = $class->dbh(
        user    => 'root',
        passwd  => $admin_pw,
        host    => $host,
        db_name => 'mysql',
    );

    $dbh->do("DROP DATABASE IF EXISTS $db_name");
    $dbh->commit();
}

=head2 create_database

=cut

sub create_database {
    my ( $class, %args ) = @_;
    my ( $admin_pw, $db_name, $host ) = @args{qw(admin_passwd db_name host)};
    my $dbh = $class->dbh(
        user    => 'root',
        passwd  => $admin_pw,
        host    => $host,
        db_name => 'mysql',
    );

    $dbh->do("CREATE DATABASE IF NOT EXISTS $db_name");
    $dbh->commit();
}

=head2 create_user

=cut

sub create_user {
    my ( $class, %args ) = @_;
    my ( $admin_pw, $user, $pw, $db_name, $host ) =
      @args{qw(admin_passwd user passwd db_name host)};
    my $dbh = $class->dbh(
        user    => 'root',
        passwd  => $admin_pw,
        host    => $host,
#        db_name => $db_name,
    );

    my $sql = "GRANT ALL ON $db_name\.* to $user";
    if ( !defined $host or $host eq 'localhost' ) {
        $sql .= '@localhost';
    } elsif ( $host eq 'localhost.localdomain' ) {
        $sql .= '@localhost.localdomain';
    }
    $sql .= " identified by '$pw'";
    $dbh->do($sql);
    $dbh->commit();
}

=head2 sql_create_dir

=cut

sub sql_create_dir {
    my $class = shift;
    return catdir( $ENV{SMOLDER_ROOT}, 'sql', 'mysql' );
}

=head2 sql_upgrade_dir

=cut

sub sql_upgrade_dir {
    my ( $class, $version ) = @_;
    return catdir( $ENV{SMOLDER_ROOT}, 'upgrades', 'sql', 'mysql', $version );
}

=head2 get_enum_values

=cut

sub get_enum_values {
    my ( $class, %args )   = @_;
    my ( $table, $column ) = @args{qw(table column)};
    my $sth = Smolder::DB->db_Main()->prepare_cached(
        qq(
        SHOW COLUMNS FROM $table LIKE '$column';
    )
    );
    $sth->execute();
    my $row = $sth->fetchrow_arrayref();
    $sth->finish();
    my $text = $row->[1];
    $text =~ s/^enum//;
    return eval "[$text]";
}

=head2 unique_failure_msg

=cut

sub unique_failure_msg {
    my ( $class, $msg ) = @_;
    return $msg =~ /Duplicate entry/i;
}

1;
