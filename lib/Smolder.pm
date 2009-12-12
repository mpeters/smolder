package Smolder;

our $VERSION = '1.50';

1;

__END__

=head1 NAME 

Smolder - continuous integration smoke server

=head1 DESCRIPTION

Smolder is a web-based continuous integration smoke server. It's a central
repository for you smoke tests for multiple public and private repositories.

Please see L<Smolder::Manual> for how to use it.

=begin html

<img src="http://i.imgur.com/Hb2cD.png" width="600">

=end html

=head1 FEATURES

=over

=item * Self contained web application

Smolder has it's own built-in HTTP server (Net::Server) and database (SQLite).

=item * Standard Format

Smolder uses L<TAP|http://en.wikipedia.org/wiki/Test_Anything_Protocol> and TAP Archives
as it's reporting format. See L<Smolder::Manual> for more details.

=item * Multiple Notification Channels

Smolder can notifiy you of new or failing tests either by email or Atom data feeds.

=item * Public and Private Projects

Use Smolder for your public open source projects, or for you private work related
projects. Smolder can host multiple projects of each type.

=item * Project Graphs

Smolder has graphs to help you visualize the changes to your test suite over time.
See how the number of tests has grown or find patterns in your failing tests.

=item * Smoke Report Organization

You can organize your smoke reports by platform, architecture or any tag you want.
This makes it easy to see how your project is doing on multiple platforms, or with
different configurations.

=back

=begin html

<img src="http://i.imgur.com/ASTGB.png" width="600">

=end html

=head1 SUPPORT

=over

=item * Source Code

L<https://github.com/mpeters/smolder/>

=item * Bugs and Requests

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Smolder>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Smolder>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Smolder>

=item * Search CPAN

L<http://search.cpan.org/dist/Smolder/>

=back

=head1 COPYRIGHT & LICENSE

Copyright 2009 Michael Peters, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
