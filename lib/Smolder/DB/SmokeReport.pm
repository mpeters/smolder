package Smolder::DB::SmokeReport;
use strict;
use warnings;
use base 'Smolder::DB';
use Smolder::Conf qw(InstallRoot);
use Smolder::Email;
use File::Spec::Functions qw(catdir catfile);
use File::Path qw(mkpath);
use File::Copy qw(move);
use File::Temp;
use DateTime;
use DateTime::Format::MySQL;
use Test::TAP::Model;
use Test::TAP::XML;
use Smolder::TAPHTMLMatrix;
use Test::TAP::Model::Visual;
use YAML;
use Carp qw(croak);
use IO::Zlib;

__PACKAGE__->set_up_table('smoke_report');

# exceptions
use Exception::Class (
    'Smolder::DB::SmokeReport::Exception',
    'Smolder::DB::SmokeReport::Exception::TAPCreation' => {
        isa         => 'Smolder::DB::SmokeReport::Exception',
        description => 'Could not create Test::TAP::XML from uploaded file!',
        
    },
);

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
    my $v = Smolder::TAPHTMLMatrix->new( $model );
    $v->tmpl_file(catfile(InstallRoot, 'templates', 'TAP', 'detailed_view.html'));
    $v->title("Test Details - #$self");
    $v->smoke_report( $self );
    my $html = $v->detail_html;

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
    my $subject = "Smolder - new " . ( $self->failed ? "failed " : '' ) . "smoke report";
    my $tt_params = { report => $self };

    # get all the developers of this project
    my @devs = $self->project->developers();
    foreach my $dev (@devs) {

        # get their preference for this project
        my $pref = $dev->project_pref( $self->project );

        # skip it, if they don't want to receive it
        next
          if ( $pref->email_freq eq 'never'
            or ( !$self->failed and $pref->email_freq eq 'on_fail' ) );

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

=head3 upload_report

This method will take the name of the uploaded file and the project it's being
added, and various other details and process them. If everything is successful
then the resulting Smolder::DB::SmokeReport object will be returned.

If the given file is compressed, it will be uncompressed before being processed.
After all processing is done, the details file will also be compressed.

It takes the following named arguments

=over

=item file

The full path to the uploaded file.
This is required.

=item format

The format of the file (XML, YAML).
This is required.

=item project

The L<Smolder::DB::Project> object that this report is being associated with.
This is required.

=item developer

The L<Smolder::DB::Developer> who is uploading this file. If none is given,
then the anonymous guest account will be used.
This is optional.

=item architecture

The architecture this test was run on.
This is optional.

=item platform

The platform this test was run on.
This is optional.

=item comments

Any comments associated with this report.
This is optional.

=back

=cut

sub upload_report {
    # TODO - validate params
    my ($self, %args) = @_;

    my $file    = $args{file};
    my $dev     = $args{developer};
    my $project = $args{project};

    # get the 'guest' developer if we weren't given one
    $dev ||= Smolder::DB::Developer->get_guest();

    # if the file is compressed, let's uncompress it
    if ( $file =~ /\.gz$/ ) {
        my $tmp = new File::Temp( UNLINK => 0, );
        my $in_fh = IO::Zlib->new();
        $in_fh->open( $file, 'rb' )
          or die "Could not open file $tmp for reading compressed!";

        my $buffer;
        while ( read( $in_fh, $buffer, 10240 ) ) {
            print $tmp $buffer;
        }
        unlink($file);
        $file = $tmp->filename();
    }

    # take the uploaded file and create a Test::TAP::Model object from it
    my $report_model;
    if ( $args{format} eq 'XML' ) {
        eval { $report_model = Test::TAP::XML->from_xml_file($file); };
    } elsif ( $args{format} eq 'YAML' ) {
        require YAML;
        eval { $report_model = Test::TAP::XML->new_with_struct( YAML::LoadFile($file) ); };
    }

    # if we couldn't create a model of the test
    if ( !$report_model || $@ ) {
        my $err = $@;
        unlink($file);
        Smolder::DB::SmokeReport::Exception::TAPCreation->throw(error => $err);
    };

    my $struct = $report_model->structure();

    # add it to the database
    my $report = Smolder::DB::SmokeReport->create(
        {
            developer    => $dev,
            project      => $args{project},
            architecture => ( $args{architecture} || '' ),
            platform     => ( $args{platform} || '' ),
            comments     => ( $args{comments} || '' ),
            category     => ( $args{category} || undef ),
            pass         => $report_model->total_passed,
            fail         => $report_model->total_failed,
            skip         => $report_model->total_skipped,
            todo         => $report_model->total_todo,
            total        => $report_model->total_seen,
            format       => $args{format},
            test_files   => scalar( $report_model->test_files ),
            duration     => ( $struct->{end_time} - $struct->{start_time} ),
            failed       => $self->did_fail($report_model),
        }
    );
    Smolder::DB->dbi_commit();

    # move the tmp file to it's real destination and compress it
    my $dest   = $report->file;
    my $out_fh = IO::Zlib->new();
    $out_fh->open( $dest, 'wb9' )
      or die "Could not open file $dest for writing compressed!";
    my $in_fh;
    open( $in_fh, $file )
      or die "Could not open file $file for reading! $!";

    my $buffer;
    while ( read( $in_fh, $buffer, 10240 ) ) {
        print $out_fh $buffer;
    }
    $out_fh->close();
    close($in_fh);
    unlink($file);

    # send an email to all the user's who want this report
    $report->send_emails();

    # purge old reports
    $project->purge_old_reports();

    # if it's a failed test, then let's go ahead and create
    # the HTML Matrix for it since it's pretty common
    $report->html if( $report->did_fail($report_model) );

    return $report;
}

=head2 did_fail

This method returns whether or not the given L<Test::TAP::Model>
object failed it's tests or not.

We can't just count the number of tests that failed since
files exiting with a non-zero status with no_plan won't have
any failing test counts, but will fail none-the-less. This will
catch those.

=cut

sub did_fail {
    my ($self, $model) = @_;
    return $model->total_failed if( $model->total_failed );

    foreach my $file ($model->test_files) {
        return 1 unless $file->ok;
    }
    return 0;
}

1;
