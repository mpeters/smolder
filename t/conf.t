use strict;
use warnings;

use Test::More;
use Smolder::TestScript;
plan( tests => 6 );

use_ok('Smolder::Conf');
ok( Smolder::Conf->get('InstallRoot') );
ok( Smolder::Conf->get('User') );
ok( !Smolder::Conf->get('SomeFakeDirective') );
