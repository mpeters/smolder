use strict;
use warnings;

use Test::More;
use Smolder::TestScript;
use Smolder::TestData qw(
  base_url
  is_smolder_running
  create_developer
  delete_developers
  create_project
  delete_projects
  db_field_value
  create_preference
  delete_preferences
);
use Smolder::DB::ProjectDeveloper;
use Smolder::Mech;

if (is_smolder_running) {
    plan(tests => 98);
} else {
    plan(skip_all => 'Smolder not running');
}

my $mech     = Smolder::Mech->new();
my $BASE_URL = base_url() . '/admin_projects';
my $pw       = 's3cr3t';
my $admin    = create_developer(admin => 1, password => $pw);

END {
    delete_developers();
    delete_preferences();
}
my %data = (
    project_name => "Im A Test Project",
    start_date   => '01/01/2006',
    public       => 0,
    enable_feed  => 0,
    max_reports  => 20,
    extra_css    => '#header_extra { color: red }',
);
my $proj;

# 1
use_ok('Smolder::Control::Admin::Projects');

# 2..5
$mech->login(username => $admin->username, password => $pw);
ok($mech->success);
$mech->get_ok($BASE_URL);
$mech->content_contains('Admin');
$mech->content_contains('Projects');

# 6..31
# add
{

    # empty form
    $mech->follow_link_ok({text => 'Add New Project'});
    $mech->form_name('add');
    $mech->set_fields(max_reports => '');
    $mech->submit();
    ok($mech->success);
    $mech->content_contains('missing required fields');
    $mech->content_contains('class="required warn">Project Name');
    $mech->content_contains('class="required warn">Start Date');
    $mech->content_contains('class="required warn">Public Project');
    $mech->content_contains('class="required warn">Data Feeds');
    $mech->content_contains('class="required warn">Number of Full Reports Saved');

    # invalid form
    my $other_proj = create_project();
    END { delete_projects() }

    # invalid form
    # set these fields like this since WWW::Mechanize won't let us set them to non-existant values
    my $request = HTTP::Request::Common::POST(
        $mech->uri,
        {
            project_name => $other_proj->name,
            start_date   => '01/01/06',
            public       => 'abc',
            enable_feed  => 'efg',
            max_reports  => 'asd',
        }
    );
    $mech->request($request);

    ok($mech->success);
    $mech->content_contains('class="required warn">Project Name');
    $mech->content_contains('name already exists');

    $mech->content_contains('class="required warn">Start Date');
    $mech->content_contains('Invalid Start Date');
    $mech->content_contains('class="required warn">Public Project');
    $mech->content_contains('class="required warn">Data Feeds');
    $mech->content_contains('class="required warn">Number of Full Reports Saved');
    $mech->content_contains('Invalid Number of Full Reports Saved');

    # complete form
    $mech->form_name('add');
    $mech->set_fields(%data);
    $mech->submit();
    ok($mech->success);
    $mech->contains_message("New project '$data{project_name}' successfully created");
    ($proj) = Smolder::DB::Project->search(name => $data{project_name});
    isa_ok($proj, 'Smolder::DB::Project');
    foreach my $field (keys %data) {
        if( $field eq 'start_date' ) {
            isa_ok($proj->start_date, 'DateTime');
            is($proj->start_date->mdy('/'), $data{start_date}, 'start_date was saved correctly');
        } elsif($field eq 'project_name') {
            is($proj->name, $data{project_name}, 'project name was saved correctly');
        } else {
            is($proj->$field, $data{$field}, "$field field was saved correctly");
        }
    }

    END { $proj->delete() if ($proj) };    # make sure it's not left over after the tests
}

# 32..36
# details
{
    $mech->get_ok("$BASE_URL/details/$proj");
    $mech->content_contains($proj->name);
    $mech->content_contains($proj->start_date->strftime('%d/%m/%Y'));
    $mech->content_like(qr|Public Project\?</label>\s*</td>\s*<td>\s*No\s*|);
    $mech->content_like(qr|Data Feed[^<]*</label>\s*</td>\s*<td>\s*No\s*|);
}

