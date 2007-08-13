package Smolder::Email;
use Smolder::Conf qw(InstallRoot HostName FromAddress SMTPHost ApachePort);
use File::Spec::Functions qw(catdir);
use Template;
use MIME::Lite;
use HTML::FormatText::WithLinks;
use Smolder::Util;
use Carp;
use strict;
use warnings;

=head1 NAME

Smolder::Email

=head1 DESCRIPTION

Smolder utility class used to send multi-part MIME email messages

=cut

our $TEMPLATE = Template->new(
    COMPILE_DIR  => catdir( InstallRoot, 'tmp' ),
    INCLUDE_PATH => catdir( InstallRoot, 'templates' ),
    COMPILE_EXT  => '.ttc',
    WRAPPER      => 'Email/wrapper.tmpl',
    FILTERS      => { pass_fail_color    => \&Smolder::Util::pass_fail_color, },
);

=head1 METHODS

=head2 send_mime_mail

This class method will create and send the email. It receives the following
named arguments:

=over

=item name

The name of the email message. This directly corresponds to the template
used for the email creation (under the F<templates/Email> directory).

=item to

The 'to' address of the recipient

=item subject

The subject line of the email

=item tt_params

This is a hash ref that will be passed to the template in order to create
the email message

=back

    Smolder::Email->send_mime_email(
        name        => 'some_email',
        to          => 'someone@something.com',
        subject     => 'Something for you',
        tt_params   => {
            foo => $foo,
            bar => $bar,
        },
    );

The 'From' address for all emails is determined from the C<FromAddress>
in F<conf/smolder.conf>. If an error occurs, the error message will be
returned.

=cut

sub send_mime_mail {
    my ( $class, %args ) = @_;
    my ( $to, $subject, $tt_params, $name ) = @args{qw(to subject tt_params name)};
    $tt_params->{host_name} = HostName();
    $tt_params->{host_name} .= ":" . ApachePort()
      unless ApachePort == 80;
    $tt_params->{subject} = $subject;

    # get the HTML and plain text content
    my $html;
    $TEMPLATE->process( "Email/$name.tmpl", $tt_params, \$html )
      || croak $TEMPLATE->error();
    my $text = HTML::FormatText::WithLinks->new()->parse($html);

    # create the multipart text and html message
    my $mime = MIME::Lite->new(
        From    => FromAddress(),
        To      => $to,
        Subject => $subject,
        Type    => 'multipart/alternative',
    );
    $mime->attach(
        Type => 'text/plain',
        Data => $text
    );
    $mime->attach(
        Type => 'text/html',
        Data => $html,
    );

    # set the SMTP host
    if( SMTPHost() ) {
        MIME::Lite->send( 'smtp', SMTPHost(), Timeout => 60 );
    }
    eval { $mime->send() };
    return $@;
}

1;
