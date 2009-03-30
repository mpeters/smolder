use strict;
use warnings;
use Test::More;
use Smolder::TestScript;
use File::Spec::Functions qw(catfile);
use File::Basename qw(basename);
use Cwd qw(cwd);

# just make sure we can compile all of our scripts
my $dir = catfile(cwd, 'bin', '*');
my @scripts = ();
@scripts = glob($dir);

plan(tests => scalar(@scripts));

# make sure they compile
foreach my $script (@scripts) {
    my $out = `perl -c $script 2>&1`;

    my $basename = basename($script);
    like($out, qr/syntax OK/, "bin/$basename compiles");
}
