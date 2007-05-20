use strict;
use warnings;

use Test::More;
use Smolder::TestScript;
use Smolder::TestData qw(
  base_url
  is_apache_running
  create_developer
  delete_developers
  create_project
  delete_projects
  db_field_value
);
use Smolder::DB::ProjectDeveloper;
use Smolder::Mech;

if (is_apache_running) {
    plan( tests => 89 );
} else {
    plan( skip_all => 'Smolder apache not running' );
}

my $mech  = Smolder::Mech->new();
my $url   = base_url() . '/admin_projects';
my $pw    = 's3cr3t';
my $admin = create_developer( admin => 1, password => $pw );
END { delete_developers() }
my %data = (
    project_name => "Im A Test Project",
    start_date   => '01/01/2006',
    public       => 0,
    enable_rss   => 0,
);
my $proj;

# 1
use_ok('Smolder::Control::Admin::Projects');

# 2..5
$mech->login( username => $admin->username, password => $pw );
ok( $mech->success );
$mech->get_ok($url);
$mech->content_contains('Admin');
$mech->content_contains('Projects');

# 6..21
# add
{

    # empty form
    $mech->follow_link_ok( { text => 'Add New Project' } );
    $mech->form_name('add');
    $mech->submit();
    ok( $mech->success );
    $mech->content_contains('missing required fields');
    $mech->content_contains('class="required warn">Project Name');
    $mech->content_contains('class="required warn">Start Date');
    $mech->content_contains('class="required warn">Public Project');
    $mech->content_contains('class="required warn">Enable RSS');

    # invalid form
    my $other_proj = create_project();
    END { delete_projects() }

    # set these fields like this since WWW::Mechanize won't let us set them to non-existant values
    my $request = HTTP::Request::Common::POST(
        $mech->uri,
        {
            project_name => $other_proj->name,
            start_date   => '01/01/06',
            public       => 'abc',
            enable_rss   => 'efg',
        }
    );
    $mech->request($request);

    ok( $mech->success );
    $mech->content_contains('class="required warn">Project Name');
    $mech->content_contains('name already exists');

    $mech->content_contains('class="required warn">Start Date');
    $mech->content_contains('Invalid Start Date');
    $mech->content_contains('class="required warn">Public Project');
    $mech->content_contains('class="required warn">Enable RSS');

    # complete form
    $mech->form_name('add');
    $mech->set_fields(%data);
    $mech->submit();
    ok( $mech->success );
    $mech->contains_message("New project '$data{project_name}' successfully created");
    ($proj) = Smolder::DB::Project->search( name => $data{project_name} );

    END { $proj->delete() if ($proj) };    # make sure it's not left over after the tests
}

# 22..26
# details
{
    $mech->get_ok("$url/details/$proj");
    $mech->content_contains( $proj->name );
    $mech->content_contains( $proj->start_date->strftime('%d/%m/%Y') );
    $mech->content_like(qr|Public Project\?</label>\s*</td>\s*<td>\s*No\s*|);
    $mech->content_like(qr|Enable RSS Feeds\?</label>\s*</td>\s*<td>\s*No\s*|);
}

# 27..43
# edit
{
    $mech->follow_link_ok( { text => 'Edit' } );

    # make sure it's prefilled
    my $form = $mech->form_name('edit');
    is($form->value('project_name'), $proj->name, 'name prefilled');
    is($form->value('start_date'), $proj->start_date->strftime('%d/%m/%Y'), 'start_date prefilled');
    is($form->value('public'), $proj->public, 'public prefilled');
    is($form->value('enable_rss'), $proj->enable_rss, 'enable_rss prefilled');

    # invalid form
    my $other_proj = create_project();
    my $uri        = base_url() . '/admin_projects/process_add/' . $proj->id;
    my $request    = HTTP::Request::Common::POST(
        $uri,
        {
            project_name => $other_proj->name,
            start_date   => '01/01/06',
            public       => 'abc',
            enable_rss   => 'def',
        }
    );
    $mech->request($request);
    ok( $mech->success );

    $mech->content_contains('class="required warn">Project Name');
    $mech->content_contains('name already exists');
    $mech->content_contains('class="required warn">Start Date');
    $mech->content_contains('Invalid Start Date');
    $mech->content_contains('class="required warn">Public Project');
    $mech->content_contains('class="required warn">Enable RSS');

    # valid
    $mech->form_name('edit');
    my %new_data = %data;
    $new_data{public} = 1;
    $new_data{enable_rss} = 1;
    $mech->set_fields(%new_data);
    $mech->submit();
    ok( $mech->success );
    $mech->contains_message("Project '$new_data{project_name}' successfully updated");
    $mech->get_ok("$url/details/$proj");
    $mech->content_like(qr|Public Project\?</label>\s*</td>\s*<td>\s*Yes\s*|);
    $mech->content_like(qr|Enable RSS Feeds\?</label>\s*</td>\s*<td>\s*Yes\s*|);
}

