package Smolder::DB;
use strict;
use warnings;
use Smolder::DBPlatform;
use Smolder::Conf qw(DBName DBUser DBPass DBHost DBPlatform);

our $DB_PLATFORM;

BEGIN {
    $DB_PLATFORM = Smolder::DBPlatform->load();
}
use base $DB_PLATFORM->cdbi_class;
use DBI;
use Class::DBI::Plugin::RetrieveAll;
use Smolder::DBPlatform;

# these are needed for Class::DBI to recognize the db handle properly

# override default to avoid using Ima::DBI closure
sub db_Main {
    __PACKAGE__->connect();
}

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

=head2 dbi_commit

Commit the current transaction

=cut

sub dbi_commit {
    my ( $self, @db_names ) = @_;
    $self->connect()->commit();
}

=head2 dbi_rollback

Rollback to the last C<dbi_commit>

=cut

sub dbi_rollback {
    my ( $self, @db_names ) = @_;
    $self->connect()->rollback();
}

=head2 connect

Returns a DBI database handle.

=cut

sub connect {
    my $db_platform = Smolder::DBPlatform->load(DBPlatform);
    return $db_platform->dbh(
        user    => DBUser,
        passwd  => DBPass,
        host    => DBHost,
        db_name => DBName,
    );
}

=head2 vars

Object method that returns a hash where the keys are the names of the 
columns and the values are the current values of those columns.

=cut

sub vars {
    my $self = shift;
    my %vars = map { $_ => $self->get($_) } ( $self->columns );
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

sub enum_values {
    my $self        = shift;
    my $db_platform = Smolder::DBPlatform->load(DBPlatform);
    my ( $table, $column );

    if ( ref $self || $self ne __PACKAGE__ ) {
        $table = $self->table();
    } else {
        $table = shift;
    }
    $column = shift;

    return $db_platform->get_enum_values(
        table  => $table,
        column => $column,
    );
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
    my ( $self, $column, $substr ) = @_;
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
        push( @bind_cols, $substr );
    }

    my $sth = Smolder::DB->db_Main()->prepare_cached($sql);
    $sth->execute(@bind_cols);
    my @values;
    while ( my $row = $sth->fetchrow_arrayref() ) {
        push( @values, $row->[0] );
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
a name of the mysql data field that you wish to sort by.  Otherwise it works
like a normal Class::DBI retrieve_all.  Please see L<Class::DBI::Plugin::RetrieveAll>
or more details.

=head2 retrieve_all_sort_field($column_name)

This object method changes the default retrieve_all() in the Class to be
auto-sorted by the specified column.  Please see
L<Class::DBI::Plugin::RetrieveAll> for more details.

=cut

1;

__END__

=head1 SEE ALSO 

=over

=item L<DBI>

=item L<Class::DBI>

=item L<Class::DBI::mysql>

=item L<Class::DBI::Plugin::RetrieveAll>

=back
