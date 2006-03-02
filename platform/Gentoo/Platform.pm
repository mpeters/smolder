package Gentoo::Platform;
use strict;
use warnings;

use base 'Smolder::Platform';

use Cwd qw(cwd);

sub guess_platform {
    return 0 unless -e '/etc/gentoo-release';
    open(RELEASE, '/etc/gentoo-release') or return 0;
    my $release = <RELEASE>;
    close RELEASE;
    return 1 if $release =~ /Gentoo/;
    return 0;
}


sub verify_dependencies {
    my ($pkg, %arg) = @_;

    # make sure we're running at least 5.8.2
    my $perl = join('.', (map { ord($_) } split("", $^V, 3)));

    unless ($perl =~ m/5.8.\d+/ ) {
        die sprintf("Your version of perl (%s) is not supported at the moment.\nPlease upgrade to at least 5.8.2\n", $perl);
    }

    return $pkg->SUPER::verify_dependencies(%arg);
}


# setup init script in /etc/init.d.
# Being Gentoo, it will be up to the users to make it start on boot.

sub finish_installation {
    my ($pkg, %arg) = @_;
    my %options = %{$arg{options}};

    my $init_script = "SMOLDER-". $options{HostName};
    print "Installing Smolder init.d script '$init_script'\n";

    my $old = cwd;
    chdir("/etc/init.d");

    my $InstallPath = $options{InstallPath};
    unlink $init_script if -e $init_script;
    my $link_init = "ln -s $InstallPath/bin/smolder_ctl $init_script";
    system($link_init) && die ("Can't link init script: $!");

    chdir $old;
}


sub post_install_message {

    my ($pkg, %arg) = @_;
    my %options = %{$arg{options}};

    $pkg->SUPER::post_install_message(%arg);

    # return a note about setting up smolder_ctl on boot.
    my $init_script = "SMOLDER-". $options{HostName};

    print <<EOREPORT;

   To make Smolder start on boot, run the following command as root:
   rc-update add $init_script boot

EOREPORT

}


1;
