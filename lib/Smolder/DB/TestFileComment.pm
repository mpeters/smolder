package Smolder::DB::TestFileComment;
use strict;
use warnings;
use base 'Smolder::DB';

__PACKAGE__->set_up_table('test_file_comment');

__PACKAGE__->has_a(project   => 'Smolder::DB::Project');
__PACKAGE__->has_a(test_file => 'Smolder::DB::TestFile');
__PACKAGE__->has_a(developer => 'Smolder::DB::Developer');
__PACKAGE__->has_a(
    added   => 'DateTime',
    inflate => sub { DateTime->from_epoch(epoch => shift) },
    deflate => sub { shift->epoch },
);

# make sure added is set to NOW
__PACKAGE__->add_trigger(
    before_create => sub {
        my $self = shift;
        $self->_attribute_set(added => DateTime->now());
    },
);

=head1 NAME

Smolder::DB::TestFileComment

=head1 DESCRIPTION

L<Class::DBI> based model class for the 'test_file_comment' table in the database.

=head1 METHODS

=head2 ACCESSSOR/MUTATORS

Each column in the borough table has a method with the same name that can be
used as an accessor and mutator.

=cut

1;
