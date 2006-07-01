package Smolder::Control::Developer::Prefs;
use base 'Smolder::Control';
use strict;
use warnings;
use Smolder::Constraints qw(enum_value length_between);

=head1 NAME

Smolder::Control::Developer::Prefs

=head1 DESCRIPTION

Controller module for dealing with developer preferences

=cut

sub setup {
    my $self = shift;
    $self->start_mode('show_all');
    $self->run_modes(
        [
            qw(
              show_all
              update_pref
              change_pw
              process_change_pw
              )
        ]
    );
}

=head1 RUN MODES

=head2 change_pw

Show the form to allow a developer to change their password. Uses the
F<Developer/Prefs/change_pw.tmpl> template.

=cut

sub change_pw {
    my ( $self, $tt_params ) = @_;
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
                my ( $dfv, $val ) = @_;
                if ( crypt( $val, $dev->password ) eq $dev->password ) {
                    return $val;
                } else {
                    return;
                }
            },

            # make sure it's long enough (but not too long)
            new_pw => length_between( 4, 255 ),

            # make sure it's the same as 'new_pw'
            new_pw_retyped => sub {
                my ( $dfv, $val ) = @_;

                # get the value of 'new_pw'
                my $data = $dfv->get_input_data( as_hashref => 1 );
                if ( $data->{new_pw} eq $val ) {
                    return $val;
                } else {
                    return;
                }
            },
        },
    };

    my $results = $self->check_rm( 'change_pw', $form )
      || return $self->check_rm_error_page();
    my $valid = $results->valid();

    $dev->password( $valid->{new_pw} );
    $dev->update();
    Smolder::DB->dbi_commit();
    return $self->change_pw( { success => 1 } );
}

=head2 show_all

Show all of the preferences for each project that this developer is assigned to.
Uses the F<Developer/Prefs/show_all.tmpl> template.

=cut

sub show_all {
    my ($self, $tt_params) = @_;
    $tt_params ||= {};
    return $self->tt_process($tt_params);
}

=head2 show_pref

Show an the preferences form for an individual project for this developer.
Uses the F<Developer/Prefs/pref_form.tmpl> template.

=cut

sub show_pref {
    my ( $self, $tt_params ) = @_;
    $tt_params ||= {};

    return $self->tt_process( 'Developer/Prefs/pref_form.tmpl', $tt_params );
}

=head2 update_pref

Update the information coming from either the C<show_all> or C<show_pref>
modes. If validation passes, the database is updated and the C<show_pref>
run mode is returned.

=cut

sub update_pref {
    my $self = shift;

    # validate the data
    my $form = {
        required           => [qw(email_type email_freq email_limit)],
        optional           => [qw(project)],
        constraint_methods => {
            email_type  => enum_value('preference', 'email_type'),
            email_freq  => enum_value('preference', 'email_freq'),
            project     => qr/^\d+$/,
            email_limit => qr/^\d+$/,
        }
    };

    my $results = $self->check_rm( 'show_pref', $form )
      || return $self->check_rm_error_page();
    my $valid = $results->valid();

    my ( $pref, $project, $sync, $default );

    # if we have a project, then we want that specific pref
    if ( $valid->{project} ) {
        $project = Smolder::DB::Project->retrieve( delete $valid->{project} );
        return $self->error_msg('Project no longer exists!') unless $project;

        $pref = $self->developer->project_pref($project);

        # else we want the default pref
    } else {
        $default = 1;
        $pref = $self->developer->preference;
        # do they also want to sync their projects?
        $sync = 1 if( $self->query->param('sync') );
    }

    # now update
    $pref->set(%$valid);
    $pref->update();
    Smolder::DB->dbi_commit();

    # if we need to sync the other prefs
    if( $sync ) {
        my @projs = $self->developer->project_developers;
        foreach my $proj (@projs) {
            $proj->preference->set(%$valid);
            $proj->preference->update();
        }
        Smolder::DB->dbi_commit();
        return $self->show_all( { sync_success => 1 })
    } else {
        return $self->show_pref(
            {
                project => $project,
                pref    => $pref,
                success => 1,
                default => $default,
            }
        );
    }
}

1;
