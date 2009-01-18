package Smolder::Redirect;
use strict;
use warnings;
use base 'CGI::Application';

sub setup {
    my $self = shift;
    $self->run_modes(['redirect']);
    $self->start_mode('redirect');
}

sub redirect {
    my $self = shift;
    $self->header_type('redirect');
    $self->header_add(-uri => '/app');
    return "Redirecting...\n";
}

1;

