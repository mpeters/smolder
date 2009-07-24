package Smolder::Control::Developer::Projects;
use base 'Smolder::Control';
use strict;
use warnings;
use CGI::Application::Plugin::Stream qw(stream_file);
use DateTime;
use Smolder::DB::Project;
use Smolder::DB::SmokeReport;
use Smolder::Conf;
use Smolder::DB::TestFile;
use Exception::Class;
use HTML::TagCloud;
use URI::Escape qw(uri_escape);
use Smolder::Control::Public::Auth;
use Smolder::Constraints qw(
  enum_value
  length_max
  unsigned_int
  bool
  file_mtype
  smoke_report_tags
);

=head1 NAME

Smolder::Control::Developer::Projects

=head1 DESCRIPTION

Controller module that deals with developer actions associated with projects.

=cut

# used to control public or registered developer functionality
# to be overriden by subclasses if necessary
sub public { return 0 }

sub setup {
    my $self = shift;
    $self->start_mode('show_all');
    $self->run_modes(
        [
            qw(
              show_all
              add_report
              process_add_report
              smoke_reports
              smoke_report
              report_details
              test_file_report_details
              platform_options
              architecture_options
              smoke_test_validity
              admin_settings
              process_admin_settings
              delete_tag
              details
              tap_archive
              tap_stream
              bulk_test_file_action
              )
        ]
    );
}

sub require_group { 'developer' }

=head1 RUN MODES

=head2 smoke_test_validity

Set or unset the C<invalid> flag on a given smoke report. Uses the
F<Developer/Projects/smoke_report_details.tmpl> template.

=cut

sub smoke_test_validity {
    my $self   = shift;
    my $report = Smolder::DB::SmokeReport->retrieve($self->param('id'));
    return $self->error_message("Smoke Report does not exist!")
      unless $report;

    # only project admins can do this
    unless ($self->developer
        && $report->project->is_admin($self->developer))
    {
        return $self->error_message("Not an admin of this project!");
    }

    # make sure it's not too long or malicious
    my $form = {
        required           => [qw(invalid)],
        optional           => [qw(invalid_reason)],
        constraint_methods => {
            invalid        => bool(),
            invalid_reason => length_max(255),
        }
    };
    my $results = Data::FormValidator->check($self->query, $form)
      || return $self->error_message('Invalid data!');
    my $valid = $results->valid();

    # now update the DB
    $report->invalid($valid->{invalid});
    $report->invalid_reason($valid->{invalid_reason});
    $report->update();

    # notify the user
    $self->add_message(msg => "Report #$report has been marked as "
          . ($valid->{invalid} ? 'invalid' : 'valid')
          . ".");
    return $self->tt_process(
        'Developer/Projects/smoke_report_details.tmpl',
        {report => $report, project => $report->project},
    );
}

=head2 platform_options

Returns an HTML list sutiable for a Prototype based "Autocomplete" form
of exising platform otpions

=cut

sub platform_options {
    my $self = shift;
    return $self->auto_complete_results(
        Smolder::DB::SmokeReport->column_values('platform', $self->query->param('platform'),));
}

=head2 architecture_options

Returns an HTML list sutiable for a Prototype based "Autocomplete" form
of exising architecture otpions

=cut

sub architecture_options {
    my $self = shift;
    return $self->auto_complete_results(
        Smolder::DB::SmokeReport->column_values(
            'architecture', $self->query->param('architecture'),
        )
    );
}

=head2 add_report

Shows the form to allow the developer to add a new smoke report to a project.
Uses the C<Developer/Projects/add_report.tmpl> template.

=cut

sub add_report {
    my ($self, $tt_params) = @_;
    $tt_params ||= {};

    my $project = Smolder::DB::Project->retrieve($self->param('id'));
    return $self->error_message('Project does not exist')
      unless $project;

    # make sure ths developer is a member of this project, or it's a public project
    # that allows anonymous uploads
    if(!$project->has_developer($self->developer)) {
        if( $project->public && !$project->allow_anon ) {
            return $self->error_message('Project does not allow anonymous reports');
        } elsif(!$project->public ) {
            return $self->error_message('Unauthorized for this project');
        }
    }

    $tt_params->{project} = $project;
    return $self->tt_process($tt_params);
}

=head2 process_add_report

Process the incoming information from the C<add_report> mode. If validation passes
we upload the file and update the database. The report is stored for permanent storage,
and summary information is extracted and inserted into the database.
If successful, redirects the user to the "Recent Smoke Tests" screen for the same
project.

If the newly uploaded report causes the C<ProjectFullReportsMax> configuration limit 
to be reached then any full reports over that limit will be purged. Their summary data 
will still be retained in the database, but the compressed XML file which contains the 
details will be removed, and the reports details will no longer be accessible.

