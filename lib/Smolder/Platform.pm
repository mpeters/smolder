package Smolder::Platform;
use strict;
use warnings;

use File::Spec::Functions qw(catdir catfile canonpath);
use Cwd qw(cwd);
use Config;
use File::Basename;

# find out which subclasses we support
my $PLATFORM_DIR = catdir($ENV{SMOLDER_ROOT}, 'platform');
opendir( DIR, $PLATFORM_DIR ) or die $!;
our @PLATFORMS = grep {
    $_ !~ /^\.\.?$/        # not the parent or a hidden file
      and $_ !~ /\.svn/    # ignore SVN cruft
} sort readdir DIR;


=head1 NAME

Smolder::Platform - base class for platform build modules

=head1 SYNOPSIS

  package Redhat9::Platform;
  use base 'Smolder::Platform';

=head1 DESCRIPTION

This module serves as a base class for the platform build modules
which build help Smolder binary distributions.  See
F<docs/build_tech_spec.pod> for details about how the build system
works.

=head1 METHODS

This module is meant to be used as a base class, so the interface
consists of methods which may be overridden.  All these methods have a
reasonable default behavior.

All methods are called as class methods.  Platform modules are free to
use package variables to hold information between calls.

=head2 load

This method will load the correct subclass. It can be specified, or
it will be divined.

    # if you know what you need
    my $platform = Smolder::Platform->load('FedoraCore3');

    # or if don't
    my $platform = Smolder::Platform->load();

=cut

sub load {
    my ($class, $subclass) = @_;

    # add in $SMOLDER_ROOT/platform for platform build modules
    my $plib = catdir( $ENV{SMOLDER_ROOT}, "platform" );
    $ENV{PERL5LIB} = "$ENV{PERL5LIB}:${plib}";
    unshift @INC, $plib;

    # try it if we got it
    if( $subclass ) {
        $subclass = $subclass . '::Platform';
        eval "use $subclass";
        die "Unable to load platform module '$subclass': $@\n" if $@;
    # else try and find it
    } else {
        my %build_params = $class->build_params();
        # if we were previously built for a platform
        if( $build_params{Platform} ) {
            $subclass = $build_params{Platform} . '::Platform';
            eval "use $subclass";
            die "Unable to load platform module '$subclass': $@\n" if $@;
        # else just see which one wants to take it
        } else {
            # look for a platform that wants to handle this
            foreach my $plat (@PLATFORMS) {
                my $pkg = $plat . '::Platform';
                eval "use $pkg";
                die "Unable to load platform modules '$pkg': $@\n" if $@;

                if ( $pkg->guess_platform ) {
                    $subclass = $pkg;
                    last;
                }
            }
        }
    }
    return $subclass;
}

=head2 verify_dependencies

Makes sure all required dependencies are in place before starting the
build, and before beginning installation.  The C<mode> parameter will
be either "build" or "install" depending on when the method is called.

This method should either succeed or die() with a message for the
user.

By default, shared object (.so) files are searched for in $Config{libpth}.
header files (.h) are search for in $Config{usrinc}, /include and /usr/local/include

The default implementation runs the following default checks (which
are all overrideable):

    verify_dependencies(mode => 'install')

=cut

sub verify_dependencies {

    my ( $pkg, %arg ) = @_;
    my $mode = $arg{mode};
    my @PATH = split( ':', ( $ENV{PATH} || "" ) );

    # check perl
    if ( $mode eq 'install' ) {
        $pkg->check_perl();
    }

    # check the database
    $pkg->check_databases( mode => $mode );

    # look for libgd
    $pkg->check_libgd( mode => $mode );
}

=head2 check_databases 

This class method will cycle through all available database platform modules
(subclasses of L<Smolder::DBPlatform>), load them and run their C<verify_dependencies()>
method.

=cut

