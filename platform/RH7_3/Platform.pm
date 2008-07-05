package RH7_3::Platform;
use strict;
use warnings;

use base 'Smolder::Platform';

sub guess_platform {
    return 0 unless -e '/etc/redhat-release';
    open(RELEASE, '/etc/redhat-release') or return 0;
    my $release = <RELEASE>;
    close RELEASE;
    return 1 if $release =~ /Red Hat Linux release 7/;
    return 0;
}

1;
