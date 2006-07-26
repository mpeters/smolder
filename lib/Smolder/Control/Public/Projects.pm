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
              forbidden
              )
        ]
    );
}

=head1 RUN MODES

=cut

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

sub show_all {
    my $self  = shift;
    my @projs = Smolder::DB::Project->search( public => 1 );

    return $self->tt_process( { projects => \@projs } );
}

sub details {
    my $self = shift;
    my $proj = $self->param('project');
    if ($proj) {
        return $self->tt_process( { project => $proj } );
    } else {
        return $self->error_message('That project does not exist!');
    }
}

# used by the templates to see if the controller is public
sub public { 1 }

sub forbidden {
    my $self = shift;
    return $self->error_message('This is not a public project');
}

1;
