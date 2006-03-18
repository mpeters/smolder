use strict;
use Test::More;
use Smolder::TestData qw(
  create_developer
  delete_developers
  create_project
  delete_projects
);

plan( tests => 15 );

# 1
use_ok('Smolder::DB::Developer');

# 2..4
# creation, etc
END { delete_developers() }
my $dev = create_developer();
isa_ok( $dev, 'Smolder::DB::Developer' );
my $new_pw = 'stuff';
$dev->password($new_pw);
$dev->update();
isnt( $dev->password, $new_pw, 'pw encrypted' );
isa_ok( $dev->preference, 'Smolder::DB::Preference' );

# 5..10
# assign to projects, etc
END { delete_projects() }
my $project  = create_project();
my $project2 = create_project();
Smolder::DB::ProjectDeveloper->create(
    {
        project   => $project,
        developer => $dev,
        admin     => 1,
    }
);
Smolder::DB::ProjectDeveloper->create(
    {
        project   => $project2,
        developer => $dev,
    }
);
my @proj_devs = $dev->project_developers();
is( scalar @proj_devs,            2 );
is( $proj_devs[0]->developer->id, $dev->id );
is( $proj_devs[1]->developer->id, $dev->id );

my @projects = $dev->projects();
is( scalar @projects, 2 );
ok(      $projects[0]->id == $proj_devs[0]->project->id
      || $projects[0]->id == $proj_devs[1]->project->id );
ok(      $projects[1]->id == $proj_devs[0]->project->id
      || $projects[1]->id == $proj_devs[1]->project->id );

# 11..13
# project_pref
isa_ok( $dev->project_pref($project),  'Smolder::DB::Preference' );
isa_ok( $dev->project_pref($project2), 'Smolder::DB::Preference' );
isnt( $dev->project_pref($project)->id, $dev->project_pref($project2) );

# 14
# full_name
my ( $fname, $lname ) = ( $dev->fname, $dev->lname );
is( $dev->full_name, "$fname $lname" );

# 15
# email_hidden
TODO: {
    local $TODO = "Not implemented";
    my $new_email = 'testing@asdf.com';
    $dev->email($new_email);
    $dev->update();
    isnt( $dev->email_hidden, $new_email );
}

