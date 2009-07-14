package Smolder::Control;
use strict;
use warnings;
use base 'CGI::Application';
use CGI::Application::Plugin::ValidateRM;
use CGI::Application::Plugin::TT;
use CGI::Application::Plugin::LogDispatch;
use CGI::Application::Plugin::JSON qw(:all);
use Template::Plugin::Cycle;
use CGI::Cookie;
#use CGI::Application::Plugin::DebugScreen;
use Smolder;
use Smolder::Util;
use Smolder::Conf qw(HostName LogFile TemplateDir);
use Smolder::DB::Developer;
use Smolder::DB::Project;
use File::Spec::Functions qw(catdir catfile tmpdir);

{package Template::Perl;
 # Import debugging functions into templates (should be switched on with a config)
 use Smolder::Debug;
}

# setup our logging
__PACKAGE__->add_callback(
    init => sub {
        my $self = shift;
        if (LogFile) {

            # setup log dispatch to use Apache::Log
            $self->log_config(
                APPEND_NEWLINE       => 1,
                LOG_DISPATCH_MODULES => [
                    {
                        module    => 'Log::Dispatch::File',
                        name      => 'smolder_log',
                        min_level => 'debug',
                        filename  => LogFile,
                    }
                ],
            );
        }
    }
);

# setup our protection
__PACKAGE__->add_callback(
    init => sub {
        my $self = shift;
        $self->run_modes(['forbidden']);
    }
);
__PACKAGE__->add_callback(
    prerun => sub {
        my $self   = shift;
        my $q      = $self->query;
        my $cookie = CGI::Cookie->fetch();
        $cookie = $cookie->{smolder};
        my $ai = Smolder::AuthInfo->new();
        my @user_groups;

        # make sure we have a cookie and a session
        if (ref $cookie) {
            my $value = $cookie->value;
            if ($value) {
                $ai->parse($value);
                if( $ai->id ) {
                    $ENV{REMOTE_USER} = $ai->id;
                    @user_groups = @{$ai->groups};
                }
            }
        }

        # log them in if the username and password are passed
        if (!$ENV{REMOTE_USER} && ($q->param('username') && $q->param('password'))) {
            my $dev =
              Smolder::Control::Public::Auth::do_login($self, $q->param('username'),
                $q->param('password'));
            @user_groups = $dev->groups if $dev;
        }

        # make them anonymous if we don't have anything up to this point
        $ENV{REMOTE_USER} ||= 'anon';

        # if our module requires any auth groups, then make sure we are a member
        # of that group
        if (my $group = $self->require_group) {
            my $found = 0;
            foreach my $ug (@user_groups) {
                if ($ug eq $group) {
                    $found = 1;
                    last;
                }
            }

            unless ($found) {
                $self->prerun_mode('forbidden');
            }
        }
    }
);
sub require_group { }

=head1 GLOBAL RUN MODES

=head2 forbidden 

Shows a FORBIDDEN message if a user tries to act on a project that is not
marked as 'forbibben'

=cut

sub forbidden {
    my $self = shift;
    return $self->error_message("You shouldn't be here. Consider yourself warned.");
}

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

our $MP2 =
  defined $ENV{MOD_PERL_API_VERSION}
  ? $ENV{MOD_PERL_API_VERSION} == 2
  : 0;

=head1 METHODS

=head2 developer

This method will return the L<Smolder::DB::Developer> object that this request 
is associated with, if it's not a public request. This information is pulled 
from the C<$ENV{REMOTE_USER}> which is set by C<mod_auth_tkt>.

=cut

sub developer {
    my $self = shift;
    unless ($self->param('__developer')) {

        # REMOTE_USER is set in our prerun
        my $dev;
        if ($ENV{REMOTE_USER} eq 'anon') {
            $dev = Smolder::DB::Developer->get_guest();
        } else {
            $dev = Smolder::DB::Developer->retrieve($ENV{REMOTE_USER});
        }
        $self->param(__developer => $dev);
    }
    return $self->param('__developer');
}

=head2 public_projects

This method will return the L<Smolder::DB::Projects> that are marked as 'public'.

=cut

