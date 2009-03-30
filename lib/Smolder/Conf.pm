package Smolder::Conf;
use strict;
use warnings;
use File::Spec::Functions qw(catfile catdir rel2abs curdir);
use File::ShareDir qw(module_dir);
use File::HomeDir;
use File::Basename qw(dirname);
use Carp qw(croak);
use Config::ApacheFormat;
use Cwd qw(fastcwd);
use IO::Scalar;
use Smolder;

# all valid configuration directives must be listed here
our (@VALID_DIRECTIVES, @REQUIRED_DIRECTIVES);

BEGIN {
    @VALID_DIRECTIVES = map { lc($_) } qw(
      Port
      FromAddress
      HostName
      LogFile
      Secret
      SMTPHost
      ProjectFullReportsMax
      TemplateDir
      DataDir
      HtdocsDir
      SQLDir
    );

    @REQUIRED_DIRECTIVES = qw(
      Port
      FromAddress
      HostName
      Secret
    );
}

=head1 NAME

Smolder::Conf - Smolder configuration module

=head1 SYNOPSIS

    # all configuration directives are available as exported subs
    use Smolder::Conf qw(Secret Port);
    $secret = Secret;

    # you can also call get() in Smolder::Conf directly
    $port = Smolder::Conf->get("Port");

    # or you can access them as methods in the Smolder::Conf module
    $port = Smolder::Conf->Port;

=head1 DESCRIPTION

This module provides access to the configuration settings in
F<smolder.conf>.  

Full details on all configuration parameters is available in the
configuration document, which you can find at F<docs/configuration>.

=cut

# package variables
our $CONF;

# look for the file in various places. Return the first one that exists
sub _conf_file_path {
    if ($ENV{SMOLDER_CONF}) {
        return $ENV{SMOLDER_CONF};
    } elsif ($ENV{SMOLDER_ROOT}) {
        my $conf_file = catfile($ENV{SMOLDER_ROOT}, 'conf', 'smolder.conf');
        return $conf_file if -e $conf_file;
    }

    my @paths = (
        rel2abs(curdir),
        catdir('', 'usr', 'local', 'smolder', 'conf'),
        catdir('', 'etc', 'smolder'),
        catdir('', 'etc'),
    );
    foreach my $path (@paths) {
        my $conf_file = catfile($path, 'smolder.conf');
        return $conf_file if -e $conf_file;
    }

    # if we got here then something is wrong
    croak(<<CROAK);

Unable to find smolder.conf!
We will look for it in the following order:

    \$CWD/smolder.conf
    \$SMOLDER_ROOT/conf/smolder.conf
    /usr/local/smolder/conf/smolder.conf
    /etc/smolder/smolder.conf
    /etc/smolder.conf
    
Or can optionally be designated by using the SMOLDER_CONF environment variable.

CROAK
}

# internal routine to load the conf file.  Called by a BEGIN during
# startup, and used during testing.
sub _load {

    # find a default conf file
    my $conf_file = _conf_file_path();

    # load conf file into package global
    eval {
        our $CONF = Config::ApacheFormat->new(valid_directives => \@VALID_DIRECTIVES,);
        $CONF->read($conf_file);
    };
    croak("Unable to read config file '$conf_file'.  Error was: $@")
      if $@;
    croak("Unable to read config file '$conf_file'.")
      unless $CONF;
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
    return $CONF->get($_[1]);
}

=head2 check

Sanity-check Smolder configuration.  This will croak() with an error
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

    # if we have a log file, does it exist and can we write to it?
    my $log_file = $CONF->get('LogFile');
    if ($log_file) {
        if (-e $log_file && -f $log_file) {
            broked("We can't write to log file $log_file") unless -r $log_file;
        } else {
            open(my $LOG, '>>', $log_file) or _broked("Could not create log file $log_file! $!");
            print $LOG '';
            close($LOG);
        }
    }
}

=head2 template_dir

The directory path for the templates for this install of Smolder

=cut

sub template_dir {
    my $class = shift;
    return $class->get('TemplateDir') || catdir(module_dir('Smolder'), 'templates');
}

=head2 htdocs_dir

The directory path for the htdocs for this install of Smolder

=cut

sub htdocs_dir {
    my $class = shift;
    return $class->get('HtdocsDir') || catdir(module_dir('Smolder'), 'htdocs');
}

=head2 sql_dir

The directory path for the raw SQL files for this install of Smolder

=cut

sub sql_dir {
    my $class = shift;
    return $class->get('SQLDir') || catdir(module_dir('Smolder'), 'sql');
}

=head2 data_dir

The directory path for data directory for this install of Smolder

=cut

sub data_dir {
    my $class = shift;
    my $dir = $class->get('DataDir') || catdir(File::HomeDir->my_data, '.smolder');
    if (!-d $dir) {
        mkdir($dir) or _broked("Can't create data directory $dir! $!");
    }
    return $dir;
}

=head2 test_data_dir

The directory path for test data directory for this copy of Smolder

=cut

sub test_data_dir {
    return rel2abs(catdir(curdir(), 't', 'data'));
}

=head1 ACCESSOR METHODS

All configuration directives can be accessed as methods themselves.

    my $port = Smolder::Conf->port();

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

    use Smolder::Conf qw(port FromAddress);
    ...
    my $port = port();
    my $from = FromAddress();

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
BEGIN { __PACKAGE__->check() unless ($ENV{SMOLDER_CONF_NOCHECK}) }

1;
