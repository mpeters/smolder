package Smolder::Util;
use Smolder::Conf qw(HostName Port);
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
    my @start_color = ('255', '00',  '00');    # ff0000
    my @end_color   = ('00',  '255', '00');    # 00ff00
    my @color_pieces;

    if ($ratio == 1) {
        @color_pieces = @end_color;
    } elsif ($ratio == 0) {
        @color_pieces = @start_color;
    } else {
        @color_pieces = ('255', 100 + ((255 - 100) * $ratio), 100 - 20,);
    }
    return sprintf('%02x%02x%02x', @color_pieces);
}

=head2 format_time

Given a number of seconds, format it as string of the format
C<HH:MM:SS> or C<MM:SS> or C<SS>.

    Smolder::Util::format_time(1000); # prints 16:40
    Smolder::Util::format_time(35);   # prints 35
    Smolder::Util::format_time(100);  # prints 1:40

=cut

sub format_time {
    my $secs = shift;
    return $secs if $secs < 60;
    my $hour = int($secs / 3600);
    my $min  = int(($secs % 3600) / 60);
    my $sec  = $secs % 60;
    if ($hour) {
        return sprintf('%i:%02i:%02i', $hour, $min, $sec);
    } elsif ($min) {
        return sprintf('%i:%02i', $min, $sec);
    }
}

=head2 url_base

This method will return the base url for the installed version of
Smolder.

=cut

{
    my $_base = 'http://' . HostName . (Port == 80 ? '' : ':' . Port);
    sub url_base { $_base }
}

1;

