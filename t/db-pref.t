use strict;
use warnings;

use Test::More;
use Smolder::TestScript;
plan(tests => 12);

# 1
use_ok('Smolder::DB::Preference');

# 2..5
# create
my $data = {
    email_type => 'link',
    email_freq => 'on_fail',
};
my $pref = Smolder::DB::Preference->create($data);
ok(defined $pref, 'valid data');
isa_ok($pref, 'Smolder::DB::Preference');
is($pref->email_type, $data->{email_type});
is($pref->email_freq, $data->{email_freq});

# 6..8
# email_types
my $types = $pref->email_types();
foreach my $enum ('full', 'summary', 'link') {
    my $found = 0;
    foreach my $type (@$types) {
        if ($enum eq $type) {
            $found = 1;
            last;
        }
    }
    ok($found, "found $enum in email_types");
}

# 9..11
# email_freqs
my $freqs = $pref->email_freqs();
foreach my $enum ('on_new', 'on_fail', 'never') {
    my $found = 0;
    foreach my $freq (@$freqs) {
        if ($enum eq $freq) {
            $found = 1;
            last;
        }
    }
    ok($found, "found $enum in email_freqs");
}

# 12
# delete
ok($pref->delete);

