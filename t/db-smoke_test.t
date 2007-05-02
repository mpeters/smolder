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
use Smolder::Conf qw(InstallRoot);
use File::Spec::Functions qw(catfile catdir);
use Test::LongString;

plan( tests => 60 );

# setup
END { delete_developers() }
my $dev = create_developer();
END { delete_projects() }
my $project   = create_project();

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
isa_ok( $report,            'Smolder::DB::SmokeReport' );
isa_ok( $report->developer, 'Smolder::DB::Developer' );
isa_ok( $report->project,   'Smolder::DB::Project' );
isa_ok( $report->added,     'DateTime' );

# upload a new file
$report = Smolder::DB::SmokeReport->upload_report(
    file => catfile(InstallRoot, 't', 'data', 'test_run_bad.tar.gz'),
    project => $project,
);
# object types
isa_ok( $report,            'Smolder::DB::SmokeReport' );
isa_ok( $report->developer, 'Smolder::DB::Developer' );
isa_ok( $report->project,   'Smolder::DB::Project' );
isa_ok( $report->added,     'DateTime' );

# basic datum
is($report->pass,        446, 'correct # of passed');
is($report->skip,        4,   'correct # of skipped');
is($report->fail,        8,   'correct # of failed');
is($report->todo,        0,   'correct # of todo');
is( $report->test_files, 20,  'correct # of files');
is( $report->total,      454, 'correct # of tests');

my $html = $report->html;
is( ref $html, 'SCALAR' );
contains_string( $$html, '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"' );
ok( -e $report->html_file, 'HTML file saved to disk' );

# make sure that each test file has it's own HTML file too
my $html_dir = catdir(InstallRoot, 'data', 'html_smoke_reports', $report->id);
for(0.. ($report->test_files -1)) {
    ok(-e catfile($html_dir, $_ . '.html'), "Test $_ has HTML file");
}

# now delete everything
$report->delete_files();
ok( !-e $report->file, 'TAP tarball removed');
ok( !-e $report->html_file, 'HTML file removed');
for(0.. ($report->test_files -1)) {
    ok(!-e catfile($html_dir, $_ . '.html'), "Test $_ has no HTML");
}


