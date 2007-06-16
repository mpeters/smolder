package Smolder::Control::Admin::Projects;
use strict;
use warnings;
use base 'Smolder::Control';
use Data::FormValidator::Constraints::DateTime qw(to_datetime);
use Smolder::Constraints qw(
  length_max
  unsigned_int
  bool
  unique_field_value
  existing_field_value
);
use Smolder::DB::Project;
use Smolder::DB::Developer;
use Smolder::DB::ProjectDeveloper;
use Smolder::DBPlatform;
my $DB_PLATFORM = Smolder::DBPlatform->load();

=head1 NAME

Smolder::Control::Admin::Projects

=head1 DESCRIPTION

Controller module for all admin actions concerning projects.

=cut

sub setup {
    my $self = shift;
    $self->start_mode('list');
    $self->run_modes(
        [
            qw(
              add
              process_add
              edit
              list
              details
              delete
              developers
              add_developer
              remove_developer
              change_admins
              )
        ]
    );
}

=head1 RUN MODES

=head2 change_admins 

Change who is considered an C<admin> for a project. Clears out all
of the old admins for a project and sets up new ones. Uses the
F<Admin/Projects/project_container.tmpl> template.

=cut

sub change_admins {
    my $self    = shift;
    my $project = Smolder::DB::Project->retrieve( $self->param('id') );
    return $self->error_message("Project does not exist!")
      unless ($project);
    my @admins = $self->query->param('admin');

    # clear out the old admins
    $project->clear_admins();
    $project->set_admins(@admins) if (@admins);
    Smolder::DB->dbi_commit();
    $self->add_message(
        msg => "Successfully changed admins for project '" . $project->name . "'."
    );

    return $self->tt_process( 'Admin/Projects/project_container.tmpl', { project => $project }, );
}

=head2 developers

Shows a list of developers and projects. Using drag-and-drop containers
a developer is added to or removed from a project.
Uses the F<Admin/Projects/developers.tmpl> template.

=cut

sub developers {
    my ( $self, $tt_params ) = @_;
    $tt_params ||= {};
    my @developers = Smolder::DB::Developer->search(guest => 0);
    my @projects   = Smolder::DB::Project->retrieve_all();

    $tt_params->{developers} = \@developers if (@developers);
    $tt_params->{projects}   = \@projects   if (@projects);
    return $self->tt_process($tt_params);
}

=head2 add_developer

Add a developer to a project (triggerred by dropping a developer into 
a project container). Uses the F<Admin/Projects/project_container.tmpl>
template.

=cut

sub add_developer {
    my $self      = shift;
    my $query     = $self->query;
    my $project   = Smolder::DB::Project->retrieve( $query->param('project') );
    my $developer = Smolder::DB::Developer->retrieve( $query->param('developer') );

    if ( $developer && $project ) {
        eval {
            Smolder::DB::ProjectDeveloper->create(
                {
                    project   => $project,
                    developer => $developer,
                }
            );
        };
        if ($@) {
            die $@ unless $DB_PLATFORM->unique_failure_msg($@);
        } else {
            Smolder::DB->dbi_commit();
            $self->add_message(
                msg => "Developer '" . $developer->username 
                    . "' has been added to project '" . $project->name . "'."
            );
        }
    }

    return $self->tt_process( 'Admin/Projects/project_container.tmpl', { project => $project } );
}

=head2 remove_developer

Remove a developer from a project (triggerred by dragging a developer from
a project container to the trash can). Uses the F<Admin/Projects/project_container.tmpl>
template.

=cut

sub remove_developer {
    my $self      = shift;
    my $query     = $self->query;
    my $project   = Smolder::DB::Project->retrieve( $query->param('project') );
    my $developer = Smolder::DB::Developer->retrieve( $query->param('developer') );

    if ( $developer && $project ) {
        Smolder::DB::ProjectDeveloper->retrieve(
            developer => $developer,
            project   => $project,
        )->delete();
        Smolder::DB->dbi_commit();

        $self->add_message(
            msg => "Developer '" . $developer->username 
                . "' has been removed from project '" . $project->name . "'."
        );
    }

    return $self->tt_process( 'Admin/Projects/project_container.tmpl', { project => $project } );
}

=head2 edit

Edit the information about a project. Uses the F<Admin/Projects/edit.tmpl>
template.

=cut

