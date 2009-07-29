package Smolder::DB::TestFile;
use strict;
use warnings;
use base 'Smolder::DB';

__PACKAGE__->set_up_table('test_file');

__PACKAGE__->has_a(
    mute_until => 'DateTime',
    inflate    => sub { DateTime->from_epoch(epoch => shift) },
    deflate => sub { shift->epoch },
);

__PACKAGE__->has_many('comments' => 'Smolder::DB::TestFileComment', { order_by => 'added DESC' });

=head1 NAME

Smolder::DB::TestFile

=head1 DESCRIPTION

L<Class::DBI> based model class for the 'test_file' table in the database.

=head1 METHODS

=head2 ACCESSSOR/MUTATORS

Each column in the borough table has a method with the same name that can be
used as an accessor and mutator.

=cut

sub is_muted {
    my ($self) = @_;

    my $mute_until = $self->mute_until;
    my $is_muted = defined($mute_until) && time < $mute_until->epoch;
    return $is_muted;
}

__PACKAGE__->has_a(project => 'Smolder::DB::Project');

1;
