use Test::More;
use strict;
use Smolder::TestData qw(
  create_project
  delete_projects
  create_developer
  delete_developers
  create_smoke_report
  delete_smoke_reports
);
use Smolder::DB::ProjectDeveloper;
use Carp;
$SIG{__DIE__} = \*Carp::confess;

plan( tests => 33 );

# 1..3
use_ok('Smolder::DB::Project');
my $project = create_project();
isa_ok( $project, 'Smolder::DB::Project' );
isa_ok( $project->start_date, 'DateTime' );
END { delete_projects() }

# 4..7
# developers
my $dev1 = create_developer();
my $dev2 = create_developer();
my $dev3 = create_developer();

END {
    delete_developers();
}
Smolder::DB::ProjectDeveloper->create(
    {
        developer => $dev1,
        project   => $project,
        admin     => 1,
    }
);
Smolder::DB::ProjectDeveloper->create(
    {
        developer => $dev2,
        project   => $project,
        admin     => 1,
    }
);
Smolder::DB::ProjectDeveloper->create(
    {
        developer => $dev3,
        project   => $project,
    }
);

my @devs = $project->developers();
is( scalar @devs, 3, 'developers() correct count' );
foreach my $d (@devs) {
    ok( $d->id == $dev1->id || $d->id == $dev2->id || $d->id == $dev3->id );
}

# 8..16
# admins, clear_admins, set_admins and is_admin
my @admins = $project->admins();
is( scalar @admins, 2 );
is( $admins[0]->id, $dev1->id );
is( $admins[1]->id, $dev2->id );
$project->clear_admins();
@admins = $project->admins();
is( scalar @admins, 0 );
$project->set_admins( $dev2, $dev3 );
@admins = $project->admins();
is( scalar @admins, 2 );
is( $admins[0]->id, $dev2->id );
is( $admins[1]->id, $dev3->id );
ok( $project->is_admin($dev2) );
ok( !$project->is_admin($dev1) );

# 17..19
# all names
my $project2 = create_project();
my @names    = Smolder::DB::Project->all_names();
cmp_ok( scalar @names, '>=', 2 );
ok( grep { $project->name  eq $_ } @names );
ok( grep { $project2->name eq $_ } @names );

# 20..25
# categories, add_category, delete_category
my @categories = ( 'Stuff', 'More Stuff', 'Still More Stuff', );
$project->add_category( $categories[0] );
$project->add_category( $categories[1] );
$project->add_category( $categories[2] );
my @cats = $project->categories();
is( scalar @cats, 3 );
foreach my $cat (@cats) {
    ok( grep { $_ eq $cat } @categories );
}
$project->delete_category( $categories[0] );
$project->delete_category( $categories[1] );
@cats = $project->categories();
is( scalar @cats, 1 );
is( $cats[0], $categories[2] );

# platforms and architectures
my $platforms = $project->platforms();
is( scalar @$platforms, 0, 'no platforms by default' );
my $architectures = $project->architectures();
is( scalar @$architectures, 0, 'no architectures by default' );

END { delete_smoke_reports }
create_smoke_report(
    project      => $project,
    developer    => $dev1,
    platform     => 'FC3',
    architecture => 'x86'
);
create_smoke_report(
    project      => $project,
    developer    => $dev1,
    platform     => 'FC3',
    architecture => 'amd64'
);
create_smoke_report(
    project      => $project,
    developer    => $dev1,
    platform     => 'FC4',
    architecture => 'x86'
);
$platforms = $project->platforms();
is( scalar @$platforms, 2,     'platforms returns 2' );
is( $platforms->[0],    'FC3', '1st platform is FC3' );
is( $platforms->[1],    'FC4', '2nd platform is FC4' );
$architectures = $project->architectures();
is( scalar @$architectures, 2,       'architectures returns 2' );
is( $architectures->[0],    'amd64', '1st architecture is x86' );
is( $architectures->[1],    'x86',   '2nd architecture is amd64' );
