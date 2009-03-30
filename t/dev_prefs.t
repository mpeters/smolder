use strict;
use warnings;
use Test::More;
use Smolder::TestScript;
use Smolder::TestData qw(
  base_url
  is_smolder_running
  logout
  create_developer
  delete_developers
  create_preference
  delete_preferences
  create_project
  delete_projects
  db_field_value
);
use Smolder::DB::ProjectDeveloper;
use Smolder::Mech;

if (is_smolder_running) {
    plan(tests => 56);
} else {
    plan(skip_all => 'Smolder not running');
}

my $mech  = Smolder::Mech->new();
my $url   = base_url() . '/developer_prefs';
my $pw    = 's3cr3t';
my $dev   = create_developer(password => $pw);
my $proj1 = create_project();
my $proj2 = create_project();
my %data  = (
    email_type  => 'link',
    email_freq  => 'on_fail',
    email_limit => 10,
);

# add this $dev to $proj1 and $proj2
my $proj_dev1 = Smolder::DB::ProjectDeveloper->create(
    {developer => $dev, project => $proj1, preference => create_preference});
my $proj_dev2 = Smolder::DB::ProjectDeveloper->create(
    {developer => $dev, project => $proj2, preference => create_preference});

END {
    $proj_dev1->delete() if $proj_dev1;
    $proj_dev2->delete() if $proj_dev2;
    delete_developers();
    delete_projects();
    delete_preferences();
}

# 1
use_ok('Smolder::Control::Developer::Prefs');

# 2..6
# login as a developer
$mech->get($url);

#is($mech->status, 401, 'auth required'); # can we control HTTP codes in C::A::Server?
$mech->content_contains("You shouldn't be here");
$mech->content_lacks('Welcome');
$mech->login(username => $dev->username, password => $pw);
ok($mech->success);
$mech->get_ok($url);
$mech->content_contains('Preferences');

# 7..10
# show
{
    $mech->get_ok($url . '/show');
    $mech->content_contains('My Defaults');
    $mech->content_contains($proj1->name);
    $mech->content_contains($proj2->name);
}

# 11..32
# update_pref
{

    # change my default pref
    # invalid form
    my $request = HTTP::Request::Common::POST(
        $url . '/update_pref/',
        {
            id         => $dev->preference->id,
            email_type => 'stuff',
            email_freq => 'more stuff',
        }
    );
    $mech->request($request);
    ok($mech->success);
    $mech->content_contains('class="required warn">Email Type');
    $mech->content_contains('class="required warn">Email Frequency');
    $mech->content_contains('class="required warn">Per-day Email Limit');

    # valid form
    $mech->get_ok($url . '/show');
    $mech->form_name('update_pref');
    $mech->set_fields(%data);
    $mech->submit();
    ok($mech->success);
    $mech->contains_message('successfully updated');
    is(db_field_value('preference', 'email_type', $dev->preference->id), $data{email_type});
    is(db_field_value('preference', 'email_freq', $dev->preference->id), $data{email_freq});

    # make sure we didn't affect our project specific settings
    isnt(
        db_field_value('preference', 'email_type', $dev->preference->id),
        db_field_value('preference', 'email_type', $proj_dev1->preference->id),
    );
    isnt(
        db_field_value('preference', 'email_freq', $dev->preference->id),
        db_field_value('preference', 'email_freq', $proj_dev1->preference->id),
    );
    isnt(
        db_field_value('preference', 'email_limit', $dev->preference->id),
        db_field_value('preference', 'email_limit', $proj_dev1->preference->id),
    );
    isnt(
        db_field_value('preference', 'email_type', $dev->preference->id),
        db_field_value('preference', 'email_type', $proj_dev2->preference->id),
    );
    isnt(
        db_field_value('preference', 'email_freq', $dev->preference->id),
        db_field_value('preference', 'email_freq', $proj_dev2->preference->id),
    );
    isnt(
        db_field_value('preference', 'email_limit', $dev->preference->id),
        db_field_value('preference', 'email_limit', $proj_dev2->preference->id),
    );

    # now update our settings for proj1
    $mech->get_ok($url . '/show');
    $mech->form_name('update_pref');
    $mech->set_fields(%data, id => $proj_dev1->preference->id,);
    $mech->submit();
    ok($mech->success);
    is(db_field_value('preference', 'email_type', $proj_dev1->preference->id), $data{email_type});
    is(db_field_value('preference', 'email_freq', $proj_dev1->preference->id), $data{email_freq});

    # make sure it didn't change our settings for proj2
    isnt(
        db_field_value('preference', 'email_type', $proj_dev1->preference->id),
        db_field_value('preference', 'email_type', $proj_dev2->preference->id),
    );
    isnt(
        db_field_value('preference', 'email_freq', $proj_dev1->preference->id),
        db_field_value('preference', 'email_freq', $proj_dev2->preference->id),
    );
    isnt(
        db_field_value('preference', 'email_limit', $proj_dev1->preference->id),
        db_field_value('preference', 'email_limit', $proj_dev2->preference->id),
    );
}

# 33..40
# sync all preferences
{
    $mech->get_ok($url . '/show');
    my $form = $mech->form_name('update_pref');
    $form->find_input('sync')->readonly(0);
    my %new_data = (
        id          => $dev->preference->id,
        email_type  => 'summary',
        email_freq  => 'on_new',
        email_limit => 10,
        sync        => 1,
    );
    $mech->set_fields(%new_data);
    $mech->submit();
    ok($mech->success);

    # now check the db to make sure they are all in sync
    is(
        db_field_value('preference', 'email_type', $dev->preference->id),
        db_field_value('preference', 'email_type', $proj_dev1->preference->id),
    );
    is(
        db_field_value('preference', 'email_freq', $dev->preference->id),
        db_field_value('preference', 'email_freq', $proj_dev1->preference->id),
    );
    is(
        db_field_value('preference', 'email_limit', $dev->preference->id),
        db_field_value('preference', 'email_limit', $proj_dev1->preference->id),
    );
    is(
        db_field_value('preference', 'email_type', $dev->preference->id),
        db_field_value('preference', 'email_type', $proj_dev2->preference->id),
    );
    is(
        db_field_value('preference', 'email_freq', $dev->preference->id),
        db_field_value('preference', 'email_freq', $proj_dev2->preference->id),
    );
    is(
        db_field_value('preference', 'email_limit', $dev->preference->id),
        db_field_value('preference', 'email_limit', $proj_dev2->preference->id),
    );
}

# 41..56
# change_pw
{
    $mech->get_ok($url . '/change_pw');
    my $new_pw = 'news3cr3t';

    # empty form
    $mech->form_name('change_pw');
    $mech->submit();
    ok($mech->success);
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
    ok($mech->success);
    $mech->content_contains('class="required warn">Current Password');
    $mech->content_contains('does not match what we have');
    $mech->content_contains('class="required warn">New Password');
    $mech->content_contains('must be at least 4 characters long');
    $mech->content_contains('class="required warn">New Password <em>(Retyped)</em>');
    $mech->content_contains('2nd New Password does not match');

    # successful form
    $mech->form_name('change_pw');
    $mech->set_fields(
        current_pw     => $pw,
        new_pw         => $new_pw,
        new_pw_retyped => $new_pw,
    );
    $mech->submit();
    ok($mech->success);
    $mech->contains_message('successfully changed');

    # now logout and log back in with the new pw
    $mech->logout();
    $mech->login(username => $dev->username, password => $new_pw);
    ok($mech->success);
    $mech->content_contains('Welcome ' . $dev->username);
}

