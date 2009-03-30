use strict;
use warnings;
use Test::More;
plan(tests => 14);

# 1
use_ok('Smolder::Util');

# 2..5
# pass_fail_color
my @ratios =
  ([1 => '00ff00'], [0 => 'ff0000'], [.25 => 'ff8a50'], [.5 => 'ffb150'], [.75 => 'ffd850'],);

foreach (@ratios) {
    my ($ratio, $color) = @$_;
    is(Smolder::Util::pass_fail_color($ratio), $color);
}

# 6..14
# format_time
my @times = (
    [0     => '0'],
    [35    => '35'],
    [60    => '1:00'],
    [90    => '1:30'],
    [300   => '5:00'],
    [655   => '10:55'],
    [1000  => '16:40'],
    [10000 => '2:46:40'],
);
foreach (@times) {
    my ($time, $formatted) = @$_;
    cmp_ok(Smolder::Util::format_time($time), 'eq', $formatted);
}

