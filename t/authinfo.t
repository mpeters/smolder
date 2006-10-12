use strict;
use warnings;

use Test::More;
use Smolder::TestScript;
use Smolder::TestData qw(
  is_apache_running
);

# this test doesn't really need Apache running but if it's never been
# run it'll fail
if (is_apache_running) {
    plan( tests => 2 );
} else {
    plan( skip_all => 'Smolder apache not running' );
}

use_ok('Smolder::AuthInfo');

my $at = Smolder::AuthInfo->new();
isa_ok( $at, 'Apache::AuthTkt' );
