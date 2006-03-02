package Smolder::DB::Preference;
use strict;
use warnings;
use base 'Smolder::DB';

__PACKAGE__->set_up_table('preference');

=head1 NAME

Smolder::DB::Preference

=head1 DESCRIPTION

L<Class::DBI> based model class for the 'preference' table in the database.

=head1 METHODS

=head2 ACCESSSOR/MUTATORS

Each column in the borough table has a method with the same name
that can be used as an accessor and mutator.

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