sub check_databases {
    my ($self, %args) = @_;
    my $mode = $args{mode};

    my $db_platform_dir = catdir($ENV{SMOLDER_ROOT}, 'lib', 'Smolder', 'DBPlatform');
    opendir( my $DIR, $db_platform_dir ) or die $!;
    my @dbs = grep {
        $_ !~ /^\.\.?$/     # not the parent or a hidden file
        and $_ !~ /\.svn/   # ignore SVN cruft
        and $_ !~ /~$/      # ignore editor droppings   
        and $_ !~ /\.swp$/
    } sort readdir $DIR;

    # now load each db platform and verify it
    require Smolder::DBPlatform;
    foreach my $db (@dbs) {
        my $basename = basename($db, '.pm');
        my $db_platform = Smolder::DBPlatform->load($basename);
        $db_platform->verify_dependencies(mode => $mode);
    }
}

=head2 check_perl

Perl is the right version and compiled for the right architecture
(skipped in build mode).

=cut

sub check_perl {

    my $pkg = shift;

    # check that Perl is right for this build
    my %params = $pkg->build_params();

    my $perl = join( '.', ( map { ord($_) } split( "", $^V, 3 ) ) );
    if ( $perl ne $params{Perl} ) {
        die <<END;

This distribution of Smolder is compiled for Perl version
'$params{Perl}', but you have '$perl' installed.  You must either
install the expected version of Perl, or download a different release
of Smolder.  Please see the installation instructions in INSTALL for
more details.

END
    }

    if ( $Config{archname} ne $params{Arch} ) {
        die <<END;

This distribution of Smolder is compiled for the '$params{Arch}'
architecture, but your copy of Perl is compiled for
'$Config{archname}'.  You must download a different Smolder
distribution, or rebuild your Perl installation.  Please see the
installation instructions in INSTALL for more details.

END
    }
}

=head2 check_libgd

Checks for the existance of the libgd shared object and header files.

    check_libgd( mode  => 'install' );

=cut

sub check_libgd {
    my ( $pkg, %args ) = @_;
    $pkg->check_libs(
        %args,
        h      => 'gd.h',
        name   => 'libgd',
        so     => 'libgd.so',
        module => 'GD',
    );
}

=head2 check_libs

Method to actually search for libraries. This method is used to check
for the necessary F<.h> and F<.so> files. It takes the following named args:

=over

=item mode

Either C<build> or C<install>. Required.

=item h

The name of the header (.h) file to look for. These files will not
be searched for if C<mode> is 'install'. Optional.

=item so

The name of the shared object (.so) file to look for. Optional.

=item name

The name of the library, used for error messages. Required.

=item module

The name of the Perl module that needs the library,
used for error messages. Optional

=item includes

An array ref of directories to search for the .h files.
By default it will look in your directories in your Perl's 
C<$Config{usrinc}>, F</include> and F</usr/local/include>.
Optional.

=item libs

An array ref of directories to search for the .so files. 
By default it will look in your directories in your Perl's 
C<$Config{libpath}>.
Optional.

=back

    $pkg->check_libs(
        h      => 'gd.h',
        so     => 'libgd.so',
        name   => 'libgd',
        module => 'GD',
    );

=cut


sub check_libs {
    my ( $pkg, %args ) = @_;
    my $mode = $args{mode};

    my $name = $args{name};
    my $so   = $args{so};
    my $h    = $args{h};
    my $mod  = $args{module};

    # build lib/includes for following searches.
    unless( $args{libs} ) {
        my @libs = split( " ", $Config{libpth} );
        my @lib_files;
        foreach my $lib (@libs) {
            opendir( DIR, $lib ) or die $!;
            push( @lib_files, grep { not -d $_ } readdir(DIR) );
            closedir(DIR);
        }
        $args{libs} = \@lib_files;
    }
    unless( $args{includes} ) {
        my @incs = ( $Config{usrinc}, '/include', '/usr/local/include' );
        $args{includes} = \@incs;
    }


    if ($so) {
        my $re = qr/^$so/;

        die "\n\n$name is missing from your system.\n" . "This library is required by Smolder.\n\n"
          unless grep { /^$re/ } @{ $args{libs} };
    }

    if ($h) {
        unless(
            $mode eq 'install' 
            or 
            grep { -e catfile( $_, $h ) } @{ $args{includes} }
        ) {
            my $msg = "The header file for $name, '$h', is missing from your system.";
            $msg .= "This file is needed to compile the $mod module which uses $name." if( $name );
            die $msg;
        } 
    }
}

