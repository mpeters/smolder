package Smolder::Dispatch;
use base 'CGI::Application::Dispatch';
use strict;
use warnings;

sub dispatch_args {
    return {
        prefix => 'Smolder::Control',
        table  => [
            ''                                             => {app => 'Public'},
            'public_projects/tap_stream/:id/:stream_index' => {
                app => 'Public::Projects',
                rm  => 'tap_stream',
            },
            'developer_projects/tap_stream/:id/:stream_index' => {
                app => 'Developer::Projects',
                rm  => 'tap_stream',
            },
            'public_projects/test_file_history/:project_id/:test_file_id' => {
                app => 'Public::Projects',
                rm  => 'test_file_history',
            },
            'developer_projects/test_file_history/:project_id/:test_file_id' => {
                app => 'Developer::Projects',
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

