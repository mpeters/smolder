package Smolder::Control::Developer;
use base 'Smolder::Control';
use strict;
use warnings;

=head1 NAME

Smolder::Control::Developer

=head1 DESCRIPTION

Controller module for generic Developer screens

=cut

sub setup {
    my $self = shift;
    $self->start_mode('welcome');
    $self->run_modes(
        [
            qw(
              welcome
              )
        ]
    );
}

sub require_group { 'developer' }

=head1 RUN MODES

=head2 welcome

Shows a welcome page using the F<Developer/welcome.tmpl> template.

=cut

sub welcome {
    my $self = shift;
    return $self->tt_process({});
}

1;