=head2 find_bin

If $ENV{PATH} exists, searches $ENV{PATH} for $bin_name, returning the
full path to the desired executable.

If $ENV{PATH} does not contain /sbin or /usr/sbin, it will search those as well.

will die() with error if it cannot find the desired executable.

    $bin = find_bin(bin => $bin_name);

=cut

sub find_bin {

    my ( $pkg, %args ) = @_;

    my $bin = $args{bin};
    my $dir;

    my %additional_paths = (
        catdir( '/', 'sbin' ) => 1,
        catdir( '/', 'usr', 'sbin' ) => 1
    );

    my @PATH = split( ':', ( $ENV{PATH} || "" ) );

    foreach $dir (@PATH) {
        delete( $additional_paths{$dir} ) if ( $additional_paths{$dir} );
    }

    push @PATH, keys(%additional_paths);

    foreach $dir (@PATH) {

        my $exec = catfile( $dir, $bin );

        return $exec if ( -e $exec );
    }

    my $path = join ':', @PATH;

    die "Cannot find required utility '$bin' in PATH=$path\n\n";

}

=head2 check_ip

Called by the installation system to check whether an IP address is
correct for the machine.  The default implementation runs
/sbin/ifconfig and tries to parse the resulting text for IP addresses.
Should return 1 if the IP address is ok, 0 otherwise.

    check_ip(ip => $ip);

=cut

sub check_ip {
    my ( $pkg, %arg ) = @_;
    my $IPAddress = $arg{ip};

    my $ifconfig = `/sbin/ifconfig`;
    my @ip_addrs = ();
    foreach my $if_line ( split( /\n/, $ifconfig ) ) {
        next unless ( $if_line =~ /inet\ addr\:(\d+\.\d+\.\d+\.\d+)/ );
        my $ip = $1;
        push( @ip_addrs, $ip );
    }
    unless ( grep { $_ eq $IPAddress } @ip_addrs ) {
        return 0;
    }
    return 1;
}

=head2 create_group

Called to create a Smolder Group, as specified by the command-line
argument to bin/smolder_install (--Group).  Takes the %options hash
built by smolder_install as the one argument.

The default version of this sub works for GNU/Linux.  Other platforms
(e.g. BSD-like) will need to override this method to work with their
platforms' requirements for user creation.

The sub will check to see if --Group exists, and create it if it
does not.  It will return the group ID (gid) in either case.

This sub will die with an error if it cannot create --Group.

    $gid = create_group(options => \%options);

=cut

sub create_group {
    my ( $pkg, %args ) = @_;

    my %options = %{ $args{options} };

    my $groupadd_bin = $pkg->find_bin( bin => 'groupadd' );

    my $group = $options{Group};

    print "Creating UNIX group ('$group')\n";
    my ( $gname, $gpasswd, $gid, $gmembers ) = getgrnam($group);

    unless ( defined($gid) ) {
        my $groupadd = $groupadd_bin;
        $groupadd .= " $group";
        system($groupadd) && die("Can't add group: $!");

        ( $gname, $gpasswd, $gid, $gmembers ) = getgrnam($group);
        print "  Group created (gid $gid).\n";

    } else {
        print "  Group already exists (gid $gid).\n";
    }

    return $gid;
}

=head2 create_user

