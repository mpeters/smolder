package Smolder::Conf;
use strict;
use warnings;

# all valid configuration directives must be listed here
our ( @VALID_DIRECTIVES, @REQUIRED_DIRECTIVES );

BEGIN {
    @VALID_DIRECTIVES = map { lc($_) } qw(
      ApacheAddr
      ApachePort
      DBHost
      DBName
      DBPass
      DBUser
      FromAddress
      Group
      HostName
      InstallRoot
      LogLevel
      SchedulerMaxChildren
      SMTPHost
      User
    );

    @REQUIRED_DIRECTIVES = qw(
      ApacheAddr
      ApachePort
      DBName
      DBPass
      DBUser
      FromAddress
      Group
      HostName
      LogLevel
      SMTPHost
      User
    );
}

use File::Spec::Functions qw(catfile catdir rel2abs);
use Carp qw(croak);
use Config::ApacheFormat;
use Cwd qw(fastcwd);
use IO::Scalar;

=head1 NAME

Smolder::Conf - Smolder configuration module

=head1 SYNOPSIS

  # all configuration directives are available as exported subs
  use Smolder::Conf qw(InstallRoot Things);
  $root = InstallRoot;
  @thinks = Things;

  # you can also call get() in Smolder::Conf directly
  $root = Smolder::Conf->get("InstallRoot");

  # or you can access them as methods in the Smolder::Conf module
  $root = Smolder::Conf->rootdir;

=head1 DESCRIPTION

This module provides access to the configuration settings in
F<smolder.conf>.  

Full details on all configuration parameters is available in the
configuration document, which you can find at F<docs/configuration>.

=cut

# package variables
our $CONF;

# internal routine to load the conf file.  Called by a BEGIN during
# startup, and used during testing.
sub _load {

    # find a default conf file
    my $conf_file;
    if ( exists $ENV{SMOLDER_CONF} ) {
        $conf_file = $ENV{SMOLDER_CONF};
    } else {
        $conf_file = catfile( $ENV{SMOLDER_ROOT}, "conf", "smolder.conf" );
    }

    croak(<<CROAK) unless -e $conf_file and -r _;

Unable to find smolder.conf!

Smolder scripts must be run from within an installed copy of Smolder,
which will have a conf/smolder.conf file.  You might be trying to run a
Smolder script from a Smolder source directory.

CROAK

    # load conf file into package global
    eval {
        our $CONF = Config::ApacheFormat->new( valid_directives => \@VALID_DIRECTIVES, );
        $CONF->read($conf_file);
    };
    croak("Unable to read config file '$conf_file'.  Error was: $@")
      if $@;
    croak("Unable to read config file '$conf_file'.")
      unless $CONF;

    my $extra    = qq(InstallRoot "$ENV{SMOLDER_ROOT}"\n);
    my $extra_fh = IO::Scalar->new( \$extra );
    $CONF->read($extra_fh);
}

# load the configuration file during startup
BEGIN { _load(); }

=head1 METHODS

=head2 get_config

Class method that returns the underlying L<Config::ApacheFormat> object.

=cut

sub get_config {
    return $CONF;
}

=head2 get


Given a directive name, returns the value (which may be a list) of a configuration directive.
Directive names are case-insensitive. 

    $value = Smolder::Conf->get("DirectiveName")

    @values = Smolder::Conf->get("DirectiveName")

=cut

sub get {
    return $CONF->get( $_[1] );
}

=head2 check

Sanity-check Smolder configuration.  This will die() with an error
message if something is wrong with the configuration file.

This is run when the Smolder::Conf loads unless the environment variable
"SMOLDER_CONF_NOCHECK" is set to a true value.

=cut

sub check {
    my $pkg = shift;

    # check required directives
    foreach my $dir (@REQUIRED_DIRECTIVES) {
        _broked("Missing required $dir directive")
          unless defined $CONF->get($dir);
    }

    # make sure User and Group exist
    _broked( "User '" . $CONF->get("User") . "' does not exist" )
      unless getpwnam( $CONF->get("User") );
    _broked( "Group '" . $CONF->get("Group") . "' does not exist" )
      unless getgrnam( $CONF->get("Group") );

}

=head1 ACCESSOR METHODS

All configuration directives can be accessed as methods themselves.

    my $dir  = $conf->InstallRoot();
    my $port = Smolder::Conf->apacheport();

Gets the value of a directive using an autoloaded method.
Directive names are case-insensitive. 

=cut

sub AUTOLOAD {
    our $AUTOLOAD;
    return if $AUTOLOAD =~ /DESTROY$/;
    my ($name) = $AUTOLOAD =~ /([^:]+)$/;

    return shift->get($name);
}

=head1 EXPORTING DIRECTIVES

Each configuration directive can also be accessed as an exported
subroutine.

    use Smolder::Conf qw(InstallRoot apacheport);
    ...
    my $root = InstallRoot();
    my $port = apacheport();

Directive names are case-insensitive. 
Gets the value of a variable using an exported, autoloaded method.
Case-insensitive.

=cut

sub import {
    my $pkg     = shift;
    my $callpkg = caller(0);

    foreach my $name (@_) {
        no strict 'refs';    # needed for glob refs
        *{"$callpkg\::$name"} = sub () { $pkg->get($name) };
    }
}

sub _broked {
    warn("Error found in smolder.conf: $_[0].\n");
    exit(1);
}

# run the check ASAP, unless we're in upgrade mode
BEGIN { __PACKAGE__->check() unless ( $ENV{SMOLDER_CONF_NOCHECK} ) }

1;
