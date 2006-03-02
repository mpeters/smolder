use strict;
use Test::More;
use Test::WWW::Mechanize;
use Smolder::TestData qw(
    base_url
    is_apache_running
    login
    create_developer
    delete_developers
    create_project
    delete_projects
    db_field_value
);
use Smolder::DB::ProjectDeveloper;

if( is_apache_running ) {
    plan('no_plan');
} else {
    plan(skip_all => 'Smolder apache not running');
}

my $mech  = Test::WWW::Mechanize->new();
my $url   = base_url() . '/developer_graphs';
my $pw    = 's3cr3t';
my $dev   = create_developer( password => $pw);
my $proj1 = create_project();
my $proj2 = create_project();
# add this $dev to $proj1 and $proj2
my $proj_dev1 = Smolder::DB::ProjectDeveloper->create({ developer => $dev, project => $proj1 });
my $proj_dev2 = Smolder::DB::ProjectDeveloper->create({ developer => $dev, project => $proj2 });
Smolder::DB->dbi_commit();

END { 
    delete_developers();
    delete_projects();
};

# 1
use_ok('Smolder::Control::Developer::Graphs');

# 2..6
# login as a developer
$mech->get_ok($url);
$mech->content_lacks('Welcome');
login(mech => $mech, username => $dev->username, password => $pw);
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

