package RedHat::Platform;
use strict;
use warnings;

use base 'Smolder::Platform';

sub release_string { '' }
sub centos_release_string { '' };

sub guess_platform {
    my $class = shift;
    return 0 unless -e '/etc/redhat-release';
    open(RELEASE, '/etc/redhat-release') or return 0;
    my $release = <RELEASE>;
    close RELEASE;
    my $release_str = $class->release_string;
    return 1 if $release =~ /\Q$release_str/;
    if( my $centos_str = $class->centos_release_string ) {
        return 1 if $release =~ /\Q$centos_str/;
    }
    return 0;
}

sub verify_dependencies {
    my ($pkg, %arg) = @_;

    # if this is Perl 5.8.0 then we need to check that the locale
    # isn't set to something UTF8-ish since that breaks this perl
    my $perl = join('.', (map { ord($_) } split("", $^V, 3)));
    if ($perl eq '5.8.0' and $ENV{LANG} and $ENV{LANG} =~ /UTF-8/) {
        die <<END;

Your version of Perl (v5.8.0) must not be used with a UTF-8 locale
setting.  You can fix this problem by either upgrading Perl to v5.8.3
or later or by editing /etc/sysconfig/i18n and choosing a non-UTF-8
LANG setting (ex: en_US).

END

    }

    return $pkg->SUPER::verify_dependencies(%arg);
}

1;
