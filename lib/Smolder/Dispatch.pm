package Smolder::Dispatch;
use base 'CGI::Application::Dispatch';
use strict;
use warnings;

sub dispatch_args {
    return {
        prefix  => 'Smolder::Control',
        table   => [
            ''                      => { app => 'Public' },
            ':app/:rm?/:id?/:type?' => {},
        ],
    };
}

1;

__END__

=head1 NAME

Smolder::Dispatch

=head1 DESCRIPTION

This class is a L<CGI::Application:::Dispatch> subclass which customizes the
dispatch table and the application module prefix.

