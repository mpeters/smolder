package Smolder::DB::SmokeReport;
use strict;
use warnings;
use base 'Smolder::DB';
use Smolder::Conf qw(DataDir TruncateTestFilenames);
use Smolder::Email;
use File::Spec::Functions qw(catdir catfile);
use File::Basename qw(basename);
use File::Path qw(mkpath rmtree);
use File::Copy qw(move copy);
use File::Temp qw(tempdir);
use Cwd qw(fastcwd);
use DateTime;
use Smolder::TAPHTMLMatrix;
use Smolder::DB::TestFile;
use Smolder::DB::TestFileResult;
use Carp qw(croak);
use TAP::Harness::Archive;
use IO::Zlib;

__PACKAGE__->set_up_table('smoke_report');

# exceptions
use Exception::Class (
    'Smolder::Exception::InvalidTAP'     => {description => 'Could not parse TAP files!',},
    'Smolder::Exception::InvalidArchive' => {description => 'Could not unpack file!',},
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
    inflate => sub { __PACKAGE__->parse_datetime(shift) },
    deflate => sub { __PACKAGE__->format_datetime(shift) },
);
__PACKAGE__->has_a(developer => 'Smolder::DB::Developer');
__PACKAGE__->has_a(project   => 'Smolder::DB::Project');

