package Smolder::DB;
use strict;
use warnings;
use base 'Class::DBI::SQLite';
use Smolder::Conf qw(SQLDir DataDir);
use DBI;
use Class::DBI::Plugin::RetrieveAll;
use File::Spec::Functions qw(catfile);

__PACKAGE__->connection(
    "dbi:SQLite:dbname=" . __PACKAGE__->db_file(),
    '', '',
    {
        RaiseError         => 1,
        PrintError         => 0,
        Warn               => 0,
        PrintWarn          => 0,
        AutoCommit         => 1,
        FetchHashKeyName   => 'NAME_lc',
        ShowErrorStatement => 1,
        ChopBlanks         => 1,
        RootClass          => 'DBIx::ContextualFetch',
    }
);

=head1 NAME

Smolder::DB

Database connections and Object-Relational-Mapper methods

=head1 SYNOPSIS

In your subclass,

 use base 'Smolder::DB';

and now you have Class::DBI::mysql methods ready for use.

 my $obj = Smolder::DB::Class->new;

=head1 DESCRIPTION

This class provides a single place for handling all of the database connections in Smolder.
It is a subclass of L<Class::DBI::mysql> and provides a base class 
for object persistence using Class::DBI.

It also provides a connect() method for getting a DBI connection from non Class::DBI code.

=head1 INTERFACE

=head2 commit

Commit the current transaction

=cut

sub commit {
    shift->db_Main->commit();
}

=head2 rollback

Rollback to the last C<commit>

=cut

sub dbi_rollback {
    shift->db_Main->rollback();
}

=head2 disconnect

Disconnects the current database handle stored in db_Main.

=cut

sub disconnect {
    return shift->db_Main->disconnect;
}

=head2 vars

Object method that returns a hash where the keys are the names of the 
columns and the values are the current values of those columns.

=cut

sub vars {
    my $self = shift;
    my %vars = map { $_ => $self->get($_) } ($self->columns);
    return %vars;
}

=head2 enum_values

Returns an arrayref containing the different values that an emum column can hold.
If used as a method on a subclass then it will use that class to determine which
table to use. Else, if called on the L<Smolder::DB> base class, it will accept
2 arguments, the first being the table to use.

    my $values = Smolder::DB::Foo->enum_values('some_column');

    my $values  = Smolder::DB->enum_values('table', 'some_column');

=cut

# SQLite doesn't support enums, so we just have to maintain this table
my %ENUMS = (
    preference => {
        email_type => [qw(full summary link)],
        email_freq => [qw(on_new on_fail never)],
    },
    project      => {graph_start => [qw(project year month week day)],},
    smoke_report => {format      => [qw(XML YAML)],},
);

sub enum_values {
    my $self = shift;
    my ($table, $column);

    if (ref $self || $self ne __PACKAGE__) {
        $table = $self->table();
    } else {
        $table = shift;
    }
    $column = shift;
    return $ENUMS{$table}->{$column} || [];
}

=head2 column_values

