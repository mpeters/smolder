package Smolder::Upgrade;
use warnings;
use strict;
use File::Spec::Functions qw(catfile);
use Smolder;
use Smolder::Conf qw(SQLDir);
use Smolder::DB;

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
hash. Your upgrade modules may use this to store state information.

=cut

# Create a trivial object
sub new {
    my $class = shift;
    bless({}, $class);
}

=head3 upgrade

This method looks at the current db_version of the database being used
and then decides which upgrade modules should be run. Upgrade modules
are children of this module and have the following naming pattern:
C<Smolder::Upgrade::VX_YZ> where C<X.YZ> is the version number.

So for example if the current version is at 1.35 and we are upgrading
to 1.67, then any C<Smolder::Upgrade::VX_YZ> modules between those 2
versions are run.

=cut

sub upgrade {
    my $self       = shift;
    # don't do anything for dev releases
    return if $Smolder::VERSION =~ /_/;
    my $db_version = Smolder::DB->db_Main->selectall_arrayref('SELECT db_version FROM db_version');
    $db_version = $db_version->[0]->[0];
    if ($db_version < $Smolder::VERSION) {

        # find applicable upgrade modules
        warn
          "Your version of Smolder ($db_version) is out of date. Upgrading to $Smolder::VERSION...\n";
        my $upgrade_dir = __FILE__;
        $upgrade_dir =~ s/\.pm$//;

        # Find upgrade modules
        opendir(DIR, $upgrade_dir) || die("Unable to open upgrade directory '$upgrade_dir': $!\n");

        my @up_modules;
        foreach my $file (sort readdir(DIR)) {
            if (   (-f catfile($upgrade_dir, $file))
                && ($file =~ /^V(\d+)\_(\d+)\.pm$/)
                && ("$1.$2" > $db_version))
            {
                push(@up_modules, $file);
            }
        }
        closedir(DIR);
        warn "  Found " . scalar(@up_modules) . " applicable upgrade modules.\n";

        if (@up_modules) {
            foreach my $mod (@up_modules) {
                $mod =~ /(.*)\.pm$/;
                my $class = $1;
                my ($major, $minor) = ($class =~ /V(\d+)_(\d+)/);
                $class = "Smolder::Upgrade::$class";
                eval "require $class";
                die "Can't load $class upgrade class: $@" if $@;
                $class->new->version_upgrade("$major.$minor");
            }
        }

        # upgrade the db_version
        Smolder::DB->db_Main->do('UPDATE db_version SET db_version = ?', undef, $Smolder::VERSION);
    }
}

=head3 version_upgrade

This method is called by C<upgrade()> for each upgrade version module. It
shouldn't be called directly from anyway else except for testing.

It performs the following steps:

=over

=item 1

Call the L<pre_db_upgrade> method .

=item 2

Run the SQL upgrade file found in F<sql/upgrade/> that has the same version
which is named for this same version. So an upgrade module named F<V1_23>
will run the F<upgrade/V1_23.sql> file if it exists.

=item 3

Call the L<post_db_upgrade> method.

=back

=cut

sub version_upgrade {
    my ($self, $version) = @_;
    $self->pre_db_upgrade();

    # find and run the SQL file
    $version =~ /(\d+)\.(\d+)/;
    my $file = catfile(SQLDir, 'upgrade', "V$1_$2.sql");
    if (-e $file) {
        warn "    Upgrading DB with file '$file'.\n";
        Smolder::DB->run_sql_file($file);
    } else {
        warn "    No SQL file ($file) for version $version. Skipping DB upgrade.\n";
    }
    $self->post_db_upgrade();

    # add any new things to the config file
    my $new_config_stuff = $self->add_to_config();
    if ($new_config_stuff) {

        # write out the new lines
        my $conf_file = catfile($ENV{SMOLDER_ROOT}, 'conf', 'smolder.conf');
        open(CONF, '>>', $conf_file)
          or die "Unable to open $conf_file: $!";
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

sub add_to_config { }

1;
