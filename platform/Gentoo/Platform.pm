package Gentoo::Platform;
use strict;
use warnings;

use base 'Smolder::Platform';

use Cwd qw(cwd);

sub guess_platform {
    return 0 unless -e '/etc/gentoo-release';
    open(RELEASE, '/etc/gentoo-release') or return 0;
    my $release = <RELEASE>;
    close RELEASE;
    return 1 if $release =~ /Gentoo/;
    return 0;
}

sub verify_dependencies {
    my ($pkg, %arg) = @_;

    # make sure we're running at least 5.8.2
    my $perl = join('.', (map { ord($_) } split("", $^V, 3)));

    unless ($perl =~ m/5.8.\d+/ ) {
        die sprintf("Your version of perl (%s) is not supported at the moment.\nPlease upgrade to at least 5.8.2\n", $perl);
    }

    return $pkg->SUPER::verify_dependencies(%arg);
}

1;
