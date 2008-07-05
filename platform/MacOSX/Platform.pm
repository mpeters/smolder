package MacOSX::Platform;
use strict;
use warnings;
use base qw{Smolder::Platform};

# smolder_install uses $^X but MacOSX doesn't like this
# on the #! line (doubled here to avoid warning)
$main::PERL_BIN = $main::PERL_BIN = "/usr/bin/perl";

sub guess_platform {
    my $release = `uname -a`;
    return $release =~ /Darwin.*/;
}

# left to its own devices Apache configure will select the Darwin install layout
# there are dependencies in Smolder (eg. smolder_apachectl) which
# assume the Apache layout (eg. httpd in bin not sbin), so force the layout choice
sub apache_build_parameters {
    return "--with-layout=Apache " . Smolder::Platform::apache_build_parameters();
}

# MacOSX ifconfig has same syntax as FreeBSD
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
    unless (grep { $_ eq $IPAddress } @ip_addrs) {
        return 0;
    }
    return 1;
}

# ask netinfo for the highest gid, and increment it to find an unused gid
sub generateGid {
    my $highestGid = qx{nidump group / | cut -f3 -d: | sort -nr | head -1};
    return ($highestGid + 1);
}

# ask netinfo for the highest uid, and increment it to find an unused uid
sub generateUid {
    my $highestUid = qx{nidump passwd / | cut -f3 -d: | sort -nr | head -1};
    return ($highestUid + 1);
}

# use netinfo to create a group
sub create_group {
    my ($pkg, %args) = @_;

    my %options = %{$args{options}};
    my $Group   = $options{Group};

    my $groupadd_bin = $pkg->find_bin(bin => 'nicl');

    print "Creating UNIX group ('$Group')\n";
    my ($gname, $gpasswd, $gid, $gmembers) = getgrnam($Group);

    unless (defined($gid)) {
        $gid = generateGid();

        map {
            print "  Running '$_'\n";
            system $_ and die "Failed to create group: $!";
          } (
            $groupadd_bin . " . -create /groups/$Group",
            $groupadd_bin . " . -append /groups/$Group gid $gid",
            $groupadd_bin . " . -flush"
          );

        print "  Group created (gid $gid).\n";
    } else {
        print "  Group already exists (gid $gid).\n";
    }

    return $gid;
}

# use netinfo to create a Smolder user
sub create_user {

    my ($pkg, %args) = @_;

    my %options = %{$args{options}};

    my $useradd_bin = $pkg->find_bin(bin => 'nicl');

    my $User        = $options{User};
    my $Group       = $options{Group};
    my $InstallPath = $options{InstallPath};

    # Create user, if necessary
    print "Creating UNIX user ('$User')\n";
    my ($uname, $upasswd, $uid, $ugid, $uquota, $ucomment, $ugcos, $udir, $ushell, $uexpire) =
      getpwnam($User);

    my ($gname, $gpasswd, $gid, $gmembers) = getgrnam($Group);

    unless (defined($uid)) {
        $uid = generateUid();

        map {
            print "  Running '$_'\n";
            system $_ and die "Failed to create user: $!";
          } (
            $useradd_bin . " . -create /users/$User",
            $useradd_bin . " . -append /users/$User group $Group",
            $useradd_bin . " . -append /users/$User home $options{InstallPath}",
            $useradd_bin . " . -append /users/$User uid $uid",
            $useradd_bin . " . -append /users/$User gid $gid",
            $useradd_bin . " . -append /groups/$Group users $User",
            $useradd_bin . " . -flush"
          );

        print "  User created (uid $uid).\n";
    } else {
        print "  User already exists (uid $uid).\n";
    }

    return $uid;
}

1;
