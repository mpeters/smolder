use strict;
use warnings;

use Test::More;
use Smolder::TestScript;
use Smolder::TestData qw(
  base_url
  is_apache_running
  create_developer
  delete_developers
);
use Smolder::Mech;

if (is_apache_running) {
    plan( tests => 6 );
} else {
    plan( skip_all => 'Smolder apache not running' );
}

my $mech  = Smolder::Mech->new();
my $url   = base_url() . '/admin';
my $pw    = 's3cr3t';
my $admin = create_developer( admin => 1, password => $pw );
END { delete_developers() }

# 1
use_ok('Smolder::Control::Admin');

# 2
$mech->get($url);
is($mech->status, 401, 'auth required');
$mech->content_lacks('Welcome');
$mech->login( username => $admin->username, password => $pw );
ok( $mech->success );
$mech->get_ok($url);
$mech->content_contains('Welcome');