Called to create a Smolder User, as specified by the command-line
argument to bin/smolder_install (--User).  Takes the %options hash
built by smolder_install as the one argument.

The default version of this sub works for GNU/Linux.  Other platforms
(e.g. BSD-like) will need to override this method to work with their
platforms' requirements for user creation.

The sub will check to see if --User exists, and create it if it
does not.  If the user is created, the default group will be
--Group.  If the user already exists, it will be made a member of
the --Group group.

The sub will return the user ID (uid) if successful.

This sub will die with an error if it cannot create --User.

    $uid = create_user(
        group_id => $gid, 
        options => \%options
    )

=cut

sub create_user {

    my ( $pkg, %args ) = @_;

    my %options = %{ $args{options} };

    my $useradd_bin = $pkg->find_bin( bin => 'useradd' );

    my $user        = $options{User};
    my $group       = $options{Group};
    my $InstallPath = $options{InstallPath};

    # Get group info.
    my ( $gname, $gpasswd, $gid, $gmembers ) = getgrnam($group);

    # Create user, if necessary
    print "Creating UNIX user ('$user')\n";
    my ( $uname, $upasswd, $uid, $ugid, $uquota, $ucomment, $ugcos, $udir, $ushell, $uexpire ) =
      getpwnam($user);

    unless ( defined($uid) ) {
        my $useradd = $useradd_bin;

        $useradd .= " -d $InstallPath -M $user -g $gid";
        system($useradd) && die("Can't add user: $!");

        # Update user data
        ( $uname, $upasswd, $uid, $ugid, $uquota, $ucomment, $ugcos, $udir, $ushell, $uexpire ) =
          getpwnam($user);
        print "  User created (uid $uid).\n";
    } else {
        print "  User already exists (uid $uid).\n";
    }

    # Sanity check - make sure the user is a member of the group.
    ( $gname, $gpasswd, $gid, $gmembers ) = getgrnam($group);

    my @group_members = ( split( /\s+/, $gmembers ) );
    my $user_is_group_member = ( grep { $_ eq $user } @group_members );

    unless ( ( $ugid eq $gid ) or $user_is_group_member ) {
        $pkg->smolder_usermod( options => \%options );
    }

    return $uid;

}

=head2 usermod

Called when --User is not a member of --Group.  This sub
adds --User to --Group.

The default version of this sub works for GNU/Linux.  Other platforms
(e.g. BSD-like) will need to override this method to work with their
platforms' requirements for user creation.

This sub will die with an error if it cannot make --User a member
of --Group.

    usermod(options => \%options)

=cut

sub smolder_usermod {
    my ( $pkg, %args ) = @_;

    my %options = %{ $args{options} };

    my $user  = $options{User};
    my $group = $options{Group};

    print "  Adding user $user to group $group.\n";

    my $usermod = $pkg->find_bin( bin => 'usermod' );

    $usermod .= " -G $group $user";

    system($usermod) && die("Can't add user $user to group $group: $!");
    print "  User added to group.\n";
}

=head2 build_perl_module

Called to build a specific Perl module distribution called C<$name> in
the current directory.  The result of calling this method should be
one or more compiled Perl modules in Smolder's C<lib/> directory.

The default implementation includes code to answer questions asked by
some of the modules (using Expect) and special build procedures for
others.

The optional 'dest_dir' parameter specifies the location to put the
results of the build.  The default is SMOLDER_ROOT/lib.

    build_perl_module(name => $name)

=cut

