package MacOSX::Platform;
use strict;
use warnings;

use base qw{Smolder::Platform};

use Cwd qw(cwd);
use Config;

# smolder_install uses $^X but MacOSX doesn't like this
# on the #! line (doubled here to avoid warning)
$main::PERL_BIN = $main::PERL_BIN = "/usr/bin/perl";

# datastructures for library and header locations
# filled in via findIncsAndLibs below these are hashes
# of filenames => paths, consulted by ia MacOSX specific
# implementation of _check_libs, below
our %libFiles;
our %incFiles;

sub guess_platform {
    my $release = `uname -a`;

    return 1 if $release =~ /Darwin.*/;
    return 0;

}

sub getLibDirs
{
    my $pkg = shift;

    my @libs = split( " ", $Config{libpth} );
    push( @libs, split( ' ', $ENV{MACOSX_LIB} ) ) if defined $ENV{MACOSX_LIB};

    print "Using lib dirs: ",join( ' ', @libs ),"\n";

    return @libs;
}

sub getIncDirs
{
    my $pkg = shift;

    my @incs = ( $Config{usrinc}, '/include', '/usr/local/include' );
    push( @incs, split( ' ', $ENV{MACOSX_INC} ) ) if defined $ENV{MACOSX_INC};

    print "Using inc dirs: ", join( ' ', @incs ),"\n";

    return @incs;
}

sub exploreDirs
{
    my ( $pkg, $hashref, @dirs ) = @_;

    my $dir;
    foreach $dir (@dirs)
    {
        -d $dir or next;

        opendir( DIR, $dir ) or die $!;

        my $dirEntry;
        for $dirEntry ( readdir( DIR ) )
        {
                not -d $dirEntry and ( $hashref->{$dirEntry} = $dir );
        }

        closedir( DIR );
    }
}

# build up the datastructure for checking libraries
# queried by _check_libs below
# need to look in 'less standard' library/ include locations 
# (eg. fink's /sw/lib, /sw/include) 
# these are defined in MACOSX_LIB and MACOSX_INC environment vars
sub findIncsAndLibs
{
    my $pkg = shift;

    $pkg->exploreDirs( \%MacOSX::Platform::libFiles, $pkg->getLibDirs() );

    $pkg->exploreDirs( \%MacOSX::Platform::incFiles, $pkg->getIncDirs() );
}

# modify library/ header checker to utilise the library/ header locations
# we stashed in findIncsAndLibs above
sub _check_libs
{
    my ($pkg, %args) = @_;

    if ( not defined %MacOSX::Platform::libFiles and not defined %MacOSX::Platform::incFiles)
    {
        $pkg->findIncsAndLibs();
    }

    my $mode = $args{mode};
    my $name = $args{name};
    my $so   = $args{so};
    my $h    = $args{h};

    print "Looking for $name...\n";

    if ( not defined $MacOSX::Platform::libFiles{$so} )
    {
        die "\n\n$name is missing from your system.\n".
            "This library is required by Smolder.\n\n";
    }
    else
    {
        print "\t$so found in ".$MacOSX::Platform::libFiles{$so}."\n";
    }
    
    if ( $mode ne 'install' and not defined $MacOSX::Platform::incFiles{$h} )
    {
        die "\n\nThe header file for $name, '$h', is missing from your system.".
            "This header is required by Smolder.\n\n";
    }
    else
    {
         print "\t$h found in ".$MacOSX::Platform::incFiles{$h}."\n";
    }

    print "\tOK\n";
}

# MacOSX uses the .dylib extension for shared libraries
sub check_libjpeg {

    my ($pkg, %args) = @_;

    $pkg->_check_libs(%args,
                      name => 'libjpeg',
                      so   => 'libjpeg.dylib',
                      h    => 'jpeglib.h');


}

# MacOSX uses the .dylib extension for shared libraries
sub check_libgif {


    my ($pkg, %args) = @_;


    # check first for libgif.
    eval {
        $pkg->_check_libs(%args,
                          name => 'libgif',
                          so   => 'libgif.dylib',
                          h    => 'gif_lib.h');
    };

    # if that fails, check for libungif (just as good).
    if ($@) {
        $pkg->_check_libs(%args,
                          name => 'libungif',
                          so   => 'libungif.dylib',
                          h    => 'gif_lib.h');
    }


}

# MacOSX uses the .dylib extension for shared libraries
sub check_libpng {


    my ($pkg, %args) = @_;

    $pkg->_check_libs(%args,
                      name => 'libpng',
                      so   => 'libpng.dylib',
                      h    => 'png.h');

}

