package Smolder::DB::TestFileResult;
use strict;
use warnings;
use base 'Smolder::DB';

__PACKAGE__->set_up_table('test_file_result');

=head1 NAME

Smolder::DB::TestFileResult

=head1 DESCRIPTION

L<Class::DBI> based model class for the 'test_file_result' table in the database.

=head1 METHODS

=head2 ACCESSSOR/MUTATORS

Each column in the borough table has a method with the same name
that can be used as an accessor and mutator.

=cut
    
__PACKAGE__->has_a(test_file => 'Smolder::DB::TestFile');
__PACKAGE__->has_a(smoke_report => 'Smolder::DB::SmokeReport');

1;