sub build_perl_module {
    my ( $pkg, %arg ) = @_;
    my $name     = $arg{name};
    my $dest_dir = $arg{dest_dir} || catdir( $ENV{SMOLDER_ROOT}, 'lib' );

    # load expect unless we're building it
    my $use_expect = ( $name =~ /IO-Tty/ or $name =~ /Expect/ ) ? 0 : 1;
    _load_expect() if $use_expect;

    my $trash_dir = catdir( cwd, '..', 'trash' );

    print "\n\n************************************************\n\n", " Building $name",
      "\n\n************************************************\n\n";

    my $EXTRA_ARGS = '';

    # Net::SSLeay needs this to find openssl
    $EXTRA_ARGS = '/usr -- ' if $name =~ /Net_SSLeay/;

    # Net::FTPServer needs this to not try to install /etc/ftp.conf
    local $ENV{NOCONF} = 1 if $name =~ /Net-FTPServer/;

    # DBD::SQLite needs to be built with our local copy
    $EXTRA_ARGS = "SQLITE_LOCATION=$ENV{SMOLDER_ROOT}/sqlite" if $name =~ /DBD-SQLite/;

    # Module::Build or MakeMaker?
    my ( $cmd, $make_cmd );
    if ( -e 'Build.PL' ) {
        $cmd =
            "$^X Build.PL $EXTRA_ARGS "
          . " --install_path lib=$dest_dir"
          . " --install_path libdoc=$trash_dir"
          . " --install_path script=$trash_dir"
          . " --install_path bin=$trash_dir"
          . " --install_path bindoc=$trash_dir"
          . " --install_path arch=$dest_dir/$Config{archname}";

        $make_cmd = './Build';
    } else {
        $cmd =
            "$^X Makefile.PL $EXTRA_ARGS "
          . "LIB=$dest_dir "
          . "PREFIX=$trash_dir "
          . "INSTALLMAN3DIR=' ' "
          . "INSTALLMAN1DIR=' '";
        $make_cmd = 'make';
    }

    # We only want the libs, not the executables or man pages
    if ($use_expect) {
        print "Running $cmd...\n";
        $pkg->expect_questions(
            cmd       => $cmd,
            questions => $pkg->perl_module_questions(),
        );

        print "Running $make_cmd...\n";
        $pkg->expect_questions(
            cmd       => $make_cmd,
            questions => $pkg->perl_module_questions(),
        );

    } else {

        # do it without Expect for IO-Tty and Expect installation.
        # Fortunately they don't ask any questions.
        print "Running $cmd...\n";
        system($cmd) == 0
          or die "$cmd failed: $?";
    }

    system("$make_cmd install") == 0 or die "$make_cmd install failed: $?";
}

=head2 apache_modperl_questions

This method returns a hashref where the keys are the questions (or the beginnings of
those questions) that Apache/mod_perl may prompt the user to answer during the install.
The values are the answers to those questions.

=cut

sub apache_modperl_questions {
    return {
        "Configure mod_perl with" => 'y',
        "Shall I build httpd"     => 'n',
    };
}

=head2 perl_module_questions

This method returns a hashref where the keys are the questions (or the beginnings of
those questions) that Perl modules may prompt the user to answer during the install.
The values are the answers to those questions.
Additions should be made as new CPAN modules are added.

=cut

sub perl_module_questions {
    return {
        "ParserDetails.ini?"                                 => 'n',
        "remove gif support?"                                => 'n',
        "mech-dump utility?"                                 => 'n',
        "configuration (y|n) ?"                              => 'n',
        "unicode entities?"                                  => 'n',
        "Do you want to skip these tests?"                   => 'y',
        "('!' to skip)"                                      => '!',
        "Mail::Sender? (y/N)"                                => 'n',
        "It requires access to an existing test database."   => 'n',
        "Do you want to build the XS Stash module?"          => 'y',
        "Do you want to use the XS Stash for all Templates?" => 'y',
        "Do you want to enable the latex filter?"            => 'n',
        "Do you want to install these components?"           => 'n',

        # all Smolder graphs are PNGs, and this is a private copy
        "Build PNG support? [y]"               => 'y',
        "Build JPEG support? [y]"              => 'n',
        "Build FreeType support? [y]"          => 'n',
        "Build support for animated GIFs? [y]" => 'n',
        "Build XPM support? [y]"               => 'n',
        "Where is libgd installed? [/usr/lib]" => '/usr/lib',
    };
}

