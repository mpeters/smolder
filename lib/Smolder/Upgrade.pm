package Smolder::Upgrade;
use warnings;
use strict;

use Smolder::Conf;
use Smolder::DB;
use Carp qw(croak);

=head1 NAME

Smolder::Upgrade - Base class for Smolder upgrade modules

=head1 SYNOPSIS

  use base 'Smolder::Upgrade';

=head1 DESCRIPTION

This module is intended to be used as a parent class for Smolder upgrade
modules. Right now it does really do much.

=head1 INTERFACE

To use this module, there are three things you have to do:

=over 4

=item use base 'Smolder::Upgrade';

This causes your upgrade module (e.g., "V1_23.pm") to inherit
certain basic functionality.  Specifically, an C<upgrade()>
which should be overridden in every child class.

=back

=head2 INHERITED METHODS

=over 4

=item new()

The new() method is a constructor which creates a trivial object from a
hash.  Your upgrade modules may use this to store state information.

=item upgrade()

The upgrade() method is called by the smolder_upgrade script to implement
an upgrade. Each version's upgrade should override and fill this out with
the steps needed during the upgrade.

=back

=cut

sub upgrade {
    my $self = shift;
    croak("No upgrade() method implemented in $self");
}

# Create a trivial object
sub new {
    my $class = shift;
    bless( {}, $class );
}

1;
