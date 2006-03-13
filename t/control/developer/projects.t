use strict;
use Test::More;
use Test::WWW::Mechanize;
use Smolder::TestData qw(
  base_url
  is_apache_running
  login
  logout
  create_developer
  delete_developers
  create_project
  delete_projects
  create_smoke_report
  delete_smoke_reports
);
use Smolder::DB::ProjectDeveloper;
use Smolder::Conf qw(InstallRoot);
use File::Spec::Functions qw(catfile);

if (is_apache_running) {
    plan( tests => 132 );
} else {
    plan( skip_all => 'Smolder apache not running' );
}

my $mech  = Test::WWW::Mechanize->new();
my $url   = base_url() . '/developer_projects';
my $pw    = 's3cr3t';
my $dev   = create_developer( password => $pw );
my $proj1 = create_project();
my $proj2 = create_project( public => 0 );

# add this $dev to $proj1 and $proj2
my $proj1_dev = Smolder::DB::ProjectDeveloper->create( { developer => $dev, project => $proj1 } );
my $proj2_dev = Smolder::DB::ProjectDeveloper->create( { developer => $dev, project => $proj2 } );
Smolder::DB->dbi_commit();

END {
    delete_developers();
    delete_projects();
}

# 1
use_ok('Smolder::Control::Developer::Projects');

# 2..6
# login as a developer
$mech->get_ok($url);
$mech->content_lacks('Welcome');
login( mech => $mech, username => $dev->username, password => $pw );
ok( $mech->success );
$mech->get_ok($url);
$mech->content_contains('My Projects');

# 7..9
# show_all
{
    $mech->get_ok( $url . '/show_all' );
    $mech->content_contains( $proj1->name );
    $mech->content_contains( $proj2->name );
}

# 10..43
# add_report and process_add_report
{
    $mech->follow_link_ok( { text => 'Upload Smoke Test', n => 1 } );
    $mech->content_contains('New Smoke Report');
    $mech->content_contains( $proj1->name );

    # empty form
    ok( $mech->form_name('add_report') );
    $mech->submit();
    ok( $mech->success );
    $mech->content_contains('either incomplete or invalid');
    $mech->content_contains('You must upload a smoke test report');
    $mech->content_contains('class="required warn">Smoke Report File');

    # invalid form
    ok( $mech->form_name('add_report') );
    my $too_big = 'a' x 300;
    $mech->set_fields(
        architecture => $too_big,
        platform     => $too_big,
        comments     => ( $too_big x 4 ),
        format       => 'XML',
    );
    $mech->submit();
    ok( $mech->success );
    $mech->content_contains('either incomplete or invalid');
    $mech->content_contains('You must upload a smoke test report');
    $mech->content_contains('class="required warn">Smoke Report File');
    $mech->content_contains('class="warn">Architecture');
    $mech->content_contains('class="warn">Platform');
    $mech->content_contains('class="warn">Comments');
    $mech->content_contains('Must be less than 1000 characters');
    $mech->content_contains('Must be less than 255 characters');
    $mech->content_contains(qq(value="$too_big"));
    $mech->content_contains( '>' . ( $too_big x 4 ) . '<' );

    # valid form
    ok( $mech->form_name('add_report') );
    $mech->set_fields(
        architecture => 'x386',
        platform     => 'Linux',
        format       => 'XML',
        comments     => 'Something random that I want to say',
        report_file  => catfile( InstallRoot, 't', 'data', 'report_bad.xml' ),
    );
    $mech->submit();

    ok( $mech->success );
    $mech->content_contains( $proj1->name . ' - Recent Smoke Reports' );

    # make sure it's in the db
    is( $proj1->report_count, 1 );
    my ($report) = $proj1->all_reports();
    isa_ok( $report,            'Smolder::DB::SmokeReport' );
    isa_ok( $report->project,   'Smolder::DB::Project' );
    isa_ok( $report->developer, 'Smolder::DB::Developer' );
    is( $report->format,     'XML' );
    is( $report->pass,       62 );
    is( $report->fail,       5 );
    is( $report->skip,       5 );
    is( $report->todo,       5 );
    is( $report->test_files, 3 );
    is( $report->total,      67 );
}

