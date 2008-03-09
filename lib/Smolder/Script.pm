aackage Smolder::Script;
use strict;
use warnings;

=head1 NAME

Smolder::Script - loader for the Smolder scripts

=head1 SYNOPSIS
 
  use Smolder::Script;

=head1 DESCRIPTION

This module exists to load and configure the Smolder system for
command-line scripts.

The first thing the module does is attempt to become the configured
User and Group.  If you're not already User then you'll
need to be root in order to change into User.

=head1 INTERFACE

None.

=cut

use Smolder::Conf qw(User Group InstallRoot);
use Carp qw(croak);

BEGIN {

    # make sure we are User/Group

    # get current uid/gid
    my $uid = $>;
    my %gid = map { ( $_ => 1 ) } split( ' ', $) );

    # extract desired uid/gid
    my @uid_data = getpwnam(User);
    warn( "Unable to find user for User '" . User . "'." ), exit(1)
      unless @uid_data;
    my $smolder_uid = $uid_data[2];
    my @gid_data  = getgrnam(Group);
    warn( "Unable to find user for Group '" . Group . "'." ), exit(1)
      unless @gid_data;
    my $smolder_gid = $gid_data[2];

    # become User/Group if necessary
    if ( $gid{$smolder_gid} ) {
        eval { $) = $smolder_gid; };
        warn(   "Unable to become Group '" . Group
              . "' : $@\n"
              . "Maybe you need to start this process as root.\n" )
          and exit(1)
          if $@;
        warn(   "Failed to become Group '" . Group
              . "' : $!.\n"
              . "Maybe you need to start this process as root.\n" )
          and exit(1)
          unless $) == $smolder_gid;
    }

    if ( $uid != $smolder_uid ) {
        eval { $> = $smolder_uid; };
        warn(   "Unable to become User '" . User
              . "' : $@\n"
              . "Maybe you need to start this process as root.\n" )
          and exit(1)
          if $@;
        warn(   "Failed to become User '" . User
              . "' : $!\n"
              . "Maybe you need to start this process as root.\n" )
          and exit(1)
          unless $> == $smolder_uid;
    }
}

1;
