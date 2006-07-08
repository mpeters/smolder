package Smolder::Pod::Hyperlink;
use Pod::Parser;
use base 'Pod::Hyperlink';
use strict;
use warnings;

sub parse {
    my ($self, $string) = @_;
    $self->SUPER::parse($string);

    my $page = $self->page;
    # if it's a smolder mod
    if( $page =~ /^Smolder::/ ) {
        $self->{-type} = 'hyperlink';
        $self->{-node} = $self->mod_to_html_file($page);
    } elsif( $page eq 'bin' ) {
        $self->{-type} = 'hyperlink';
        $self->{-node} = '/docs/bin_' . $self->{-node} . '.html';
    # if it's a doc
    } elsif( $page eq 'docs' ) {
        $self->{-type} = 'hyperlink';
        $self->{-node} = '/docs/docs_' . $self->{-node} . '.html';
    # if it's a link to another module
    } elsif( $page =~ /::/ ) {
        $self->{-type} = 'hyperlink';
        $self->{-node} = "http://search.cpan.org/perldoc?$page";
    }
}

sub mod_to_html_file {
    my ($self, $mod_name) = @_;
    my $file = lc $mod_name;
    $file =~ s/::/_/g;
    return "/docs/lib_$file.html";
}

=head1 NAME

Smolder::Pod::Hyperlink

=head1 DESCRIPTION

Smolder specific handling of hyperlinks (C<< L<...> >>) in Smolder
POD.

It does the following to make sure smolder docs are linked appropriatly

=over

=item *

Any links to smolder modules (beginning with C<Smolder::> will be linked to the
corresponding html file that begins with F<docs/html/lib_smolder_>.

So this

    L<"developer db object"|Smolder::DB::Developer>

Will become something like

    <a href="lib_smolder_db_developer">developer db object</a>

=item *

Any links to smolder scripts in F<bin/> will be linked to the
corresponding html file that begins with F<docs/html/bin_>

So this

    L<"smolder control script"|bin/smolder_ctl>

Will become something like

    <a href="bin_smolder_ctl">smolder control script</a>

=item *

Any links to smolder docs (found in F<docs/>) will be linked to the
corresponding html file that begins with F<docs/html/docs_>.

So this

    L<"smolder configuration"|docs/configuration.pod>

Will become something like

    <a href="docs_configuration">smolder configuration</a>

=item *

Any links to non-smolder modules are linked to L<http://search.cpan.org>.

=item *

Any links that begin with C<http://> are simply left as-is.

=back

=cut

1;
