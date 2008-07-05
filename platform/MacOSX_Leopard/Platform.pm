package MacOSX_Leopard::Platform;
use base 'MacOSX::Platform';
use strict;
use warnings;

# use Directory Service to create a group
sub create_group {
    my ($pkg, %args) = @_;

    my %options = %{$args{options}};
    my $Group   = $options{Group};

    my $groupadd_bin = $pkg->find_bin(bin => 'dscl');

    print "Creating UNIX group ('$Group')\n";
    my ($gname, $gpasswd, $gid, $gmembers) = getgrnam($Group);

    unless (defined($gid)) {
        $gid = generateGid();

        map {
            print "  Running '$_'\n";
            system $_ and die "Failed to create group: $!";
        } ($groupadd_bin . " . -create /groups/$Group PrimaryGroupID $gid",);

        print "  Group created (gid $gid).\n";
    } else {
        print "  Group already exists (gid $gid).\n";
    }

    return $gid;
}

# use Directory Services to create a Smolder user
sub create_user {

    my ($pkg, %args) = @_;

    my %options = %{$args{options}};

    my $useradd_bin = $pkg->find_bin(bin => 'dscl');

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
            $useradd_bin . " . -create /Users/$User",
            $useradd_bin . " . -append /users/$User group $Group",
            $useradd_bin . " . -append /users/$User NFSHomeDirectory $options{InstallPath}",
            $useradd_bin . " . -append /users/$User UniqueID $uid",
            $useradd_bin . " . -append /users/$User PrimaryGroupID $gid",
            $useradd_bin . " . -append /groups/$Group GroupMembership $User",
          );

        print "  User created (uid $uid).\n";
    } else {
        print "  User already exists (uid $uid).\n";
    }

    return $uid;
}

# ask netinfo for the highest gid, and increment it to find an unused gid
sub generateGid {
    my $highestGid =
      qx{dscl . -readall /groups PrimaryGroupID  | grep PrimaryGroupID | cut -d ' ' -f 2 | sort -rn | head -1};

    return ($highestGid + 1);
}

# ask netinfo for the highest uid, and increment it to find an unused uid
sub generateUid {
    my $highestUid =
      qx{dscl . -readall /users UniqueID  | grep UniqueID | cut -d ' ' -f 2 | sort -rn | head -1};
    return ($highestUid + 1);
}


1;
