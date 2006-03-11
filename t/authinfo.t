use Test::More;
use strict;

plan( tests => 2 );
use_ok('Smolder::AuthInfo');

my $at = Smolder::AuthInfo->new();
isa_ok( $at, 'Apache::AuthTkt' );
