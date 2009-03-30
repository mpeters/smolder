package Smolder::Control::Public::Graphs;
use strict;
use base 'Smolder::Control::Developer::Graphs';
use Smolder::DB::Project;

=head1 NAME 

Smolder::Control::Public::Graphs

=head1 DESCRIPTION

Controller module for graphs for public projects. Inherits from 
L<Smolder::Control::Developer::Graphs>, but puts restrictions
on what non-developer public users can do.

=cut

sub setup {
    my $self = shift;
    $self->start_mode('start');
    $self->run_modes(
        [
            qw(
              start
              image
              forbidden_project
              )
        ]
    );
}

sub cgiapp_prerun {
    my $self = shift;
    my $id   = $self->param('id');
    if ($id) {
        my $proj = Smolder::DB::Project->retrieve($id);
        if ($proj && !$proj->public) {
            $self->prerun_mode('forbidden_project');
        } else {
            $self->param(project => $proj);
        }
    }
}

# used by the templates to see if the controller is public
sub public        { 1 }
sub require_group { }

=head1 RUN MODES

=head2 start

Display the initial start form for a project's graph with some
reasonable defaults. Uses the F<Public/Graphs/start.tmpl>
template.

This method is provided by L<Smolder::Control::Developer::Graphs>.

=head2 image

Creates and returns a graph image to the browser based on the parameters
chosen by the user.

This method is provided by L<Smolder::Control::Developer::Graphs>.

=head2 forbidden_project

Shows a FORBIDDEN message if a user tries to act on a project that is not
marked as 'public'

=cut

sub forbidden_project {
    my $self = shift;
    return $self->error_message('This is not a public project');
}

1;
