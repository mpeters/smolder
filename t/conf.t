use strict;
use warnings;

use Test::More;
use Smolder::TestScript;
plan(tests => 4);

use_ok('Smolder::Conf');
ok(Smolder::Conf->get('Port'));
ok(Smolder::Conf->get('HostName'));
ok(!Smolder::Conf->get('SomeFakeDirective'));
