use strict;
use Test::More;
use Smolder::TestData qw(
    create_project
    delete_projects
    create_developer
    delete_developers
);

plan(tests => 7);

# 1
use_ok('Smolder::DB::ProjectDeveloper');

END {
    delete_projects();
    delete_developers();
};

# 2..6
# creation
my $proj_dev = Smolder::DB::ProjectDeveloper->create({
    project     => create_project(),
    developer   => create_developer(),
});
isa_ok($proj_dev, 'Smolder::DB::ProjectDeveloper');
isa_ok($proj_dev->added, 'DateTime');
isa_ok($proj_dev->project, 'Smolder::DB::Project');
isa_ok($proj_dev->developer, 'Smolder::DB::Developer');
isa_ok($proj_dev->preference, 'Smolder::DB::Preference');

# 7
# delete
ok($proj_dev->delete);
