package Smolder::Mech;
use strict;
use warnings;
use base 'Test::WWW::Mechanize';
use Smolder::Conf;
use Smolder::TestData qw(base_url);
use JSON qw(from_json);
use Test::Builder;
use Test::More;

=head1 NAME 

Smolder::Mech

=head1 DESCRIPTION

L<Test::WWW::Mechanize> subclass with some Smolder specific
helper methods

    my $mech = Smolder::Mech->new();
    $mech->login($user);

=head1 METHODS

=head2 login

This routine will go to the login form, provide credentials
and login. It receives the following named args, all required:

=over

=item username

The text to use for the username field

=item password

The text to use for the password field. If none is given, it will use
'testing'.

=back

    $mech->login(
        username    => $username,
        password    => 's3cr3t',
    );

=cut

sub login {
    my $self = shift;
    my %args = @_;
    my $url  = base_url() . '/public_auth/login';
    $self->get($url);
    $self->form_name('login');
    $self->set_fields(
        username => $args{username},
        password => $args{password},
    );
    $self->submit();
}

=head2 logout

Logout the current user.

    $mech->logout();

=cut

sub logout {
    my $self = shift;
    my $url  = base_url() . '/public_auth/logout';
    $self->get($url);
}

=head1 get

Extends C<get()> from L<Test::WWW::Mechanize> to also disconnect
any open Database handles before making a request if we are using
SQLite to avoid locking the database

=cut

sub get {
    my $self = shift;
    Smolder::DB->disconnect();
    return $self->SUPER::get(@_);
}

=head1 submit

Extends C<submit()> from L<Test::WWW::Mechanize> to also disconnect
any open Database handles before making a request if we are using
SQLite to avoid locking the database

=cut

sub submit {
    my $self = shift;
    Smolder::DB->disconnect();
    return $self->SUPER::submit(@_);
}

=head1 request

Extends C<request()> from L<Test::WWW::Mechanize> to also disconnect
any open Database handles before making a request if we are using
SQLite to avoid locking the database

=cut

sub request {
    my $self = shift;
    Smolder::DB->disconnect();
    return $self->SUPER::request(@_);
}

=head1 contains_message

This method will look in the C<X-JSON> HTTP header
of the response, look through each message in the
C<messages> array and see if any of them match
the given message.

If given message is a scalar, the message must match
exactly, else if it's a regex, then it will be matched
against that.

=cut

sub contains_message {
    my ($self, $match) = @_;
    my $resp = $self->response();
    my $json = from_json($self->response->header('X-JSON') || '{}');
    my $msgs = $json->{messages} || [];
    my $diag = "contains message $match.";

    # so test diagnostics are right
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    foreach my $msg (@$msgs) {
        if (ref $match eq 'Regexp') {
            if ($msg->{msg} =~ $match) {
                ok(1, $diag);
                return 1;
            }
        } else {
            if (index($msg->{msg}, $match) != -1) {
                ok(1, $diag);
                return 1;
            }
        }
    }

    $diag = qq(Could not find message "$match". Existing messages are:\n)
      . join("\n", map { $_->{msg} } @$msgs);
    ok(0, $diag);
    return 0;
}

1;

