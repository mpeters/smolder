use strict;
use Test::More;
use Test::WWW::Mechanize;
use Smolder::TestData qw(
    base_url
    is_apache_running
    login
    create_developer
    delete_developers
);

if( is_apache_running ) {
    plan(tests => 6);
} else {
    plan(skip_all => 'Smolder apache not running');
}

my $mech  = Test::WWW::Mechanize->new();
my $url   = base_url() . '/admin';
my $pw    = 's3cr3t';
my $admin = create_developer(admin => 1, password => $pw);
END { delete_developers() };
# 1
use_ok('Smolder::Control::Admin');

# 2
$mech->get_ok($url);
$mech->content_lacks('Welcome');
login(mech => $mech, username => $admin->username, password => $pw);
ok($mech->success);
$mech->get_ok($url);
$mech->content_contains('Welcome');