# 44..48
# list
{
    $mech->follow_link_ok( { text => 'All Projects' } );
    $mech->content_contains( $proj->name );
    $mech->content_contains( $proj->start_date->strftime('%d/%m/%Y') );
    $mech->content_contains('Yes');
    $mech->follow_link_ok( { text => '[Edit]', n => -1 } );
}

# 49..84
# add_developer, change_admins and remove_developer
{

    # first 'add_developer'
    $mech->get_ok("$url/list");
    $mech->follow_link_ok( { text => 'Add Developers to Projects' } );
    my $dev1 = create_developer();
    my $dev2 = create_developer();
    my $dev3 = create_developer();
    my $uri  = base_url() . '/admin_projects/add_developer';

    # add admin, dev1, dev2 and dev3 to proj
    # and try to add dev1 twice to make sure it doesn't cause an error
    foreach my $developer ( $admin, $dev1, $dev2, $dev3, $dev1 ) {
        my $request = HTTP::Request::Common::POST(
            $uri,
            {
                project   => $proj->id,
                developer => $developer->id,
            }
        );
        $mech->request($request);
        ok( $mech->success );

        # make sure this developer is in this project
        my $proj_dev = Smolder::DB::ProjectDeveloper->retrieve(
            project   => $proj,
            developer => $developer,
        );
        isa_ok( $proj_dev, 'Smolder::DB::ProjectDeveloper' );
    }

    # make sure that all are listed under this proj's details
    $mech->follow_link_ok( { text => $proj->name, url_regex => qr/admin_projects\/details/ } );
    $mech->content_contains( $proj->name );
    $mech->content_contains( $dev1->username );
    $mech->content_contains( $dev2->username );
    $mech->content_contains( $dev3->username );
    $mech->follow_link_ok( { text => $dev1->username } );

    # change admins
    # set an initial admin
    my $proj_dev1 = Smolder::DB::ProjectDeveloper->retrieve(
        project   => $proj,
        developer => $dev1,
    );
    $proj_dev1->admin(1);
    $proj_dev1->update();
    Smolder::DB->dbi_commit();

    # set dev2 as the admin
    $mech->get_ok( base_url() . "/admin_projects/change_admins/$proj?admin=$dev2" );
    my $name = $dev1->username;
    $mech->content_unlike(qr/$name\s+<span[^>]+>\(admin\)</m);
    $name = $dev2->username;
    $mech->content_like(qr/$name\s+<span[^>]+>\(admin\)</m);
    $name = $dev3->username;
    $mech->content_unlike(qr/$name\s+<span[^>]+>\(admin\)</m);

    # set dev1 and dev3 as admins
    $mech->get_ok( base_url() . "/admin_projects/change_admins/$proj?admin=$dev1&admin=$dev3" );
    $name = $dev1->username;
    $mech->content_like(qr/$name\s+<span[^>]+>\(admin\)</m);
    $name = $dev2->username;
    $mech->content_unlike(qr/$name\s+<span[^>]+>\(admin\)</m);
    $name = $dev3->username;
    $mech->content_like(qr/$name\s+<span[^>]+>\(admin\)</m);
    my @admins = $proj->admins();
    is( scalar @admins, 2 );
    is( $admins[0]->id, $dev1->id );
    is( $admins[1]->id, $dev3->id );

    # now remove_developer for $dev2
    $uri = base_url() . '/admin_projects/remove_developer';
    my $request = HTTP::Request::Common::POST(
        $uri,
        {
            project   => $proj->id,
            developer => $dev2->id,
        }
    );
    $mech->request($request);
    ok( $mech->success );

    # make sure this developer is not in this project
    my $proj_dev = Smolder::DB::ProjectDeveloper->retrieve(
        project   => $proj->id,
        developer => $dev2->id,
    );
    ok( !defined $proj_dev );

    # make sure that dev2 is not listed under this proj's details
    $mech->follow_link_ok( { text => $proj->name, url_regex => qr/admin_projects\/details/ } );
    $mech->content_contains( $proj->name );
    $mech->content_contains( $dev1->username );
    $mech->content_lacks( $dev2->username );
    $mech->content_contains( $dev3->username );
}

# 85..89
# delete
{
    $mech->follow_link_ok( { text => 'All Projects' } );
    ok( $mech->form_name("delete_$proj") );
    $mech->submit();
    ok( $mech->success );
    $mech->content_contains('project_list');
    $mech->content_lacks( $proj->name );
}

