package Smolder::Mech;
use strict;
use warnings;
use base 'Test::WWW::Mechanize';
use Smolder::Conf qw(DBPlatform);
use Smolder::TestData qw(base_url);

=head1 NAME 

Smolder::Mech

=head1 DESCRIPTION

L<Test::WWW::Mechanize> subclass with some Smolder specific
helper methods

    my $mech = Smolder::Mech->new();
    $mech->login($user);

=head1 METHODS

=head2 new

Constructor

    my $mech = Smolder::Mech->new();

=cut

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    bless $self, $class;
    return $self;
}

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
    if( DBPlatform eq 'SQLite' ) {
        Smolder::DB->db_Main->disconnect();
    }
    return $self->SUPER::get(@_);
}

=head1 submit

Extends C<submit()> from L<Test::WWW::Mechanize> to also disconnect
any open Database handles before making a request if we are using
SQLite to avoid locking the database

=cut

sub submit {
    my $self = shift;
    if( DBPlatform eq 'SQLite' ) {
        Smolder::DB->db_Main->disconnect();
    }
    return $self->SUPER::submit(@_);
}

=head1 request

Extends C<request()> from L<Test::WWW::Mechanize> to also disconnect
any open Database handles before making a request if we are using
SQLite to avoid locking the database

=cut

sub request {
    my $self = shift;
    if( DBPlatform eq 'SQLite' ) {
        Smolder::DB->db_Main->disconnect();
    }
    return $self->SUPER::request(@_);
}

1;

