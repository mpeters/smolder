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
              process_delete
              developers
              add_developer
              remove_developer
              change_admins
              )
        ]
    );
}

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

    return $self->tt_process( 'Admin/Projects/project_container.tmpl', { project => $project }, );
}

sub developers {
    my ( $self, $tt_params ) = @_;
    $tt_params ||= {};
    my @developers = Smolder::DB::Developer->retrieve_all();
    my @projects   = Smolder::DB::Project->retrieve_all();

    $tt_params->{developers} = \@developers if (@developers);
    $tt_params->{projects}   = \@projects   if (@projects);
    return $self->tt_process($tt_params);
}

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
            die $@ unless $@ =~ /Duplicate entry/i;
        } else {
            Smolder::DB->dbi_commit();
        }
    }

    return $self->tt_process( 'Admin/Projects/project_container.tmpl', { project => $project, } );
}

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
    }

    return $self->tt_process( 'Admin/Projects/project_container.tmpl', { project => $project } );
}

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
            start_date   => $project->start_date->strftime('%d/%m/%Y'),
            public       => $project->public,
        );
        $output = HTML::FillInForm->new->fill(
            scalarref => $self->tt_process( \%tt_params ),
            fdat      => \%project_data,
        );
    }
    return $output;
}

sub list {
    my ( $self, $action ) = @_;
    my @projects = Smolder::DB::Project->retrieve_all();
    my %tt_params;
    $tt_params{projects} = \@projects if (@projects);
    $tt_params{$action} = 1 if ($action);
    return $self->tt_process( \%tt_params );
}

sub add {
    my ( $self, $tt_params ) = @_;
    $tt_params ||= {};
    return $self->tt_process($tt_params);
}

sub process_add {
    my $self = shift;
    my $id   = $self->param('id');
    my $form = {
        required           => [qw(project_name start_date public)],
        constraint_methods => {
            project_name => [ length_max(255), unique_field_value( 'project', 'name', $id ), ],
            start_date   => to_datetime('%m/%d/%Y'),
            public       => bool(),
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
        if ( $@ =~ /Duplicate entry/ ) {
            return $self->add( { err_unique_project_name => 1 } );

            # else it's something else, so just throw it again
        } else {
            die $@;
        }
    }

    Smolder::DB->dbi_commit();

    # now show the project's details page
    return $self->details( $project, $action );
}

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

sub delete {
    my $self    = shift;
    my $id      = $self->param('id');
    my $project = Smolder::DB::Project->retrieve($id);
    return $self->error_message("Can't find Project with id '$id'!") unless $project;

    return $self->tt_process( { project => $project, } );
}

sub process_delete {
    my $self    = shift;
    my $id      = $self->param('id');
    my $project = Smolder::DB::Project->retrieve($id);

    if ($project) {

        # remove all files associated with test reports for this project
        # TODO - consider moving this into a trigger
        my @smokes = $project->smoke_reports();
        $_->delete_files foreach (@smokes);

        $project->delete();
        Smolder::DB->dbi_commit();

    }
    return $self->list('delete');
}

1;
