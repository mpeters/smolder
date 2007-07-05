package Smolder::Upgrade;
use warnings;
use strict;

use Smolder::Conf qw(DBName DBUser DBHost DBPass DBPlatform);
use File::Spec::Functions qw(catfile catdir);
use Smolder::DB;
use Carp qw(croak);

=head1 NAME

Smolder::Upgrade - Base class for Smolder upgrade modules

=head1 SYNOPSIS

    use base 'Smolder::Upgrade';

    sub pre_db_upgrade  {....}
    sub post_db_upgrade { ... }

=head1 DESCRIPTION

This module is intended to be used as a parent class for Smolder upgrade
modules.

=head2 METHODS

=head3 new

The new() method is a constructor which creates a trivial object from a
hash.  Your upgrade modules may use this to store state information.

=cut

# Create a trivial object
sub new {
    my $class = shift;
    bless( {}, $class );
}

=head3 upgrade

The upgrade() method is called by the smolder_upgrade script to implement
an upgrade. This method will perform the following actions:

=over

=item call the L<pre_db_upgrade> method 

=item run the SQL upgrade file found in F<upgrade/> that has the same version
which is named for this same version. So an upgrade module named F<V1_23>
will run the F<upgrade/V1_23.sql> file if it exists.

=item call the L<post_db_upgrade> method

=back

=cut

sub upgrade {
    my $self     = shift;
    my $platform = _load_platform();

    $self->pre_db_upgrade($platform);

    # find and run the SQL file
    my $file = catfile( $ENV{SMOLDER_ROOT}, 'upgrades', 'sql', lc DBPlatform, ref($self) . '.sql' );
    if ( -e $file ) {
        print "    Upgrading DB with file '$file'.\n";
        my $db_platform = Smolder::DBPlatform->load();
        $db_platform->run_sql_file(
            file   => $file,
            user   => ( DBUser || '' ),
            passwd => ( DBPass || '' ),
            host   => ( DBHost || '' ),
        );
    } else {
        print "    Could not find SQL file '$file'. Skipping DB upgrade.\n";
    }
    $self->post_db_upgrade($platform);

    # add any new things to the config file
    my $new_config_stuff = $self->add_to_config();
    if( $new_config_stuff ) {
        # write out the new lines
        open(CONF, '>>', catfile($ENV{SMOLDER_ROOT}, 'conf', 'smolder.conf'))
          or die "Unable to open conf/krang.conf: $!";
        print CONF $new_config_stuff;
        close(CONF);
    }
}

=head3 pre_db_upgrade

This method must be implemented in your subclass. It is called before
the SQL upgrade file is run. 
It receives the L<Smolder::Platform> class for the given platform.

=cut

sub pre_db_upgrade {
    my $self = shift;
    die "pre_db_upgrade() must be implemented in " . ref($self);
}

=head3 post_db_upgrade

This method must be implemented in your subclass. It is called after
the SQL upgrade file is run.
It receives the L<Smolder::Platform> class for the given platform.

=cut

sub post_db_upgrade {
    my $self = shift;
    die "post_db_upgrade() must be implemented in " . ref($self);
}

=head3 add_to_config

This method will take a given string and add it to the end of the
current configuration file. This is useful for adding new required
directives with a reasonable default.

=cut

sub add_to_config {}


sub _load_platform {

    exit_error("Can't find data/build.db.  Do you need to run 'make build'?")
      unless -e catfile( $ENV{SMOLDER_ROOT}, 'data', 'build.db' );
    require Smolder::Platform;
    my %build_params = Smolder::Platform->build_params;

    # add in $SMOLDER_ROOT/platform for platform build modules
    my $plib = catdir( $ENV{SMOLDER_ROOT}, "platform" );
    $ENV{PERL5LIB} = "$ENV{PERL5LIB}:${plib}";
    unshift @INC, $plib;

    my $platform = "$build_params{Platform}::Platform";
    eval "use $platform;";
    die "Unable to load $platform: $@"
      if $@;
    return $platform;
}

1;
