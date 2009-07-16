package Server::Control::Smolder;
use File::Slurp;
use Moose;
use Smolder::Conf;
use strict;
use warnings;

extends 'Server::Control::Simple';

__PACKAGE__->meta->make_immutable();

sub _build_port {
    my $self = shift;
    return Smolder::Conf->get('Port');
}

sub do_start {
    my $self = shift;

    # Run start(), instead of background()
    my $pid = $self->server->start();
    write_file( $self->pid_file, $pid );
}

1;
