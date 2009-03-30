use strict;
use warnings;

use Test::More;
use Smolder::TestScript;
plan(tests => 7);

use_ok('Smolder::AuthInfo');
my $ai = Smolder::AuthInfo->new();
isa_ok($ai, 'Smolder::AuthInfo');
my %data = (
    id     => 123,
    groups => [qw(foo bar)],
);

my $ticket = $ai->ticket(%data);
ok($ticket, 'got a ticket');

# test parsing a good ticket
$ai->parse($ticket);
is($ai->id, $data{id}, 'good ticket: id correct');
is_deeply($ai->groups, $data{groups}, 'good ticket: groups correct');

# try a bad ticket where someone tampers with the groups
my ($data, $hash) = split('::::', $ticket);
my $bad_ticket = $data . ',admin::::' . $hash;
$ai->parse($bad_ticket);
ok(!$ai->id,     'bad ticket: no id');
ok(!$ai->groups, 'bad ticket: no groups');

