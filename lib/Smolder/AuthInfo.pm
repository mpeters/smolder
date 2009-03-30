package Smolder::AuthInfo;
use strict;
use Digest::MD5 qw(md5_hex);
use Smolder::Conf qw(Secret);

=head1 NAME

Smolder::AuthInfo

=head1 DESCRIPTION

Utility class to manage authentication tickets.

=head1 METHODS

=head2 new

Returns a new object.

    my $ai = Smolder::AuthInfo->new();

=cut

sub new {
    return bless {}, shift;
}

=head2 ticket

Return a new auth ticket given an id and groups.

    $ai->ticket(
        id     => $dev->id,
        groups => [qw(developer admin)],
    );

=cut

sub ticket {
    my ($self, %args) = @_;
    my $str = join(',', $args{id}, @{$args{groups}});
    return $str . '::::' . md5_hex($str, Secret);
}

=head2 parse

Parse an auth ticket. The user's id and groups
are then available in the C<id()> and C<groups()> methods
if the ticket was not tampered with.

    $ai->parse($string);
    my $id = $at->id;
    my $groups = $at->groups;

=cut

sub parse {
    my ($self, $str) = @_;
    my ($data, $digest) = split('::::', $str);
    if (md5_hex($data, Secret) eq $digest) {
        my ($id, @groups) = split(',', $data);
        $self->{id}     = $id;
        $self->{groups} = \@groups;
    } else {
        $self->{id}     = undef;
        $self->{groups} = undef;
    }
}

=head1 groups

Returns an array reference containing the groups of the
most recently parsed auth ticket.

=cut

sub groups {
    return shift->{groups};
}

=head1 id

Returns the id of the most recently parsed auth ticket.

=cut

sub id {
    return shift->{id};
}

1;
