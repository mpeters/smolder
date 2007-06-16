package V1_90;
use strict;
use warnings;
use base 'Smolder::Upgrade';

sub pre_db_upgrade  { }
sub post_db_upgrade { }

# add a new random secret
sub add_to_config {
    my $secret = _random_secret();
    return "\n# Secret\n# A secret key used for encrypting various bits (auth tokens, etc)\nSecret $secret\n";
}

sub _random_secret {
    my $length = int(rand(10) + 20);
    my $secret = '';
    my @chars = ('a'..'z', 'A'..'Z', 0..9, qw(! @ $ % ^ & - _ = + | ; : . / < > ?));
    $secret .= $chars[int(rand($#chars + 1))] for(0..$length);
    return $secret;
}


1;
