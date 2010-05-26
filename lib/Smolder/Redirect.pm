package Smolder::Redirect;
use strict;
use warnings;
use base 'CGI::Application';

use Smolder::Conf qw( HostName Port );

sub setup {
    my $self = shift;
    $self->run_modes( ['redirect'] );
    $self->start_mode('redirect');
}

sub redirect {
    my $self = shift;
    $self->header_type('redirect');
    $self->header_add( -uri => 'http://' 
            . HostName
            . ( Port == 80 ? '' : ':' . Port )
            . '/app' );
    return "Redirecting...\n";
}

1;