=cut

sub _goto_login {
    my $self = shift;
    my $q    = $self->query;
    $self->header_type('redirect');
    my $url = "/app/public_auth/login";
    $self->header_props(-url => $url, -status => '401');
    return "Redirecting to $url";
}

sub process_add_report {
    my $self    = shift;
    my $q       = $self->query;
    my $project = Smolder::DB::Project->retrieve($self->param('id'));
    return $self->error_message('Project does not exist')
      unless $project;

    if ($q->param('username') && $q->param('password')) {
        Smolder::Control::Public::Auth::do_login($self, $q->param('username'),
            $q->param('password'));
    }

    # we need to be logged in to use this...
    return $self->_goto_login if !$self->public && $self->developer->guest;

    # make sure ths developer is a member of this project, or it's a public project
    # that allows anonymous uploads
    if(!$project->has_developer($self->developer)) {
        if( $project->public && !$project->allow_anon ) {
            return $self->error_message('Project does not allow anonymous reports');
        } elsif(!$project->public ) {
            return $self->error_message('Unauthorized for this project');
        }
    }
            
    my $form = {
        required           => [qw(report_file)],
        optional           => [qw(architecture platform comments tags revision)],
        constraint_methods => {
            architecture => length_max(255),
            platform     => length_max(255),
            revision     => length_max(255),
            comments     => length_max(1000),
            report_file  => file_mtype(
                qw(
                  application/x-gzip
                  application/x-gtar
                  application/x-tar
                  application/x-zip
                  multipart/x-gzip
                  )
            ),
            tags => smoke_report_tags(),
        },
    };

    my $results = $self->check_rm('add_report', $form)
      || return $self->check_rm_error_page;
    my $valid = $results->valid();

    my $report;
    eval {
        $report = Smolder::DB::SmokeReport->upload_report(
            file         => $valid->{report_file},
            developer    => $self->developer,
            project      => $project,
            architecture => $valid->{architecture},
            platform     => $valid->{platform},
            comments     => $valid->{comments},
            revision     => $valid->{revision},
        );
    };

    # is this an exception we can deal with?
    my $e;
    if ($e = Exception::Class->caught('Smolder::Exception::InvalidTAP')) {
        $self->log->warning($e->error . "\n" . $e->trace->as_string);
        return $self->add_report({invalid_report_file => 1});
    } elsif ($e = Exception::Class->caught('Smolder::Exception::InvalidArchive')) {
        $self->log->warning($e->error . "\n" . $e->trace->as_string);
        return $self->add_report({invalid_report_file => 1});
    } else {
        $e = Exception::Class->caught();
        if ($e) {
            ref $e && $e->isa('Exception::Class') ? $e->rethrow : die $e;
        }
    }

    # add the tags if present
    if ($valid->{tags}) {
        $report->add_tag($_) foreach @{$valid->{tags}};
    }

    # redirect to our recent reports
    $self->header_type('redirect');
    my $url =
      '/app/' . ($self->public ? 'public' : 'developer') . "_projects/smoke_reports/$project";
    $self->header_add(-uri => $url);
    return "Reported #$report added.\nRedirecting to $url";
}

=head2 smoke_report

Shows the summary info for a given smoke_report. Uses the F<Developer/Projects/smoke_report.tmpl>
template.

=cut

sub smoke_report {
    my $self  = shift;
    my $query = $self->query();

    my $smoke = Smolder::DB::SmokeReport->retrieve($self->param('id'));
    return $self->error_message('Smoke report does not exist')
      unless $smoke;
    my $project = $smoke->project;

    # make sure ths developer is a member of this project
    unless ($project->public || $project->has_developer($self->developer)) {
        return $self->error_message('Unauthorized for this project');
    }

    return $self->tt_process({report => $smoke, project => $project});
}

=head2 smoke_reports

Shows a list of smoke reports for a given project based on the limit, offset
and tag parameters. Uses the F<Developer/Projects/smoke_reports.tmpl>
template.

=cut

sub smoke_reports {
    my ($self, $tt_params) = @_;
    $tt_params ||= {};
    my $query = $self->query();

    my $project = Smolder::DB::Project->retrieve($self->param('id'));
    return $self->error_message('Project does not exist')
      unless $project;

    # make sure ths developer is a member of this project
    unless ($project->public || $project->has_developer($self->developer)) {
        return $self->error_message('Unauthorized for this project');
    }

    # prevent malicious limit and offset values
    my $form = {
        optional           => [qw(limit offset tag)],
        constraint_methods => {
            limit  => unsigned_int(),
            offset => unsigned_int(),
        },
    };
    return $self->error_message('Something fishy')
      unless Data::FormValidator->check($query, $form);

    $tt_params->{project} = $project;
    $tt_params->{limit}   = defined $query->param('limit') ? $query->param('limit') : (Smolder::Conf->get('ReportsPerPage') || 5);
    $tt_params->{offset}  = $query->param('offset') || 0;
    $tt_params->{tag}     = $query->param('tag') || undef;

    return $self->tt_process($tt_params);
}

