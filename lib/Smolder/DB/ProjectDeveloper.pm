package Smolder::DB::ProjectDeveloper;
use strict;
use warnings;
use base 'Smolder::DB';

__PACKAGE__->set_up_table('project_developer');

=head1 NAME

Smolder::DB::ProjectDeveloper

=head1 DESCRIPTION

L<Class::DBI> based model class for the 'project_developer' table in the database.

=head1 METHODS

=head2 ACCESSSOR/MUTATORS

Each column in the borough table has a method with the same name
that can be used as an accessor and mutator.

The following columns will return objects instead of the value contained in the table:

=cut

__PACKAGE__->has_a(project    => 'Smolder::DB::Project');
__PACKAGE__->has_a(developer  => 'Smolder::DB::Developer');
__PACKAGE__->has_a(preference => 'Smolder::DB::Preference');
__PACKAGE__->has_a(
    added   => 'DateTime',
    inflate => sub { __PACKAGE__->parse_datetime(shift) },
    deflate => sub { __PACKAGE__->format_datetime(shift) },
);

# make sure we delete any preferences that are attached to us
__PACKAGE__->add_trigger(
    after_delete => sub {
        my $self = shift;
        my $pref = $self->preference;
        $pref->delete if $pref;
    }
);

# make sure added is set to NOW
__PACKAGE__->add_trigger(
    before_create => sub {
        my $self = shift;
        $self->_attribute_set(added => DateTime->now());
    },
);

=over

=item project

This is the L<Smolder::DB::Project> object to which this developer belongs.

=item developer

This is the L<Smolder::DB::Developer> object that belongs to this project.

=item preference

This is the L<Smolder::DB::Preference> object that belongs to this Developer for this Project.
When the object is created it starts out as a copy of the Developer's default Preference.

=item added

This is a L<DateTime> object for when the Developer was added to the Project.

=back

=cut

1;