# 37..53
# edit
{
    $mech->follow_link_ok({text => 'Edit'});

    # make sure it's prefilled
    my $form = $mech->form_name('edit');
    is($form->value('project_name'), $proj->name, 'name prefilled');
    is($form->value('start_date'), $proj->start_date->strftime('%d/%m/%Y'), 'start_date prefilled');
    is($form->value('public'), $proj->public, 'public prefilled');
    is($form->value('enable_feed'), $proj->enable_feed, 'enable_feed prefilled');

    # invalid form
    my $other_proj = create_project();
    my $url        = "$BASE_URL/process_add/$proj";
    my $request    = HTTP::Request::Common::POST(
        $url,
        {
            project_name => $other_proj->name,
            start_date   => '01/01/06',
            public       => 'abc',
            enable_feed  => 'def',
        }
    );
    $mech->request($request);
    ok($mech->success);

    $mech->content_contains('class="required warn">Project Name');
    $mech->content_contains('name already exists');
    $mech->content_contains('class="required warn">Start Date');
    $mech->content_contains('Invalid Start Date');
    $mech->content_contains('class="required warn">Public Project');
    $mech->content_contains('class="required warn">Data Feed');

    # valid
    $mech->form_name('edit');
    my %new_data = %data;
    $new_data{public}      = 1;
    $new_data{enable_feed} = 1;
    $mech->set_fields(%new_data);
    $mech->submit();
    ok($mech->success);
    $mech->contains_message("Project '$new_data{project_name}' successfully updated");
    $mech->get_ok("$BASE_URL/details/$proj");
    $mech->content_like(qr|Public Project\?</label>\s*</td>\s*<td>\s*Yes\s*|);
    $mech->content_like(qr|Data Feeds[^<]*</label>\s*</td>\s*<td>\s*Yes\s*|);
}

# 54..57
# list
{
    $mech->follow_link_ok({text => 'All Projects'});
    $mech->content_contains($proj->name);
    $mech->content_contains('Yes');
    $mech->follow_link_ok({text => '[Edit]', n => -1});
}

# 58..92
# devs, add_dev, change_admin and remove_dev
{

    # first 'devs'
    $mech->get_ok("$BASE_URL/devs/$proj");
    $mech->content_contains('No users are currently assigned to this project');

    my $dev1 = create_developer();
    my $dev2 = create_developer();
    my $dev3 = create_developer();
    my $url  = "$BASE_URL/add_dev";

    # add admin, dev1, dev2 and dev3 to proj
    # and try to add dev1 twice to make sure it doesn't cause an error
    foreach my $developer ($admin, $dev1, $dev2, $dev3, $dev1) {
        my $request = HTTP::Request::Common::POST(
            $url,
            {
                project   => $proj->id,
                developer => $developer->id,
            }
        );
        $mech->request($request);
        ok($mech->success);

        # make sure this developer is in this project
        my $proj_dev = Smolder::DB::ProjectDeveloper->retrieve(
            project   => $proj,
            developer => $developer,
        );
        isa_ok($proj_dev, 'Smolder::DB::ProjectDeveloper');
    }

    # make sure that all are listed under this proj's details
    $mech->get_ok("$BASE_URL/details/$proj");
    $mech->content_contains($proj->name);
    $mech->content_contains($dev1->username);
    $mech->content_contains($dev2->username);
    $mech->content_contains($dev3->username);
    $mech->follow_link_ok({text => $dev1->username});

    # get the admins for this project
    my @admins = $proj->admins();
    is(scalar @admins, 0, 'no admins currently');

    # set dev2 as the admin
    $mech->get_ok("$BASE_URL/change_admin?project=$proj&developer=$dev2");
    @admins = $proj->admins();
    is(scalar @admins, 1,         'now with 1 admin');
    is($admins[0]->id, $dev2->id, 'dev2 is now an admin');

    # set dev1 as an admin
    $mech->get_ok("$BASE_URL/change_admin?project=$proj&developer=$dev1");
    @admins = $proj->admins();
    is(scalar @admins, 2, 'now with 2 admin');
    is_deeply(
        [sort { $a->id <=> $b->id } @admins],
        [$dev1, $dev2],
        '2 correct devs are now admins',
    );

    # now unset dev2 as an admin
    $mech->get_ok("$BASE_URL/change_admin?project=$proj&developer=$dev2&remove=1");
    @admins = $proj->admins();
    is(scalar @admins, 1,         'now with 1 admin');
    is($admins[0]->id, $dev1->id, 'dev1 is now the only admin');

    # now remove_developer for $dev2
    $url = "$BASE_URL/remove_dev";
    my $request = HTTP::Request::Common::POST(
        $url,
        {
            project   => $proj->id,
            developer => $dev2->id,
        }
    );
    $mech->request($request);
    ok($mech->success);

    # make sure this developer is not in this project
    my $proj_dev = Smolder::DB::ProjectDeveloper->retrieve(
        project   => $proj->id,
        developer => $dev2->id,
    );
    ok(!defined $proj_dev);

    # make sure that dev2 is not listed under this proj's details
    $mech->get_ok("$BASE_URL/details/$proj");
    $mech->content_contains($proj->name);
    $mech->content_contains($dev1->username);
    $mech->content_lacks($dev2->username);
    $mech->content_contains($dev3->username);
}

# 93..97
# delete
{
    $mech->follow_link_ok({text => 'All Projects'});
    ok($mech->form_name("delete_$proj"));
    $mech->submit();
    ok($mech->success);
    $mech->content_contains('project_list');
    $mech->content_lacks($proj->name);
}

