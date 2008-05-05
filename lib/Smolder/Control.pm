package Smolder::Control;
use strict;
use warnings;
use base 'CGI::Application';
use CGI::Application::Plugin::ValidateRM;
use CGI::Application::Plugin::TT;
use CGI::Application::Plugin::LogDispatch;
use CGI::Application::Plugin::JSON qw(:all);
use Template::Plugin::Cycle;
#use CGI::Application::Plugin::DebugScreen;

use Smolder;
use Smolder::Util;
use Smolder::Conf qw(InstallRoot HostName ApachePort DBName DBUser DBPass);
use Smolder::DB::Developer;
use Smolder::DB::Project;

use File::Spec::Functions qw(catdir catfile);
use HTML::GenerateUtil qw(escape_html EH_INPLACE);

# turn off browser caching and setup our logging
__PACKAGE__->add_callback(
    init => sub {
        my $self = shift;
        # it's all dynamic, so don't let the browser cache anything
        my $r = $self->param('r');
        # doing no_cache on internal redirects (auth redirects, etc)
        # results in a seg fault
        $r->no_cache(1) if $r->is_initial_req;

        # setup log dispatch to use Apache::Log
        $self->log_config(
            APPEND_NEWLINE       => 1,
            LOG_DISPATCH_MODULES => [
                {
                    module    => 'Log::Dispatch::ApacheLog',
                    name      => 'apache_log',
                    min_level => 'debug',
                    apache    => $self->param('r'),
                }
            ],
        );
    }
);

=head1 NAME

Smolder::Control

=head1 DESCRIPTION

This module serves as a base class for all controller classes in smolder. As such
it defines some behavior with regard to templates, form validation, etc
and provides some utility methods for accessing this data.

=head1 VARIABLES

=head2 MP2

Will be true if we are running under Apache2/mod_perl2

    if( $Smolder::Control::MP2 ) {
        ...
    }

=cut

our $MP2 = defined $ENV{MOD_PERL_API_VERSION} ?
    $ENV{MOD_PERL_API_VERSION} == 2
    : 0;

=head1 METHODS

=head2 developer

This method will return the L<Smolder::DB::Developer> object that this request 
is associated with, if it's not a public request. This information is pulled 
from the C<$ENV{REMOTE_USER}> which is set by C<mod_auth_tkt>.

=cut

sub developer {
    my $self = shift;

    # REMOTE_USER is set by Smolder::AuthHandler
    if( $ENV{REMOTE_USER} && $ENV{REMOTE_USER} eq 'anon' ) {
        return Smolder::DB::Developer->get_guest();
    } else {
        return Smolder::DB::Developer->retrieve( $ENV{REMOTE_USER} );
    }

}

=head2 public_projects

This method will return the L<Smolder::DB::Projects> that are marked as 'public'.

=cut

sub public_projects {
    my $self = shift;
    my @projs = Smolder::DB::Project->search( public => 1, { order_by => 'name' });
    return \@projs;
}

=head2 error_message

A simple run mode to display an error message. This should not be used to show expected
messages, but rather to display un-recoverable and un-expected occurances.

=cut

sub error_message {
    my ( $self, $msg ) = @_;
    $self->log->warning("An error occurred: $msg");
    return $self->tt_process( 'error_message.tmpl', { message => $msg, }, );
}

=head2 tt_process

This method is provided by the L<TT Plugin|CGI::Application::Plugin::TT> plugin. It is used
to choose and process the Template Toolkit templates. If no name is provided for the
template (as the first argument) then the package name and the run mode will be used
to determine which template to use. For instance:

    $self->tt_process({ arg1 => 'foo', arg2 => 'bar' });

If this was done in the C<Smolder::Control::Foo> package for the 'list' run mode then
it would use the F<templates/Foo/list.tmpl> template. If you want to use a different template
then you can explicitly specify it as well:

    $self->tt_process('Foo/list.tmpl', { arg1 => 'foo', arg2 => 'bar' });

See L<TEMPLATE_CONFIGURATION> for more details.

=head2 dfv_msgs

This is a convenience method to get access to the last L<Data::FormValidator> messages
that were created due to a form validation failure. These messages are simply flags indicating
which fields were missinage, which failed their constraints and which constraints failed.

See L<FORM VALIDATION> for more information.

=cut

sub dfv_msgs {
    my $self = shift;
    my $results;

    # we need to eval{} 'cause ValidateRM doesn't like dfv_results() being called
    # without check_rm() being called first.
    eval { $results = $self->dfv_results };
    if ( !$@ ) {
        return $results->msgs();
    } else {
        return {};
    }
}

=head2 auto_complete_results

This method takes an array ref of values to be returned to an AJAX Autocomplete
field.

=cut

sub auto_complete_results {
    my ( $self, $values ) = @_;
    my $html = '<ul>';
    foreach (@$values) {
        $html .= '<li>' . escape_html( $_, EH_INPLACE ) . '</li>';
    }
    return $html . '</ul>';
}

=head2 url_base

This method will return the base url for the installed version of
Smolder.

=cut

{
    my $_base = 'http://' . HostName 
        . ( ApachePort == 80 ? '' : ':' . ApachePort );

    sub url_base { $_base };
}

=head2 static_url

