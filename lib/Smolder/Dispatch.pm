package Smolder::Dispatch;
use base 'CGI::Application::Dispatch';
use strict;
use warnings;

sub dispatch_args {
    return {
        prefix => 'Smolder::Control',
        table  => [
            ''                                      => {app => 'Public'},
            'projects/tap_stream/:id/:stream_index' => {
                app => 'Projects',
                rm  => 'tap_stream',
            },
            'projects/test_file_history/:id/:test_file_id' => {
                app => 'Projects',
                rm  => 'test_file_history',
            },
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

