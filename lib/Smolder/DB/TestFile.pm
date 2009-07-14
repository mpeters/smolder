package Smolder::DB::TestFile;
use strict;
use warnings;
use base 'Smolder::DB';

__PACKAGE__->set_up_table('test_file');

=head1 NAME

Smolder::DB::TestFile

=head1 DESCRIPTION

L<Class::DBI> based model class for the 'test_file' table in the database.

=head1 METHODS

=head2 ACCESSSOR/MUTATORS

Each column in the borough table has a method with the same name
that can be used as an accessor and mutator.

=cut
    
__PACKAGE__->has_a(project => 'Smolder::DB::Project');

1;
