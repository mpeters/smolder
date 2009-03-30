package Smolder::Control::Developer::Prefs;
use base 'Smolder::Control';
use strict;
use warnings;
use Smolder::Constraints qw(enum_value length_between unsigned_int existing_field_value);

=head1 NAME

Smolder::Control::Developer::Prefs

=head1 DESCRIPTION

Controller module for dealing with developer preferences

=cut

sub setup {
    my $self = shift;
    $self->start_mode('show');
    $self->run_modes(
        [
            qw(
              show
              update_pref
              change_pw
              process_change_pw
              get_pref_details
              )
        ]
    );
}

sub require_group { 'developer' }

=head1 RUN MODES

=head2 change_pw

Show the form to allow a developer to change their password. Uses the
F<Developer/Prefs/change_pw.tmpl> template.

=cut

sub change_pw {
    my ($self, $tt_params) = @_;
    $tt_params ||= {};
    return $self->tt_process($tt_params);
}

=head2 process_change_pw

Handled the incoming data from the C<change_pw> run mode. If
it passes validation then it updates the database and then returns
to the C<change_pw> mode.

=cut

sub process_change_pw {
    my $self = shift;
    my $dev  = $self->developer;

    # validate the incoming info
    my $form = {
        required           => [qw(current_pw new_pw new_pw_retyped)],
        constraint_methods => {

            # make sure it's the right encrypted pw
            current_pw => sub {
                my ($dfv, $val) = @_;
                if (crypt($val, $dev->password) eq $dev->password) {
                    return $val;
                } else {
                    return;
                }
            },

            # make sure it's long enough (but not too long)
            new_pw => length_between(4, 255),

            # make sure it's the same as 'new_pw'
            new_pw_retyped => sub {
                my ($dfv, $val) = @_;

                # get the value of 'new_pw'
                my $data = $dfv->get_input_data(as_hashref => 1);
                if ($data->{new_pw} eq $val) {
                    return $val;
                } else {
                    return;
                }
            },
        },
    };

    my $results = $self->check_rm('change_pw', $form)
      || return $self->check_rm_error_page();
    my $valid = $results->valid();

    $dev->password($valid->{new_pw});
    $dev->update();
    $self->add_message(msg => "Password successfully changed.");
    return $self->change_pw();
}

=head2 show

Show all of the preferences for each project that this developer is assigned to.
Uses the F<Developer/Prefs/show.tmpl> template.

=cut

sub show {
    my ($self, $tt_params, $pref) = @_;
    $tt_params ||= {};
    my $html = $self->tt_process($tt_params);

    # if this wasn't an update form submission
    # and we don't have a preference, then make it the default
    if (!$self->query->param('update_pref') && !$pref) {
        $pref = $self->developer->preference;
    }

    # if we have a preference use it to fill in the form
    if ($pref) {
        my %fill_data = map { $_ => $pref->$_ } qw(id email_type email_freq email_limit);
        return HTML::FillInForm->new()->fill(
            scalarref => $html,
            fdat      => \%fill_data,
        );
    } else {
        return $html;
    }
}

=head2 get_pref_details

This run mode will return a JSON header which contains the name-value
pairs for this preferences data.

=cut

sub get_pref_details {
    my $self = shift;
    my $pref = Smolder::DB::Preference->retrieve($self->query->param('id'));
    my %data;
    if ($pref) {
        %data = map { $_ => $pref->$_ } qw(email_type email_freq email_limit);
    }

    return $self->add_json_header(%data);
}

=head2 update_pref

Update the information coming from the C<show> run mode.
If validation passes, the database is updated and the C<show>
run mode is returned.

=cut

sub update_pref {
    my $self = shift;

    # validate the data
    my $form = {
        required           => [qw(id email_type email_freq email_limit)],
        constraint_methods => {
            id          => existing_field_value('preference', 'id'),
            email_type  => enum_value('preference',           'email_type'),
            email_freq  => enum_value('preference',           'email_freq'),
            email_limit => unsigned_int(),
        }
    };

    my $results = $self->check_rm('show', $form)
      || return $self->check_rm_error_page();
    my $valid = $results->valid();

    my $pref = Smolder::DB::Preference->retrieve($valid->{id});
    if ($pref) {
        delete $valid->{id};
        $pref->set(%$valid);
        $pref->update();

        # is this the default pref?
        if ($pref->id eq $self->developer->preference) {
            $self->add_message(msg => "Default preferences successfully updated.");
        } else {
            $self->add_message(msg => "Preference for project '"
                  . $pref->project->name
                  . "' has been successfully updated'");
        }
    }

    # if we are updating the default pref and they want to sync them
    if ($self->query->param('sync') && ($pref->id eq $self->developer->preference)) {
        my @projs = $self->developer->project_developers;
        foreach my $proj (@projs) {
            $proj->preference->set(%$valid);
            $proj->preference->update();
        }
        $self->add_message(msg => "Preferences have been successfully synced with all Projects.");
    }
    return $self->show({}, $pref);
}

1;
