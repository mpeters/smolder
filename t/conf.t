use Test::More;
use strict;
plan(tests => 4);

use_ok('Smolder::Conf');
ok(Smolder::Conf->get('InstallRoot'));
ok(Smolder::Conf->get('User'));
ok(!Smolder::Conf->get('SomeFakeDirective'));