=head2 expect_questions

Given a command and a hashref of questions this method will run the command
and answer the questions as they appear (it is has a match).

    expect_questions(
        cmd         => 'Makefile.PL',
        questions   => $pkg->perl_module_questions(),
    );

=cut

sub expect_questions {
    my ( $pkg, %options ) = @_;
    my $command   = Expect->spawn( $options{cmd} );
    my @responses = values %{ $options{questions} };
    my @questions = keys %{ $options{questions} };

    while ( my $match = $command->expect( undef, @questions ) ) {
        $command->send( $responses[ $match - 1 ] . "\n" );
    }
    $command->soft_close();
    if ( $command->exitstatus() != 0 ) {
        die "$options{cmd} failed: $?";
    }
}

=head2 build_apache_modperl

Called to build Apache and mod_perl in their respective locations.
Uses C<apache_build_parameters()> and C<modperl_build_parameters()>
which may be easier to override.  The result should be a working
Apache installation in C<apache/>.

    build_apache_modperl(
        apache_dir       => $dir, 
        modperl_dir      => $dir, 
        mod_auth_tkt_dir => $dir, 
        mod_ssl_dir      => $dir
    )

=cut

sub build_apache_modperl {
    my ( $pkg, %arg ) = @_;
    my ( $apache_dir, $mod_perl_dir, $mod_auth_tkt_dir, $mod_ssl_dir ) =
      @arg{qw(apache_dir mod_perl_dir mod_auth_tkt_dir mod_ssl_dir)};
    _load_expect();

    print "\n\n************************************************\n\n",
      "  Building Apache/mod_ssl/mod_perl/mod_auth_tkt",
      "\n\n************************************************\n\n";

    # gather params
    my $apache_params   = $pkg->apache_build_parameters(%arg);
    my $mod_perl_params = $pkg->mod_perl_build_parameters(%arg);
    my $mod_ssl_params  = $pkg->mod_ssl_build_parameters(%arg);
    my $old_dir         = cwd;

    print "\n\n************************************************\n\n", "  Building mod_ssl",
      "\n\n************************************************\n\n";

    # build mod_ssl
    chdir($mod_ssl_dir) or die "Unable to chdir($mod_ssl_dir): $!";
    my $cmd = "./configure --with-apache=../$apache_dir $mod_ssl_params";
    print "Calling '$cmd'\n";
    system($cmd ) == 0
      or die "Unable to configure mod_ssl: $!";
    chdir($old_dir);

    print "\n\n************************************************\n\n", "  Building mod_perl",
      "\n\n************************************************\n\n";

    # build mod_perl
    chdir($mod_perl_dir) or die "Unable to chdir($mod_perl_dir): $!";
    $cmd = "$^X Makefile.PL $mod_perl_params";
    print "Calling '$cmd'...\n";

    my $command = $pkg->expect_questions(
        cmd       => $cmd,
        questions => $pkg->apache_modperl_questions(),
    );

    system("make PERL=$^X") == 0
      or die "mod_perl make failed: $?";
    system("make install PERL=$^X") == 0
      or die "mod_perl make install failed: $?";

    print "\n\n************************************************\n\n", "  Building Apache",
      "\n\n************************************************\n\n";

    # build Apache
    chdir($old_dir)    or die $!;
    chdir($apache_dir) or die "Unable to chdir($apache_dir): $!";
    print "Calling './configure $apache_params'.\n";
    system("./configure $apache_params") == 0
      or die "Apache configure failed: $?";
    system("make") == 0
      or die "Apache make failed: $?";
    system("make install") == 0
      or die "Apache make install failed: $?";
    system("make certificate TYPE=DUMMY") == 0
      or die "Apache make failed: $?";

    # clean up unneeded apache directories
    my $root = $ENV{SMOLDER_ROOT};
    system("rm -rf $root/apache/man $root/apache/htdocs/*");

    print "\n\n************************************************\n\n", "  Building mod_auth_tkt",
      "\n\n************************************************\n\n";

    # build mod_auth_tkt
    chdir($old_dir)          or die $!;
    chdir($mod_auth_tkt_dir) or die "Unable to chdir($mod_auth_tkt_dir): $!";
    $cmd = "./configure --apxs=$root/apache/bin/apxs --debug --debug-verbose";
    print "Calling '$cmd'.\n";
    system($cmd) == 0
      or die "mod_auth_tkt build failed: $?";
    $cmd = "make && make install";
    print "Calling '$cmd'.\n";
    system($cmd) == 0
      or die "mod_auth_tkt installation failed: $?";
}