# 44..57
# smoke_reports
{
    for ( 1 .. 13 ) {
        create_smoke_report(
            project   => $proj1,
            developer => $dev,
        );
    }
    END { delete_smoke_reports() }

    $mech->get_ok("/app/developer_projects/smoke_reports/$proj1");
    $mech->content_contains( $proj1->name . ' - Recent Smoke Reports' );

    # only 5 per page by default
    $mech->content_like(qr/(Added .*){5}/s);
    $mech->content_unlike(qr/(Added .*){6}/s);

    # check the paging
    my $link = $mech->find_link( n => 1, text => "\x{21d0}" );
    ok( !defined $link );

    # go from 1 to 2
    $mech->follow_link_ok( { n => 1, text => "\x{21d2}" } );

    # go from 2 to 3
    $mech->follow_link_ok( { n => 1, text => "\x{21d2}" } );

    # can't go past 3
    $link = $mech->find_link( n => 1, text => "\x{21d2}" );
    ok( !defined $link );

    # go from 3 to 2
    $mech->follow_link_ok( { n => 1, text => "\x{21d0}" } );

    # go from 2 to 1
    $mech->follow_link_ok( { n => 1, text => "\x{21d0}" } );

    # can't go past 1
    $link = $mech->find_link( n => 1, text => "\x{21d0}" );
    ok( !defined $link );

    # changing the per-page
    $mech->form_name('smoke_reports');
    $mech->set_fields( limit => 10, );
    $mech->submit();
    ok( $mech->success );
    $mech->content_like(qr/(Added .*){10}/s);
    $mech->content_unlike(qr/(Added .*){11}/s);
}

# 58..66
# report_details
{

    # first HTML
    $mech->get_ok("/app/developer_projects/smoke_reports/$proj1");
    $mech->follow_link_ok( { n => 1, text => 'HTML' } );
    ok( $mech->ct, 'text/html' );

    # now XML
    $mech->get_ok("/app/developer_projects/smoke_reports/$proj1");
    $mech->follow_link_ok( { n => 1, text => 'XML' } );
    ok( $mech->ct, 'text/xml' );

    # now YAML
    $mech->get_ok("/app/developer_projects/smoke_reports/$proj1");
    $mech->follow_link_ok( { n => 1, text => 'YAML' } );
    ok( $mech->ct, 'text/plain' );
}

# 67..79
# smoke_report_validity
{
    my $url = "/app/developer_projects/smoke_test_validity";

    # without a report
    $mech->get_ok($url);
    $mech->content_contains("Smoke Report does not exist");

    # not an admin of the project
    my $report = create_smoke_report(
        project   => $proj1,
        developer => $dev,
    );
    my $report_id = $report->id;

    $mech->get_ok("$url/$report_id");
    $mech->content_contains("Not an admin of this project");

    # now make me an admin
    $proj1_dev->admin(1);
    $proj1_dev->update();
    Smolder::DB->dbi_commit();

    # don't give all the necessary data
    $mech->get_ok("$url/$report_id");
    $mech->content_contains("Invalid data");

    # now make it invalid
    $mech->get_ok("$url/$report_id?invalid=1&invalid_reason=something+sucks");
    $mech->content_contains("INVALID");
    $report = undef;
    $report = Smolder::DB::SmokeReport->retrieve($report_id);
    ok( $report->invalid );
    is( $report->invalid_reason, 'something sucks' );

    # now make it valid
    $mech->get_ok("$url/$report_id?invalid=0");
    $mech->content_lacks("INVALID");
    $report = undef;
    $report = Smolder::DB::SmokeReport->retrieve($report_id);
    ok( !$report->invalid );
}

# 87..90
# single smoke_report
{
    # not an admin of the project
    my $report = create_smoke_report(
        project   => $proj1,
        developer => $dev,
    );
    my $url   = "/app/developer_projects/smoke_report/$report";
    my $title = "Smoke Report #$report";
    $mech->get_ok($url);
    $mech->title_like(qr/\Q$title\E/);
    $mech->content_contains('(' . $proj1->name . ')');
    $mech->content_contains($dev->username);
}

