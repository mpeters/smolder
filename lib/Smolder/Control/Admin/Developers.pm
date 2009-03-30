package Smolder::Control::Admin::Developers;
use strict;
use warnings;
use base 'Smolder::Control';
use Smolder::DB::Project;
use Smolder::DB::Developer;
use Smolder::Email;
use Smolder::Constraints qw(email unsigned_int length_max length_between bool unique_field_value);
use Email::Valid;

=head1 NAME

Smolder::Control::Admin::Developers

=head1 DESCRIPTION

Controller module for Admin activities concerning Developers

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
              process_edit
              list
              delete
              reset_pw
              details
              )
        ]
    );
}

sub require_group { 'admin' }

=head1 RUN MODES

=head2 reset_pw

Allow an admin to reset the password of a developer to a new random string
and then email the new password to the developer. Uses the F<Email/reset_pw.tmpl>
template for the email and the F<Admin/Developers/resetpw_success.tmpl> for
displaying the result.

=cut

sub reset_pw {
    my $self = shift;
    my $dev  = Smolder::DB::Developer->retrieve($self->param('id'));
    return $self->error_message("Developer no longer exists!")
      unless $dev;

    my $email  = $dev->email;
    my $user   = $dev->username;
    my $new_pw = $dev->reset_password();

    # send the email
    my $error = Smolder::Email->send_mime_mail(
        name      => 'reset_pw',
        to        => $email,
        subject   => 'Reset of password by Admin',
        tt_params => {
            developer => $dev,
            new_pw    => $new_pw,
        },
    );
    if ($error) {
        $self->add_message(
            msg  => "Could not send email to '$user'. Please check error logs!",
            type => 'warning',
        );
        $self->log->warning("Could not send 'reset_pw' email to $email - $error");
    } else {
        $self->add_message(msg =>
              "Password for '$user' has been reset and an email sent with their new password.");
    }
    return ' ';
}

=head2 edit 

Show the edit form to allow an admin to edit the data about a developer.
Uses the F<Admin/Developers/edit.tmpl> template.

=cut

sub edit {
    my ($self, $err_msgs) = @_;
    my $developer = Smolder::DB::Developer->retrieve($self->param('id'));
    my $output;

    # if we have any error messages, then just re-fill the form
    # and show them
    if ($err_msgs) {
        $err_msgs->{developer} = $developer;
        $output = HTML::FillInForm->new->fill(
            scalarref => $self->tt_process($err_msgs),
            qobject   => $self->query,
        );

        # else get the developer in question
    } else {
        my %developer_data = $developer->vars();
        $output = HTML::FillInForm->new->fill(
            scalarref => $self->tt_process({developer => $developer}),
            fdat      => \%developer_data,
        );
    }
    return $output;
}

=head2 process_edit

Processes the incoming data from the C<edit> mode and update the
developers info in the database if validation passes. Uses the
F<Admin/Developers/edit_success.tmpl> template.

=cut

sub process_edit {
    my $self = shift;
    my $id   = $self->param('id');
    my $form = {
        required           => [qw(username fname lname email admin)],
        constraint_methods => {
            username => [length_max(255), unique_field_value('developer', 'username', $id),],
            fname    => length_max(255),
            lname    => length_max(255),
            email    => email(),
            admin    => bool(),
        },
    };

    my $results = $self->check_rm('edit', $form)
      || return $self->check_rm_error_page;
    my $valid = $results->valid();

    my $developer = Smolder::DB::Developer->retrieve($id);
    return $self->error_message("Developer no longer exists!")
      unless $developer;
    $developer->set(%$valid);

    # we need to eval{} since we don't want there to be duplicate usernames (id)
    eval { $developer->update };

    # if there was a problem.
    if ($@) {

        # if it was a duplicate developer, then we can handle that
        if (Smolder::Conf->unique_failure_msg($@)) {
            return $self->edit({err_unique_username => 1});

            # else it's something else, so just throw it again
        } else {
            die $@;
        }
    }

    # now show the successful message
    $self->add_message(msg => "User '" . $developer->username . "' has been successfully updated.");
    return $self->add_json_header(list_changed => 1);
}

=head2 list

Show a list of all developers. Uses the F<Admin/Developers/list_table.tmpl>
template.

=cut

sub list {
    my $self       = shift;
    my $cgi        = $self->query();
    my @developers = Smolder::DB::Developer->search(guest => 0);

    my %tt_params;
    $tt_params{developers} = \@developers if (@developers);

    return $self->tt_process(\%tt_params);
}

=head2 add

Show the add form for adding a new developer. Uses the 
F<Admin/Developers/add.tmpl> template.

=cut

sub add {
    my ($self, $tt_params) = @_;
    $tt_params ||= {};
    return $self->tt_process($tt_params);
}

=head2 process_add

Process the incoming data from the C<add> mode and add it to the
database if validation passes. Uses the F<Admin/Developers/add_success.tmpl>.

=cut

sub process_add {
    my $self = shift;
    my $form = {
        required           => [qw(username email password admin)],
        optional           => [qw(fname lname)],
        constraint_methods => {
            username => [length_max(255), unique_field_value('developer', 'username'),],
            fname    => length_max(255),
            lname    => length_max(255),
            email    => email(),
            password => length_between(4, 255),
            admin    => bool(),
        },
    };

    my $results = $self->check_rm('add', $form)
      || return $self->check_rm_error_page;
    my $valid = $results->valid();

    # create a new preference for this developer;
    my $pref = Smolder::DB::Preference->create();
    $valid->{preference} = $pref;
    my $developer;

    # we need to eval{} since we don't want there to be duplicate usernames
    eval { $developer = Smolder::DB::Developer->create($valid) };

    # if there was a problem.
    if ($@) {

        # if it was a duplicate developer, then we can handle that
        if (Smolder::Conf->unique_failure_msg($@)) {
            return $self->add({err_unique_username => 1});

            # else it's something else, so just throw it again
        } else {
            die $@;
        }
    }

    # now show the successful message
    $self->add_message(msg => "New user '" . $developer->username . "' successfully created.");
    return $self->add_json_header(list_changed => 1);
}

=head2 delete 

Delete a Developer and all data associated with him. If
successful returns the C<list> mode.

=cut

sub delete {
    my $self      = shift;
    my $id        = $self->param('id');
    my $developer = Smolder::DB::Developer->retrieve($id);

    if ($developer) {

        # remove all reports from this developer
        my @smokes = $developer->smoke_reports();
        foreach my $smoke (@smokes) {
            $smoke->delete_files();
        }

        my $username = $developer->username;
        $developer->delete();
        $self->add_message(msg => "User '$username' has been successfully deleted.");
    }

    return $self->list();
}

=head2 details

Show the details of a developer. Uses the F<Admin/Developers/details.tmpl>
template.

=cut

sub details {
    my ($self, $developer, $action) = @_;
    my $new;

    # if we weren't given a developer, then get it from the query string
    if (!$developer) {
        my $id = $self->param('id');
        $new       = 0;
        $developer = Smolder::DB::Developer->retrieve($id);
        return $self->error_message("Can't find Developer with id '$id'!") unless $developer;
    } else {
        $new = 1;
    }

    my %tt_params = (developer => $developer);
    $tt_params{$action} = 1 if ($action);

    return $self->tt_process(\%tt_params);
}

1;
