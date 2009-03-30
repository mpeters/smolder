package Smolder::Upgrade::V1_1;
use strict;
use warnings;
use base 'Smolder::Upgrade';
use File::Path qw(rmtree);
use File::Spec::Functions qw(catdir);
use Smolder::Conf;

sub pre_db_upgrade { }

sub post_db_upgrade {

    # let's purge all the existing reports
    require Smolder::DB::SmokeReport;
    my @reports = Smolder::DB::SmokeReport->retrieve_all();
    foreach my $report (@reports) {
        $report->delete_files();
        $report->purged(1);
        $report->update();
        Smolder::DB->dbi_commit();
    }

    # remove the old HTML reports in the old format
    rmtree(catdir(Smolder::Conf->data_dir, 'html_smoke_reports'));

    # remove the old XML reports
    my $report_dir = catdir(Smolder::Conf->data_dir, 'smoke_reports');
    rmtree($report_dir);
    mkdir($report_dir);
}

# add a new random secret
sub add_to_config {
    my $secret = _random_secret();
    return qq|
# Secret
# A secret key used for encrypting various bits (auth tokens, etc)
Secret $secret

|;
}

sub _random_secret {
    my $length = int(rand(10) + 20);
    my $secret = '';
    my @chars  = ('a' .. 'z', 'A' .. 'Z', 0 .. 9, qw(! @ $ % ^ & - _ = + | ; : . / < > ?));
    $secret .= $chars[int(rand($#chars + 1))] for (0 .. $length);
    return $secret;
}

1;
