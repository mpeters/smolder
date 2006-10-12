use strict;
use warnings;

use Test::More;
use Smolder::TestScript;
use Smolder::Conf qw(InstallRoot);
use File::Spec::Functions qw(catfile);
use File::Basename qw(basename);

# just make sure we can compile all of our scripts
my $dir = catfile( InstallRoot, 'bin', '*' );
my @scripts = ();
@scripts = glob($dir);
plan( tests => scalar(@scripts) );

# make sure they compile
foreach my $script (@scripts) {
    my $out      = `perl -c $script 2>&1`;
    my $basename = basename($script);
    like( $out, qr/syntax OK/, "bin/$basename compiles" );
}
