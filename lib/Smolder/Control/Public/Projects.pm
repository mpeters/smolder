package Smolder::Control::Public::Projects;
use strict;
use base 'Smolder::Control::Developer::Projects';
use Smolder::DB;
use Smolder::DB::Project;
use HTML::FillInForm;

=head1 NAME 

Smolder::Control::Public::Projects

=head1 DESCRIPTION

Controller module for public projects. Inherits from 
L<Smolder::Control::Developer::Projects>, but puts restrictions
on what non-developer public users can do.

=cut

sub setup {
    my $self = shift;
    $self->start_mode('show_all');
    $self->run_modes(
        [
            qw(
              show_all
              details
              smoke_reports
              smoke_report
              report_details
              add_report
              process_add_report
              forbidden
              )
        ]
    );
}

sub cgiapp_prerun {
    my $self = shift;
    my $id   = $self->param('id');
    if ($id) {
        my $proj = Smolder::DB::Project->retrieve($id);
        if ( $proj && !$proj->public ) {
            $self->prerun_mode('forbidden');
        } else {
            $self->param( project => $proj );
        }
    }
}

# used by the templates to see if the controller is public
sub public { 1 }

=head1 RUN MODES

=head2 show_all

Shows a list of all the public projects.

=cut

sub show_all {
    my $self  = shift;
    my @projs = Smolder::DB::Project->search( public => 1 );

    return $self->tt_process( { projects => \@projs } );
}

=head2 details

Shows the details of a project.

=cut

sub details {
    my $self = shift;
    my $proj = $self->param('project');
    if ($proj) {
        return $self->tt_process( { project => $proj } );
    } else {
        return $self->error_message('That project does not exist!');
    }
}

=head2 forbidden 

Shows a FORBIDDEN message if a user tries to act on a project that is not
marked as 'forbibben'

=cut

sub forbidden {
    my $self = shift;
    return $self->error_message('This is not a public project');
}

=head2 smoke_reports

Shows a list of smoke reports for a given public project.

This method is provided by L<Smolder::Control::Developer::Projects>.

=head2 smoke_report

Shows a single smoke report for a public project.

This method is provided by L<Smolder::Control::Developer::Projects>.

=head2 report_details

Shows the details of an uploaded test for a public project in either
HTML, XML or YAML.

This method is provided by L<Smolder::Control::Developer::Projects>.

=head2 add_report

Shows the form to allow public users (non-developers) to upload a smoke
report to a public project.

This method is provided by L<Smolder::Control::Developer::Projects>.

=head2 process_add_report

Process the information from the L<add_report> run mode.

This method is provided by L<Smolder::Control::Developer::Projects>.

=cut

1;
