package FreeBSD::Platform;
use strict;
use warnings;

use base 'Smolder::Platform';

use Cwd qw(cwd);

sub guess_platform {

    my $release = `uname -a`;

    return 1 if $release =~ /FreeBSD.*/;
    return 0;

}

# BSD ifconfig has slightly different syntax.
sub check_ip {
    my ($pkg, %arg) = @_;
    my $IPAddress = $arg{ip};

    my $ifconfig = `/sbin/ifconfig`;
    my @ip_addrs = ();
    foreach my $if_line (split(/\n/, $ifconfig)) {
        next unless ($if_line =~ /inet\ (\d+\.\d+\.\d+\.\d+)/);
        my $ip = $1;
        push(@ip_addrs, $ip);
    }
    unless (grep {$_ eq $IPAddress} @ip_addrs) {
        return 0;
    }
    return 1;
}

# BSD creates groups differently as well.
sub create_group {
    my ($pkg, %args) = @_;

    my %options = %{$args{options}};
    my $Group  = $options{Group};

    my $groupadd_bin = $pkg->find_bin(bin => 'pw');

    print "Creating UNIX group ('$Group')\n";
    my ($gname,$gpasswd,$gid,$gmembers) = getgrnam($Group);

    unless (defined($gid)) {
        my $groupadd = $groupadd_bin;
        $groupadd .= " groupadd $Group";
        system($groupadd) && die("Can't add group: $!");

        ($gname,$gpasswd,$gid,$gmembers) = getgrnam($Group);
        print "  Group created (gid $gid).\n";

    } else {
        print "  Group already exists (gid $gid).\n";
    }

    return $gid;
}

# BSD also creates users in a different fashion.
sub create_user {

    my ($pkg, %args) = @_;

    my %options = %{$args{options}};

    my $useradd_bin = $pkg->find_bin(bin => 'pw');

    my $User   = $options{User};
    my $Group  = $options{Group};
    my $InstallPath = $options{InstallPath};

    # Get Group info.
    my ($gname,$gpasswd,$gid,$gmembers) = getgrnam($Group);

    # Create user, if necessary
    print "Creating UNIX user ('$User')\n";
    my ($uname,$upasswd,$uid,$ugid,$uquota,$ucomment,$ugcos,$udir,$ushell,$uexpire) = getpwnam($User);

    unless (defined($uid)) {
        my $useradd = $useradd_bin;

        $useradd .= " useradd $User -d $InstallPath -g $gid -c 'Smolder User'";
        system($useradd) && die("Can't add user: $!");

        # Update user data
        ($uname,$upasswd,$uid,$ugid,$uquota,$ucomment,$ugcos,$udir,$ushell,$uexpire) = getpwnam($User);
        print "  User created (uid $uid).\n";
    } else {
        print "  User already exists (uid $uid).\n";
    }

    # Sanity check - make sure the user is a member of the group.
    ($gname,$gpasswd,$gid,$gmembers) = getgrnam($Group);

    my @group_members = ( split(/\s+/, $gmembers) );
    my $user_is_group_member = ( grep { $_ eq $User } @group_members );

    unless (($ugid eq $gid) or $user_is_group_member) {
        $pkg->usermod(options => \%options);
    }

    return $uid;

}

# BSD usermod is different as well.
sub usermod {
    my ($pkg, %args) = @_;

    my %options = %{$args{options}};

    my $User  = $options{User};
    my $Group = $options{Group};

    print "  Adding user $User to group $Group.\n";

    my $usermod = $pkg->find_bin(bin => 'pw');

    $usermod .= " usermod $User -G $Group ";

    system($usermod) && die("Can't add user $User to group $Group: $!");
    print "  User added to group.\n";

}

# setup init script in /etc/rc.d.
sub finish_installation {
    my ($pkg, %arg) = @_;
    my %options = %{$arg{options}};

    my $init_script = "SMOLDER-". $options{HostName};
    print "Installing Smolder init script '$init_script'\n";

    my $old = cwd;
    chdir("/etc/rc.d");

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

    my $init_script = "SMOLDER-" . $options{HostName};

    # return a note about setting up smolder_ctl on boot.
    print "   Smolder has installed a control script in: /etc/rc.d/$init_script\n\n";

}

1;