=head2 apache_build_parameters

Returns a string containing the parameters passed to Apache's
C<configure> script by C<build_apache_modperl()>.

    apache_build_parameters(
        apache_dir  => $dir, 
        modperl_dir => $dir
    )

=cut

sub apache_build_parameters {
    my $root = $ENV{SMOLDER_ROOT};
    return "--prefix=${root}/apache "
      . "--activate-module=src/modules/perl/libperl.a "
      . "--disable-shared=perl "
      . "--enable-module=ssl          --enable-shared=ssl "
      . "--enable-module=rewrite      --enable-shared=rewrite "
      . "--enable-module=proxy        --enable-shared=proxy "
      . "--enable-module=mime_magic   --enable-shared=mime_magic "
      . "--enable-module=unique_id    --enable-shared=unique_id "
      . "--enable-module=expires "
      . "--without-execstrip "
      . "--enable-module=so";
}

=head2 mod_perl_build_parameters

Returns a string containing the parameters passed to mod_perl's
C<Makefile.PL> script by L<build_apache_modperl>.

    mod_perl_build_parameters(
        apache_dir  => $dir, 
        modperl_dir => $dir
    );

=cut

sub mod_perl_build_parameters {
    my ( $pkg, %arg ) = @_;
    my $root  = $ENV{SMOLDER_ROOT};
    my $trash = catdir( cwd, '..', 'trash' );

    return "LIB=$root/lib "
      . "PREFIX=$trash "
      . "APACHE_SRC=$arg{apache_dir}/src "
      . "USE_APACI=1 "
      . "PERL_DEBUG=1 APACI_ARGS='--without-execstrip' EVERYTHING=1";
}

=head2 mod_ssl_build_parameters

Returns a string containing the parameters passed to configure.

    mod_ssl_build_parameters(apache_dir => $dir)

=cut

sub mod_ssl_build_parameters {
    my ( $pkg, %arg ) = @_;
    return "--enable-shared=ssl --apache=../$arg{apache_dir}";
}

=head2 build_swishe

Given the directory where swish-e will be installed to, and assuming
we are already in the directory where swish-e has been unpacked, run
the commands to build swish-e.

=cut

sub build_swishe {
    my ( $pkg, %options ) = @_;
    my $dir = $options{swishe_dir};

    system( "./configure --prefix=$dir/swish-e " . "--exec_prefix=$dir/swish-e" ) == 0
      or die "Unable to configure swish-e! $!";
    system("make && make install") == 0
      or die "Unable to make swish-e! $!";
}

=head2 build_sqlite

Given the directory where SQLite3 will be installed to, and assuming
we are already in the directory where SQLite3 has been unpacked, run
the commands to build SQLite3.

=cut

sub build_sqlite {
    my ( $pkg, %options ) = @_;
    my $dir = $options{sqlite_dir};

    system( "./configure --prefix=$dir/sqlite " . "--exec_prefix=$dir/sqlite" ) == 0
      or die "Unable to configure SQLite! $!";
    system("make && make install") == 0
      or die "Unable to make SQLite! $!";
}

