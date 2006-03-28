use strict;
use Test::More;
use Smolder::TestData qw(
  base_url
  is_apache_running
);
use Smolder::TestMech;

if (is_apache_running) {
    plan( tests => 2 );
} else {
    plan( skip_all => 'Smolder apache not running' );
}

my $mech = Smolder::TestMech->new();
my $url  = base_url() . '/public';

# 1
use_ok('Smolder::Control::Public');

# 2
$mech->get_ok($url);

