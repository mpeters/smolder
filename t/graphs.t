use strict;
use warnings;
use Test::More;
use Smolder::TestScript;
use Smolder::TestData qw(
  base_url
  is_smolder_running
  create_developer
  delete_developers
  create_project
  delete_projects
  db_field_value
  create_preference
  delete_preferences
);
use Smolder::Mech;
use Smolder::DB::ProjectDeveloper;

if (is_smolder_running) {
    plan('no_plan');
} else {
    plan(skip_all => 'Smolder not running');
}

my $mech  = Smolder::Mech->new();
my $url   = base_url() . '/graphs';
my $pw    = 's3cr3t';
my $dev   = create_developer(password => $pw);
my $proj1 = create_project( public => 0 );
my $proj2 = create_project();

# add this $dev to $proj1 and $proj2
my $proj_dev1 = Smolder::DB::ProjectDeveloper->create(
    {developer => $dev, project => $proj1, preference => create_preference()});
my $proj_dev2 = Smolder::DB::ProjectDeveloper->create(
    {developer => $dev, project => $proj2, preference => create_preference()});

END {
    delete_developers();
    delete_projects();
    delete_preferences();
}

# 1
use_ok('Smolder::Control::Graphs');

# 2..6
# login as a developer
$mech->get("$url/start/$proj1");
#is($mech->status, 401, 'auth required'); # can we control HTTP codes in C::A::Server?
$mech->content_contains("Unauthorized");
$mech->content_lacks('Progress Graphs');
$mech->login(username => $dev->username, password => $pw);
ok($mech->success);
$mech->get_ok("$url/start/$proj1");
$mech->content_contains('Progress Graphs');

# 7
# image
#{
# default

# todo, skip, total

# all

# different types

# no data
#}

