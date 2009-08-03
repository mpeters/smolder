package Smolder::Conf;
use strict;
use warnings;
use File::Spec::Functions qw(catfile catdir rel2abs curdir);
use File::ShareDir qw(dist_dir);
use File::HomeDir;
use File::Basename qw(dirname);
use Carp qw(croak);
use Smolder;

sub _random_secret {
    my $length = int(rand(5) + 10);
    my $secret = '';
    my @chars = ('a'..'z', 'A'..'Z', 0..9);
    $secret .= $chars[int(rand($#chars + 1))] for(0..$length);
    return $secret;
}

my %VALUES;

BEGIN {
    my $share_dir;
    my $blib_share_dir = rel2abs(catdir(curdir, 'blib', 'lib', 'auto', 'share', 'dist', 'Smolder'));
    if( -d $blib_share_dir ) {
        $share_dir = $blib_share_dir;
    } else {
        $share_dir = dist_dir('Smolder');
    }

    %VALUES = (
        Port                  => 8080,
        HostName              => 'localhost.localdomain',
        FromAddress           => 'smolder@localhost.localdomain',
        SMTPHost              => 'localhost.localdomain',
        LogFile               => '',
        PidFile               => catdir($share_dir, 'data', 'smolder.pid'),
        TemplateDir           => catdir($share_dir, 'templates'),
        DataDir               => catdir(File::HomeDir->my_data, '.smolder'),
        HtdocsDir             => catdir($share_dir, 'htdocs'),
        SQLDir                => catdir($share_dir, 'sql'),
        Secret                => _random_secret(),
        AutoRefreshReports    => 0,
        TruncateTestFilenames => 0,
        ErrorsToScreen        => 0,
        ReportsPerPage        => 5,
        TestSourceRoot        => undef,
        AutoRedirectToProject => 0,
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

    # give Smolder::Conf some values to override the defaults
    Smolder::Conf->init(
        Secret   => '1Adxd23023s',
        Port     => 80,
        HostName => 'smolder.myorg.com',
        LogFile  => '/path/to/logs',
    );

    # pull the conf values from a file
    Smolder::Conf->init_from_file('/path/to/conf/file');

=head1 DESCRIPTION

This module provides access to the configuration settings in
F<smolder.conf>.  Smolder tries to have reasonable defaults but they
can be overridden when needed.

=head1 METHODS

=head2 init

Override the configuration defaults by providing named-value pairs:

    Smolder::Conf->init(
        Secret   => '1Adxd23023s',
        Port     => 80,
        HostName => 'smolder.myorg.com',
        LogFile  => '/path/to/logs',
    );

=cut

sub init {
    my ($class, %args) = @_;
    foreach my $key (keys %args) {
        if( exists $VALUES{$key} ) {
            $VALUES{$key} = $args{$key};
        } else {
            croak "$key is not a valid Smolder config parameter!";
        }
    }
}

=head2 init_from_file

Override the configuration defaults by providing a file. Config files are simple
lists of name-values pairs. One pair per-line and each name/value is separated by
whitespace:

    HostName    smolder.test
    DataDir     /var/lib/smolder/
    Port        80
    FromAddress smolder@smolder.test
    TemplateDir /var/share/smolder/templates
    HtdocsDir   /var/share/smolder/htdocs
    SQLDir      /var/share/smolder/sql

=cut

sub init_from_file {
    my ($class, $file) = @_;
    croak "Config file $file does not exist!" unless -e $file;
    croak "Config file $file is not readable!" unless -r $file;

    open(my $FH, '<', $file) or croak "Could not open file $file for reading: $!";
    my %values;
    while(my $line = <$FH>) {
        # only get lines that look like name-value pairs but not comments
        if( $line !~ /\s*#/ && $line =~ /(\S+)\s+(\S+)/ ) {
            # strip off any quotes
            my ($key, $val) = ($1, $2);
            $val =~ s/^'(.*)'$/$1/;
            $val =~ s/^"(.*)"$/$1/;
            $values{$key} = $val;
        }
    }
    $class->init(%values);
}

BEGIN {
    __PACKAGE__->init_from_file($ENV{SMOLDER_CONF}) if $ENV{SMOLDER_CONF};
}

=head2 get

Given a directive name, returns the value (which may be a list) of a configuration directive.
Directive names are case-insensitive. 

    $value = Smolder::Conf->get('DirectiveName');

=cut

sub get {
    my ($class, $key) = @_;
    if( exists $VALUES{$key} ) {
        return $VALUES{$key};
    } else {
        croak "$key is not a valid Smolder config parameter!";
    }
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

1;
