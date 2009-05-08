use strict;
use warnings;
use Test::More;
use Smolder::TestScript;
use Smolder::Mech;
use Smolder::DB::ProjectDeveloper;
use Smolder::Conf;
use File::Spec::Functions qw(catfile);
use Smolder::TestData qw(
  base_url
  is_smolder_running
  create_project
  delete_projects
  create_smoke_report
  delete_smoke_reports
  create_developer
  delete_developers
);

if (is_smolder_running) {
    plan(tests => 69);
} else {
    plan(skip_all => 'Smolder not running');
}

my $mech     = Smolder::Mech->new();
my $url      = base_url() . '/public_projects';
my $dev      = create_developer();
my $proj1_id = create_project(public => 1, allow_anon => 1)->id();
my $proj2_id = create_project(public => 0)->id();

END {
    delete_projects();
    delete_developers();
}

# 1
use_ok('Smolder::Control::Public::Projects');

# 2..4
# show_all
{
    $mech->get_ok($url . '/show_all');
    my ($proj1, $proj2) = _get_proj($proj1_id, $proj2_id);
    $mech->content_contains($proj1->name);
    $mech->content_lacks($proj2->name);
}

# 5..9
# project details
{

    # non public project
    $mech->get_ok($url . "/details/$proj2_id");
    $mech->content_contains('not a public project');

    # a public project
    $mech->get_ok($url . "/details/$proj1_id");
    $mech->content_lacks('not a public project');
    $mech->content_contains('Details');
}

# 10..45
# add_report and process_add_report
{
    my $proj1 = _get_proj($proj1_id);
    $mech->follow_link_ok({text => 'Add Smoke Report', n => 1});
    $mech->content_contains('New Smoke Report');
    $mech->content_contains($proj1->name);

    # empty form
    ok($mech->form_name('add_report'));
    $mech->submit();
    ok($mech->success);
    $mech->content_contains('missing required fields');
    $mech->content_contains('You must upload a smoke test report');
    $mech->content_contains('class="required warn">Smoke Report File');

    # invalid form
    ok($mech->form_name('add_report'));
    my $too_big = 'a' x 300;
    $mech->set_fields(
        architecture => $too_big,
        platform     => $too_big,
        comments     => ($too_big x 4),
    );
    $mech->submit();
    ok($mech->success);
    $mech->content_contains('missing required fields');
    $mech->content_contains('You must upload a smoke test report');
    $mech->content_contains('class="required warn">Smoke Report File');
    $mech->content_contains('class="warn">Architecture');
    $mech->content_contains('class="warn">Platform');
    $mech->content_contains('class="warn">Comments');
    $mech->content_contains('Comments must be less than 1000 characters');
    $mech->content_contains('Architecture must be less than 255 characters');
    $mech->content_contains('Platform must be less than 255 characters');
    $mech->content_contains(qq(value="$too_big"));
    $mech->content_contains('>' . ($too_big x 4) . '<');

    # valid form
    ok($mech->form_name('add_report'));
    $mech->set_fields(
        architecture => 'x386',
        platform     => 'Linux',
        comments     => 'Something random that I want to say',
        report_file  => catfile(Smolder::Conf->test_data_dir, 'test_run_bad.tar.gz'),
    );
    $mech->submit();
    ok($mech->success);
    $mech->content_contains($proj1->name);
    $mech->content_contains('Recent Smoke Reports');

    # make sure it's in the db
    $proj1 = _get_proj($proj1_id);
    is($proj1->report_count, 1);
    my ($report) = $proj1->all_reports();
    isa_ok($report,            'Smolder::DB::SmokeReport');
    isa_ok($report->project,   'Smolder::DB::Project');
    isa_ok($report->developer, 'Smolder::DB::Developer');
    is($report->developer->guest, 1);
    is($report->pass,       453, 'correct # of passed');
    is($report->skip,       4,   'correct # of skipped');
    is($report->fail,       11,  'correct # of failed');
    is($report->todo,       0,   'correct # of todo');
    is($report->test_files, 21,  'correct # of files');
    is($report->total,      464, 'correct # of tests');
}

# 46..60
# smoke_reports
{
    my $proj1 = _get_proj($proj1_id);
    for (1 .. 13) {
        create_smoke_report(
            project   => $proj1,
            developer => $dev,
        );
    }
    END { delete_smoke_reports() }

    $mech->get_ok("/app/public_projects/smoke_reports/$proj1");
    $mech->content_contains($proj1->name);
    $mech->content_contains('Recent Smoke Reports');

    # only 5 per page by default
    $mech->content_like(qr/(Added .*){5}/s);
    $mech->content_unlike(qr/(Added .*){6}/s);

    # check the paging
    my $link = $mech->find_link(n => 1, text => "\x{21d0}");
    ok(!defined $link);

    $mech->follow_link_ok({n => 1, text => "\x{21d2}"}, 'link from page 1 to 2');
    $mech->follow_link_ok({n => 1, text => "\x{21d2}"}, 'link from page 2 to 3');

    # can't go past 3
    $link = $mech->find_link(n => 1, text => "\x{21d2}");
    ok(!defined $link);

    $mech->follow_link_ok({n => 1, text => "\x{21d0}"}, 'link from page 3 to 2');
    $mech->follow_link_ok({n => 1, text => "\x{21d0}"}, 'link from page 2 to 1');

    # can't go past 1
    $link = $mech->find_link(n => 1, text => "\x{21d0}");
    ok(!defined $link);

    # changing the per-page
    $mech->form_name('smoke_reports');
    $mech->set_fields(limit => 10,);
    $mech->submit();
    ok($mech->success);
    $mech->content_like(qr/(Added .*){10}/s);
    $mech->content_unlike(qr/(Added .*){11}/s);
}

# 61..65
# report_details
{
    my $proj1 = _get_proj($proj1_id);

    $mech->get_ok("/app/public_projects/smoke_reports/$proj1");
    $mech->follow_link_ok({n => 1, url_regex => qr/report_details/});
    ok($mech->ct, 'text/html');

    # individual report files
    $mech->get_ok("/app/public_projects/test_file_report_details/$proj1/0");
    ok($mech->ct, 'text/html');
}

# 66..69
# single smoke_report
{
    my $proj1 = _get_proj($proj1_id);

    # not an admin of the project
    my $report = create_smoke_report(
        project   => $proj1,
        developer => $dev,
    );
    my $url   = "/app/public_projects/smoke_report/$report";
    my $title = "Smoke Report #$report";
    $mech->get_ok($url);
    $mech->title_like(qr/\Q$title\E/);
    $mech->content_contains('(' . $proj1->name . ')');
    $mech->content_contains($dev->username);
}

sub _get_proj {
    my (@ids) = @_;
    my @projs;
    foreach my $id (@ids) {
        push(@projs, Smolder::DB::Project->retrieve($id));
    }
    if (wantarray) {
        return @projs;
    } else {
        return $projs[0];
    }
}