=head2 finish_installation

Anything that needs to be done at the end of installation can be done
here.  The default implementation does nothing.  The options hash
contains all the options passed to C<smolder_install> (ex: InstallPath).

    finish_installation(options => \%options)>

=cut

sub finish_installation { }

=head2 finish_upgrade

Anything that needs to be done at the end of an upgrade can be done
here. The default implementation does nothing.

=cut

sub finish_upgrade { }

=head2 post_install_message

Called by bin/smolder_install, returns install information once everything
is complete.

    post_install_message(options => \%options)

=cut

sub post_install_message {

    my ( $pkg, %args ) = @_;

    my %options = %{ $args{options} };

    print <<EOREPORT;


#####                                                         #####
###                                                             ###
                   Smolder INSTALLATION COMPLETE               
###                                                             ###
#####                                                         #####


   Installed at   : $options{InstallPath}
   Control script : $options{InstallPath}/bin/smolder_ctl
   Config file    : $options{InstallPath}/conf/smolder.conf
   Admin Password : 'qa_rocks'
  

   Running on $options{IPAddress} - http://$options{HostName}:$options{ApachePort}/

EOREPORT

}

=head2 post_upgrade_message

Called by bin/smolder_upgrade, returns upgrade information once everything
is complete.

    post_upgrade_message(options => \%options)

=cut

sub post_upgrade_message {

    my ( $pkg, %args ) = @_;

    my %options = %{ $args{options} };

    print <<EOREPORT;


#####                                                         #####
###                                                             ###
                  Smolder UPGRADE COMPLETE                       
###                                                             ###
#####                                                         #####


   Installed at:      $options{InstallPath}
   Control script:    $options{InstallPath}/bin/smolder_ctl
   Smolder conf file: $options{InstallPath}/conf/smolder.conf

   Running on $options{IPAddress} --
     http://$options{HostName}:$options{ApachePort}/

EOREPORT

}

=head2 guess_platform

Called to guess whether this module should handle building on this
platform.  This is used by C<smolder_build> when the user doesn't
specify a platform.  This method should return true if the module
wants to handle the platform.

The default implementation returns false all the time.  When
implementing this module, err on the side of caution since the user
can always specify their platform explicitely.

=cut

sub guess_platform {
    return 0;
}

=head2 build_params

Reads the F<data/build.db> file produced by C<smolder_build> and returns
a hash of the values available (Platform, Perl, Arch).

=cut

sub build_params {
    my $db_file = catfile( $ENV{SMOLDER_ROOT}, 'data', 'build.db' );
    return () unless -e $db_file;

    # it would be nice to use Config::ApacheFormat here, but
    # unfortunately it's not possible to guarantee that it will load
    # because it uses Scalar::Util which is an XS module.  If the
    # caller isn't running the right architecture then it will fail to
    # load.  So, fall back to parsing by hand...
    open( DB, $db_file ) or die "Unable to open '$db_file': $!\n";
    my ( $platform, $perl, $arch );
    while (<DB>) {
        chomp;
        next if /^\s*#/;
        if (/^\s*platform\s+["']?([^'"]+)["']?/i) {
            $platform = $1;
        } elsif (/^\s*perl\s+["']?([^'"]+)/i) {
            $perl = $1;
        } elsif (/^\s*arch\s+["']?([^'"]+)/i) {
            $arch = $1;
        }
    }
    close DB;

    return (
        Platform => $platform,
        Perl     => $perl,
        Arch     => $arch
    );
}

sub _load_expect {

    # load Expect - don't load at compile time because this module is
    # used during install when Expect isn't needed
    eval "use Expect;";
    die <<END if $@;

Unable to load the Expect Perl module.  You must install Expect before
running smolder_build.  The source packages you need are included with
Project:

   src/IO-Tty-1.02.tar.gz
   src/Expect-1.15.tar.gz

END
}

1;
