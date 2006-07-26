use strict;
use Test::More;
use Smolder::TestData qw(
  create_developer
  delete_developers
  is_apache_running
  base_url
  db_field_value
);
use Smolder::Conf qw(HostName);
use Smolder::Mech;

if (is_apache_running) {
    plan('no_plan');
} else {
    plan( skip_all => 'Smolder Apache not running' );
}

# 1
use_ok('Smolder::Control::Public::Auth');
my $mech = Smolder::Mech->new();
my $url  = base_url() . '/public_auth';
END { delete_developers() }
my $pw  = 'stuff123';
my $dev = create_developer( password => $pw );

# 2..15
# login
{

    # incomplete
    $mech->get_ok( $url . '/login' );
    $mech->form_name('login');
    $mech->set_fields(
        username => '',
        password => '',
    );
    $mech->submit();
    ok( $mech->success );
    $mech->content_contains('incomplete or invalid');
    $mech->content_contains('class="required warn">Username');

    # invalid
    $mech->form_name('login');
    $mech->set_fields(
        username => 'asdfasdf',
        password => 'notreallyreal',
    );
    $mech->submit();
    ok( $mech->success );
    $mech->content_contains('class="required warn">Username');
    $mech->content_contains('class="required warn">Password');
    $mech->content_contains('Invalid username or password!');

    # valid username, invalid pw
    $mech->form_name('login');
    $mech->set_fields(
        username => $dev->username,
        password => 'notreallyreal',
    );
    $mech->submit();
    ok( $mech->success );
    $mech->content_contains('class="required warn">Username');
    $mech->content_contains('class="required warn">Password');
    $mech->content_contains('Invalid username or password!');

    # valid
    $mech->form_name('login');
    $mech->set_fields(
        username => $dev->username,
        password => $pw,
    );
    $mech->submit();
    ok( $mech->success );
    $mech->content_contains( "Welcome " . $dev->username );
}

# 16..17
# logout
{
    $mech->follow_link_ok( { text => 'logout' } );
    $mech->content_contains('logout was successful');
}

# 18..26
# forgot_pw
{
    $mech->get_ok( $url . '/login' );
    $mech->follow_link_ok( { text => '[I forgot my password!]' } );
    $mech->content_contains('Forgot Password');

    # non existant developer
    $mech->form_name('forgot_pw');
    $mech->set_fields( username => 'completely fake usernamed that wont exist' );
    $mech->submit();
    ok( $mech->success );
    $mech->content_contains('User does not exist!');
    $mech->content_contains('class="required warn">Username');

    # successful
    my $old_pw = $dev->password();
    $mech->form_name('forgot_pw');
    $mech->set_fields( username => $dev->username );
    $mech->submit();
    ok( $mech->success );
    $mech->content_contains('email with a new password');
    isnt( $old_pw, db_field_value( 'developer', 'password', $dev->id ) );
}

# 27..28
# timeout, forbidden
{
    $mech->get_ok( $url . '/timeout' );
    $mech->get_ok( $url . '/forbidden' );
}

