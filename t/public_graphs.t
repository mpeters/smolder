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
);
use Smolder::Mech;
use Smolder::DB::ProjectDeveloper;

if (is_smolder_running) {
    plan('no_plan');
} else {
    plan(skip_all => 'Smolder not running');
}

my $mech  = Smolder::Mech->new();
my $url   = base_url() . '/public_graphs';
my $dev   = create_developer();
my $proj1 = create_project();

END {
    delete_developers();
    delete_projects();
}

# 1
use_ok('Smolder::Control::Developer::Graphs');

# 2..3
# start page
$mech->get_ok("$url/start/$proj1");
$mech->content_contains('Progress Graphs');

# image
# default
# todo, skip, total
# all
# different types
# no data

