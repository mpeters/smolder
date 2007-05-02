use strict;
use warnings;

use Test::More;
use Smolder::TestScript;
use Smolder::Conf qw(InstallRoot);
use Smolder::Platform;
use File::Spec::Functions qw(catfile);
use File::Basename qw(basename);

my %build_params = Smolder::Platform->build_params();

# just make sure we can compile all of our scripts
my $dir = catfile( InstallRoot, 'bin', '*' );
my @scripts = ();
@scripts = glob($dir);

my @dev_scripts = qw(
    smolder_src_dependency_check
    smolder_pod2html
);
# if we aren't in a dev build, skip the dev scripts
if( ! $build_params{Dev} ) {
    foreach my $script (@dev_scripts) {
        @scripts = grep { $_ !~ /$script/ } @scripts;
    }
}

plan( tests => scalar(@scripts) );

# make sure they compile
foreach my $script (@scripts) {
    my $out      = `perl -c $script 2>&1`;
    
    my $basename = basename($script);
    like( $out, qr/syntax OK/, "bin/$basename compiles" );
}