=head2 report_details

Show the full report for download.  Does not use a template but simply
outputs the pregenerated file.

=cut

sub report_details {
    my $self   = shift;
    my $report = Smolder::DB::SmokeReport->retrieve($self->param('id'));

    if (Smolder::Conf->get('AutoRefreshReports')) {
        Smolder::DB::SmokeReport->update_all_report_html();
    }

    return $self->error_message('Test Report does not exist')
      unless $report;

    # make sure ths developer is a member of this project
    unless ($report->project->public || $report->project->has_developer($self->developer)) {
        return $self->error_message('Unauthorized for this project');
    }

    my $tt_params = {
        tap     => ${$report->html},
        project => $report->project,
        report  => $report,
    };

    return $self->tt_process('Developer/Projects/tap.tmpl', $tt_params),;
}

=head2 test_file_report_details

Show the details of an individual test file. This is called from
the HTML page generated by L<report_details> by an AJAX call.

=cut

sub test_file_report_details {
    my $self   = shift;
    my $report = Smolder::DB::SmokeReport->retrieve($self->param('id'));
    return $self->error_message('Test Report does not exist')
      unless $report;
    my $num = $self->param('type') || 0;

    # make sure ths developer is a member of this project
    unless ($report->project->public || $report->project->has_developer($self->developer)) {
        return $self->error_message('Unauthorized for this project');
    }
    return $report->html_test_detail($num);
}

=head2 tap_archive

Return the TAP archive for a given report to the browser

=cut

sub tap_archive {
    my $self   = shift;
    my $report = Smolder::DB::SmokeReport->retrieve($self->param('id'));
    return $self->error_message('Test Report does not exist')
      unless $report;

    # make sure ths developer is a member of this project
    unless ($report->project->public || $report->project->has_developer($self->developer)) {
        return $self->error_message('Unauthorized for this project');
    }

    return $self->stream_file($report->file);
}

=head2 tap_stream

Return the TAP stream for a given report and given stream index number to the browser.

=cut

sub tap_stream {
    my $self      = shift;
    my $report_id = $self->param('id');
    my $tap_index = $self->param('stream_index');
    my $report    = Smolder::DB::SmokeReport->retrieve($report_id);
    return $self->error_message("Test Report $report_id does not exist")
      unless $report;

    # make sure ths developer is a member of this project
    unless ($report->project->public || $report->project->has_developer($self->developer)) {
        return $self->error_message('Unauthorized for this project');
    }
    my $output = $report->tap_stream($tap_index);
    $$output = '<pre>' . $$output . '</pre>';
    return $output;
}

=head2 show_all

Show all of the projects this developer is associated with and a menu for
each one.

=cut

sub show_all {
    my $self = shift;
    return $self->tt_process({});
}

=head2 admin_settings

If this developer is the admin of a project then show them a form to update some
project specific settings. Uses the F<Developer/Projects/admin_settings_form.tmpl>
and the F<Developer/Projects/admin_settings.tmpl> templates.

=cut

sub admin_settings {
    my ($self, $tt_params) = @_;

    my $project = Smolder::DB::Project->retrieve($self->param('id'));
    return $self->error_message('Project does not exist')
      unless $project;

    # only show if this developer is an admin of this project
    unless ($project->is_admin($self->developer)) {
        return $self->error_message('You are not an admin of this Project!');
    }

    # if we have something then we're coming from another sub so fill the
    # form from the CGI params
    my $out;
    if ($tt_params) {
        $tt_params->{project}   = $project;
        $tt_params->{tag_cloud} = $self->_project_tag_cloud($project);
        $out                    = HTML::FillInForm->new()->fill(
            scalarref =>
              $self->tt_process('Developer/Projects/admin_settings_form.tmpl', $tt_params),
            fobject => $self->query(),
        );

    } else {

        # else we weren't passed anything, then we need to fill in the form
        # from the DB
        $tt_params              = {};
        $tt_params->{project}   = $project;
        $tt_params->{tag_cloud} = $self->_project_tag_cloud($project);
        my $fill_data = {
            default_platform => $project->default_platform,
            default_arch     => $project->default_arch,
            allow_anon       => $project->allow_anon,
            graph_start      => $project->graph_start,
        };
        $out = HTML::FillInForm->new()->fill(
            scalarref => $self->tt_process($tt_params),
            fdat      => $fill_data,
        );
    }
    return $out;
}

