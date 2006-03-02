use Test::More;
use strict;
use Data::FormValidator;
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
@good = (1, 23, 12343543);
@bad  = ('a', '12.232', '123asd');
_check_with_dfv('unsigned_int', \@good, 1);
_check_with_dfv('unsigned_int', \@bad,  0);

# 12..15
# bool
@good = (1,0);
@bad  = (2, 'a');
_check_with_dfv('bool', \@good, 1);
_check_with_dfv('bool', \@bad,  0);

# 16..19
# length_max
@good = ('asdf', 'adsfasdf');
@bad  = ('asdfasdfasdf', 'asdfasdfasdfadsf123');
_check_with_dfv('length_max', \@good, 1, 10);
_check_with_dfv('length_max', \@bad,  0, 10);

# 20..23
# length_min
@good = ('asdfasdfasdf', 'asdfasdfasdfadsf123');
@bad  = ('asdf', 'adsfasdf');
_check_with_dfv('length_min', \@good, 1, 10);
_check_with_dfv('length_min', \@bad,  0, 10);

# 24..31
# length_between
@good = ('asdfg', 'asdfgh');
@bad  = ('asdf', 'adsfasdf');
_check_with_dfv('length_between', \@good, 1, 5, 7);
_check_with_dfv('length_between', \@good, 1, 7, 5);
_check_with_dfv('length_between', \@bad,  0, 5, 7);
_check_with_dfv('length_between', \@bad,  0, 7, 5);

# 32..36
# pref_email_type
@good = ('full', 'summary', 'link');
@bad  = ('stuff', 'more stuff');
_check_with_dfv('pref_email_type', \@good, 1);
_check_with_dfv('pref_email_type', \@bad,  0);

# 37..41
# pref_email_freq
@good = ('on_new', 'on_fail', 'never');
@bad  = ('stuff', 'more stuff');
_check_with_dfv('pref_email_freq', \@good, 1);
_check_with_dfv('pref_email_freq', \@bad,  0);

# 42..44
# unique_field_value
my $proj = create_project();
END { delete_projects };
@good = ('stuff', 'more stuff');
@bad  = ($proj->name);
_check_with_dfv('unique_field_value', \@good, 1, 'project', 'name');
_check_with_dfv('unique_field_value', \@bad,  0, 'project', 'name');




sub _check_with_dfv {
    my ($name, $data, $good, @args) = @_;
    my $sub_name = "Smolder::Constraints::$name";
    my $constraint;
    { 
        no strict;
        $constraint = $sub_name->(@args);
    }
    foreach my $value (@$data) {
        my $results = Data::FormValidator->check(
            { $name => $value },
            { required => $name, constraint_methods => { $name => $constraint } }
        );
        if( $good ) {
            ok(defined $results->valid($name), "$name with '$value'");
        } else {
            ok(! defined $results->valid($name), "$name with '$value'");
        }
    }
}

