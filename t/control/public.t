use strict;
use Test::More;
use Test::WWW::Mechanize;
use Smolder::TestData qw(
  base_url
  is_apache_running
);

if (is_apache_running) {
    plan( tests => 2 );
} else {
    plan( skip_all => 'Smolder apache not running' );
}

my $mech = Test::WWW::Mechanize->new();
my $url  = base_url() . '/public';

# 1
use_ok('Smolder::Control::Public');

# 2
$mech->get_ok($url);

