use strict;
use Test::More;
use File::Spec::Functions qw(catfile);
use File::Basename qw(basename);
use Smolder::Conf qw(InstallRoot HostName);
use Smolder::DB::SmokeReport;
use Smolder::DB::ProjectDeveloper;
use Smolder::TestData qw(
    create_project 
    delete_projects 
    create_developer 
    delete_developers
    create_preference
    delete_preferences
);

plan('no_plan');

my $bin          = catfile(InstallRoot(), 'bin', 'smolder_smoke_signal');
my $host         = HostName();
my $project      = create_project();
my $project_name = $project->name;
my $pw           = 's3cr3t';
my $dev          = create_developer( password => $pw );
my $username     = $dev->username;
my $test_file    = catfile(InstallRoot(), 't', 'data', 'report_good.xml');

END { 
    delete_projects();
    delete_developers();
    delete_preferences();
};

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
$out = `$bin --server $host --project $project_name --username $username --password $pw --file stuff 2>&1`;
like($out, qr/does not exist/i);

# invalid server
$out = `$bin --server something.tld --project $project_name --username $username --password $pw --file $test_file 2>&1`;
like($out, qr/Could not reach/i);

# non-existant project
$out = `$bin --server $host --project "${project_name}asdf" --username $username --password $pw --file $test_file 2>&1`;
like($out, qr/you are not a member of/i);

# invalid login
$out = `$bin --server $host --project "$project_name" --username $username --password asdf --file $test_file 2>&1`;
like($out, qr/Could not login/i);

# non-project-member
$out = `$bin --server $host --project "$project_name" --username $username --password $pw --file $test_file 2>&1`;
like($out, qr/you are not a member of/i);

# add this person to the project
Smolder::DB::ProjectDeveloper->create({
    project     => $project,
    developer   => $dev,
    preference  => create_preference(),
});
Smolder::DB->dbi_commit();

# successfull upload
$out = `$bin --server $host --project "$project_name" --username $username --password $pw --file $test_file 2>&1`;
like($out, qr/successfully uploaded/i);

# make sure it's uploaded to the server
$out =~ /as #(\d+)/;
my $report_id = $1; 
my $report = Smolder::DB::SmokeReport->retrieve($report_id);
isa_ok($report, 'Smolder::DB::SmokeReport');

# test optional options
# comments
my $comments = "Some tests";
$out = `$bin --server $host --project "$project_name" --username $username --password $pw --file $test_file --comments "$comments" 2>&1`;
like($out, qr/successfully uploaded/i);
$out =~ /as #(\d+)/;
$report_id = $1; 
$report = Smolder::DB::SmokeReport->retrieve($report_id);
is($report->comments, $comments);

# platform
my $platform = "my platform";
$out = `$bin --server $host --project "$project_name" --username $username --password $pw --file $test_file --comments "$comments" --platform "$platform" 2>&1`;
like($out, qr/successfully uploaded/i);
$out =~ /as #(\d+)/;
$report_id = $1; 
$report = Smolder::DB::SmokeReport->retrieve($report_id);
is($report->comments, $comments);
is($report->platform, $platform);

# architecture
my $arch = "128 bit something";
$out = `$bin --server $host --project "$project_name" --username $username --password $pw --file $test_file --comments "$comments" --platform "$platform" --architecture "$arch" 2>&1`;
like($out, qr/successfully uploaded/i);
$out =~ /as #(\d+)/;
$report_id = $1; 
$report = Smolder::DB::SmokeReport->retrieve($report_id);
is($report->comments, $comments);
is($report->platform, $platform);
is($report->architecture, $arch);

# category
# TODO - add a category
