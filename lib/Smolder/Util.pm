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

# adapted from Test::TAP::Model::Visual
sub pass_fail_color {
    my $ratio = shift;
    # handle percentages
    $ratio = $ratio / 100 if $ratio > 1;
    my @start_color = ('255', '00',  '00');     # ff0000
    my @end_color   = ('00',  '255', '00');     # 00ff00
    my @color_pieces;
    
    if ( $ratio == 1 ) {
        @color_pieces = @end_color;
    } elsif( $ratio == 0 ) {
        @color_pieces = @start_color;
    } else {
        @color_pieces = (
            '255',
            100 + ( ( 255 - 100 ) * $ratio ),
            100 - 20,
        );
    }
    return sprintf('%02x%02x%02x', @color_pieces);
}

1;

