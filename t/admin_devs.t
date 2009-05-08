use strict;
use warnings;

use Test::More;
use Smolder::TestScript;
use Smolder::TestData qw(
  base_url
  is_smolder_running
  create_developer
  delete_developers
  db_field_value
);
use Smolder::Mech;

if (is_smolder_running) {
    plan(tests => 60);
} else {
    plan(skip_all => 'Smolder not running');
}

my $mech  = Smolder::Mech->new();
my $url   = base_url() . '/admin_developers';
my $pw    = 's3cr3t';
my $admin = create_developer(admin => 1, password => $pw);
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

# 2..5
$mech->login(username => $admin->username, password => $pw);
ok($mech->success);
$mech->get_ok($url);
$mech->content_contains('Admin');
$mech->content_contains('Users');

# 6..23
# add
{

    # empty form
    $mech->follow_link_ok({text => 'Add New User'});
    $mech->form_name('add');
    $mech->submit();
    ok($mech->success);
    $mech->content_contains('missing required fields');
    $mech->content_contains('class="required warn">Username');
    $mech->content_contains('class="required warn">Email');
    $mech->content_contains('class="required warn">Password');
    $mech->content_contains('class="required warn">Site Admin?');

    # invalid form
    $mech->form_name('add');
    $mech->set_fields(
        username => 'admin',
        fname    => ('x' x 300),
        lname    => ('x' x 300),
        email    => 'stuff',
        password => 'abc'
    );
    $mech->submit();
    ok($mech->success);
    $mech->content_contains('missing required fields');
    $mech->content_contains('class="required warn">Username');
    $mech->content_contains('user with that username already');
    $mech->content_contains('class="required warn">Email');
    $mech->content_contains('Not a valid email address');
    $mech->content_contains('class="required warn">Password');
    $mech->content_contains('Must be at leat 4 characters');
    $mech->content_contains('class="required warn">Site Admin?');

    # complete form
    $mech->form_name('add');
    $mech->set_fields(%data);
    $mech->submit();
    ok($mech->success);
    $mech->contains_message("New user '$data{username}' successfully created");
    ($dev) = Smolder::DB::Developer->search(username => $data{username});
    END { $dev->delete() if ($dev) }
}

# 24..25
# details
{
    $mech->get_ok($url . "/details/$dev");
    $mech->content_contains($dev->username);
    $mech->content_contains($dev->full_name);
    $mech->content_contains($dev->email);
}

# 28..47
# edit
{
    $mech->get_ok("$url/list");
    $mech->follow_link_ok({url => "/app/admin_developers/edit/$dev"});

    # make sure it's prefilled
    $mech->content_contains('value="' . $dev->username . '"');
    $mech->content_contains('value="' . $dev->fname . '"');
    $mech->content_contains('value="' . $dev->lname . '"');
    $mech->content_contains('value="' . $dev->email . '"');
    $mech->content_contains('value="' . $dev->username . '"');

    # invalid form
    $mech->form_name('edit');
    $mech->set_fields(
        username => 'admin',
        fname    => ('x' x 300),
        lname    => ('x' x 300),
        email    => 'stuff',
    );
    $mech->submit();
    ok($mech->success);
    $mech->content_contains('class="required warn">Username');
    $mech->content_contains('user with that username already');
    $mech->content_contains('class="required warn">First Name');
    $mech->content_contains('class="required warn">Last Name');
    $mech->content_contains('class="required warn">Email');
    $mech->content_contains('Not a valid email address');

    # valid
    $mech->form_name('edit');
    my %new_data = %data;
    $new_data{fname} = 'Michael';
    delete $new_data{password};
    $mech->set_fields(%new_data);
    $mech->submit();
    ok($mech->success);
    $mech->contains_message("User '$data{username}' has been successfully updated");
    $mech->get_ok("$url/list");
    $mech->follow_link_ok({url => "/app/admin_developers/edit/$dev"});
    $mech->content_contains($new_data{fname});
    $mech->content_lacks($data{fname});
}

# 48..50
# reset_pw
{
    $mech->get_ok("$url/list");
    $mech->form_name("resetpw_$dev");
    $mech->submit();
    ok($mech->success);
    isnt($dev->password, db_field_value('developer', 'password', $dev->id));
}

# 51..55
# list
{
    $mech->get_ok("$url/list");
    $mech->content_contains($dev->username);
    $mech->content_contains($dev->email);
    $mech->content_contains($dev->email);
    $mech->follow_link_ok({text => '[Edit]', n => -1});
}

# 56..60
# delete
{
    $mech->get_ok("$url/list");
    ok($mech->form_name("delete_$dev"));
    $mech->submit();
    ok($mech->success);
    $mech->content_contains('developer_list');
    $mech->content_lacks($dev->username);
}

