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

my $mech = Smolder::Mech->new();
my $url  = base_url() . '/developer';
my $pw   = 's3cr3t';
my $dev  = create_developer( password => $pw );
END { delete_developers() }

# 1
use_ok('Smolder::Control::Developer');

# 2..6
$mech->get_ok($url);
$mech->content_lacks('Welcome');
$mech->login( username => $dev->username, password => $pw );
ok( $mech->success );
$mech->get_ok($url);
$mech->content_contains('Welcome');