# when a new object is created, set 'added' to now()
__PACKAGE__->add_trigger(
    before_create => sub {
        my $self = shift;
        $self->_attribute_set(added => DateTime->now(time_zone => 'local'),);
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

=head3 add_tag

This method will add a tag to a given smoke report

    $report->add_tag('foo');

=cut

sub add_tag {
    my ($self, $tag) = @_;
    my $sth = $self->db_Main->prepare_cached(
        q/
        INSERT INTO smoke_report_tag (smoke_report, tag) VALUES (?,?)
    /
    );
    $sth->execute($self->id, $tag);
}

=head3 delete_tag

This method will remove a tag from a given smoke report

    $report->delete_tag('foo');

=cut

sub delete_tag {
    my ($self, $tag) = @_;
    my $sth = $self->db_Main->prepare_cached(
        q/
        DELETE FROM smoke_report_tag WHERE smoke_report = ? AND tag = ?
    /
    );
    $sth->execute($self->id, $tag);
}

=head3 tags

Returns a list of all of tags that have been added to this smoke report.
(in the smoke_report_tag table).

    # returns a simple list of scalars
    my @tags = $report->tags();

=cut

sub tags {
    my ($self, %args) = @_;
    my @tags;
    my $sth = $self->db_Main->prepare_cached(
        q/
        SELECT DISTINCT(srt.tag) FROM smoke_report_tag srt
        WHERE srt.smoke_report = ? ORDER BY srt.tag/
    );
    $sth->execute($self->id);
    my $tags = $sth->fetchall_arrayref([0]);
    return map { $_->[0] } @$tags;
}

=head3 data_dir

The directory in which the data files for this report reside.
If it doesn't exist it will be created.

=cut

sub data_dir {
    my $self = shift;
    my $dir = catdir(DataDir, 'smoke_reports', $self->project->id, $self->id);

    # create it if it doesn't exist
    mkpath($dir) if (!-d $dir);
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
    return $self->_slurp_file(catfile($self->data_dir, 'html', 'report.html'));
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

    return $self->_slurp_file($file);
}

=head3 tap_stream

This method will return the file name that holds the recorded TAP stream
given the index of that stream.

=cut

sub tap_stream {
    my ($self, $index) = @_;
    return $self->_slurp_file(catfile($self->data_dir, 'tap', "$index.tap"));
}

# just return the file
# TODO - do something else if the file no longer exists
sub _slurp_file {
    my ($self, $file_name) = @_;
    my $text;
    local $/;
    open(my $IN, $file_name)
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
    my $subject =
      "[" . $self->project->name . "] new " . ($self->failed ? "failed " : '') . "Smolder report";
    my $matrix = Smolder::TAPHTMLMatrix->new(
        smoke_report => $self,
        test_results => $results,
    );
    my $tt_params = {
        report  => $self,
        matrix  => $matrix,
        results => $results,
    };

    # get all the developers of this project
    my @devs = $self->project->developers();
    foreach my $dev (@devs) {

        # get their preference for this project
        my $pref = $dev->project_pref($self->project);

        # skip it, if they don't want to receive it
        next
          if ($pref->email_freq eq 'never'
            or (!$self->failed and $pref->email_freq eq 'on_fail'));

        # see if we need to reset their email_sent_timestamp
        # if we've started a new day
        my $last_sent = $pref->email_sent_timestamp;
        my $now       = DateTime->now(time_zone => 'local');
        my $interval  = $last_sent ? ($now - $last_sent) : undef;

        if (!$interval or ($interval->delta_days >= 1)) {
            $pref->email_sent_timestamp($now);
            $pref->email_sent(0);
            $pref->update;
        }

        # now check to see if we've passed their limit
        next if ($pref->email_limit && $pref->email_sent >= $pref->email_limit);

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
        $pref->email_sent($pref->email_sent + 1);
        $pref->update();
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
    return 1;
}

=head3 summary

Returns a text string summarizing the whole test run.

=cut

sub summary {
    my $self = shift;
    return
      sprintf('%i test cases: %i ok, %i failed, %i todo, %i skipped and %i unexpectedly succeeded',
        $self->total, $self->pass, $self->fail, $self->todo, $self->skip, $self->todo_pass,)
      . ", tags: "
      . join(', ', map { qq("$_") } $self->tags);
}

=head3 total_percentage

Returns the total percentage of passed tests.

=cut

sub total_percentage {
    my $self = shift;
    if ($self->total && $self->failed) {
        return sprintf('%i', (($self->total - $self->failed) / $self->total) * 100);
    } else {
        return 100;
    }
}

=head2 CLASS METHODS

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
            architecture => ($args{architecture} || ''),
            platform     => ($args{platform} || ''),
            comments     => ($args{comments} || ''),
            revision     => ($args{revision} || ''),
        }
    );

    my $tags = $args{tags} || [];
    $report->add_tag($_) foreach (@$tags);

    my $results = $report->update_from_tap_archive($file);

    # send an email to all the user's who want this report
    $report->_send_emails($results);

    # move the tmp file to it's real destination
    my $dest = $report->file;
    my $out_fh;
    if ($file =~ /\.gz$/ or $file =~ /\.zip$/) {
        open($out_fh, '>', $dest)
          or die "Could not open file $dest for writing:$!";
    } else {

        #compress it if it's not already
        $out_fh = IO::Zlib->new();
        $out_fh->open($dest, 'wb9')
          or die "Could not open file $dest for writing compressed!";
    }

    my $in_fh;
    open($in_fh, $file)
      or die "Could not open file $file for reading! $!";
    my $buffer;
    while (read($in_fh, $buffer, 10240)) {
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

    # our data structures for holding the info about the TAP parsing
    my ($duration, @suite_results, @tests, $label);
    my ($total, $failed, $skipped, $planned) = (0, 0, 0, 0);
    my $file_index      = 0;
    my $next_file_index = 0;

    # make our tap directory if it doesn't already exist
    my $tap_dir = catdir($self->data_dir, 'tap');
    unless (-d $tap_dir) {
        mkdir($tap_dir) or die "Could not create directory $tap_dir: $!";
    }

    my $meta;

    # keep track of some things on our own because TAP::Parser::Aggregator
    # doesn't handle total or failed right when a test exits early
    my %suite_data;
    my $aggregator = TAP::Harness::Archive->aggregator_from_archive(
        {
            archive              => $file,
            made_parser_callback => sub {
                my ($parser, $file, $full_path) = @_;
                $label = TruncateTestFilenames ? basename($file) : $file;

                # clear them out for a new run
                @tests = ();
                ($failed, $skipped) = (0, 0, 0);

                # save the raw TAP stream somewhere we can use it later
                $file_index = $next_file_index++;
                my $new_file = catfile($self->data_dir, 'tap', "$file_index.tap");
                copy($full_path, $new_file) or die "Could not copy $full_path to $new_file. $!\n";
            },
            meta_yaml_callback => sub {
                my $yaml = shift;
                $meta     = $yaml->[0];
                $duration = $meta->{stop_time} - $meta->{start_time};
            },
            parser_callbacks => {
                ALL => sub {
                    my $line = shift;
                    if ($line->type eq 'test') {
                        my %details = (
                            ok      => ($line->is_ok     || 0),
                            skip    => ($line->has_skip  || 0),
                            todo    => ($line->has_todo  || 0),
                            comment => ($line->as_string || 0),
                        );
                        $failed++ if !$line->is_ok && !$line->has_skip && !$line->has_todo;
                        $skipped++ if $line->has_skip;
                        push(@tests, \%details);
                    } elsif ($line->type eq 'comment' || $line->type eq 'unknown') {
                        my $slot = $line->type eq 'comment' ? 'comment' : 'uknonwn';

                        # TAP doesn't have an explicit way to associate a comment
                        # with a test (yet) so we'll assume it goes with the last
                        # test. Look backwards through the stack for the last test
                        my $last_test = $tests[-1];
                        if ($last_test) {
                            $last_test->{$slot} ||= '';
                            $last_test->{$slot} .= ("\n" . $line->as_string);
                        }
                    }
                },
                EOF => sub {
                    my $parser = shift;

                    # did we run everything we planned to?
                    my $planned = $parser->tests_planned;
                    my $run     = $parser->tests_run;
                    my $total;
                    if ($planned && $planned > $run) {
                        $total = $planned;
                        foreach (1 .. $planned - $run) {
                            $failed++;
                            push(
                                @tests,
                                {
                                    ok      => 0,
                                    skip    => 0,
                                    todo    => 0,
                                    comment => "test died after test # $run",
                                    died    => 1,
                                }
                            );
                        }
                    } else {
                        $total = $run;
                    }

                    my $percent = $total ? sprintf('%i', (($total - $failed) / $total) * 100) : 100;

                    # record the individual test file and test file result
                    my $test_file = Smolder::DB::TestFile->find_or_create(
                        {
                            project => $self->project,
                            label   => $label
                        }
                    ) or die "could not find or create test file '$label'";
                    Smolder::DB::TestFileResult->insert_or_replace(
                        {
                            test_file    => $test_file->id,
                            smoke_report => $self->id,
                            project      => $self->project->id,
                            total        => $total,
                            failed       => $failed,
                            percent      => $percent,
                            file_index   => $file_index,
                        }
                    ) or die "could not set result for test file '$label'";

                    # push a hash onto the list of results for TAPHTMLMatrix
                    push(
                        @suite_results,
                        {
                            label       => $label,
                            tests       => [@tests],
                            total       => $total,
                            failed      => $failed,
                            percent     => $percent,
                            all_skipped => ($skipped == $total),
                            is_muted    => $test_file->is_muted,
                            mute_until  => $test_file->is_muted
                            ? $test_file->mute_until->strftime("%a %b %d")
                            : '',
                            file_index => $file_index,
                            test_file  => $test_file->id,
                        }
                    );
                    $suite_data{total}  += $total;
                    $suite_data{failed} += $failed;
                  }
            },
        }
    );

    # update
    $self->set(
        pass       => scalar $aggregator->passed,
        fail       => $suite_data{failed},              # aggregator doesn't calculate these 2 right
        total      => $suite_data{total},
        skip       => scalar $aggregator->skipped,
        todo       => scalar $aggregator->todo,
        todo_pass  => scalar $aggregator->todo_passed,
        test_files => scalar @suite_results,
        failed     => !!$aggregator->failed,
        duration   => $duration,
    );

    # we can take some things from the meta information in the archive
    # if they weren't provided during the upload
    if ($meta->{extra_properties}) {
        foreach my $k (keys %{$meta->{extra_properties}}) {
            foreach my $field qw(architecture platform comments) {
                if (lc($k) eq $field && !$self->get($field)) {
                    $self->set($field => delete $meta->{extra_properties}->{$k});
                    last;
                }
            }
        }
    }

    # generate the HTML reports
    my $matrix = Smolder::TAPHTMLMatrix->new(
        smoke_report => $self,
        test_results => \@suite_results,
        meta         => $meta,
    );
    $matrix->generate_html();
    $self->update();

    return \@suite_results;
}

=head3 update_all_report_html 

Look at all existing reports in the database and regenerate
the HTML for each of these reports. This is useful for development
and also upgrading when the report HTML template files have changed
and you want that change to propagate.

=cut

sub update_all_report_html {
    my $class = shift;
    my @reports = $class->search(purged => 0);
    foreach my $report (@reports) {
        warn "Updating report #$report\n";
        eval { $report->update_from_tap_archive() };
        warn "  Problem updating report #$report: $@\n" if $@;
    }

}

1;