sub edit {
    my ( $self, $err_msgs ) = @_;
    my $query = $self->query;
    my $output;
    my $project = Smolder::DB::Project->retrieve( $self->param('id') );

    my %tt_params = ( project => $project, );

    # if we have any error messages, then just re-fill the form
    # and show them
    if ($err_msgs) {
        $output = HTML::FillInForm->new->fill(
            scalarref => $self->tt_process( { %$err_msgs, %tt_params } ),
            qobject   => $query,
        );

        # else fill in the data with the project's innards
    } else {
        my %project_data = (
            id           => $project->id,
            project_name => $project->name,
            start_date   => $project->start_date->strftime('%m/%d/%Y'),
            public       => $project->public,
            enable_feed  => $project->enable_feed,
        );
        $output = HTML::FillInForm->new->fill(
            scalarref => $self->tt_process( \%tt_params ),
            fdat      => \%project_data,
        );
    }
    return $output;
}

=head2 list

Show a list of the current projects. Uses the F<Admin/Projects/list.tmpl>
template.

=cut

sub list {
    my $self     = shift;
    my @projects = Smolder::DB::Project->retrieve_all();
    my %tt_params;
    $tt_params{projects} = \@projects if (@projects);

    if ( $self->query->param('table_only') ) {
        return $self->tt_process( 'Admin/Projects/list_table.tmpl', \%tt_params, );
    } else {
        return $self->tt_process( \%tt_params );
    }
}

=head2 add

Show the form to add a new project. Uses the C<Admin/Projects/add.tmpl>
template.

=cut

sub add {
    my ( $self, $tt_params ) = @_;
    $tt_params ||= {};
    return $self->tt_process($tt_params);
}

=head2 process_add

Process the incoming data from both the C<add> and C<edit> modes. Updates
the database if validation passes and then uses either the 
F<Admin/Projects/add_success.tmpl> or F<Admin/Projects/edit_success.tmpl>
templates.

=cut

sub process_add {
    my $self = shift;
    my $id   = $self->param('id');
    my $form = {
        required           => [qw(project_name start_date public enable_feed)],
        constraint_methods => {
            project_name => [ length_max(255), unique_field_value( 'project', 'name', $id ), ],
            start_date   => to_datetime('%m/%d/%Y'),
            public       => bool(),
            enable_feed  => bool(),
        },
    };

    my $results = $self->check_rm( ( $id ? 'edit' : 'add' ), $form )
      || return $self->check_rm_error_page;
    my $valid = $results->valid();
    $valid->{name} = delete $valid->{project_name};

    my ( $project, $action );

    # if we're editing
    if ($id) {
        $action  = 'edit';
        $project = Smolder::DB::Project->retrieve($id);
        return $self->error_message("Project no longer exists!")
          unless $project;
        $project->set(%$valid);
        $project->update;

        # else we're adding a new one
    } else {
        $action = 'add';

        # we need to eval{} since there is a small race condition
        # that it could contain a duplicate name
        eval { $project = Smolder::DB::Project->create($valid) };
    }

    # if there was a problem.
    if ($@) {

        # if it was a duplicate project name, then we can handle that
        if ( $DB_PLATFORM->unique_failure_msg($@) ) {
            return $self->add( { err_unique_project_name => 1 } );

            # else it's something else, so just throw it again
        } else {
            die $@;
        }
    }
    Smolder::DB->dbi_commit();

    # now show the project's success message
    my $msg = $id ?  "Project '" . $project->name . "' successfully updated."
        : "New project '" . $project->name . "' successfully created.";
    $self->add_message(msg => $msg);
    return $self->add_json_header(list_changed => 1);
}

=head2 details

Show the details about a project. Uses the F<Admin/Projects/details.tmpl>
template.

=cut

sub details {
    my ( $self, $project, $action ) = @_;
    my $new;

    # if we weren't given a project, then get it from the URL
    if ( !$project ) {
        $new = 0;
        my $id = $self->param('id');
        $project = Smolder::DB::Project->retrieve($id);
        return $self->error_message("Can't find Project with id '$id'!") unless $project;
    } else {
        $new = 1;
    }

    my %tt_params = ( project => $project );
    $tt_params{$action} = 1 if ($action);
    return $self->tt_process( \%tt_params );
}

=head2 delete

Delete a project and all information associated with it. If successful
returns to the C<list> run mode.

=cut

sub delete {
    my $self    = shift;
    my $id      = $self->param('id');
    my $project = Smolder::DB::Project->retrieve($id);

    if ($project) {

        # remove all files associated with test reports for this project
        # TODO - consider moving this into a trigger
        my @smokes = $project->smoke_reports();
        $_->delete_files foreach (@smokes);

        my $project_name = $project->name;
        $project->delete();
        Smolder::DB->dbi_commit();
        $self->add_message(msg => "Project '$project_name' successfully deleted.");
    }

    $self->query->param(table_only => 1);
    return $self->list();
}

1;
