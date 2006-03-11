use strict;
use Test::More;
use Test::WWW::Mechanize;
use Smolder::TestData qw(
  base_url
  is_apache_running
  login
  create_developer
  delete_developers
  db_field_value
);

if (is_apache_running) {
    plan( tests => 61 );
} else {
    plan( skip_all => 'Smolder apache not running' );
}

my $mech  = Test::WWW::Mechanize->new();
my $url   = base_url() . '/admin_developers';
my $pw    = 's3cr3t';
my $admin = create_developer( admin => 1, password => $pw );
my %data  = (
    username => 'i_am_a_test',
    fname    => 'Another',
    lname    => 'Test',
    password => 'testing',
    email    => 'testing@testing.com',
    admin    => 0,
);
my $dev;

END { delete_developers() }

# 1
use_ok('Smolder::Control::Admin::Developers');

# 2..4
login( mech => $mech, username => $admin->username, password => $pw );
ok( $mech->success );
$mech->get_ok($url);
$mech->content_contains('Admin - Developers');

# 5..26
# add
{

    # empty form
    $mech->follow_link_ok( { text => 'Add New Developer' } );
    $mech->form_name('add');
    $mech->submit();
    ok( $mech->success );
    $mech->content_contains('either incomplete or invalid');
    $mech->content_contains('class="required warn">Username');
    $mech->content_contains('class="required warn">First Name');
    $mech->content_contains('class="required warn">Last Name');
    $mech->content_contains('class="required warn">Email Address');
    $mech->content_contains('class="required warn">Password');
    $mech->content_contains('class="required warn">Site Admin?');

    # invalid form
    $mech->form_name('add');
    $mech->set_fields(
        username => 'admin',
        fname    => ( 'x' x 300 ),
        lname    => ( 'x' x 300 ),
        email    => 'stuff',
        password => 'abc'
    );
    $mech->submit();
    ok( $mech->success );
    $mech->content_contains('either incomplete or invalid');
    $mech->content_contains('class="required warn">Username');
    $mech->content_contains('developer with that username already');
    $mech->content_contains('class="required warn">First Name');
    $mech->content_contains('class="required warn">Last Name');
    $mech->content_contains('class="required warn">Email Address');
    $mech->content_contains('Not a valid email address');
    $mech->content_contains('class="required warn">Password');
    $mech->content_contains('Must be at leat 4 characters');
    $mech->content_contains('class="required warn">Site Admin?');

    # complete form
    $mech->form_name('add');
    $mech->set_fields(%data);
    $mech->submit();
    ok( $mech->success );
    $mech->content_contains('New developer successfully created');
    ($dev) = Smolder::DB::Developer->search( username => $data{username} );
    END { $dev->delete() if ($dev) }
}

# 27..30
# details
{
    $mech->get_ok( $url . "/details/$dev" );
    $mech->content_contains( $dev->username );
    $mech->content_contains( $dev->full_name );
    $mech->content_contains( $dev->email );
}

# 31..48
# edit
{
    $mech->follow_link_ok( { text => 'Edit' } );

    # make sure it's prefilled
    $mech->content_contains( 'value="' . $dev->username . '"' );
    $mech->content_contains( 'value="' . $dev->fname . '"' );
    $mech->content_contains( 'value="' . $dev->lname . '"' );
    $mech->content_contains( 'value="' . $dev->email . '"' );
    $mech->content_contains( 'value="' . $dev->username . '"' );

    # invalid form
    $mech->form_name('edit');
    $mech->set_fields(
        username => 'admin',
        fname    => ( 'x' x 300 ),
        lname    => ( 'x' x 300 ),
        email    => 'stuff',
    );
    $mech->submit();
    ok( $mech->success );
    $mech->content_contains('either incomplete or invalid');
    $mech->content_contains('class="required warn">Username');
    $mech->content_contains('developer with that username already');
    $mech->content_contains('class="required warn">First Name');
    $mech->content_contains('class="required warn">Last Name');
    $mech->content_contains('class="required warn">Email Address');
    $mech->content_contains('Not a valid email address');

    # valid
    $mech->form_name('edit');
    my %new_data = %data;
    $new_data{fname} = 'Michael';
    delete $new_data{password};
    $mech->set_fields(%new_data);
    $mech->submit();
    ok( $mech->success );
    $mech->content_contains('Developer successfully updated');
    $mech->content_contains( $new_data{fname} );
    $mech->content_lacks( $data{fname} );
}

# 49..51
# reset_pw
{
    $mech->follow_link_ok( { text => 'Reset Password' } );
    $mech->form_name('reset_pw');
    $mech->submit();
    ok( $mech->success );
    isnt( $dev->password, db_field_value( 'developer', 'password', $dev->id ) );
}

# 52..56
# list
{
    $mech->follow_link_ok( { text => 'All Developers' } );
    $mech->content_contains( $dev->username );
    $mech->content_contains( $dev->email );
    $mech->content_contains( $dev->email );
    $mech->follow_link_ok( { text => '[Edit]', n => -1 } );
}

# 57..61
# delete
{
    $mech->follow_link_ok( { text => 'All Developers' } );
    ok( $mech->form_name("delete_$dev") );
    $mech->submit();
    ok( $mech->success );
    $mech->content_contains('Developer List');
    $mech->content_lacks( $dev->username );
}

