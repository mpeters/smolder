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
    plan(tests => 30);
} else {
    plan(skip_all => 'Smolder not running');
}

my $bin          = catfile(cwd(), 'bin', 'smolder_smoke_signal');
my $host         = HostName() . ':' . Port();
my $project      = create_project();
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
like($out, qr/Missing required field 'server'/i);
$out = `$bin --server $host 2>&1`;
like($out, qr/Missing required field 'project'/i);
$out = `$bin --server $host --project $project_name 2>&1`;
like($out, qr/Missing required field 'username'/i);
$out = `$bin --server $host --project $project_name --username $username 2>&1`;
like($out, qr/Missing required field 'password'/i);
$out = `$bin --server $host --project $project_name --username $username --password $pw 2>&1`;
like($out, qr/Missing required field 'file'/i);

# invalid file
$out =
  `$bin --server $host --project $project_name --username $username --password $pw --file stuff 2>&1`;
like($out, qr/does not exist/i);

# invalid server
$out =
  `$bin --server something.tld --project $project_name --username $username --password $pw --file $good_run_gz 2>&1`;
like($out, qr/Could not reach/i);

SKIP: {

    # non-existant project
    $out =
      `$bin --server $host --project "${project_name}asdf" --username $username --password $pw --file $good_run_gz 2>&1`;
    skip("Smolder not running", 14)
      if ($out =~ /Received status 500/);
    like($out, qr/you are not a member of/i);

    # invalid login
    $out =
      `$bin --server $host --project "$project_name" --username $username --password asdf --file $good_run_gz 2>&1`;
    like($out, qr/Could not login/i);

    # non-project-member
    $out =
      `$bin --server $host --project "$project_name" --username $username --password $pw --file $good_run_gz 2>&1`;
    like($out, qr/you are not a member of/i);

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
    like($out, qr/successfully uploaded/i);
    $out =~ /as #(\d+)/;
    $report_id = $1;
    $report    = Smolder::DB::SmokeReport->retrieve($report_id);
    is($report->comments, $comments);
    Smolder::DB->disconnect();

    # platform
    my $platform = "my platform";
    $out =
      `$bin --server $host --project "$project_name" --username $username --password $pw --file $good_run_gz --comments "$comments" --platform "$platform" 2>&1`;
    like($out, qr/successfully uploaded/i);
    $out =~ /as #(\d+)/;
    $report_id = $1;
    $report    = Smolder::DB::SmokeReport->retrieve($report_id);
    is($report->comments, $comments);
    is($report->platform, $platform);
    Smolder::DB->disconnect();

    # architecture
    my $arch = "128 bit something";
    $out =
      `$bin --server $host --project "$project_name" --username $username --password $pw --file $good_run_gz --comments "$comments" --platform "$platform" --architecture "$arch" 2>&1`;
    like($out, qr/successfully uploaded/i);
    $out =~ /as #(\d+)/;
    $report_id = $1;
    $report    = Smolder::DB::SmokeReport->retrieve($report_id);
    is($report->comments,     $comments);
    is($report->platform,     $platform);
    is($report->architecture, $arch);
    Smolder::DB->disconnect();

    # tags
    my @tags = ("Foo", "My Bar");
    Smolder::DB->disconnect();
    my $cmd =
      qq($bin --server $host --project "$project_name" --username $username --password $pw --file $good_run_gz --comments "$comments" --platform "$platform" --architecture "$arch" --tags ")
      . join(', ', @tags)
      . qq(" 2>&1);
    $out = `$cmd`;
    like($out, qr/successfully uploaded/i);
    $out =~ /as #(\d+)/;
    $report_id = $1;
    $report    = Smolder::DB::SmokeReport->retrieve($report_id);
    is($report->comments,     $comments);
    is($report->platform,     $platform);
    is($report->architecture, $arch);
    my @assigned_tags = $report->tags;
    cmp_ok(@tags, '==', 2, 'correct number of tags');

    foreach my $t (@tags) {
        ok(grep { $_ eq $t } @assigned_tags, qq(tag "$t" correctly appears in report));
    }
    delete_tags(@tags);
    Smolder::DB->disconnect();
}
