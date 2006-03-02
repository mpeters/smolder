package Smolder::Control::Developer::Prefs;
use base 'Smolder::Control';
use strict;
use warnings;
use Smolder::Constraints qw(pref_email_type pref_email_freq length_between);

sub setup {
    my $self = shift;
    $self->start_mode('show_all');
    $self->run_modes([qw(
        show_all
        update_pref
        change_pw
        process_change_pw
    )]);
}

sub process_change_pw {
    my $self = shift;
    my $dev = $self->developer;
    
    # validate the incoming info
    my $form = {
        required            => [qw(current_pw new_pw new_pw_retyped)],
        constraint_methods  => {
            # make sure it's the right encrypted pw
            current_pw     => sub {
                my ($dfv, $val) = @_;
                if( crypt($val, $dev->password) eq $dev->password ) {
                    return $val;
                } else {
                    return;
                }
            },
            # make sure it's long enough (but not too long)
            new_pw         => length_between(4, 255),
            # make sure it's the same as 'new_pw'
            new_pw_retyped => sub {
                my ($dfv, $val) = @_;
                # get the value of 'new_pw'
                my $data = $dfv->get_input_data( as_hashref => 1 );
                if( $data->{new_pw} eq $val ) {
                    return $val
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
    Smolder::DB->dbi_commit();
    return $self->change_pw({ success => 1 });
}

sub change_pw {
    my ($self, $tt_params) = @_;
    $tt_params ||= {};
    return $self->tt_process($tt_params);
}

sub show_all {
    my $self = shift;
    return $self->tt_process({});
}

sub show_pref {
    my ($self, $tt_params) = @_;
    $tt_params ||= {};
    return $self->tt_process('Developer/Prefs/pref_form.tmpl', $tt_params);
}

sub update_pref {
    my $self = shift;
    
    # validate the data
    my $form = {
        required            => [qw(email_type email_freq)],
        optional            => [qw(project)],
        constraint_methods  => {
            email_type  => pref_email_type(),
            email_freq  => pref_email_freq(),
            project     => qr/^\d+$/,
        }
    };

    my $results = $self->check_rm('show_pref', $form)
        || return $self->check_rm_error_page();
    my $valid = $results->valid();

    my ($pref, $project);
    # if we have a project, then we want that specific pref
    if( $valid->{project} ) {
        $project = Smolder::DB::Project->retrieve( delete $valid->{project});
        return $self->error_msg('Project no longer exists!') unless $project;

        $pref = $self->developer->project_pref($project);
    # else we want the default pref
    } else {
        $pref = $self->developer->preference;
    }

    # now update
    $pref->set(%$valid);
    $pref->update();
    Smolder::DB->dbi_commit();

    return $self->show_pref({
        project => $project,
        pref    => $pref,
        success => 1,
    });
}


1;
