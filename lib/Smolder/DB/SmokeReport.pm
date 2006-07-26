package Smolder::DB::SmokeReport;
use strict;
use warnings;
use base 'Smolder::DB';
use Smolder::Conf qw(InstallRoot);
use Smolder::Email;
use File::Spec::Functions qw(catdir catfile);
use File::Path qw(mkpath);
use File::Temp;
use DateTime;
use DateTime::Format::MySQL;
use Test::TAP::XML;
use Test::TAP::HTMLMatrix;
use Test::TAP::Model::Visual;
use YAML;
use Carp qw(croak);
use IO::Zlib;

__PACKAGE__->set_up_table('smoke_report');

=head1 NAME

Smolder::DB::SmokeReport

=head1 DESCRIPTION

L<Class::DBI> based model class for the 'smoke_report' table in the database.

=head1 METHODS

=head2 ACCESSSOR/MUTATORS

Each column in the borough table has a method with the same name
that can be used as an accessor and mutator.

The following columns will return objects instead of the value contained in the table:

=cut

__PACKAGE__->has_a(
    added   => 'DateTime',
    inflate => sub { DateTime::Format::MySQL->parse_datetime(shift) },
    deflate => sub { DateTime::Format::MySQL->format_datetime(shift) },
);
__PACKAGE__->has_a( developer => 'Smolder::DB::Developer' );
__PACKAGE__->has_a( project   => 'Smolder::DB::Project' );

# when a new object is created, set 'added' to now()
__PACKAGE__->add_trigger(
    before_create => sub {
        my $self = shift;
        $self->_attribute_set( added => DateTime->now( time_zone => 'local' ), );
    },
);

=over

=item added

A L<DateTime> object representing the datetime stored.

=item developer

The L<Smolder::DB::Developer> object who added this report

=item project

The L<Smolder::DB::Project> object that this report is about

=back

=head2 OBJECT METHODS

=head3 file

This returns the file name of where the full XML file for this
smoke report does (or will) reside. If the directory does not
yet exist, it will be created.

=cut

sub file {
    my $self = shift;
    my $date = $self->added()->strftime('%Y%m');
    my $dir  = catdir( InstallRoot, 'data', 'smoke_reports', $self->project->id, $date, );

    # create it if it doesn't exist
    mkpath($dir) if ( !-d $dir );

    return catfile( $dir, $self->id . '.xml.gz' );
}

=head3 html

A reference to the HTML text of this Test Report.

=cut

sub html {
    my $self = shift;

    # if we already have the file then use it
    if ( $self->html_file && -e $self->html_file ) {
        return $self->_slurp_file( $self->html_file );
    }

    # else we need to generate a new HTML file
    my $model = Test::TAP::Model::Visual->new_with_struct( $self->model_obj->structure );

    # create some header text based on the info of the smoke_report
    my $extra = <<END_EXTRA;

Project:      %s
Uploaded:     %s by %s
Platform:     %s
Architecture: %s
Duration      %i secs
Comments:     %s

END_EXTRA
    $extra = sprintf( $extra,
        $self->project->name,       $self->added->strftime('%A, %B %e %Y, %l:%M:%S %p'),
        $self->developer->username, $self->platform || 'Unknown',
        $self->architecture || 'Unknown', $self->duration,
        $self->comments     || 'none', );

    my $v = Test::TAP::HTMLMatrix->new( $model, $extra );
    $v->has_inline_css(1);
    my $html = $v->html;

    # save this to a file
    my $dir = catdir( InstallRoot, 'tmp', 'html_smoke_reports' );
    unless ( -d $dir ) {
        mkpath($dir) or croak "Could not create directory '$dir'! $!";
    }
    my $tmp = new File::Temp(
        UNLINK => 0,
        SUFFIX => '.html',
        DIR    => $dir,
    );
    print $tmp $html
      or croak "Could not print to $tmp! $!";
    close($tmp);
    $self->html_file( $tmp->filename );
    $self->update();
    Smolder::DB->dbi_commit();

    return \$html;
}

=head3 html_nonref 

The L<html> method returns a reference to the full HTML report and this
is almost always what you want. However, in templates, you cannot use
a scalar reference. So instead, this convenience method is supplied to
allow calling it within a template.

=cut

sub html_nonref {
    my $self = shift;
    my $html = $self->html;
    return $$html;
}

sub _slurp_file {
    my ( $self, $file_name ) = @_;
    my $text;
    local $/;
    open( my $IN, $file_name )
      or croak "Could not open file '$file_name' for reading! $!";

    $text = <$IN>;
    close($IN)
      or croak "Could not close file '$file_name'! $!";
    return \$text;
}

=head3 xml

A reference to the XML text of this Test Report.

=cut

