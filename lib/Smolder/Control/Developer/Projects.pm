package Smolder::Control::Developer::Projects;
use base 'Smolder::Control';
use strict;
use warnings;

=head1 NAME

Smolder::Control::Developer::Projects

=head1 DESCRIPTION

Controller module that deals with developer actions associated with projects.

=cut

use Smolder::DB::Project;
use Smolder::DB::SmokeReport;
use Smolder::Constraints qw(
  enum_value
  length_max
  unsigned_int
  bool
  existing_project_category
  file_mtype
);
use Smolder::Conf qw(InstallRoot);
use Smolder::DBPlatform;
use Test::TAP::Model;
use Test::TAP::XML;
use File::Temp;
use File::Spec::Functions qw(catdir catfile);
use File::Copy qw(move);
use IO::Zlib;

my $DB_PLATFORM = Smolder::DBPlatform->load();

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
              platform_options
              architecture_options
              smoke_test_validity
              admin_settings
              process_admin_settings
              add_category
              delete_category
              )
        ]
    );
}

=head1 RUN MODES

=head2 smoke_test_validity

Set or unset the C<invalid> flag on a given smoke report. Uses the
F<Developer/Projects/smoke_report_details.tmpl> template.

=cut

sub smoke_test_validity {
    my $self   = shift;
    my $report = Smolder::DB::SmokeReport->retrieve( $self->param('id') );
    return $self->error_message("Smoke Report does not exist!")
      unless $report;

    # only project admins can do this
    unless ( $self->developer
        && $report->project->is_admin( $self->developer ) )
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
    my $results = Data::FormValidator->check( $self->query, $form )
      || return $self->error_message('Invalid data!');
    my $valid = $results->valid();

    # now update the DB
    $report->invalid( $valid->{invalid} );
    $report->invalid_reason( $valid->{invalid_reason} );
    $report->update();
    Smolder::DB->dbi_commit();

    return $self->tt_process(
        'Developer/Projects/smoke_report_details.tmpl',
        { report => $report, project => $report->project },
    );
}

=head2 platform_options

Returns an HTML list sutiable for a Prototype based "Autocomplete" form
of exising platform otpions

=cut

sub platform_options {
    my $self = shift;
    return $self->prototype->auto_complete_result(
        Smolder::DB::SmokeReport->column_values( 'platform', $self->query->param('platform'), ) );
}


=head2 architecture_options

Returns an HTML list sutiable for a Prototype based "Autocomplete" form
of exising architecture otpions

=cut