sub _project_tag_cloud {
    my ($self, $project, $url) = @_;
    my @tags = $project->tags(with_counts => 1);
    if (@tags) {
        my $cloud = HTML::TagCloud->new();
        foreach (@tags) {
            my $tag_url = $url ? "$url?tag=" . uri_escape($_->{tag}) : 'javascript:void(0)';
            $cloud->add($_->{tag}, $tag_url, $_->{count});
        }
        return $cloud->html_and_css(100);
    } else {
        return '';
    }
}

=head2 process_admin_settings 

Process the incoming information from the C<admin_settings> mode. If
it passes validation then update the database. If successful, returns
to the C<admin_settings> mode.

=cut

sub process_admin_settings {
    my $self    = shift;
    my $project = Smolder::DB::Project->retrieve($self->param('id'));
    return $self->error_message('Project does not exist')
      unless $project;

    # only process if this developer is an admin of this project
    unless ($project->is_admin($self->developer)) {
        return $self->error_message('You are not an admin of this Project!');
    }

    # validate the incoming data
    my $form = {
        required           => [qw(allow_anon graph_start)],
        optional           => [qw(default_arch default_platform)],
        constraint_methods => {
            allow_anon       => bool(),
            default_arch     => length_max(255),
            default_platform => length_max(255),
            graph_start      => enum_value('project', 'graph_start'),
        },
    };
    my $results = $self->check_rm('admin_settings', $form)
      || return $self->check_rm_error_page;
    my $valid = $results->valid();

    # set and save
    foreach my $field qw(allow_anon default_arch default_platform graph_start) {
        $project->$field($valid->{$field});
    }
    $project->update();

    $self->add_message(msg => "Project settings successfully updated.",);
    return $self->admin_settings({success => 1});
}

=head2 delete_tag

Deletes a tag that is associated with a given Project. If validation
passes the database is updated and all smoke reports that were associated
with this tag are either re-assigned or simply not associated with a
tag (depending on what the project admin chooses). Returns to the
C<admin_settings> mode if successful.

=cut

sub delete_tag {
    my $self    = shift;
    my $project = Smolder::DB::Project->retrieve($self->param('id'));
    return $self->error_message('Project does not exist')
      unless $project;

    # only process if this developer is an admin of this project
    unless ($project->is_admin($self->developer)) {
        return $self->error_message('You are not an admin of this Project!');
    }

    my $query = $self->query();
    my ($tag, $replacement) = map { $query->param($_) } qw(tag replacement);

    if ($replacement) {

        # change the tag
        $project->change_tag($tag, $replacement);
        $self->add_message(msg => "Tag '$tag' was successfully replaced by '$replacement'.");
    } else {

        # delete the old tag
        $project->delete_tag($tag);
        $self->add_message(
            msg => "Tag '$tag' successfully deleted from project '" . $project->name . "'.");
    }

    return $self->admin_settings();
}

=head2 details

Shows the details of a project.

=cut

sub details {
    my $self = shift;
    my $id   = $self->param('id');
    my $proj = Smolder::DB::Project->retrieve($id);

    unless ($proj->public || $proj->has_developer($self->developer)) {
        return $self->error_message('Unauthorized for this project');
    }

    if ($proj) {
        my $url = "/app/"
          . ($self->public ? 'public' : 'developer')
          . '_projects/smoke_reports/'
          . $proj->id;
        my $tag_cloud = $self->_project_tag_cloud($proj, $url);
        return $self->tt_process({project => $proj, tag_cloud => $tag_cloud});
    } else {
        return $self->error_message('That project does not exist!');
    }
}

=head2 bulk_test_file_action

Perform bulk actions on test files

=cut

sub bulk_test_file_action {
    use Smolder::Debug;
    my $self = shift;
    my $id   = $self->param('id');
    my $query = $self->query;
    my ($action) = grep { /(.+)_action/ } $query->param
        or die "could not find action";
    $action = substr($action, 0, -7);
    my @testfile_ids = $query->param('testfiles');
    my @testfiles = map { Smolder::DB::TestFile->retrieve($_) } @testfile_ids;
    if ($action eq 'mute') {
        my $num_days = $query->param('num_days');
        die "could not find num_days" if !defined($num_days);
        my $mute_until_time = DateTime->now->add(days => $num_days)->truncate(to => 'day')->epoch;
        foreach my $testfile (@testfiles) {
            $testfile->mute_until($mute_until_time);
            $testfile->update;
        }
    }

    $self->header_type('redirect');
    my $url =
      '/app/' . ($self->public ? 'public' : 'developer') . "_projects/report_details/$id";
    $self->header_add(-uri => $url);
    return "Redirecting";
}

1;
