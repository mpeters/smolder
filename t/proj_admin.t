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
  create_smoke_report
  delete_smoke_reports
);
use Smolder::Mech;
use Smolder::DB::ProjectDeveloper;
use Smolder::Conf qw(InstallRoot);
use File::Spec::Functions qw(catfile);

if (is_apache_running) {
    plan( tests => 39 );
} else {
    plan( skip_all => 'Smolder apache not running' );
}

my $mech     = Smolder::Mech->new();
my $url      = base_url() . '/developer_projects';
my $pw       = 's3cr3t';
my $dev      = create_developer( password => $pw );
my $proj1_id = create_project()->id();

# add this $dev to $proj1
my $proj1_dev = Smolder::DB::ProjectDeveloper->create(
    {
        developer => $dev,
        project   => $proj1_id,
        admin     => 1,
    }
);
Smolder::DB->dbi_commit();

END {
    delete_developers();
    delete_projects();
}

# 1
use_ok('Smolder::Control::Developer::Projects');

# 2..6
# login as a developer
$mech->get_ok($url);
$mech->content_lacks('Welcome');
$mech->login( username => $dev->username, password => $pw );
ok( $mech->success );
$mech->get_ok($url);
$mech->content_contains('My Projects');

# 7..21
# admin_settings, process_admin_settings
{
    my $proj1    = _get_proj($proj1_id);
    my $url      = "/app/developer_projects/admin_settings";
    my %settings = (
        default_arch     => 'AMD64',
        default_platform => 'Linux FC4',
        allow_anon       => 0,
    );
    $proj1->default_platform('Foo');
    $proj1->default_arch('Bar');
    $proj1->allow_anon(1);
    $proj1->update();
    Smolder::DB->dbi_commit();

    # is form pre-filled
    $mech->get_ok("$url/$proj1");
    $mech->content_contains('Settings');
    $mech->content_contains('checked="checked" value="1"');
    $mech->content_contains('value="Foo"');
    $mech->content_contains('value="Bar"');

    # invalid form
    ok( $mech->form_name('admin_settings_form') );
    $mech->set_fields(
        default_arch     => ( 'x' x 300 ),
        default_platform => ( 'x' x 300 ),
    );
    $mech->submit();
    ok( $mech->success );
    $mech->content_contains('Default Platform must be under 255 characters');
    $mech->content_contains('Default Architecture must be under 255 characters.');
    Smolder::DB->dbi_commit();

    # valid form
    ok( $mech->form_name('admin_settings_form') );
    $mech->set_fields(%settings);
    $mech->submit();
    ok( $mech->success );
    $mech->contains_message('successfully updated');
    Smolder::DB->dbi_commit();

    my $proj_id = $proj1->id;
    $proj1 = undef;
    $proj1 = Smolder::DB::Project->retrieve($proj_id);
    foreach ( keys %settings ) {
        is( $proj1->$_, $settings{$_} );
    }
}

# 21..39
# add_category, delete_category
{
    my $proj1      = _get_proj($proj1_id);
    my $url        = "/app/developer_projects/admin_settings";
    my @categories = ( "Stuff", "More Stuff", );
    $mech->get_ok("$url/$proj1");
    $mech->content_contains('Settings');
    $mech->content_contains('none');

    # empty form
    $mech->form_name('project_categories_form');
    $mech->submit();
    ok( $mech->success );
    $mech->content_contains('missing required fields');

    # invalid form
    $mech->form_name('project_categories_form');
    $mech->set_fields( category => ( 'x' x 300 ) );
    $mech->submit();
    ok( $mech->success );
    $mech->content_contains('Category name must be under 255 characters.');

    # successful
    $mech->form_name('project_categories_form');
    $mech->set_fields( category => $categories[0] );
    $mech->submit();
    ok( $mech->success );
    $mech->contains_message('successfully added');
    $mech->content_contains( $categories[0] );
    Smolder::DB->dbi_commit();

    # try to add it again
    $mech->form_name('project_categories_form');
    $mech->set_fields( category => $categories[0] );
    $mech->submit();
    ok( $mech->success );
    $mech->content_contains('already exists');

    # add the next one
    $mech->form_name('project_categories_form');
    $mech->set_fields( category => $categories[1] );
    $mech->submit();
    ok( $mech->success );
    $mech->contains_message('successfully added');
    $mech->content_contains( $categories[0] );
    $mech->content_contains( $categories[1] );
    Smolder::DB->dbi_commit();

    # make sure they're all there
    foreach my $cat ( $proj1->categories ) {
        ok( grep { $_ eq $cat } @categories );
    }
}

sub _get_proj {
    my (@ids) = @_;
    my @projs;
    foreach my $id (@ids) {
        push( @projs, Smolder::DB::Project->retrieve($id) );
    }
    if (wantarray) {
        return @projs;
    } else {
        return $projs[0];
    }
}

