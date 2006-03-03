package Smolder::Cleanup;
use Smolder::DB;

sub handler : method {
    my $r = shift;
    Smolder::DB->clear_object_index();
}

1;

__END__

=head1 NAME

Smolder::Cleanup

=head1 DESCRIPTION

Module designed to run as a PerlCleanupHandler to clean up various aspects
of Smolder. So far the following cleanup actions are performed:

=over

=item Remove anything from the L<Class::DBI> Live Object Index.

=back
