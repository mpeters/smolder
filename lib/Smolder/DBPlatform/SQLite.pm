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
    my ( $class, %args ) = @_;

    # no deps since we build SQLite ourselves
    return 1;
}

=head2 verify_admin

=cut

sub verify_admin {
    my ( $class, %args ) = @_;

    # nothing special here
    return 1;
}

=head2 run_sql_file

=cut

sub run_sql_file {
    my ( $class,   %args ) = @_;
    my ( $db_name, $file ) = @args{qw(db_name file)};
    open( my $IN, $file ) or die "Could not open file '$file' for reading: $!";

    require Smolder::DB;
    my $dbh = Smolder::DB->db_Main();

    my $sql = '';

    # read each line
    while ( my $line = <$IN> ) {

        # skip comments
        next if ( $line =~ /^--/ );
        $sql .= $line;

        # if we have a ';' at the end of the line then it should
        # be the end of the statement
        if ( $line =~ /;\s*$/ ) {
            $dbh->do($sql)
              or die "Could not execute SQL '$sql': $!";
            $sql = '';
        }
    }

    close($file);
}

=head2 dbh

=cut

sub dbh {
    my ( $class, %args ) = @_;
    my $db_name = $args{db_name};
    require DBI;
    return DBI->connect_cached($class->connection_options(%args));
}

=head2 connection_options

=cut

sub connection_options {
    my ($class, %args) = @_;
    my $dsn     = "dbi:SQLite:dbname=" . $class->_get_db_file($args{db_name});
    return ($dsn, '', '', \%Smolder::DBPlatform::CONNECT_OPTIONS);
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
    my ( $class, $file ) = @_;

    # open the file we want to print to
    open( my $OUT, '>', $file )
      or die "Could not open file '$file' for writing: $!";

    # get the list of tables
    require Smolder::DB;
    my $dbh = Smolder::DB->db_Main();
    my $sth = $dbh->prepare(
        q(
        SELECT name FROM sqlite_master WHERE type = 'table'
        AND name NOT LIKE 'sqlite_%' AND sql NOT NULL
    )
    );
    $sth->execute();
    my ( @tables, $table );
    $sth->bind_col( 1, \$table );
    while ( $sth->fetch ) {
        push( @tables, $table );
    }
    $sth->finish();

    # now get the SQL for each table and output it
    foreach my $t (@tables) {

        # first the schema
        $sth = $dbh->prepare(
            q(
            SELECT sql FROM sqlite_master 
            WHERE type = 'table' AND name = ?
        )
        );
        $sth->execute($t);
        my $sql;
        $sth->bind_col( 1, \$sql );
        while ( $sth->fetch ) {
            print $OUT "$sql;\n";
        }
        $sth->finish();

        # now the indexes
        $sth = $dbh->prepare(
            q(
            SELECT sql FROM sqlite_master
            WHERE type = 'index' AND tbl_name = ?
        )
        );
        $sth->execute($t);
        $sth->bind_col( 1, \$sql );
        while ( $sth->fetch ) {
            print $OUT "$sql;\n" if ($sql);
        }
        $sth->finish();
        print $OUT "\n\n";

        # now get all of the data in this table
        $sth = $dbh->prepare(qq(SELECT * FROM $t));
        $sth->execute();
        while ( my $row = $sth->fetchrow_arrayref ) {

            # massage each value so we can create the SQL
            my @values;
            foreach my $value (@$row) {

                # NULLs
                if ( !defined $value ) {
                    $value = 'NULL';

                    # escape and quote it
                } else {
                    $value =~ s/"/\\"/g;
                    $value = qq("$value");
                }
                push( @values, $value );
            }

            # create the SQL
            my $sql = "INSERT INTO $t VALUES (" . join( ', ', @values ) . ");\n";
            print $OUT $sql;
        }

        print $OUT "\n\n";
    }
    close($OUT);
}

=head2 drop_database

=cut

sub drop_database {
    my ( $class, %args ) = @_;
    my $db_name = $args{db_name};
    my $file    = $class->_get_db_file($db_name);

    # just delete the file
    if ( -e $file ) {
        unlink($file)
          or croak "Could not unlike DB file '$file': $!";
    }
}

=head2 create_database

=cut

sub create_database {
    my ( $class, %args ) = @_;
    my $db_name = $args{db_name};
    my $file    = $class->_get_db_file($db_name);

    # just create the empty file if it's not already there
    unless ( -e $file ) {
        open( FH, ">$file" ) or die "Could not open file '$file' for writing: $!";
        close(FH) or die "Could not close file '$file': $!";
    }
}

=head2 create_user

=cut

sub create_user {
    my ( $class, %args ) = @_;

    # no op
}

=head2 sql_create_dir

=cut

sub sql_create_dir {
    my $class = shift;
    return catdir( $ENV{SMOLDER_ROOT}, 'sql', 'sqlite' );
}

=head2 sql_upgrade_dir

=cut

sub sql_upgrade_dir {
    my ( $class, $version ) = @_;
    return catdir( $ENV{SMOLDER_ROOT}, 'upgrades', 'sql', 'sqlite', $version );
}

=head2 get_enum_values

=cut

sub get_enum_values {
    my ( $class, %args )   = @_;
    my ( $table, $column ) = @args{qw(table column)};

    # SQLite doesn't support enums, so we just have to maintain this table
    my $enums = {
        preference => {
            email_type => [qw(full summary link)],
            email_freq => [qw(on_new on_fail never)],
        },
        project      => { graph_start => [qw(project year month week day)], },
        smoke_report => { format      => [qw(XML YAML)], },
    };
    return $enums->{$table}->{$column} || [];
}

=head2 unique_failure_msg

=cut

sub unique_failure_msg {
    my ( $class, $msg ) = @_;
    return $msg =~ /not unique\(/i;
}

sub _get_db_file {
    my ( $class, $db_name ) = @_;
    return catfile( $ENV{SMOLDER_ROOT}, 'data', "$db_name.sqlite" );
}


1;
