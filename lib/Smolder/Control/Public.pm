package Smolder::Control::Public;
use base 'Smolder::Control';
use strict;
use warnings;

=head1 NAME

Smolder::Control::Public

=head1 DESCRIPTION

Controller module for generic Public screens.

=cut

sub setup {
    my $self = shift;
    $self->start_mode('welcome');
    $self->run_modes(
        [
            qw(
              welcome
              developer_tutorial
              admin_tutorial
              not_found
              nav
              )
        ]
    );
}

=head1 RUN MODES

=head2 welcome

Shows a welcome page using the F<Public/welcome.tmpl> template.

=cut

sub welcome {
    # JS -  we have only one project, so just go directly there.
    #
    my $self = shift;
    $self->header_type('redirect');
    $self->header_add( -uri => '/app/public_projects/smoke_reports/2' );
    return "redirecting";
    # return $self->tt_process( {} );
}

=head2 nav

Return the nav HTML snippet incase we need to update it

=cut

sub nav {
    my $self = shift;
    return $self->tt_process('nav.tmpl', {no_wrapper => 1});

}

=head2 developer_tutorial

Shows a tutorial for a developer  using the F<Public/developer_tutorial.tmpl> template.

=cut

sub developer_tutorial {
    my $self = shift;
    return $self->tt_process({});
}

=head2 admin_tutorial

Shows a tutorial for an admin  using the F<Public/admin_tutorial.tmpl> template.

=cut

sub admin_tutorial {
    my $self = shift;
    return $self->tt_process({});
}

=head2 not_found

Show the PAGE NOT FOUND error.

=cut

sub not_found {
    my $self = shift;
    return $self->tt_process({});
}

=head2 error

Show the INTERNAL SERVER ERROR page.

=cut

sub error {
    my $self = shift;
    return $self->tt_process({});
}

1;
