package Smolder::DB::Preference;
use strict;
use warnings;
use base 'Smolder::DB';
use Smolder::DB::Project;

__PACKAGE__->set_up_table('preference');

__PACKAGE__->has_a(
    email_sent_timestamp => 'DateTime',
    inflate              => sub { DateTime::Format::MySQL->parse_datetime(shift) },
    deflate              => sub { DateTime::Format::MySQL->format_datetime(shift) },
);

sub create {
    my ($class, $args) = @_;
    $args ||= {
        email_type => 'full',
        email_freq => 'on_new',
    };
    return $class->SUPER::create($args);
}

=head1 NAME

Smolder::DB::Preference

=head1 DESCRIPTION

L<Class::DBI> based model class for the 'preference' table in the database.

=head1 METHODS

=head2 ACCESSSOR/MUTATORS

Each column in the borough table has a method with the same name
that can be used as an accessor and mutator.

=head2 OBJECT METHODS

=head3 project

If this Preference is associated with a project, then this will return
that L<Smolder::DB::Project> object, else it will return C<undef>.

=cut

sub project {
    my $self = shift;
    my $sql  = q(
        SELECT project.* FROM project, project_developer
        WHERE project.id = project_developer.project
        AND project_developer.preference = ?
    );
    my $sth = $self->db_Main->prepare_cached($sql);
    $sth->execute($self->id);
    my @projs = Smolder::DB::Project->sth_to_objects($sth);
    return $projs[0];
}

=head2 CLASS METHODS

=head3 email_types

Returns an arrayref of all acceptable values for the C<email_type> field.

=cut

sub email_types {
    my $class = shift;
    return $class->enum_values('email_type');
}

=head3 email_freqs

Returns an arrayref of all acceptable values for the C<email_freq> field.

=cut

sub email_freqs {
    my $class = shift;
    return $class->enum_values('email_freq');
}

1;

