use strict;
use warnings;

use Test::More;
use Smolder::TestScript;
plan(tests => 5);

use_ok('Smolder::Conf');
ok(Smolder::Conf->get('Port'));
ok(Smolder::Conf->get('HostName'));

eval { Smolder::Conf->get('SomeFakeDirective') };
ok($@);
like($@, qr/not a valid Smolder config/);