This method will take the URL and add the smolder version number
to the front so that caching can be more aggressive. This is only
done if it's not a developer install, so that developers aren't
frustrated by having to fight with browser caches.

=cut

sub static_url {
    my ( $self, $url ) = @_;

    # only do this if we aren't a dev install
    # if the 'src' dir exists it's a dev install
    if ( -d catdir( InstallRoot, 'src' ) ) {
        return $url;
    } else {
        $url =~ s/^\///;
        return catfile( '',  $Smolder::VERSION, $url );
    }
}

=head2 add_message

Adds an message that will be displayed to the user.
Takes the following name-value pairs;

=over

=item msg

The text of the message to send. It will be HTML escaped, so
it must not contain HTML.

=item type

The type of the message, either C<info> or C<warning>. By
default C<info> is assumed.

=back

=cut

sub add_message {
    my ($self, %args) = @_;
    my $msgs = $self->json_header_value('messages') || [];
    push(@$msgs, { type => ($args{type} || 'info') , msg => ($args{msg} || '') });
    $self->add_json_header(messages => $msgs);
}

=head1 TEMPLATE CONFIGURATION

As mentioned above, template access/control is performed through the
L<CGI::Application::Plugin::TT> plugin. The important are the settings used:

=over

=item The search path of templates is F<InstallRoot/templates>

=item All templates are wrapped with the F<templates/wrapper.tmpl>
template unless the C<ajax> CGI param is set.

=item Recursion is allowed for template INCLUDE and PROCESS

=item The following FILTERS are available to each template:

=over

=item pass_fail_color

Given a percentage (usually of passing tests to the total number run)
this filter will return an HTML RGB color suitable for a colorful indicator
of performance.

=back

=back

=cut

# configuration options for CAP::TT (Template Toolkit)
my $TT_CONFIG = {
    TEMPLATE_OPTIONS => {
        COMPILE_DIR  => catdir( InstallRoot, 'tmp' ),
        INCLUDE_PATH => catdir( InstallRoot, 'templates' ),
        COMPILE_EXT  => '.ttc',
        WRAPPER      => 'wrapper.tmpl',
        RECURSION    => 1,
        FILTERS      => { pass_fail_color => \&Smolder::Util::pass_fail_color },
    },
    TEMPLATE_NAME_GENERATOR => sub {
        my $self = shift;

        # the directory is based on the object's package name
        my $mod = ref $self;
        $mod =~ s/Smolder::Control:://;
        my $dir = catdir( split( /::/, $mod ) );

        # the filename is the method name of the caller
        ( caller(2) )[3] =~ /([^:]+)$/;
        my $name = $1;
        if ( $name eq 'tt_process' ) {

            # we were called from tt_process, so go back once more on the caller stack
            ( caller(3) )[3] =~ /([^:]+)$/;
            $name = $1;
        }
        return catfile( $dir, $name . '.tmpl' );
    },
    #TEMPLATE_PRECOMPILE_DIR => catdir( InstallRoot, 'templates'),
};
__PACKAGE__->tt_config($TT_CONFIG);

__PACKAGE__->add_callback(
    'tt_pre_process',
    sub {
        my ( $self, $file, $vars ) = @_;
        if ( $self->query->param('ajax') ) {
            $vars->{no_wrapper} = 1;
            $vars->{ajax}       = 1;
        }
        $vars->{smolder_version} = $Smolder::VERSION;
        $vars->{odd_even} = Template::Plugin::Cycle->new(qw(odd even));
        return;
    }
);

=head1 FORM VALIDATION

For form validation we use L<CGI::Application::Plugin::ValidateRM> which in
turn uses L<Data::FormValidator>. We further customize the validation by
providing the C<untaint_all_constraints> option which means that some values
will become "transformed" (dates will become L<DateTime> objects, etc).

We also customize the resulting hash of messages that is generated upon
validation failure. All failed and missing constraints will become err_$field. All
fields that were present but failed a constraint will become invalid_$name 
(where $name is the name of the field or the name of the constraint if it's 
named). And all missing constraints will have a missing_$field message. 
Also, the 'any_errors' message will be set.

=cut

__PACKAGE__->add_callback(
    init => sub {
        my $self  = shift;
        $self->param(
            'dfv_defaults' => {
                filters                 => ['trim'],
                msgs                    => \&_create_dfv_msgs,
                untaint_all_constraints => 1,
            }
        );
    }
);

sub _create_dfv_msgs {
    my $dfv = shift;
    my %msgs;

    # if there's anything wrong
    if ( !$dfv->success ) {

        # add 'any_errors'
        $msgs{any_errors} = 1;

        if ( $dfv->has_invalid ) {

            # add any error messages for failed (possibly named) constraints
            foreach my $failed ( $dfv->invalid ) {
                $msgs{"err_$failed"}     = 1;
                $msgs{"invalid_$failed"} = 1;
                my $names = $dfv->invalid($failed);
                foreach my $name (@$names) {
                    next if ( ref $name );    # skip regexes
                    $msgs{"invalid_$name"} = 1;
                }
            }
        }

        # now add for missing
        if ( $dfv->has_missing ) {
            foreach my $missing ( $dfv->missing ) {
                $msgs{"err_$missing"}     = 1;
                $msgs{"missing_$missing"} = 1;
                $msgs{'has_missing'}      = 1;
            }
        }
    }
    return \%msgs;
}

1;
