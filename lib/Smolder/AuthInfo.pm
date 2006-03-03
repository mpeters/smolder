package Smolder::AuthInfo;
use strict;
use Smolder::Conf qw(InstallRoot);
use File::Spec::Functions qw(catfile);
use Apache::AuthTkt;

=head1 NAME

Smolder::AuthInfo

=head1 DESCRIPTION

Uses Apache::AuthTkt to manage provide access to user's auth information.

=head1 METHODS

=head2 new

Returns the Apache::AuthTkt object with our site configuration.

    my $at = Smolder::AuthInfo->new();

=cut

sub new {
    my $at = Apache::AuthTkt->new( conf => catfile( InstallRoot, 'tmp', 'httpd.conf' ), );
    $at->ignore_ip(1);
    return $at;
}

1;