sub public_projects {
    my $self = shift;
    my @projs = Smolder::DB::Project->search(public => 1, {order_by => 'name'});
    return \@projs;
}

=head2 error_message

A simple run mode to display an error message. This should not be used to show expected
messages, but rather to display un-recoverable and un-expected occurances.

=cut

sub error_message {
    my ($self, $msg) = @_;
    $self->log->warning("An error occurred: $msg");
    return $self->tt_process('error_message.tmpl', {message => $msg,},);
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
    if (!$@) {
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
    my ($self, $values) = @_;
    my $html = '<ul>';
    foreach (@$values) {
        $html .= '<li>' . $self->query->escapeHTML($_) . '</li>';
    }
    return $html . '</ul>';
}

=head2 static_url

This method will take the URL and add the smolder version number
to the front so that caching can be more aggressive. This is only
done if it's not a developer install, so that developers aren't
frustrated by having to fight with browser caches.

=cut

sub static_url {
    my ($self, $url) = @_;

    # TODO - fix this after the switch to CGI::Application::Server
    return $url;

    $url =~ s/^\///;
    return catfile('', $Smolder::VERSION, $url);
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
    push(@$msgs, {type => ($args{type} || 'info'), msg => ($args{msg} || '')});
    $self->add_json_header(messages => $msgs);
}

=head1 TEMPLATE CONFIGURATION

As mentioned above, template access/control is performed through the
L<CGI::Application::Plugin::TT> plugin. The important are the settings used:

=over

=item The search path of templates is F<lib/Smolder/Data/templates>

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
        EVAL_PERL    => 1,
        COMPILE_DIR  => tmpdir(),
        INCLUDE_PATH => TemplateDir,
        COMPILE_EXT  => '.ttc',
        WRAPPER      => 'wrapper.tmpl',
        RECURSION    => 1,
        FILTERS      => {
            pass_fail_color => \&Smolder::Util::pass_fail_color,
            format_time     => \&Smolder::Util::format_time,
        },
    },
    TEMPLATE_NAME_GENERATOR => sub {
        my $self = shift;

        # the directory is based on the object's package name
        my $mod = ref $self;
        $mod =~ s/Smolder::Control:://;
        my $dir = catdir(split(/::/, $mod));

        # the filename is the method name of the caller
        (caller(2))[3] =~ /([^:]+)$/;
        my $name = $1;
        if ($name eq 'tt_process') {

            # we were called from tt_process, so go back once more on the caller stack
            (caller(3))[3] =~ /([^:]+)$/;
            $name = $1;
        }
        return catfile($dir, $name . '.tmpl');
    },

    #TEMPLATE_PRECOMPILE_DIR => catdir( tmpdir(), 'templates'),
};
__PACKAGE__->tt_config($TT_CONFIG);

__PACKAGE__->add_callback(
    'tt_pre_process',
    sub {
        my ($self, $file, $vars) = @_;
        if ($self->query->param('ajax')) {
            $vars->{no_wrapper} = 1;
            $vars->{ajax}       = 1;
        }
        $vars->{smolder_version} = $Smolder::VERSION;
        $vars->{odd_even}        = Template::Plugin::Cycle->new(qw(odd even));
        $vars->{url_base}        = Smolder::Util::url_base();
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
        my $self = shift;
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
    if (!$dfv->success) {

        # add 'any_errors'
        $msgs{any_errors} = 1;

        if ($dfv->has_invalid) {

            # add any error messages for failed (possibly named) constraints
            foreach my $failed ($dfv->invalid) {
                $msgs{"err_$failed"}     = 1;
                $msgs{"invalid_$failed"} = 1;
                my $names = $dfv->invalid($failed);
                foreach my $name (@$names) {
                    next if (ref $name);    # skip regexes
                    $msgs{"invalid_$name"} = 1;
                }
            }
        }

        # now add for missing
        if ($dfv->has_missing) {
            foreach my $missing ($dfv->missing) {
                $msgs{"err_$missing"}     = 1;
                $msgs{"missing_$missing"} = 1;
                $msgs{'has_missing'}      = 1;
            }
        }
    }
    return \%msgs;
}

1;
