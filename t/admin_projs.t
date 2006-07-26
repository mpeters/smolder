use strict;
use Test::More;
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
    plan( tests => 86 );
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

# 6..20
# add
{

    # empty form
    $mech->follow_link_ok( { text => 'Add New Project' } );
    $mech->form_name('add');
    $mech->submit();
    ok( $mech->success );
    $mech->content_contains('either incomplete or invalid');
    $mech->content_contains('class="required warn">Project Name');
    $mech->content_contains('class="required warn">Start Date');
    $mech->content_contains('class="required warn">Public Project?');

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
        }
    );
    $mech->request($request);

    ok( $mech->success );
    $mech->content_contains('either incomplete or invalid');
    $mech->content_contains('class="required warn">Project Name');
    $mech->content_contains('name already exists');

    $mech->content_contains('class="required warn">Start Date');
    $mech->content_contains('Invalid Start Date');
    $mech->content_contains('class="required warn">Public Project?');

    # complete form
    $mech->form_name('add');
    $mech->set_fields(%data);
    $mech->submit();
    ok( $mech->success );
    $mech->content_contains("New project '$data{project_name}' successfully created");
    ($proj) = Smolder::DB::Project->search( name => $data{project_name} );

    END { $proj->delete() if ($proj) };    # make sure it's not left over after the tests
}

# 21..24
# details
{
    $mech->get_ok("$url/details/$proj");
    $mech->content_contains( $proj->name );
    $mech->content_contains( $proj->start_date->strftime('%d/%m/%Y') );
    $mech->content_contains( $proj->public ? 'Yes' : 'No' );
}

# 25..40
# edit
{
    $mech->follow_link_ok( { text => 'Edit' } );

    # make sure it's prefilled
    $mech->content_contains( 'value="' . $proj->name . '"' );
    $mech->content_contains( 'value="' . $proj->start_date->strftime('%d/%m/%Y') . '"' );
    $mech->content_contains( 'value="' . $proj->public . '"' );

    # invalid form
    my $other_proj = create_project();
    my $uri        = base_url() . '/admin_projects/process_add/' . $proj->id;
    my $request    = HTTP::Request::Common::POST(
        $uri,
        {
            project_name => $other_proj->name,
            start_date   => '01/01/06',
            public       => 'abc',
        }
    );
    $mech->request($request);
    ok( $mech->success );

    $mech->content_contains('either incomplete or invalid');
    $mech->content_contains('class="required warn">Project Name');
    $mech->content_contains('name already exists');
    $mech->content_contains('class="required warn">Start Date');
    $mech->content_contains('Invalid Start Date');
    $mech->content_contains('class="required warn">Public Project?');

    # valid
    $mech->form_name('edit');
    my %new_data = %data;
    $new_data{public} = 1;
    $mech->set_fields(%new_data);
    $mech->submit();
    ok( $mech->success );
    $mech->content_contains("Project '$new_data{project_name}' successfully updated");
    $mech->get_ok("$url/details/$proj");
    $mech->content_contains('Yes');
    $mech->content_lacks('No');
}

# 41..45
# list
{
    $mech->follow_link_ok( { text => 'All Projects' } );
    $mech->content_contains( $proj->name );
    $mech->content_contains( $proj->start_date->strftime('%d/%m/%Y') );
    $mech->content_contains('Yes');
    $mech->follow_link_ok( { text => '[Edit]', n => -1 } );
}

# 46..81
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
    $mech->follow_link_ok( { text => $proj->name } );
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
    $mech->follow_link_ok( { text => $proj->name } );
    $mech->content_contains( $proj->name );
    $mech->content_contains( $dev1->username );
    $mech->content_lacks( $dev2->username );
    $mech->content_contains( $dev3->username );
}

# 82..86
# delete
{
    $mech->follow_link_ok( { text => 'All Projects' } );
    ok( $mech->form_name("delete_$proj") );
    $mech->submit();
    ok( $mech->success );
    $mech->content_contains('Projects');
    $mech->content_lacks( $proj->name );
}

