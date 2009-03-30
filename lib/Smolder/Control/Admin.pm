package Smolder::Control::Admin;
use base 'Smolder::Control';
use strict;
use warnings;

=head1 NAME

Smolder::Control::Admin

=head1 DESCRIPTION

Controller module for admin pages.

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
sub require_group { 'admin' }

=head1 RUN MODES

=head2 welcome

Shows a welcome page using the F<Admin/welcome.tmpl> template.

=cut

sub welcome {
    my $self = shift;
    return $self->tt_process({});
}

1;