# modify perl module build process to pass 
# location of expat library and header to Makefile.pl of XML::Parser
sub build_perl_module {
    my ($pkg, %arg) = @_;
    my $name        = $arg{name};
    my $dest_dir    = $arg{dest_dir} || 
                      File::Spec->catdir($ENV{SMOLDER_ROOT}, 'lib');

    # load expect unless we're building it
    my $use_expect = ($name =~ /IO-Tty/ or $name =~ /Expect/) ? 0 : 1;
    Smolder::Platform->_load_expect() if $use_expect;


    my $trash_dir = File::Spec->catdir(cwd, '..', 'trash');

    print "\n\n************************************************\n\n",
          " Building $name",
          "\n\n************************************************\n\n";

    # Net::FTPServer needs this to not try to install /etc/ftp.conf
    local $ENV{NOCONF} = 1 if $name =~ /Net-FTPServer/;


    # Module::Build or MakeMaker?
    my ($cmd, $make_cmd);
    if (-e 'Build.PL') {
        $cmd =
          "$^X Build.PL "
          . " --install_path lib=$dest_dir"
          . " --install_path libdoc=$trash_dir"
          . " --install_path script=$trash_dir"
          . " --install_path bin=$trash_dir"
          . " --install_path bindoc=$trash_dir"
          . " --install_path arch=$dest_dir/$Config{archname}";

        $make_cmd = './Build';
    } else {
        $cmd = "$^X Makefile.PL LIB=$dest_dir PREFIX=$trash_dir INSTALLMAN3DIR=' ' INSTALLMAN1DIR=' '";
        $make_cmd = 'make';
    }

    # when building XML::Parser
    # need to tell Makefile.PL where the expat libs are
    # we stashed their locations in verify_dependencies, above
    ( $name=~/XML-Parser/i ) and ( $cmd.=' EXPATLIBPATH='.$MacOSX::Platform::libFiles{'libexpat.dylib'}.' EXPATINCPATH='.$MacOSX::Platform::incFiles{'expat.h'} );
    ( $name=~/Imager/i ) and ( $cmd = "IM_LIBPATH=$ENV{MACOSX_LIB} IM_INCPATH=$ENV{MACOSX_INC} $cmd" );

   if ($use_expect) {
        print "Running '$cmd'...\n";
        my $command =
          Expect->spawn($cmd);

        # setup command to answer questions modules ask
        my @responses = qw(n n n n n y !);
        while (
               my $match = $command->expect(
                  undef,
                 'ParserDetails.ini? [Y]',
                 'remove gif support? [Y/n]',
                 'mech-dump utility? [y]',
                 'configuration (y|n) ? [no]',
                 'unicode entities? [no]',
                 'Do you want to skip these tests? [y]',
                 "('!' to skip)",
                                           )
              )
          {
              $command->send( $responses[ $match - 1 ] . "\n" );
          }
        $command->soft_close();
        if ( $command->exitstatus() != 0 ) {
            die "$cmd failed: $?";
        }
        print "Running $make_cmd...\n";
        $command = Expect->spawn($make_cmd);
        @responses = qw(n);
        while ( my $match = $command->expect( undef,
                                              'Mail::Sender? (y/N)',
                                            ) ) {
            $command->send($responses[ $match - 1 ] . "\n");
        }
        $command->soft_close();
        if ( $command->exitstatus() != 0 ) {
            die "make failed: $?";
        }

    } else {
        # do it without Expect for IO-Tty and Expect installation.
        # Fortunately they don't ask any questions.
        print "Running $cmd...\n";
        system( $cmd ) == 0
            or die "make failed: $?";
    } 

    system("$make_cmd install") == 0 or die "make install failed: $?";
}

# left to its own devices Apache configure will select the Darwin install layout
# there are dependencies in Smolder (eg. smolder_apachectl) which
# assume the Apache layout (eg. httpd in bin not sbin), so force the layout choice
sub apache_build_parameters {
    return "--with-layout=Apache ". Smolder::Platform::apache_build_parameters();
}

##########################################################################
#
# Platform-specific code for smolder_install
#
##########################################################################
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
    unless (grep {$_ eq $IPAddress} @ip_addrs) {
        return 0;
    }
    return 1;
}

# ask netinfo for the highest gid, and increment it to find an unused gid
sub generateGid
{
	my $highestGid = qx{nidump group / | cut -f3 -d: | sort -nr | head -1};
	return ( $highestGid + 1 );
}

# ask netinfo for the highest uid, and increment it to find an unused uid
sub generateUid
{
	my $highestUid = qx{nidump passwd / | cut -f3 -d: | sort -nr | head -1};
	return ( $highestUid + 1 );
}

# use netinfo to create a group
sub create_group {
    my ($pkg, %args) = @_;

    my %options = %{$args{options}};
    my $Group  = $options{Group};

    my $groupadd_bin = $pkg->find_bin(bin => 'nicl');

    print "Creating UNIX group ('$Group')\n";
    my ($gname,$gpasswd,$gid,$gmembers) = getgrnam($Group);

    unless (defined($gid)) {
        $gid = generateGid();

        map
        {
            print "  Running '$_'\n";
            system $_ and die "Failed to create group: $!";
        } (    
            $groupadd_bin." . -create /groups/$Group",
            $groupadd_bin." . -append /groups/$Group gid $gid",
            $groupadd_bin." . -flush"
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

    my $User   = $options{User};
    my $Group  = $options{Group};
    my $InstallPath = $options{InstallPath};
        
    # Create user, if necessary
    print "Creating UNIX user ('$User')\n";
    my ($uname,$upasswd,$uid,$ugid,$uquota,$ucomment,$ugcos,$udir,$ushell,$uexpire) = getpwnam($User);

    my ($gname,$gpasswd,$gid,$gmembers) = getgrnam($Group);

    unless (defined($uid)) {
        $uid = generateUid();

        map
        {
            print "  Running '$_'\n";
            system $_ and die "Failed to create user: $!";
        } (
            $useradd_bin." . -create /users/$User",
	        $useradd_bin." . -append /users/$User group $Group",
            $useradd_bin." . -append /users/$User home $options{InstallPath}",
            $useradd_bin." . -append /users/$User uid $uid",
            $useradd_bin." . -append /users/$User gid $gid",
            $useradd_bin." . -append /groups/$Group users $User",
            $useradd_bin." . -flush"        
        );

        print "  User created (uid $uid).\n";
    } else {
        print "  User already exists (uid $uid).\n";
    }

    return $uid;
}

1;
