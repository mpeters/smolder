package Smolder::Control::Public::Projects;
use strict;
use base 'Smolder::Control::Developer::Projects';
use Smolder::Conf qw(HostName);
use Smolder::DB;
use Smolder::DB::Project;
use Smolder::Util;
use HTML::FillInForm;
use XML::Atom::SimpleFeed;
use DateTime;

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
              test_file_report_details
              add_report
              process_add_report
              forbidden
              feed
              tap_archive
              tap_stream
              bulk_test_file_action
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
            $self->prerun_mode('forbidden');
        } else {
            $self->param(project => $proj);
        }
    }
}

# used by the templates to see if the controller is public
sub public        { 1 }
sub require_group { }

=head1 RUN MODES

=head2 show_all

Shows a list of all the public projects.

=cut

sub show_all {
    my $self = shift;
    my @projs = Smolder::DB::Project->search(public => 1, {order_by => 'name'});

    return $self->tt_process({projects => \@projs});
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

=head2 feed

Will return an XML data feed (Atom) to the browser. The 5 most recent smoke
reports for a project are included in this feed. An optional C<type>
can also be specified which is can either be C<all> or C<failures>.Only
projects that have been marked as C<enable_feed> will appear in any feed.

=cut

sub feed {
    my $self = shift;
    my @binds;
    my $sql = qq/
        SELECT sr.* FROM smoke_report sr
        JOIN project p ON (sr.project = p.id)
        WHERE p.enable_feed = 1 AND p.id = ?
    /;
    my $id      = $self->param('id');
    my $project = Smolder::DB::Project->retrieve($id);
    my $type    = $self->param('type');
    push(@binds, $id);

    if ($type and $type eq 'failed') {
        $sql .= ' AND sr.failed = 1 ';
    }

    $sql .= ' ORDER BY sr.added DESC LIMIT 5';

    my $sth = Smolder::DB::SmokeReport->db_Main->prepare_cached($sql);
    $sth->execute(@binds);
    my @reports = Smolder::DB::SmokeReport->sth_to_objects($sth);

    $self->header_props(-type => 'text/xml');

    my $updated;
    if (@reports) {
        $updated = $reports[0]->added;
    } else {
        $updated = DateTime->now();
    }

    my $feed = XML::Atom::SimpleFeed->new(
        title   => '[' . $project->name . '] Smolder - ' . HostName,
        link    => Smolder::Util::url_base,
        id      => Smolder::Util::url_base,
        updated => $updated->strftime('%FT%TZ'),
    );

    foreach my $report (@reports) {
        my $link =
            Smolder::Util::url_base() . '/app/'
          . ($project->public ? 'public' : 'developer')
          . '_projects/smoke_report/'
          . $report->id;
        $feed->add_entry(
            title => '#'
              . $report->id . ' - '
              . ($report->failed ? 'Failed' : 'New')
              . ' Smoke Report',
            author  => $report->developer->username,
            link    => $link,
            id      => $link,
            summary => $report->summary,
            updated => $report->added->strftime('%FT%TZ'),
        );
    }
    return $feed->as_string();
}

1;