Returns an array ref of all the unique values in a table's column
This must be used in a sub class (it's an abstract method).

    my $values = Smolder::DB::Foo->column_values($column);

May also be passed a second optional argument which will be used to
limit the values returned to those that start with the given string.

For example, to retrieve all of the values for a given C<$column> that
begin with the letter 's':

    my $values = Smolder::DB::Foo->column_values($column, 's');

=cut

sub column_values {
    my ($self, $column, $substr) = @_;
    my $table = $self->table();
    my $sql   = qq(
        SELECT DISTINCT $column FROM $table WHERE $column IS NOT NULL
        AND $column != ''
    );
    my @bind_cols = ();

    # add the substring clause if we need to
    if ($substr) {
        $substr .= '%';
        $sql    .= " AND $column LIKE ? ";
        push(@bind_cols, $substr);
    }

    my $sth = Smolder::DB->db_Main()->prepare_cached($sql);
    $sth->execute(@bind_cols);
    my @values;
    while (my $row = $sth->fetchrow_arrayref()) {
        push(@values, $row->[0]);
    }
    return \@values;
}

=head2 refresh

TODO
CURRENT DOES NOT WORK!!!!

This object method will through away the object in memory and re-fetch
it from the database. This is useful when changes could be made in the db
in another thread (such as testing) and you want to make sure the object is
current.

=cut

# TODO - make this work
sub refresh {
    my $self = shift;
    $self->remove_from_object_index();
    my $class = ref $self;
    my $id    = $self->id;
    $self = undef;
    $self = $class->retrieve($id);
    return $self;
}

=head2 retrieve_all_sorted_by($column_name)

This object methed is exported from L<Class::DBI::Plugin::RetrieveAll>.  It takes
a name of the data field that you wish to sort by.  Otherwise it works
like a normal Class::DBI retrieve_all.  Please see L<Class::DBI::Plugin::RetrieveAll>
or more details.

=head2 retrieve_all_sort_field($column_name)

This object method changes the default retrieve_all() in the Class to be
auto-sorted by the specified column.  Please see
L<Class::DBI::Plugin::RetrieveAll> for more details.


=head2 db_file

Returns the full path to the SQLite DB file.

=cut

sub db_file {
    return catfile(DataDir, "smolder.sqlite");
}

=head2 run_sql_file

Given the runs the SQL contained in the file against out SQLite DB

    Smolder::DB->run_sql_file('/usr/local/smolder/foo.sql');

=cut

sub run_sql_file {
    my ($class, $file) = @_;
    open(my $IN, $file) or die "Could not open file '$file' for reading: $!";

    require Smolder::DB;
    my $dbh = Smolder::DB->db_Main();

    my $sql = '';

    # read each line
    while (my $line = <$IN>) {

        # skip comments
        next if ($line =~ /^--/);
        $sql .= $line;

        # if we have a ';' at the end of the line then it should
        # be the end of the statement
        if ($line =~ /;\s*$/) {
            $dbh->do($sql)
              or die "Could not execute SQL '$sql': $!";
            $sql = '';
        }
    }

    close($file);
}

=head2 dump_database

Given the filename of where to put the dump, this method will create the SQL necessary
to restore the database to it's present state including all schema creationg statements.

    Smolder::DB->dump_database('/usr/local/smolder/dump.sql');

=cut

sub dump_database {
    my ($class, $file) = @_;

    # open the file we want to print to
    open(my $OUT, '>', $file)
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
    my (@tables, $table);
    $sth->bind_col(1, \$table);

    while ($sth->fetch) {
        push(@tables, $table);
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
        $sth->bind_col(1, \$sql);
        while ($sth->fetch) {
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
        $sth->bind_col(1, \$sql);
        while ($sth->fetch) {
            print $OUT "$sql;\n" if ($sql);
        }
        $sth->finish();
        print $OUT "\n\n";

        # now get all of the data in this table
        $sth = $dbh->prepare(qq(SELECT * FROM $t));
        $sth->execute();
        while (my $row = $sth->fetchrow_arrayref) {

            # massage each value so we can create the SQL
            my @values;
            foreach my $value (@$row) {

                # NULLs
                if (!defined $value) {
                    $value = 'NULL';

                    # escape and quote it
                } else {
                    $value =~ s/"/\\"/g;
                    $value = qq("$value");
                }
                push(@values, $value);
            }

            # create the SQL
            my $sql = "INSERT INTO $t VALUES (" . join(', ', @values) . ");\n";
            print $OUT $sql;
        }

        print $OUT "\n\n";
    }
    close($OUT);
}

=head2 create_database

This method will create a brand new, completely empty database file for Smolder.

    Smolder::DB->create_database();

=cut

sub create_database {
    my $class = shift;
    my $file  = $class->db_file();

    # create a new file by this name whether it exists or not
    open(FH, ">$file") or die "Could not open file '$file' for writing: $!";
    close(FH) or die "Could not close file '$file': $!";

    my @files   = glob(catfile(SQLDir, '*.sql'));
    foreach my $f (@files) {
        eval { $class->run_sql_file($f) };
        die "Couldn't load SQL file $f! $@" if $@;
    }

    # Set the db_version
    my $version = $Smolder::VERSION;
    my $dbh     = $class->db_Main;
    eval { $dbh->do("UPDATE db_version set db_version=$version") };
    die "Could not update db_version! $@" if $@;
}

=head2 unique_failure_msg 

Given a DB failure message, will return true if the message was a failure due to a
failed UNIQUE contstraint, else will return false.

    eval { $class->create(%args) };
    if( $@ ) {
        die unless Smolder::DB->unique_failure_msg($@);
    }

=cut

sub unique_failure_msg {
    my ($class, $msg) = @_;
    return $msg =~ /not unique/i;
}

1;

__END__

=head1 SEE ALSO 

=over

=item L<DBI>

=item L<Class::DBI>

=item L<Class::DBI::SQLite>

=item L<Class::DBI::Plugin::RetrieveAll>

=back
