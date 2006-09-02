package Smolder::Cleanup;
use Smolder::DB;
use Smolder::Conf qw(InstallRoot);
use File::Spec::Functions qw(catfile);

sub handler : method {
    my $r = shift;
    Smolder::DB->clear_object_index();
}

sub loaded_modules: method {
    my ($class, $apache) = @_;
    my $file;

    if( ref $apache && $apache->isa('Apache') ) {
        $file = catfile(InstallRoot, 'tmp', "preload-after-$$.txt");
    } else {
        $file = catfile(InstallRoot, 'tmp', $apache);
    }

    open(my $fh,">$file") or die "Unable to open file '$file': $!";
    for (sort keys %INC) {
        print $fh "$_\n";
    }
    close $fh
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
