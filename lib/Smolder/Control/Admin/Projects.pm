package Smolder::Control::Admin::Projects;
use strict;
use warnings;
use base 'Smolder::Control';
use Data::FormValidator::Constraints::DateTime qw(to_datetime);
use Smolder::DB::Project;
use Smolder::DB::Developer;
use Smolder::DB::ProjectDeveloper;
use Smolder::Constraints qw(
  length_max
  unsigned_int
  bool
  unique_field_value
  existing_field_value
);

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
              devs
              add_dev
              remove_dev
              change_admin
              )
        ]
    );
}

sub require_group { 'admin' }

=head1 RUN MODES

=head2 change_admin

Change the project admin status for a developer within a project.

=cut

sub change_admin {
    my $self    = shift;
    my $query   = $self->query;
    my $project = Smolder::DB::Project->retrieve($query->param('project'));
    return $self->error_message("Project does not exist!") unless $project;

    my $dev = Smolder::DB::Developer->retrieve($query->param('developer'));
    return $self->error_message("Project does not exist!") unless $dev;

    # clear out the old admins
    if ($query->param('remove')) {
        $project->clear_admins($dev->id);
        $self->add_message(msg => "Successfully removed developer '"
              . $dev->username
              . "' as an admin of '"
              . $project->name
              . "'.");
    } else {
        $project->set_admins($dev->id);
        $self->add_message(msg => "Successfully made developer '"
              . $dev->username
              . "' an admin of '"
              . $project->name
              . "'.");
    }
    return;
}

=head2 devs

Shows a list of developers that can be assigned to this
project and any developers currently assigned to this project
for editing.

Uses the F<Admin/Projects/devs.tmpl> template.

=cut

sub devs {
    my ($self, $tt_params, $proj) = @_;
    $tt_params ||= {};
    $proj ||= Smolder::DB::Project->retrieve($self->param('id') || $self->query->param('project'));
    my @devs = Smolder::DB::Developer->search(guest => 0);
    my @proj_devs = $proj->developers;

    # only show developers that aren't in this project
    my %devs_in_project = map { $_->id => 1 } @proj_devs;
    @devs = grep { !$devs_in_project{$_->id} } @devs;

    $tt_params = {
        developers         => \@devs,
        project            => $proj,
        project_developers => \@proj_devs,
        %$tt_params,
    };
    return $self->tt_process($tt_params);
}

=head2 add_dev

Add a developer to a project. Returns the C<dev> run mode when done.

=cut

sub add_dev {
    my $self  = shift;
    my $query = $self->query;
    my $proj  = Smolder::DB::Project->retrieve($query->param('project'));
    my $dev   = Smolder::DB::Developer->retrieve($query->param('developer'));

    if ($dev && $proj) {
        my $proj_pref = $dev->preference->copy;
        eval {
            my $proj_dev = Smolder::DB::ProjectDeveloper->create(
                {
                    project    => $proj,
                    developer  => $dev,
                    preference => $proj_pref,
                }
            );
        };
        if ($@) {
            my $err = $@;
            $proj_pref->delete if $proj_pref;
            die $err unless Smolder::DB->unique_failure_msg($err);
        } else {
            $self->add_message(msg => "Developer '"
                  . $dev->username
                  . "' has been added to project '"
                  . $proj->name
                  . "'.");
        }
    }

    $self->add_json_header(update_nav => 1) if $dev->id == $self->developer->id;
    return $self->devs({}, $proj);
}

=head2 remove_dev

Remove a developer from a project. Returns the C<dev> run mode
when done.

=cut

sub remove_dev {
    my $self  = shift;
    my $query = $self->query;
    my $proj  = Smolder::DB::Project->retrieve($query->param('project'));
    my $dev   = Smolder::DB::Developer->retrieve($query->param('developer'));

    if ($dev && $proj) {
        Smolder::DB::ProjectDeveloper->retrieve(
            developer => $dev,
            project   => $proj,
        )->delete();

        $self->add_message(msg => "Developer '"
              . $dev->username
              . "' has been removed from project '"
              . $proj->name
              . "'.");
    }

    $self->add_json_header(update_nav => 1) if $dev->id == $self->developer->id;
    return $self->devs({}, $proj);
}

=head2 edit

Edit the information about a project. Uses the F<Admin/Projects/edit.tmpl>
template.

=cut

sub edit {
    my ($self, $err_msgs) = @_;
    my $query = $self->query;
    my $output;
    my $project = Smolder::DB::Project->retrieve($self->param('id'));

    my %tt_params = (project => $project, edit => 1);

    # if we have any error messages, then just re-fill the form
    # and show them
    if ($err_msgs) {
        $output = HTML::FillInForm->new->fill(
            scalarref => $self->tt_process("Admin/Projects/add.tmpl", {%$err_msgs, %tt_params}),
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
            max_reports  => $project->max_reports,
            extra_css    => $project->extra_css,
        );
        $output = HTML::FillInForm->new->fill(
            scalarref => $self->tt_process("Admin/Projects/add.tmpl", \%tt_params),
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
    my @projects = Smolder::DB::Project->retrieve_all_sorted_by('name');
    my %tt_params;
    $tt_params{projects} = \@projects if (@projects);

    return $self->tt_process(\%tt_params);
}

=head2 add

Show the form to add a new project. Uses the C<Admin/Projects/add.tmpl>
template.

=cut

sub add {
    my ($self, $tt_params) = @_;
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
        required           => [qw(project_name start_date public enable_feed max_reports)],
        optional           => [qw(extra_css)],
        constraint_methods => {
            project_name => [length_max(255), unique_field_value('project', 'name', $id),],
            start_date   => to_datetime('%m/%d/%Y'),
            public       => bool(),
            enable_feed  => bool(),
            max_reports  => unsigned_int(),
        },
    };

    my $results = $self->check_rm(($id ? 'edit' : 'add'), $form)
      || return $self->check_rm_error_page;
    my $valid = $results->valid();
    $valid->{name} = delete $valid->{project_name};

    my ($project, $action);

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
        if (Smolder::DB->unique_failure_msg($@)) {
            return $self->add({err_unique_project_name => 1});

            # else it's something else, so just throw it again
        } else {
            die $@;
        }
    }

    # now show the project's success message
    if( $id ) {
        $self->add_message(msg => "Project '" . $project->name . "' successfully updated.");
    } else {
        $self->add_message(msg => "New project '" . $project->name . "' successfully created.");
    }
    return $self->add_json_header(list_changed => 1, update_nav => 1);
}

=head2 details

Show the details about a project. Uses the F<Admin/Projects/details.tmpl>
template.

=cut

sub details {
    my ($self, $project, $action) = @_;
    my $new;

    # if we weren't given a project, then get it from the URL
    if (!$project) {
        $new = 0;
        my $id = $self->param('id');
        $project = Smolder::DB::Project->retrieve($id);
        return $self->error_message("Can't find Project with id '$id'!") unless $project;
    } else {
        $new = 1;
    }

    my %tt_params = (project => $project);
    $tt_params{$action} = 1 if ($action);
    return $self->tt_process(\%tt_params);
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
        $self->add_message(msg => "Project '$project_name' successfully deleted.");
    }

    return $self->list();
}

1;
