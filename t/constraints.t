use strict;
use warnings;
use Test::More;
use Data::FormValidator;
use Smolder::TestScript;
use Smolder::TestData qw(create_project delete_projects);

plan(tests => 44);

# 1
use_ok('Smolder::Constraints');

# 2..5
# email
my @good = qw(
  mpeters@plusthree.com
  test@test.com
);
my @bad = qw(
  something.net
  bad@stuff
);
_check_with_dfv('email', \@good, 1);
_check_with_dfv('email', \@bad,  0);

# 6..11
# unsigned_int
@good = (1,   23,       12343543);
@bad  = ('a', '12.232', '123asd');
_check_with_dfv('unsigned_int', \@good, 1);
_check_with_dfv('unsigned_int', \@bad,  0);

# 12..15
# bool
@good = (1, 0);
@bad  = (2, 'a');
_check_with_dfv('bool', \@good, 1);
_check_with_dfv('bool', \@bad,  0);

# 16..19
# length_max
@good = ('asdf',         'adsfasdf');
@bad  = ('asdfasdfasdf', 'asdfasdfasdfadsf123');
_check_with_dfv('length_max', \@good, 1, 10);
_check_with_dfv('length_max', \@bad,  0, 10);

# 20..23
# length_min
@good = ('asdfasdfasdf', 'asdfasdfasdfadsf123');
@bad  = ('asdf',         'adsfasdf');
_check_with_dfv('length_min', \@good, 1, 10);
_check_with_dfv('length_min', \@bad,  0, 10);

# 24..31
# length_between
@good = ('asdfg', 'asdfgh');
@bad  = ('asdf',  'adsfasdf');
_check_with_dfv('length_between', \@good, 1, 5, 7);
_check_with_dfv('length_between', \@good, 1, 7, 5);
_check_with_dfv('length_between', \@bad,  0, 5, 7);
_check_with_dfv('length_between', \@bad,  0, 7, 5);

# 32..36
# enum_value (preference, email_type)
@good = ('full', 'summary', 'link');
@bad = ('stuff', 'more stuff');
_check_with_dfv('enum_value', \@good, 1, 'preference', 'email_type');
_check_with_dfv('enum_value', \@bad,  0, 'preference', 'email_type');

# 37..41
# enum_value (preference, email_freq)
@good = ('on_new', 'on_fail', 'never');
@bad = ('stuff', 'more stuff');
_check_with_dfv('enum_value', \@good, 1, 'preference', 'email_freq');
_check_with_dfv('enum_value', \@bad,  0, 'preference', 'email_freq');

# 42..44
# unique_field_value
my $proj = create_project();
END { delete_projects }
@good = ('stuff', 'more stuff');
@bad = ($proj->name);
_check_with_dfv('unique_field_value', \@good, 1, 'project', 'name');
_check_with_dfv('unique_field_value', \@bad,  0, 'project', 'name');

sub _check_with_dfv {
    my ($name, $data, $pass, @args) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my $sub_name = "Smolder::Constraints::$name";
    my $constraint;
    {
        no strict;
        $constraint = $sub_name->(@args);
    }
    foreach my $value (@$data) {
        my $results = Data::FormValidator->check({$name => $value},
            {required => $name, constraint_methods => {$name => $constraint}});
        if ($pass) {
            ok(defined $results->valid($name), "$name with '$value'");
        } else {
            ok(!defined $results->valid($name), "$name with '$value'");
        }
    }
}