sub xml {
    my $self = shift;
    my $file = $self->file;

    # return as-is unless compressed
    return $self->_slurp_file($file)
      unless $file =~ /\.gz$/;

    # uncompress the XML file and return
    my $in_fh = IO::Zlib->new();
    $in_fh->open( $file, 'rb' )
      or die "Could not open file $file for reading compressed!";

    # IO::Zlib ignores $/ and doesn't support an offset for read(), so
    # the usual faster slurp won't work
    my ( $buffer, $xml );
    while ( read( $in_fh, $buffer, 10240 ) ) {
        $xml .= $buffer;
    }
    $in_fh->close();

    return \$xml;
}

=head3 yaml

A reference to the YAML representation of this Test Report

=cut

sub yaml {
    my $self  = shift;
    my $model = $self->model_obj;
    my $yaml  = YAML::Dump( $model->structure );
    return \$yaml;
}

=head3 model_obj

The L<Test::TAP::XML> object for this smoke test run.

=cut

sub model_obj {
    my $self = shift;
    if ( !$self->{__TAP_MODEL_XML} ) {
        my $file = $self->file;

        # are we dealing with a compressed file
        if ( $file =~ /\.gz/ ) {

            # uncompress the XML file into a temp file
            my $tmp = new File::Temp(
                UNLINK => 1,
                SUFFIX => '.xml',
            );
            my $in_fh = IO::Zlib->new();
            $in_fh->open( $self->file, 'rb' )
              or die "Could not open file $tmp for reading compressed!";

            my $buffer;
            while ( read( $in_fh, $buffer, 10240 ) ) {
                print $tmp $buffer or die "Could not print buffer to $tmp: $!";
            }
            close($tmp);
            $in_fh->close();
            $self->{__TAP_MODEL_XML} = Test::TAP::XML->from_xml_file( $tmp->filename );
        } else {
            $file = $self->file;
            $self->{__TAP_MODEL_XML} = Test::TAP::XML->from_xml_file( $self->file );
        }

    }
    return $self->{__TAP_MODEL_XML};
}

=head3 send_emails

This method will send the appropriate email to all developers of this Smoke
Report's project who requested email notification (through their preferences), 
depending on this report's status.

=cut

sub send_emails {
    my $self = shift;

    # setup some stuff for the emails that we only need to do once
    my $subject = "Smolder - new " . ( $self->fail ? "failed " : '' ) . "smoke report";
    my $tt_params = { report => $self };

    # get all the developers of this project
    my @devs = $self->project->developers();
    foreach my $dev (@devs) {

        # get their preference for this project
        my $pref = $dev->project_pref( $self->project );

        # skip it, if they don't want to receive it
        next
          if ( $pref->email_freq eq 'never'
            or ( !$self->fail and $pref->email_freq eq 'on_fail' ) );

        # see if we need to reset their email_sent_timestamp
        # if we've started a new day
        my $last_sent = $pref->email_sent_timestamp;
        my $now       = DateTime->now( time_zone => 'local' );
        my $interval  = $last_sent ? ( $now - $last_sent ) : undef;

        if ( !$interval or ( $interval->delta_days >= 1 ) ) {
            $pref->email_sent_timestamp($now);
            $pref->email_sent(0);
            $pref->update;
            Smolder::DB->dbi_commit();
        }

        # now check to see if we've passed their limit
        next if ( $pref->email_limit && $pref->email_sent >= $pref->email_limit );

        # now send the type of email they want to receive
        my $type  = $pref->email_type;
        my $email = $dev->email;
        my $error = Smolder::Email->send_mime_mail(
            to        => $email,
            name      => "smoke_report_$type",
            subject   => $subject,
            tt_params => $tt_params,
        );
        croak "Could not send smoke_report_$type email to $email! $error"
          if ($error);

        # now increment their sent count
        $pref->email_sent( $pref->email_sent + 1 );
        $pref->update();
        Smolder::DB->dbi_commit();
    }
}

=head3 delete_files

This method will delete all of the files that can be created and stored in association
with a smoke test report (the 'html_file' and 'file' fields). It will C<croak> if the
files can't be deleted for some reason. Returns true if all is good.

=cut

sub delete_files {
    my $self = shift;
    if ( $self->file && -e $self->file ) {
        unlink $self->file or die "Could not delete file '" . $self->file . "'! $!";
    }
    if ( $self->html_file && -e $self->html_file ) {
        unlink $self->html_file or die "Could not delete file '" . $self->html_file . "'! $!";
    }
    $self->file(undef);
    $self->html_file(undef);
    $self->update();
    Smolder::DB->dbi_commit();
    return 1;
}

=head2 CLASS METHODS

=head3 change_category

This method will change a group of smoke reports that are in one Project's
category into another.

    Smolder::DB::SmokeReport->change_category(
        project     => $project,
        category    => 'Something',
        replacement => 'Something Else',
    );

=cut

sub change_category {
    my ( $self, %args ) = @_;

    # TODO - use Params::Validate to validate these args
    my $sth = $self->db_Main->prepare_cached(
        q(
        UPDATE smoke_report SET category = ?
        WHERE project = ? AND category = ?
    )
    );
    $sth->execute( $args{replacement}, $args{project}->id, $args{category} );
}

1;
