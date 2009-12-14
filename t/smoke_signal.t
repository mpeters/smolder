use strict;
use warnings;
use Test::More;
use File::Spec::Functions qw(catfile);
use File::Basename qw(basename);
use Smolder::TestScript;
use Smolder::Conf qw(HostName Port);
use Smolder::DB::SmokeReport;
use Smolder::DB::ProjectDeveloper;
use Cwd qw(cwd);
use Smolder::TestData qw(
  is_smolder_running
  create_project
  delete_projects
  create_developer
  delete_developers
  create_preference
  delete_preferences
  delete_tags
);

if (is_smolder_running) {
    plan(tests => 33);
} else {
    plan(skip_all => 'Smolder not running');
}

my $bin          = catfile(cwd(), 'bin', 'smolder_smoke_signal');
my $host         = HostName() . ':' . Port();
my $project      = create_project(public => 0);
my $project_name = $project->name;
my $pw           = 's3cr3t';
my $dev          = create_developer(password => $pw);
my $username     = $dev->username;
my $good_run_gz  = catfile(Smolder::Conf->test_data_dir, 'test_run_good.tar.gz');
my $good_run     = catfile(Smolder::Conf->test_data_dir, 'test_run_bad.tar');

END {
    delete_projects();
    delete_developers();
    delete_preferences();
}

# test required options
my $out = `$bin 2>&1`;
like($out, qr/Missing required field 'server'/i, 'missing --server');
$out = `$bin --server $host 2>&1`;
like($out, qr/Missing required field 'project'/i, 'missing --project');
$out = `$bin --server $host --project $project_name --username $username --password $pw 2>&1`;
like($out, qr/Missing required field 'file'/i, 'missing --file');

# invalid file
$out =
  `$bin --server $host --project $project_name --username $username --password $pw --file stuff 2>&1`;
like($out, qr/does not exist/i, 'invalid file');

# invalid server
$out =
  `$bin --server something --project $project_name --username $username --password $pw --file $good_run_gz 2>&1`;
like($out, qr/Could not reach/i, 'invalid server');

