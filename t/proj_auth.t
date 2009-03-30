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
  create_smoke_report
  delete_smoke_reports
);
use Smolder::Mech;
use Smolder::DB::ProjectDeveloper;
use Smolder::Conf;
use File::Spec::Functions qw(catfile);

if (is_smolder_running) {
    plan(tests => 15);
} else {
    plan(skip_all => 'Smolder not running');
}

my $mech    = Smolder::Mech->new();
my $url     = base_url() . '/developer_projects';
my $pw      = 's3cr3t';
my $dev     = create_developer(password => $pw);
my $proj_id = create_project(public => 0)->id();

END {
    delete_developers();
    delete_projects();
}

# 1
use_ok('Smolder::Control::Developer::Projects');

# 2..6
# login as a developer
$mech->get($url);

#is($mech->status, 401, 'auth required'); # can we control HTTP codes in C::A::Server?
$mech->content_contains("You shouldn't be here");
$mech->login(username => $dev->username, password => $pw);
ok($mech->success);
$mech->get_ok($url);
$mech->content_contains('My Projects');

# 7..20
# authorization for non-public project
{

    # make sure I can't see these pages
    $mech->get_ok("/app/developer_projects/add_report/$proj_id");
    $mech->content_contains('Unauthorized');
    $mech->get_ok("/app/developer_projects/process_add_report/$proj_id");
    $mech->content_contains('Unauthorized');
    $mech->get_ok("/app/developer_projects/smoke_reports/$proj_id");
    $mech->content_contains('Unauthorized');

    # check project_settings and project_project_settings
    $mech->get_ok("/app/developer_projects/admin_settings/$proj_id");
    $mech->content_contains('You are not an admin');
    $mech->get_ok("/app/developer_projects/process_admin_settings/$proj_id");
    $mech->content_contains('You are not an admin');
}

