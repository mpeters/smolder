use strict;
use warnings;
use Test::More;
use Smolder::TestScript;
use Smolder::TestData qw(
  base_url
  is_apache_running
  create_developer
  delete_developers
  create_project
  delete_projects
  create_smoke_report
  delete_smoke_reports
);
use Smolder::Mech;
use Smolder::DB::ProjectDeveloper;
use Smolder::Conf qw(InstallRoot);
use File::Spec::Functions qw(catfile);

if (is_apache_running) {
    plan( tests => 80 );
} else {
    plan( skip_all => 'Smolder apache not running' );
}

my $mech     = Smolder::Mech->new();
my $url      = base_url() . '/developer_projects';
my $pw       = 's3cr3t';
my $dev      = create_developer( password => $pw );
my $proj1_id = create_project()->id();
my $proj2_id = create_project( public => 0 )->id();

# add this $dev to $proj1 and $proj2
my $proj1_dev =
  Smolder::DB::ProjectDeveloper->create( { developer => $dev, project => $proj1_id } );
my $proj2_dev =
  Smolder::DB::ProjectDeveloper->create( { developer => $dev, project => $proj2_id } );
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
$mech->login( username => $dev->username, password => $pw );
ok( $mech->success );
$mech->get_ok($url);
$mech->content_contains('My Projects');

# 7..9
# show_all
{
    $mech->get_ok( $url . '/show_all' );
    my ( $proj1, $proj2 ) = _get_proj( $proj1_id, $proj2_id );
    $mech->content_contains( $proj1->name );
    $mech->content_contains( $proj2->name );
}

# 10..43
# add_report and process_add_report
{
    my $proj1 = _get_proj($proj1_id);
    $mech->follow_link_ok( { text => 'Upload Smoke Test', n => 1 } );
    $mech->content_contains('New Smoke Report');
    $mech->content_contains( $proj1->name );

    # empty form
    ok( $mech->form_name('add_report') );
    $mech->submit();
    ok( $mech->success );
    $mech->content_contains('missing required fields');
    $mech->content_contains('You must upload a smoke test report');
    $mech->content_contains('class="required warn">Smoke Report File');

    # invalid form
    ok( $mech->form_name('add_report') );
    my $too_big = 'a' x 300;
    $mech->set_fields(
        architecture => $too_big,
        platform     => $too_big,
        comments     => ( $too_big x 4 ),
    );
    $mech->submit();
    ok( $mech->success );
    $mech->content_contains('missing required fields');
    $mech->content_contains('You must upload a smoke test report');
    $mech->content_contains('class="required warn">Smoke Report File');
    $mech->content_contains('class="warn">Architecture');
    $mech->content_contains('class="warn">Platform');
    $mech->content_contains('class="warn">Comments');
    $mech->content_contains('must be less than 1000 characters');
    $mech->content_contains('must be less than 255 characters');
    $mech->content_contains(qq(value="$too_big"));
    $mech->content_contains( '>' . ( $too_big x 4 ) . '<' );

    # valid form
    ok( $mech->form_name('add_report') );
    $mech->set_fields(
        architecture => 'x386',
        platform     => 'Linux',
        comments     => 'Something random that I want to say',
        report_file  => catfile( InstallRoot, 't', 'data', 'test_run_bad.tar.gz' ),
    );
    $mech->submit();
    ok( $mech->success );
    $mech->content_contains( $proj1->name );
    $mech->content_contains('Recent Smoke Reports');

    # make sure it's in the db
    $proj1 = _get_proj($proj1_id);
    is( $proj1->report_count, 1 );
    my ($report) = $proj1->all_reports();
    isa_ok( $report,            'Smolder::DB::SmokeReport' );
    isa_ok( $report->project,   'Smolder::DB::Project' );
    isa_ok( $report->developer, 'Smolder::DB::Developer' );
    is($report->pass,        446, 'correct # of passed');
    is($report->skip,        4,   'correct # of skipped');
    is($report->fail,        8,   'correct # of failed');
    is($report->todo,        0,   'correct # of todo');
    is( $report->test_files, 20,  'correct # of files');
    is( $report->total,      454, 'correct # of tests');
}


# 44..58
# smoke_reports
{
    my $proj1 = _get_proj($proj1_id);
    for ( 1 .. 13 ) {
        create_smoke_report(
            project   => $proj1,
            developer => $dev,
        );
    }
    END { delete_smoke_reports() }

    $mech->get_ok("/app/developer_projects/smoke_reports/$proj1");
    $mech->content_contains( $proj1->name );
    $mech->content_contains('Recent Smoke Reports');

    # only 5 per page by default
    $mech->content_like(qr/(Added .*){5}/s);
    $mech->content_unlike(qr/(Added .*){6}/s);

    # check the paging
    my $link = $mech->find_link( n => 1, text => "\x{21d0}" );
    ok( !defined $link, 'no go-back link' );

    # go from 1 to 2
    $mech->follow_link_ok( { n => 1, text => "\x{21d2}" }, 'go from 1 to 2' );

    # go from 2 to 3
    $mech->follow_link_ok( { n => 1, text => "\x{21d2}" }, 'go from 2 to 3' );
    # can't go past 3
    $link = $mech->find_link( n => 1, text => "\x{21d2}" );
    ok( !defined $link, 'no go-forward link' );

    # go from 3 to 2
    $mech->follow_link_ok( { n => 1, text => "\x{21d0}" }, 'go from 3 to 2' );

    # go from 2 to 1
    $mech->follow_link_ok( { n => 1, text => "\x{21d0}" }, 'go from 2 to 1' );

    # can't go past 1
    $link = $mech->find_link( n => 1, text => "\x{21d0}" );
    ok( !defined $link, 'no go-back link' );

    # changing the per-page
    $mech->form_name('smoke_reports');
    $mech->set_fields( limit => 10, );
    $mech->submit();
    ok( $mech->success );
    $mech->content_like(qr/(Added .*){10}/s);
    $mech->content_unlike(qr/(Added .*){11}/s);
}

# 59..63
# report_details
{
    my $proj1 = _get_proj($proj1_id);

    # first HTML
    $mech->get_ok("/app/developer_projects/smoke_reports/$proj1");
    $mech->follow_link_ok( { n => 1, text => 'Details' } );
    ok( $mech->ct, 'text/html' );

    # individual report files
    $mech->get_ok("/app/developer_projects/test_file_report_details/$proj1/0");
    ok( $mech->ct, 'text/html' );
}

# 64..76
# smoke_report_validity
{
    my $proj1 = _get_proj($proj1_id);
    my $url   = "/app/developer_projects/smoke_test_validity";

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

# 77..80
# single smoke_report
{
    my $proj1 = _get_proj($proj1_id);

    # not an admin of the project
    my $report = create_smoke_report(
        project   => $proj1,
        developer => $dev,
    );
    my $url   = "/app/developer_projects/smoke_report/$report";
    my $title = "Smoke Report #$report";
    $mech->get_ok($url);
    $mech->title_like(qr/\Q$title\E/);
    $mech->content_contains( '(' . $proj1->name . ')' );
    $mech->content_contains( $dev->username );
}

sub _get_proj {
    my (@ids) = @_;
    my @projs;
    foreach my $id (@ids) {
        push( @projs, Smolder::DB::Project->retrieve($id) );
    }
    if (wantarray) {
        return @projs;
    } else {
        return $projs[0];
    }
}

