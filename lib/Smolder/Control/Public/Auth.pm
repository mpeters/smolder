package Smolder::Control::Public::Auth;
use strict;
use base 'Smolder::Control';
use Smolder::AuthInfo;
use Smolder::DB::Developer;
use Smolder::DB;
use Smolder::Email;
use HTML::FillInForm;
use Apache::Cookie;

our $HOME_PAGE_URL = "/app/developer";

sub setup {
    my $self = shift;
    $self->start_mode('login');
    $self->run_modes(
        [
            qw(
              login
              process_login
              logout
              show_logout
              forgot_pw
              process_forgot_pw
              timeout
              forbidden
              )
        ]
    );
}

sub login {
    my ( $self, $tt_params ) = @_;
    if ($tt_params) {
        return $self->tt_process($tt_params);
    } else {
        return HTML::FillInForm->new()->fill(
            scalarref => $self->tt_process( {} ),
            fobject   => $self->query,
        );
    }
}

sub process_login {
    my $self    = shift;
    my $form    = { required => [qw(username password)], };
    my $results = $self->check_rm( 'login', $form )
      || return $self->check_rm_error_page();

    my ( $user, $pw ) = ( $results->valid('username'), $results->valid('password') );

    # see if we have a user with this password
    my ($dev) = Smolder::DB::Developer->search( username => $user );
    if ($dev) {

        # check to see if the password matches the encrypted one
        if ( crypt( $pw, $dev->password ) eq $dev->password ) {

            # figure out which tokens to add
            my @tokens = ('developer');
            push( @tokens, 'admin' ) if ( $dev->admin );

            my $at = Smolder::AuthInfo->new();

            # now add the AuthTKT cookie going out
            my $cookie = $at->cookie(
                uid    => $dev->id,
                tokens => join( ',', @tokens ),
            );
            $self->header_add( -cookie => [$cookie] );

            # url of where to go next
            my $url = $self->query->param('back') || $HOME_PAGE_URL;
            $self->header_type('redirect');
            $self->header_add( -uri => $url );
            Smolder::DB->dbi_commit();
            return "Redirecting to '$url'";
        }
    }

    # if we got here then something failed
    return $self->login( { validation_failed => 1 } );
}

sub forgot_pw {
    my ( $self, $tt_params ) = @_;
    $tt_params ||= {};
    return $self->tt_process($tt_params);
}

sub process_forgot_pw {
    my $self = shift;
    my ($developer) = Smolder::DB::Developer->search( username => $self->query->param('username') );
    my $tt_params = {};
    if ($developer) {
        my $new_pw = $developer->reset_password();
        Smolder::DB->dbi_commit();

        # send an email with the new password
        my $error = Smolder::Email->send_mime_mail(
            name      => 'forgot_pw',
            to        => $developer->email,
            subject   => 'Forgot your password',
            tt_params => {
                developer => $developer,
                new_pw    => $new_pw,
            },
        );

        warn "\n\nNEW PASSWORD FOR DEVELOPER #"
          . $developer->id . " ("
          . $developer->username
          . ") is '$new_pw'\n\n";
        $tt_params->{success} = 1;
        $tt_params->{email}   = $developer->email;
    } else {
        $tt_params->{not_found} = 1;
    }
    return $self->forgot_pw($tt_params);
}

sub logout {
    my ( $self, $tt_params ) = @_;
    $tt_params ||= {};

    # remove their auth cookie
    my $at = Smolder::AuthInfo->new();

    # now add the AuthTKT cookie going out
    my $cookie = Apache::Cookie->new(
        $self->param('r'),
        -name    => 'auth_tkt',
        -value   => '',
        -expires => '-1d',
    );
    $self->header_add( -cookie => [$cookie] );
    $self->header_type('redirect');
    $self->header_add( -uri => '/app/public_auth/show_logout' );
    return "Redirecting to '/app/public_auth/show_logout'.";
}

sub show_logout {
    my ( $self, $tt_params ) = @_;
    $tt_params ||= {};
    return $self->tt_process($tt_params);
}

sub timeout {
    my ( $self, $tt_params ) = @_;
    if ($tt_params) {
        return $self->tt_process($tt_params);
    } else {
        return HTML::FillInForm->new()->fill(
            scalarref => $self->tt_process( {} ),
            fobject   => $self->query,
        );
    }
}

sub forbidden {
    my ( $self, $tt_params ) = @_;
    if ($tt_params) {
        return $self->tt_process($tt_params);
    } else {
        return HTML::FillInForm->new()->fill(
            scalarref => $self->tt_process( {} ),
            fobject   => $self->query,
        );
    }
}

1;
