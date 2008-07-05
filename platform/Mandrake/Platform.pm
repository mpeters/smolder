package Mandrake::Platform;
use strict;
use warnings;

use base 'RedHat::Platform';

sub guess_platform {
    return -e '/etc/mandrake-release';
}

1;