# 90..98
# admin_settings, process_admin_settings
{
    my $url      = "/app/developer_projects/admin_settings";
    my %settings = (
        default_arch     => 'AMD64',
        default_platform => 'Linux FC4',
        allow_anon       => 0,
    );
    $proj1->default_platform('Foo');
    $proj1->default_arch('Bar');
    $proj1->allow_anon(1);
    $proj1->update();
    Smolder::DB->dbi_commit();

    # is form pre-filled
    $mech->get_ok("$url/$proj1");
    $mech->content_contains('Project Settings');
    $mech->content_contains('checked="checked" value="1"');
    $mech->content_contains('value="Foo"');
    $mech->content_contains('value="Bar"');

    # invalid form
    ok( $mech->form_name('admin_settings_form') );
    $mech->set_fields(
        default_arch     => ( 'x' x 300 ),
        default_platform => ( 'x' x 300 ),
    );
    $mech->submit();
    ok( $mech->success );
    $mech->content_contains('either incomplete or invalid');
    $mech->content_contains('Too long. Must be under 255 characters.');

    # valid form
    ok( $mech->form_name('admin_settings_form') );
    $mech->set_fields(%settings);
    $mech->submit();
    ok( $mech->success );
    $mech->content_contains('successfully updated');

    my $proj_id = $proj1->id;
    $proj1 = undef;
    $proj1 = Smolder::DB::Project->retrieve($proj_id);
    foreach ( keys %settings ) {
        is( $proj1->$_, $settings{$_} );
    }
}

# 99..117
# add_category, delete_category
{
    my $url = "/app/developer_projects/admin_settings";
    my @categories = ( "Stuff", "More Stuff", );
    $mech->get_ok("$url/$proj1");
    $mech->content_contains('Project Settings');
    $mech->content_contains('none');

    # empty form
    $mech->form_name('project_categories_form');
    $mech->submit();
    ok( $mech->success );
    $mech->content_contains('either incomplete or invalid');

    # invalid form
    $mech->form_name('project_categories_form');
    $mech->set_fields( category => ( 'x' x 300 ) );
    $mech->submit();
    ok( $mech->success );
    $mech->content_contains('either incomplete or invalid');
    $mech->content_contains('Too long');

    # successful
    $mech->form_name('project_categories_form');
    $mech->set_fields( category => $categories[0] );
    $mech->submit();
    ok( $mech->success );
    $mech->content_contains('succesfully added');
    $mech->content_contains( $categories[0] );

    # try to add it again
    $mech->form_name('project_categories_form');
    $mech->set_fields( category => $categories[0] );
    $mech->submit();
    ok( $mech->success );
    $mech->content_contains('already exists');

    # add the next one
    $mech->form_name('project_categories_form');
    $mech->set_fields( category => $categories[1] );
    $mech->submit();
    ok( $mech->success );
    $mech->content_contains('succesfully added');
    $mech->content_contains( $categories[0] );
    $mech->content_contains( $categories[1] );

    # make sure they're all there
    foreach my $cat ( $proj1->categories ) {
        ok( grep { $_ eq $cat } @categories );
    }
}

# 118..132
# authorization for non-public project
{

    # login as another developer not associated with the projects
    logout( mech => $mech );
    my $dev2 = create_developer( password => $pw );
    $mech->get_ok($url);
    login( mech => $mech, username => $dev2->username, password => $pw );

    # make sure I can't see these pages
    $mech->get_ok("/app/developer_projects/add_report/$proj2");
    $mech->content_contains('Unauthorized');
    $mech->get_ok("/app/developer_projects/process_add_report/$proj2");
    $mech->content_contains('Unauthorized');
    $mech->get_ok("/app/developer_projects/smoke_reports/$proj2");
    $mech->content_contains('Unauthorized');

    # check the add_category, delete_category
    $mech->get_ok("/app/developer_projects/add_category/$proj2");
    $mech->content_contains('You are not an admin');
    $mech->get_ok("/app/developer_projects/delete_category/$proj2");
    $mech->content_contains('You are not an admin');

    # check project_settings and project_project_settings
    $mech->get_ok("/app/developer_projects/admin_settings/$proj2");
    $mech->content_contains('You are not an admin');
    $mech->get_ok("/app/developer_projects/process_admin_settings/$proj2");
    $mech->content_contains('You are not an admin');
}

