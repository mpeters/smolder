package Smolder::DB::SmokeReport;
use strict;
use warnings;
use base 'Smolder::DB';
use Smolder::Conf qw(InstallRoot);
use Smolder::Email;
use File::Spec::Functions qw(catdir catfile abs2rel);
use File::Path qw(mkpath rmtree);
use File::Copy qw(move);
use File::Temp qw(tempdir);
use File::Find qw(find);
use Cwd qw(fastcwd);
use DateTime;
use DateTime::Format::MySQL;
use Smolder::TAPHTMLMatrix;
use TAP::Parser;
use TAP::Parser::Aggregator;
use Carp qw(croak);
use IO::Zlib;

__PACKAGE__->set_up_table('smoke_report');

# exceptions
use Exception::Class (
    'Smolder::Exception::InvalidTAP' => {
        description => 'Could not parse TAP files!',
    },
    'Smolder::Exception::InvalidArchive' => {
        description => 'Could not unpack file!',
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

=head3 data_dir

The directory in which the data files for this report reside.
If it doesn't exist it will be created.

=cut

sub data_dir {
    my $self = shift;
    my $date = $self->added()->strftime('%Y%m');
    my $dir  = catdir( InstallRoot, 'data', 'smoke_reports', $self->project->id, $date, $self->id );

    # create it if it doesn't exist
    mkpath($dir) if ( !-d $dir );
    return $dir;
}

=head3 file

This returns the file name of where the full report file for this
smoke report does (or will) reside. If the directory does not
yet exist, it will be created.

=cut

sub file {
    my $self = shift;
    return catfile($self->data_dir, 'report.tar.gz');
}

=head3 html

A reference to the HTML text of this Test Report.

=cut

sub html {
    my $self = shift;
    # TODO - do something else if this result has been deleted
    # TODO - stream the file instead of slurping into memory
    return $self->_slurp_file( catfile($self->data_dir, 'html', 'report.html') );
}

=head3 html_test_detail 

This method will return the HTML for the details of an individual
test file. This is useful when you only need the details for some
of the test files (such as an AJAX request).

It receives one argument, which is the index of the test file to
show.

=cut

sub html_test_detail {
    my ($self, $num) = @_;
    my $file = catfile($self->data_dir, 'html', "$num.html");

    # just return the file
    # TODO - do something else if the file no longer exists
    # TODO - stream the file instead of slurping into memory
    return $self->_slurp_file( $file );
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


# This method will send the appropriate email to all developers of this Smoke
# Report's project who requested email notification (through their preferences), 
# depending on this report's status.

sub _send_emails {
    my ($self, $results) = @_;

    # setup some stuff for the emails that we only need to do once
    my $subject = "Smolder - new " . ( $self->failed ? "failed " : '' ) . "smoke report";
    my $tt_params = { 
        report => $self, 
        matrix => Smolder::TAPHTMLMatrix->new( $results ),
    };

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

        warn "Could not send 'smoke_report_$type' email to '$email': $error" if $error;
            
        # now increment their sent count
        $pref->email_sent( $pref->email_sent + 1 );
        $pref->update();
        Smolder::DB->dbi_commit();
    }
}

=head3 delete_files

This method will delete all of the files that can be created and stored in association
with a smoke test report (the 'data_dir' directory). It will C<croak> if the
files can't be deleted for some reason. Returns true if all is good.

=cut

sub delete_files {
    my $self = shift;
    rmtree($self->data_dir);
    $self->update();
    Smolder::DB->dbi_commit();
    return 1;
}

=head3 summary

Returns a text string summarizing the whole test run.

=cut

sub summary {
    my $self = shift;
    return sprintf(
        '%i test cases: %i ok, %i failed, %i todo, %i skipped and %i unexpectedly succeeded',
        $self->total,
        $self->pass,
        $self->fail,
        $self->todo,
        $self->skip,
        $self->todo_pass,
    );
}

=head3

Returns the total percentage of passed tests.

=cut

sub total_percentage {
    my $self = shift;
    if( $self->total && $self->failed ) {
        return sprintf('%i', (($self->total - $self->failed) / $self->total) * 100);
    } else {
        return 100;
    }
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
    my $sth = $self->db_Main->prepare_cached(q(
        UPDATE smoke_report SET category = ?
        WHERE project = ? AND category = ?
    ));
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
    my ($class, %args) = @_;

    my $file    = $args{file};
    my $dev     = $args{developer} ||= Smolder::DB::Developer->get_guest();
    my $project = $args{project};

    # create our initial report
    my $report = $class->create(
        {
            developer    => $dev,
            project      => $args{project},
            architecture => ( $args{architecture} || '' ),
            platform     => ( $args{platform}     || '' ),
            comments     => ( $args{comments}     || '' ),
            category     => ( $args{category}     || undef ),
        }
    );

    $report->update_from_tap_archive($file);

    # send an email to all the user's who want this report
    #$report->_send_emails(\@test_results);

    # move the tmp file to it's real destination 
    my $dest   = $report->file;
    my $out_fh;
    if( $file =~ /\.gz$/ ) {
        open($out_fh, '>', $dest)
            or die "Could not open file $dest for writing:$!";
    } else {
        #compress it if it's not already
        $out_fh = IO::Zlib->new();
        $out_fh->open( $dest, 'wb9' )
            or die "Could not open file $dest for writing compressed!";
    }

    my $in_fh;
    open( $in_fh, $file )
      or die "Could not open file $file for reading! $!";
    my $buffer;
    while ( read( $in_fh, $buffer, 10240 ) ) {
        print $out_fh $buffer;
    }
    close($in_fh);
    $out_fh->close();

    # purge old reports
    $project->purge_old_reports();

    return $report;
}

sub update_from_tap_archive {
    my ($self, $file) = @_;
    $file ||= $self->file;

    # create a temp directory to hold in-progress archive
    my $temp_dir = tempdir( DIR => catdir(InstallRoot, 'tmp'));

    # open up the .tar.gz file so we can examine the files
    my $z = "";
    $z = "z" if $file =~ /\.gz$/;
    my $cmd = "tar -x${z}f $file";
    my $old_dir = fastcwd();
    chdir($temp_dir) or die "Could not chdir to $temp_dir - $!";
    system($cmd) == 0 or Smolder::Exception::InvalidArchive->throw(error => $@);

    my ($duration, @tap_files);

    # do we have a .yml file in the archive?
    my ($yaml_file) = glob("$temp_dir/*.yml");
    if( $yaml_file ) {
        # parse it into a structure
        require YAML::Tiny;
        my $meta = YAML::Tiny->new()->read($yaml_file);
        die "Could not read YAML $yaml_file: " . YAML::Tiny->errstr if YAML::Tiny->errstr;
        $meta = $meta->[0];

        if( $meta->{start_time} && $meta->{stop_time} ) {
            $duration = $meta->{stop_time} - $meta->{start_time};
        }

        if( $meta->{file_order} && ref $meta->{file_order} eq 'ARRAY' ) {
            foreach my $file (@{$meta->{file_order}}) {
                $file = catfile($temp_dir, $file);
                push(@tap_files, $file) if -e $file;
            }
        }
    }

    # if we don't have the file names yet, just traverse the archive
    # and use all .tap files
    if(! @tap_files ) {
        find(
            {
                wanted => sub { push(@tap_files, $_) if $_ =~ /\.tap$/ },
                no_chdir => 1,
            },
            $temp_dir
        );
    }

    # parse the TAP files into a results structure
    my $aggregate = TAP::Parser::Aggregator->new();
    my @test_results;
    foreach my $tap_file (@tap_files) {
        my $label = abs2rel($tap_file, $temp_dir);
        $label =~ s/\.tap$//;
        push(@test_results, $self->parse_tap_file($tap_file, $aggregate, $label));
    }

    # update
    $self->set(
        pass       => scalar $aggregate->passed,
        fail       => scalar $aggregate->failed,
        skip       => scalar $aggregate->skipped,
        todo       => scalar $aggregate->todo,
        todo_pass  => scalar $aggregate->todo_passed,
        total      => $aggregate->total,
        test_files => scalar @test_results,
        failed     => ! !$aggregate->failed,
        duration   => $duration,
    );
    Smolder::DB->dbi_commit();

    # generate the HTML reports
    my $matrix = Smolder::TAPHTMLMatrix->new( 
        smoke_report => $self, 
        test_results => \@test_results, 
    );
    $matrix->generate_html();
    $self->update();
    Smolder::DB->dbi_commit();
}

sub parse_tap_file {
    my ($class, $file_name, $aggregate, $label) = @_;
    my $fh;
    open($fh, $file_name) or die "Could not open $file_name for reading: $!";

    my @tests;
    my $parser = TAP::Parser->new({source => $fh});

    my $total   = 0;
    my $failed  = 0;
    my $skipped = 0;
    while(my $line = $parser->next) {
        if( $line->type eq 'test' ) {
            my %details = (
                ok      => $line->is_ok,
                skip    => $line->has_skip,
                todo    => $line->has_todo,
                comment => $line->as_string,
            );
            $total++;
            $failed++ if !$line->is_ok;
            $skipped++ if $line->has_skip;
            push(@tests, \%details);
        } elsif( $line->type eq 'comment' ) {
            # TAP doesn't have an explicit way to associate a comment
            # with a test (yet) so we'll assume it goes with the last
            # test. Look backwards through the stack for the last test
            my $last_test = $tests[-1];
            if( $last_test ) {
                $last_test->{comment} ||= '';
                $last_test->{comment} .= ("\n" . $line->as_string);
            }
        }
    }

    # add this to the aggregator
    $aggregate->add($label, $parser) if $aggregate;
    my $percent = $total ? sprintf('%i', (($total - $failed) / $total) * 100 ) : 100;
    return {
        label       => $label,
        tests       => \@tests,
        total       => $total,
        failed      => $failed,
        percent     => $percent,
        all_skipped => ( $skipped == $total ),
    }
}

1;
