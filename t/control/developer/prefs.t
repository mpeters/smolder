use strict;
use Test::More;
use Test::WWW::Mechanize;
use Smolder::TestData qw(
  base_url
  is_apache_running
  login
  logout
  create_developer
  delete_developers
  create_project
  delete_projects
  db_field_value
);
use Smolder::DB::ProjectDeveloper;

if (is_apache_running) {
    plan( tests => 43 );
} else {
    plan( skip_all => 'Smolder apache not running' );
}

my $mech  = Test::WWW::Mechanize->new();
my $url   = base_url() . '/developer_prefs';
my $pw    = 's3cr3t';
my $dev   = create_developer( password => $pw );
my $proj1 = create_project();
my $proj2 = create_project();
my %data  = (
    email_type => 'link',
    email_freq => 'on_fail',
);

# add this $dev to $proj1 and $proj2
my $proj_dev1 = Smolder::DB::ProjectDeveloper->create( { developer => $dev, project => $proj1 } );
my $proj_dev2 = Smolder::DB::ProjectDeveloper->create( { developer => $dev, project => $proj2 } );
Smolder::DB->dbi_commit();

END {
    delete_developers();
    delete_projects();
}

# 1
use_ok('Smolder::Control::Developer::Prefs');

# 2..6
# login as a developer
$mech->get_ok($url);
$mech->content_lacks('Welcome');
login( mech => $mech, username => $dev->username, password => $pw );
ok( $mech->success );
$mech->get_ok($url);
$mech->content_contains('Preferences');

# 7..10
# show_all
{
    $mech->get_ok( $url . '/show_all' );
    $mech->content_contains('Default Preferences');
    $mech->content_contains( $proj1->name );
    $mech->content_contains( $proj2->name );
}

# 11..27
# update_pref
{

    # change my default pref
    # invalid form
    my $request = HTTP::Request::Common::POST(
        $url . '/update_pref/',
        {
            email_type => 'stuff',
            email_freq => 'more stuff',
        }
    );
    $mech->request($request);
    ok( $mech->success );
    $mech->content_contains('class="required warn">Email Type');
    $mech->content_contains('class="required warn">Email Frequency');

    # valid form
    $mech->form_name('update_pref_');
    $mech->set_fields(%data);
    $mech->submit();
    ok( $mech->success );
    $mech->content_contains('Preferences successfully updated');
    is( db_field_value( 'preference', 'email_type', $dev->preference->id ), $data{email_type} );
    is( db_field_value( 'preference', 'email_freq', $dev->preference->id ), $data{email_freq} );

    # make sure we didn't affect our project specific settings
    isnt(
        db_field_value( 'preference', 'email_type', $dev->preference->id ),
        db_field_value( 'preference', 'email_type', $proj_dev1->preference->id ),
    );
    isnt(
        db_field_value( 'preference', 'email_freq', $dev->preference->id ),
        db_field_value( 'preference', 'email_freq', $proj_dev1->preference->id ),
    );
    isnt(
        db_field_value( 'preference', 'email_type', $dev->preference->id ),
        db_field_value( 'preference', 'email_type', $proj_dev2->preference->id ),
    );
    isnt(
        db_field_value( 'preference', 'email_freq', $dev->preference->id ),
        db_field_value( 'preference', 'email_freq', $proj_dev2->preference->id ),
    );

    # now update our settings for proj1
    $mech->get_ok( $url . '/show_all' );
    $mech->form_name( 'update_pref_' . $proj_dev1->preference->id );
    $mech->set_fields(%data);
    $mech->submit();
    ok( $mech->success );
    is( db_field_value( 'preference', 'email_type', $proj_dev1->preference->id ),
        $data{email_type} );
    is( db_field_value( 'preference', 'email_freq', $proj_dev1->preference->id ),
        $data{email_freq} );

    # make sure it didn't change our settings for proj2
    isnt(
        db_field_value( 'preference', 'email_type', $proj_dev1->preference->id ),
        db_field_value( 'preference', 'email_type', $proj_dev2->preference->id ),
    );
    isnt(
        db_field_value( 'preference', 'email_freq', $proj_dev1->preference->id ),
        db_field_value( 'preference', 'email_freq', $proj_dev2->preference->id ),
    );
}

# 28..43
# change_pw
{
    $mech->get_ok( $url . '/change_pw' );
    my $new_pw = 'news3cr3t';

    # empty form
    $mech->form_name('change_pw');
    $mech->submit();
    ok( $mech->success );
    $mech->content_contains('class="required warn">Current Password');
    $mech->content_contains('class="required warn">New Password');
    $mech->content_contains('class="required warn">New Password <em>(Retyped)</em>');

    # invalid form
    $mech->form_name('change_pw');
    $mech->set_fields(
        current_pw     => 'stuff',
        new_pw         => 'abc',
        new_pw_retyped => 'abcd',
    );
    $mech->submit();
    ok( $mech->success );
    $mech->content_contains('class="required warn">Current Password');
    $mech->content_contains('Does not match your current password');
    $mech->content_contains('class="required warn">New Password');
    $mech->content_contains('Must be at least 4 characters long');
    $mech->content_contains('class="required warn">New Password <em>(Retyped)</em>');
    $mech->content_contains('Does not match your New Password');

    # successful form
    $mech->form_name('change_pw');
    $mech->set_fields(
        current_pw     => $pw,
        new_pw         => $new_pw,
        new_pw_retyped => $new_pw,
    );
    $mech->submit();
    ok( $mech->success );
    $mech->content_contains('Password successfully changed!');

    # now logout and log back in with the new pw
    logout( mech => $mech );
    login( mech => $mech, username => $dev->username, password => $new_pw );
    ok( $mech->success );
    $mech->content_contains( 'Welcome ' . $dev->username );
}

