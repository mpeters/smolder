use strict;
use warnings;
use Test::More;
use Smolder::TestScript;
use Smolder::TestData qw(
  create_project
  delete_projects
  create_developer
  delete_developers
  create_smoke_report
  delete_smoke_reports
  create_preference
  delete_preferences
);
use Smolder::DB::ProjectDeveloper;
use Carp;
$SIG{__DIE__} = \*Carp::confess;

plan(tests => 51);

# 1..3
use_ok('Smolder::DB::Project');
my $project = create_project();
isa_ok($project,             'Smolder::DB::Project');
isa_ok($project->start_date, 'DateTime');
END { delete_projects }

# 4..7
# developers
my $dev1 = create_developer();
my $dev2 = create_developer();
my $dev3 = create_developer();

END {
    delete_developers;
    delete_preferences;
}
Smolder::DB::ProjectDeveloper->create(
    {
        developer   => $dev1,
        project     => $project,
        admin       => 1,
        preference  => create_preference(),
    }
);
Smolder::DB::ProjectDeveloper->create(
    {
        developer  => $dev2,
        project    => $project,
        admin      => 1,
        preference => create_preference(),
    }
);
Smolder::DB::ProjectDeveloper->create(
    {
        developer  => $dev3,
        project    => $project,
        preference => create_preference(),
    }
);

my @devs = $project->developers();
is(scalar @devs, 3, 'developers() correct count');
foreach my $d (@devs) {
    ok($d->id == $dev1->id || $d->id == $dev2->id || $d->id == $dev3->id);
}

# 8..16
# admins, clear_admins, set_admins and is_admin
my @admins = $project->admins();
is(scalar @admins, 2);
is($admins[0]->id, $dev1->id);
is($admins[1]->id, $dev2->id);
$project->clear_admins();
@admins = $project->admins();
is(scalar @admins, 0);
$project->set_admins($dev2, $dev3);
@admins = $project->admins();
is(scalar @admins, 2);
is($admins[0]->id, $dev2->id);
is($admins[1]->id, $dev3->id);
ok($project->is_admin($dev2));
ok(!$project->is_admin($dev1));

# 17..19
# all names
my $project2 = create_project();
my @names    = Smolder::DB::Project->all_names();
cmp_ok(scalar @names, '>=', 2);
ok(grep { $project->name  eq $_ } @names);
ok(grep { $project2->name eq $_ } @names);

# 20..25
# tags and delete_tag
END { delete_smoke_reports }
my @reports = (
    create_smoke_report(
        project      => $project,
        developer    => $dev1,
        platform     => 'FC3',
        architecture => 'x86',
        tags         => ['foo', 'bar', 'baz'],
    ),
    create_smoke_report(
        project      => $project,
        developer    => $dev1,
        platform     => 'FC3',
        architecture => 'amd64',
        tags         => ['foo', 'bar baz'],
    ),
    create_smoke_report(
        project      => $project,
        developer    => $dev1,
        platform     => 'FC4',
        architecture => 'x86',
        tags         => ['foo', 'bar', 'biz'],
    ),
);

my @tags = $project->tags();
is(scalar @tags, 5,         'correct number of tags');
is($tags[0],     'bar',     '1st tag correct');
is($tags[1],     'bar baz', '2nd tag correct');
is($tags[2],     'baz',     '3rd tag correct');
is($tags[3],     'biz',     '3rd tag correct');
is($tags[4],     'foo',     '5th tag correct');
@tags = $project->tags(with_counts => 1);
is(scalar @tags,      5,         'correct number of tags - with_count');
is($tags[0]->{tag},   'bar',     '1st tag correct - with_count');
is($tags[1]->{tag},   'bar baz', '2nd tag correct - with_count');
is($tags[2]->{tag},   'baz',     '3rd tag correct - with_count');
is($tags[3]->{tag},   'biz',     '3rd tag correct - with_count');
is($tags[4]->{tag},   'foo',     '5th tag correct - with_count');
is($tags[0]->{count}, 2,         '1st count correct');
is($tags[1]->{count}, 1,         '2nd count correct');
is($tags[2]->{count}, 1,         '3rd count correct');
is($tags[3]->{count}, 1,         '3rd count correct');
is($tags[4]->{count}, 3,         '5th count correct');

$project->delete_tag($_) for qw(bar biz);
@tags = $project->tags();
is(scalar @tags, 3,         'correct number of tags - after delete');
is($tags[0],     'bar baz', '1st tag correct - after delete');
is($tags[1],     'baz',     '2nd tag correct - after delete');
is($tags[2],     'foo',     '3rd tag correct - after delete');

$project->change_tag('bar baz', 'tennessee');
@tags = $project->tags();
is(scalar @tags, 3,           'correct number of tags - after change');
is($tags[0],     'baz',       '1st tag correct - after change');
is($tags[1],     'foo',       '2nd tag correct - after change');
is($tags[2],     'tennessee', '3rd tag correct - after change');

$project->delete_tag($_) for ("tennessee", "baz", "foo");
@tags = $project->tags();
is(scalar @tags, 0, 'correct number of tags - after delete all');

# platforms and architectures
my $platforms = $project->platforms();
is(scalar @$platforms, 2,     'platforms returns 2');
is($platforms->[0],    'FC3', '1st platform is FC3');
is($platforms->[1],    'FC4', '2nd platform is FC4');
my $architectures = $project->architectures();
is(scalar @$architectures, 2,       'architectures returns 2');
is($architectures->[0],    'amd64', '1st architecture is x86');
is($architectures->[1],    'x86',   '2nd architecture is amd64');