sub architecture_options {
    my $self = shift;
    return $self->prototype->auto_complete_result(
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
    my ( $self, $tt_params ) = @_;
    $tt_params ||= {};

    my $project = Smolder::DB::Project->retrieve( $self->param('id') );
    return $self->error_message('Project does not exist')
      unless $project;

    # make sure ths developer is a member of this project
    unless ( $project->public || $project->has_developer( $self->developer ) ) {
        return $self->error_message('Unauthorized for this project');
    }

    $tt_params->{project} = $project;
    return $self->tt_process($tt_params);
}

=head2 process_add_report

Process the incoming information from the C<add_report> mode. If validation passes
we upload the file and update the database. The report is stored for permanent storage
as an XML file and summary information is extracted and inserted into the database.
If successful, redirects the user to the "Recent Smoke Tests" screen for the same
project.

=cut

sub process_add_report {
    my $self    = shift;
    my $project = Smolder::DB::Project->retrieve( $self->param('id') );
    return $self->error_message('Project does not exist')
      unless $project;

    # make sure ths developer is a member of this project
    unless ( $project->public || $project->has_developer( $self->developer ) ) {
        return $self->error_message('Unauthorized for this project');
    }

    my $form = {
        required           => [qw(report_file format)],
        optional           => [qw(architecture platform comments category)],
        constraint_methods => {
            format       => enum_value('smoke_report', 'format'),
            architecture => length_max(255),
            platform     => length_max(255),
            comments     => length_max(1000),
            report_file  => file_mtype(qw(text/plain text/xml text/yaml application/x-gzip multipart/x-gzip)),
            category     => existing_project_category($project),
        },
    };

    my $results = $self->check_rm( 'add_report', $form )
      || return $self->check_rm_error_page;
    my $valid = $results->valid();

    # if the file is compressed, let's uncompress it
    my $report_file = $valid->{report_file};
    if( $report_file =~ /\.gz$/ ) {
        my $tmp = new File::Temp(
            UNLINK => 0,
        );
        my $in_fh = IO::Zlib->new();
        $in_fh->open($report_file, 'rb')
            or die "Could not open file $tmp for reading compressed!";

        my $buffer;
        while(read($in_fh, $buffer, 10240)) {
            print $tmp $buffer;
        }
        $report_file = $tmp->filename();
    }

    # take the uploaded file and create a Test::TAP::Model object from it
    my $report_model;
    if ( $valid->{format} eq 'XML' ) {
        eval { $report_model = Test::TAP::XML->from_xml_file( $report_file ); };
    } elsif ( $valid->{format} eq 'YAML' ) {
        require YAML;
        eval {
            $report_model =
              Test::TAP::XML->new_with_struct( YAML::LoadFile( $report_file ) );
        };
    }

    # if we couldn't create a model of the test
    if ( !$report_model || $@) {
        my $err = $@;
        $self->log->warning("Could not create Test::TAP::XML from uploaded file! $err");
        unlink( $report_file );
        return $self->add_report(
            {
                'err_valid_file'                       => 1,
                ( 'err_valid_' . lc $valid->{format} ) => 1
            }
        );
    }
    my $struct = $report_model->structure();

    # now add it to the database
    my $report = Smolder::DB::SmokeReport->create(
        {
            developer    => $self->developer,
            project      => $project,
            architecture => ( $valid->{architecture} || '' ),
            platform     => ( $valid->{platform} || '' ),
            comments     => ( $valid->{comments} || '' ),
            pass         => $report_model->total_passed,
            fail         => $report_model->total_failed,
            skip         => $report_model->total_skipped,
            todo         => $report_model->total_todo,
            total        => $report_model->total_seen,
            format       => $valid->{format},
            test_files   => scalar( $report_model->test_files ),
            duration     => ( $struct->{end_time} - $struct->{start_time} ),
            category     => ( $valid->{category} || undef ),
        }
    );
    Smolder::DB->dbi_commit();

    # now move the tmp file to it's real destination and compress it
    my $dest = $report->file;
    my $out_fh = IO::Zlib->new();
    $out_fh->open($dest, 'wb9') 
        or die "Could not open file $dest for writing compressed!";
    my $in_fh;
    open($in_fh, $report_file)
        or die "Could not open file $report_file for reading! $!" ;

    my $buffer;
    while(read($in_fh, $buffer, 10240)) {
        print $out_fh $buffer;
    }
    $out_fh->close();
    close($in_fh);

    # now send an email to all the user's who want this report
    $report->send_emails();

    # redirect to our recent reports
    $self->header_type('redirect');
    my $url = "/app/developer_projects/smoke_reports/$project";
    $self->header_add( -uri => $url );
    return "Redirecting to $url";
}

=head2 smoke_report

Shows the summary info for a given smoke_report. Uses the F<Developer/Projects/smoke_report.tmpl>
template.

=cut

sub smoke_report {
    my $self = shift;
    my $query = $self->query();

    my $smoke = Smolder::DB::SmokeReport->retrieve( $self->param('id') );
    return $self->error_message('Smoke report does not exist')
      unless $smoke;
    my $project = $smoke->project;

    # make sure ths developer is a member of this project
    unless ( $project->public || $project->has_developer( $self->developer ) ) {
        return $self->error_message('Unauthorized for this project');
    }

    return $self->tt_process({ report => $smoke, project => $project });
}

=head2 smoke_reports

Shows a list of smoke reports for a given project based on the limit, offset
and category parameters. Uses the F<Developer/Projects/smoke_reports.tmpl>
template.

=cut

sub smoke_reports {
    my ( $self, $tt_params ) = @_;
    $tt_params ||= {};
    my $query = $self->query();

    my $project = Smolder::DB::Project->retrieve( $self->param('id') );
    return $self->error_message('Project does not exist')
      unless $project;

    # make sure ths developer is a member of this project
    unless ( $project->public || $project->has_developer( $self->developer ) ) {
        return $self->error_message('Unauthorized for this project');
    }

    # prevent malicious limit and offset values
    my $form = {
        optional           => [qw(limit offset category)],
        constraint_methods => {
            limit    => unsigned_int(),
            offset   => unsigned_int(),
            category => existing_project_category($project),
        },
    };
    return $self->error_message('Something fishy')
      unless Data::FormValidator->check( $query, $form );

    $tt_params->{project}  = $project;
    $tt_params->{limit}    = defined $query->param('limit') ? $query->param('limit') : 5;
    $tt_params->{offset}   = $query->param('offset') || 0;
    $tt_params->{category} = $query->param('category') || undef;

    return $self->tt_process($tt_params);
}

=head2 report_details

Show the full report in a given format (HTML, XML, YAML) in the browser or
for download. Does not use a template but outputs the details directly
in the format requested.

=cut

sub report_details {
    my $self   = shift;
    my $report = Smolder::DB::SmokeReport->retrieve( $self->param('id') );
    return $self->error_message('Test Report does not exist')
      unless $report;
    my $type = $self->param('type') || 'html';

    # make sure ths developer is a member of this project
    unless ( $report->project->public || $report->project->has_developer( $self->developer ) ) {
        return $self->error_message('Unauthorized for this project');
    }

    my ( $content, $content_type );
    if ( $type eq 'html' ) {
        $content      = $report->html();
        $content_type = 'text/html';
    } elsif ( $type eq 'xml' ) {
        $content      = $report->xml();
        $content_type = 'text/xml';
    } elsif ( $type eq 'yaml' ) {
        $content      = $report->yaml();
        $content_type = 'text/plain';
    }
    $self->header_type('none');
    my $r = $self->param('r');
    $r->send_http_header($content_type);
    return $content;
}

=head2 show_all

Show all of the projects this developer is associated with and a menu for
each one.

=cut

sub show_all {
    my $self = shift;
    return $self->tt_process( {} );
}

=head2 admin_settings

If this developer is the admin of a project then show them a form to update some
project specific settings. Uses the F<Developer/Projects/admin_settings_form.tmpl>
and the F<Developer/Projects/admin_settings.tmpl> templates.

=cut

sub admin_settings {
    my ( $self, $tt_params ) = @_;

    my $project = Smolder::DB::Project->retrieve( $self->param('id') );
    return $self->error_message('Project does not exist')
      unless $project;

    # only show if this developer is an admin of this project
    unless ( $project->is_admin( $self->developer ) ) {
        return $self->error_message('You are not an admin of this Project!');
    }

    # if we have something then we're coming from another sub so fill the
    # form from the CGI params
    my $out;
    if ($tt_params) {
        $tt_params->{project} = $project;
        $out = HTML::FillInForm->new()->fill(
            scalarref =>
              $self->tt_process( 'Developer/Projects/admin_settings_form.tmpl', $tt_params ),
            fobject => $self->query(),
        );

        # else we weren't passed anything, then we need to fill in the form
        # from the DB
    } else {
        my $fill_data = {
            default_platform => $project->default_platform,
            default_arch     => $project->default_arch,
            allow_anon       => $project->allow_anon,
            graph_start      => $project->graph_start,
        };
        $out = HTML::FillInForm->new()->fill(
            scalarref => $self->tt_process( { project => $project } ),
            fdat      => $fill_data,
        );
    }
    return $out;
}

=head2 process_admin_settings 

Process the incoming information from the C<admin_settings> mode. If
it passes validation then update the database. If successful, returns
to the C<admin_settings> mode.

=cut

sub process_admin_settings {
    my $self    = shift;
    my $project = Smolder::DB::Project->retrieve( $self->param('id') );
    return $self->error_message('Project does not exist')
      unless $project;

    # only process if this developer is an admin of this project
    unless ( $project->is_admin( $self->developer ) ) {
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
    my $results = $self->check_rm( 'admin_settings', $form )
      || return $self->check_rm_error_page;
    my $valid = $results->valid();

    # set and save
    foreach my $field qw(allow_anon default_arch default_platform graph_start) {
        $project->$field( $valid->{$field} );
    }
    $project->update();
    Smolder::DB->dbi_commit();

    return $self->admin_settings( { success => 1 } );
}

=head2 categories

Display the list of categories that are associated with this project.
Uses the F<Developer/Projects/categories.tmpl> template.

=cut

sub categories {
    my ( $self, $tt_params, $project ) = @_;

    $project ||= Smolder::DB::Project->retrieve( $self->param('id') );
    return $self->error_message('Project does not exist')
      unless $project;

    $tt_params->{project} = $project;
    return $self->tt_process($tt_params);
}

=head2 add_category

Add a category to a project for organizing Smoke Reports. If validation
passes the infomation is added to the database and we return to the 
C<categories> mode.

=cut

sub add_category {
    my $self    = shift;
    my $project = Smolder::DB::Project->retrieve( $self->param('id') );
    return $self->error_message('Project does not exist')
      unless $project;

    # only process if this developer is an admin of this project
    unless ( $project->is_admin( $self->developer ) ) {
        return $self->error_message('You are not an admin of this Project!');
    }

    my $form = {
        required           => [qw(category)],
        constraint_methods => { category => length_max(255), }
    };
    my $results = $self->check_rm( 'categories', $form )
      || return $self->check_rm_error_page;
    my $valid = $results->valid();

    # try to insert
    eval { $project->add_category( $valid->{category} ) };
    if ($@) {
        if ( $DB_PLATFORM->unique_failure_msg($@) ) {
            return $self->categories( { err_duplicate_category => 1 } );
        } else {
            die $@;
        }
    }
    Smolder::DB->dbi_commit();

    # now return to that page again
    return $self->categories( { add_success => 1 }, $project );
}

=head2 delete_category

Deletes a category that is associated with a given Project. If validation
passes the database is updated and all smoke reports that were associated
with this category are either re-assigned or simply not associated with a
category (depending on what the project admin chooses). Returns to the
C<categories> mode if successful.

=cut

sub delete_category {
    my $self    = shift;
    my $project = Smolder::DB::Project->retrieve( $self->param('id') );
    return $self->error_message('Project does not exist')
      unless $project;

    # only process if this developer is an admin of this project
    unless ( $project->is_admin( $self->developer ) ) {
        return $self->error_message('You are not an admin of this Project!');
    }

    my $query = $self->query();
    my ( $cat, $replacement ) = map { $query->param($_) } qw(category replacement);

    if ($replacement) {

        # change categories
        Smolder::DB::SmokeReport->change_category(
            project     => $project,
            category    => $cat,
            replacement => $replacement,
        );
    }

    # delete the old category
    $project->delete_category($cat);
    Smolder::DB->dbi_commit();

    return $self->categories( { delete_successful => 1 }, $project );
}

1;