SKIP: {

    # non-existant project
    $out =
      `$bin --server $host --project "${project_name}asdf" --username $username --password $pw --file $good_run_gz 2>&1`;
    skip("Smolder not running", 14)
      if ($out =~ /Received status 500/);
    like($out, qr/do not have access/i, 'non-existant project');

    # invalid login
    $out =
      `$bin --server $host --project "$project_name" --username $username --password asdf --file $good_run_gz 2>&1`;
    like($out, qr/Could not login/i, 'bad login credentials');

    # non-project-member
    $out =
      `$bin --server $host --project "$project_name" --username $username --password $pw --file $good_run_gz 2>&1`;
    like($out, qr/do not have access/i, 'not a member of the project');

    # add this person to the project
    Smolder::DB::ProjectDeveloper->create(
        {
            project    => $project,
            developer  => $dev,
            preference => create_preference(),
        }
    );
    Smolder::DB->disconnect();

    # successful tar.gz upload
    $out =
      `$bin --server $host --project "$project_name" --username $username --password $pw --file $good_run_gz 2>&1`;
    like($out, qr/successfully uploaded/i, 'Successful .tar.gz upload');

    # make sure it's uploaded to the server
    $out =~ /as #(\d+)/;
    my $report_id = $1;
    my $report    = Smolder::DB::SmokeReport->retrieve($report_id);
    isa_ok($report, 'Smolder::DB::SmokeReport', 'report obj from .tar.gz');
    Smolder::DB->disconnect();

    # succesful tar upload
    $out =
      `$bin --server $host --project "$project_name" --username $username --password $pw --file $good_run 2>&1`;
    like($out, qr/successfully uploaded/i, 'Successful .tar upload');

    # make sure it's uploaded to the server
    $out =~ /as #(\d+)/;
    $report_id = $1;
    $report    = Smolder::DB::SmokeReport->retrieve($report_id);
    isa_ok($report, 'Smolder::DB::SmokeReport', 'report obj from .tar');
    Smolder::DB->disconnect();

    # test optional options
    # comments
    my $comments = "Some tests";
    $out =
      `$bin --server $host --project "$project_name" --username $username --password $pw --file $good_run_gz --comments "$comments" 2>&1`;
    like($out, qr/successfully uploaded/i, 'successfully uploaded w/comments');
    $out =~ /as #(\d+)/;
    $report_id = $1;
    $report    = Smolder::DB::SmokeReport->retrieve($report_id);
    is($report->comments, $comments, 'correct comments');
    Smolder::DB->disconnect();

    # platform
    my $platform = "my platform";
    $out =
      `$bin --server $host --project "$project_name" --username $username --password $pw --file $good_run_gz --comments "$comments" --platform "$platform" 2>&1`;
    like($out, qr/successfully uploaded/i, 'successful upload w/platform info');
    $out =~ /as #(\d+)/;
    $report_id = $1;
    $report    = Smolder::DB::SmokeReport->retrieve($report_id);
    is($report->comments, $comments, 'correct comments');
    is($report->platform, $platform, 'correct platform');
    Smolder::DB->disconnect();

    # architecture
    my $arch = "128 bit something";
    $out =
      `$bin --server $host --project "$project_name" --username $username --password $pw --file $good_run_gz --comments "$comments" --platform "$platform" --architecture "$arch" 2>&1`;
    like($out, qr/successfully uploaded/i, 'successful upload w/arch');
    $out =~ /as #(\d+)/;
    $report_id = $1;
    $report    = Smolder::DB::SmokeReport->retrieve($report_id);
    is($report->comments,     $comments, 'correct comments');
    is($report->platform,     $platform, 'correct platform');
    is($report->architecture, $arch, 'correct arch');
    Smolder::DB->disconnect();

    # tags
    my @tags = ("Foo", "My Bar");
    Smolder::DB->disconnect();
    my $cmd =
      qq($bin --server $host --project "$project_name" --username $username --password $pw --file $good_run_gz --comments "$comments" --platform "$platform" --architecture "$arch" --tags ")
      . join(', ', @tags)
      . qq(" 2>&1);
    $out = `$cmd`;
    like($out, qr/successfully uploaded/i, 'successful upload w/tags');
    $out =~ /as #(\d+)/;
    $report_id = $1;
    $report    = Smolder::DB::SmokeReport->retrieve($report_id);
    is($report->comments,     $comments, 'correct comments');
    is($report->platform,     $platform, 'correct platform');
    is($report->architecture, $arch, 'correct arch');
    my @assigned_tags = $report->tags;
    cmp_ok(@tags, '==', 2, 'correct number of tags');

    foreach my $t (@tags) {
        ok(grep { $_ eq $t } @assigned_tags, qq(tag "$t" correctly appears in report));
    }
    delete_tags(@tags);
    Smolder::DB->disconnect();

    # non-public project anonymous 
    $cmd = qq($bin --server $host --project "$project_name" --file $good_run_gz --comments "$comments" --platform "$platform" 2>&1);
    $out = `$cmd`;
    like($out, qr/not a public project/i, 'not a public project');
    Smolder::DB->disconnect();

    # invalid anonymous upload
    $project->public(1);
    $project->allow_anon(0);
    $project->update();
    Smolder::DB->disconnect();
    $cmd = qq($bin --server $host --project "$project_name" --file $good_run_gz --comments "$comments" --platform "$platform" 2>&1);
    $out = `$cmd`;
    like($out, qr/not allow anonymous/i, 'no anonymous uploads');
    Smolder::DB->disconnect();

    # anonymous upload
    $project->allow_anon(1);
    $project->update();
    Smolder::DB->disconnect();
    $cmd = qq($bin --server $host --project "$project_name" --file $good_run_gz --comments "$comments" --platform "$platform" 2>&1);
    $out = `$cmd`;
    like($out, qr/successfully uploaded/i, 'successful anonymous upload');
    $out =~ /as #(\d+)/;
    $report_id = $1;
    $report    = Smolder::DB::SmokeReport->retrieve($report_id);
    is($report->comments,     $comments, 'correct comments');
    is($report->platform,     $platform, 'correct platform');
    Smolder::DB->disconnect();
}
