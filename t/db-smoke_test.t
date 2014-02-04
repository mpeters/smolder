use strict;
use warnings;
use Test::More;
use Smolder::TestScript;
use Smolder::TestData qw(
  create_developer
  delete_developers
  create_project
  delete_projects
);
use Smolder::Conf;
use File::Spec::Functions qw(catfile catdir);
use Test::LongString;

plan(tests => 82);

# setup
END { delete_developers() }
my $dev = create_developer();
END { delete_projects() }
my $project = create_project();

# 1
use_ok('Smolder::DB::SmokeReport');

# test basic creation
my $report = Smolder::DB::SmokeReport->create(
    {
        developer    => $dev,
        project      => $project,
        architecture => 'x386',
        platform     => 'Linux FC3',
        comments     => 'nothing to say',
        pass         => 100,
        fail         => 20,
        skip         => 10,
        todo         => 10,
        total        => 140,
        test_files   => 10,
        duration     => 30,
    }
);
END { $report->delete if ($report) }
isa_ok($report,            'Smolder::DB::SmokeReport');
isa_ok($report->developer, 'Smolder::DB::Developer');
isa_ok($report->project,   'Smolder::DB::Project');
isa_ok($report->added,     'DateTime');

# upload a new file
$report = Smolder::DB::SmokeReport->upload_report(
    file    => catfile(Smolder::Conf->test_data_dir, 'test_run_bad.tar.gz'),
    project => $project,
);

# object types
isa_ok($report,            'Smolder::DB::SmokeReport');
isa_ok($report->developer, 'Smolder::DB::Developer');
isa_ok($report->project,   'Smolder::DB::Project');
isa_ok($report->added,     'DateTime');

# basic datum
is($report->pass,       453, 'correct # of passed');
is($report->skip,       4,   'correct # of skipped');
is($report->fail,       11,  'correct # of failed');
is($report->todo,       0,   'correct # of todo');
is($report->test_files, 21,  'correct # of files');
is($report->total,      464, 'correct # of tests');
ok(!$report->duration, 'duration not provided');

my $html_file = catfile($report->data_dir, 'html', 'report.html');

my $html = $report->html;
is(ref $html, 'SCALAR');
contains_string($$html, '<table', 'just looking for an HTML tag');
ok(-e $html_file, 'HTML file saved to disk');

# make sure that each test file has its own HTML file too
for (0 .. ($report->test_files - 1)) {
    ok(-e catfile($report->data_dir, 'html', "$_.html"), "Test $_ has HTML file");
}

# try uploading a report with a meta yml file
$report->update_from_tap_archive(catfile(Smolder::Conf->test_data_dir, 'test_run_bad_yml.tar.gz'));
is($report->pass,       453, 'correct # of passed');
is($report->skip,       4,   'correct # of skipped');
is($report->fail,       11,  'correct # of failed');
is($report->todo,       0,   'correct # of todo');
is($report->test_files, 21,  'correct # of files');
is($report->total,      464, 'correct # of tests');
is($report->duration,   208, 'correct duration');

# now delete the leftover files
my $data_dir = $report->data_dir;
my $file     = $report->file;
$report->delete_files();
ok(!-e $file,      'TAP tarball removed');
ok(!-e $html_file, 'HTML file removed');
for (0 .. ($report->test_files - 1)) {
    ok(!-e catfile($data_dir, 'html', "$_.html"), "Test $_ HTML has been removed");
}
ok(!-d $data_dir, 'data directory removed');

# add_tag, tags and delete_tag
$report->add_tag('foo');
$report->add_tag('bar');
my @tags = $report->tags();
is(scalar @tags, 2,     'correct tag count');
is($tags[0],     'bar', 'correct 1st tag');
is($tags[1],     'foo', 'correct 2nd tag');
$report->add_tag('apple');
@tags = $report->tags();
is(scalar @tags, 3,       'correct tag count');
is($tags[0],     'apple', 'correct 1st tag');
is($tags[1],     'bar',   'correct 2nd tag');
is($tags[2],     'foo',   'correct 3rd tag');
$report->delete_tag('bar');
@tags = $report->tags();
is(scalar @tags, 2,       'correct tag count');
is($tags[0],     'apple', 'correct 1st tag');
is($tags[1],     'foo',   'correct 2nd tag');
$report->delete_tag('foo');
$report->delete_tag('apple');
@tags = $report->tags();
is(scalar @tags, 0, 'no tags left');

