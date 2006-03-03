package Smolder::Util;
use strict;
use warnings;

=head1 NAME

Smolder::Util

=head1 DESCRIPTION 

Collection of various useful routines for Smolder

=head1 ROUTINES

=head2 pass_fail_color

Given a ratio, will return an RRGGBB color suitable for a web page
as a visual indicator of a test's success. Green == 100%, Red == 0%.

=cut

sub pass_fail_color {

    # adapted from Test::TAP::Model::Visual
    my $ratio = shift;
    my $l     = 100;
    if ( $ratio == 1 ) {
        return "00ff00";
    } else {
        return sprintf( "ff%02x%02x", $l + ( ( 255 - $l ) * $ratio ), $l - 20 );
    }
}

1;

