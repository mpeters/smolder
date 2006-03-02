package Smolder::Control::Public;
use base 'Smolder::Control';
use strict;
use warnings;

sub setup {
    my $self = shift;
    $self->start_mode('welcome');
    $self->run_modes([qw(
        welcome
    )]);
}

sub welcome {
    my $self = shift;
    return $self->tt_process({});
}


1;
