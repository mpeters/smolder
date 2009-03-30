package Smolder::TestScript;
use strict;
use warnings;

=head1 NAME

Smolder::TestScript - setup various things for smolder tests scripts

=head1 DESCRIPTION

This module will setup very things for Smolder test scripts
simply by being C<use>ing it in your scripts.

=head1 SYNOPSIS

    use Smolder::TestScript;

=cut

use Test::Builder;

sub import {
    no warnings;
    *Test::Builder::failure_output = sub { return \*STDOUT };
}

1;
