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
use File::Spec::Functions qw(catfile);
use File::Copy;
use Test::TAP::XML;
use Test::LongString;

plan( tests => 17 );

# setup
END { delete_developers() }
my $dev = create_developer();
END { delete_projects() }
my $project   = create_project();
my $orig_file = catfile( InstallRoot, 't', 'data', 'report_good.xml' );
my $tap       = Test::TAP::XML->from_xml_file($orig_file);

# 1
use_ok('Smolder::DB::SmokeReport');

my $struct = $tap->structure();

# now add it to the database
my $report = Smolder::DB::SmokeReport->create(
    {
        developer    => $dev,
        project      => $project,
        architecture => 'x386',
        platform     => 'Linux FC3',
        comments     => 'nothing to say',
        pass         => $tap->total_passed,
        fail         => $tap->total_failed,
        skip         => $tap->total_skipped,
        todo         => $tap->total_todo,
        total        => $tap->total_seen,
        format       => 'XML',
        test_files   => scalar( $tap->test_files ),
        duration     => ( $struct->{end_time} - $struct->{start_time} ),
    }
);
copy( $orig_file, $report->file ) or die "could not copy $orig_file to '" . $report->file . "': $!";
END { $report->delete if ($report) }
isa_ok( $report,            'Smolder::DB::SmokeReport' );
isa_ok( $report->developer, 'Smolder::DB::Developer' );
isa_ok( $report->project,   'Smolder::DB::Project' );
isa_ok( $report->added,     'DateTime' );
isa_ok( $report->model_obj, 'Test::TAP::XML' );

my $html = $report->html();
is( ref $html, 'SCALAR' );
contains_string( $$html, '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"' );
ok( -e $report->html_file );    # was the html file cached?

# this just checks for failure... it could be much better
ok($report->html_email );
my $xml = $report->xml;
contains_string( $$xml, "<?xml version='1.0' standalone='yes'?>" );
my $yaml = $report->yaml;
contains_string( $$yaml, '---' );    # is there a better way to determine if it's YAML?

#TODO - not sure if there's a good way to test the email sending
TODO: {
    local $TODO = "not testing email sending";

    # $report->send_email
    ok(0);
}

my $old_file      = $report->file;
my $old_html_file = $report->html_file;
ok( $report->delete_files );
ok( !$report->html_file );
ok( !-e $old_file );
ok( !-e $old_html_file );

