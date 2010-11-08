package Smolder::Manual;
1;

__END__

=head1 NAME 

Smolder::Manual - How to use Smolder more effectively

=head1 UPLOAD FILE FORMAT

This describes the file format for test reports expected by Smolder. This
report file can either be uploaded using the web interface or the
C<smolder_smoke_signal> utility for automating the upload.

=head2 TAP

TAP is the "Test Anything Prototcol" and is the basic format behind all
test reports. Whatever language you use for your testing or whatever
infrastructure or harness you have running your tests, if it can output
TAP then it can work with Smolder. There are TAP emiters for almost all
currently popular languages (C, Java, PHP, Perl, Python, Ruby, etc). And
even if your language of choice doesn't have an existing TAP emiter, TAP
is such a simple protocol that it's a fairly trivial task to write one.

The full documentation for TAP can be found at
http://search.cpan.org/perldoc?TAP with more information available at
http://testanything.org.

The basic idea is that a single file of TAP output is equivalent to
a single test script or module. These files are collected together in
a tar (optionally compressed with gzip) or a zip archive. This archive
file can have an arbitrary number of these TAP files (the file extension
doesn't matter, but you can use F<.tap> if you need to use something)
in an arbitrary number of directories (nice for grouping and organizing
your tests).

=head2 Simple Example

Here's a quick example of using a few C<bash> commands to create a
Smolder test report file from a typical Perl test suite (typical Perl 
test suites use L<Test::Builder> which output TAP) :

    $] foreach i in t/*.t; do perl $i > `basename .t`.tap; done
    $] tar -zc *.tap > test_run.tar.gz

=head2 YAML

Pretty straight forward. Now, there are some additional details which
you may or may not want Smolder to keep track of. What order did my
test files run in? How long did the test suite take to run? Since these
are questions about the whole test run in general it's not possible to
really associate them with any one test's output. 

This is why we also allow this test suite meta information to be presented
to Smolder in a small and simple YAML file. This file is usually named
F<meta.yml>, but you can use anything really as long as there's only
one file with the F<.yml> extension. It looks something like this:

    ---
    file_order:
      - foo.tap
      - bar.tap
      - extra/baz.tap
      - extra/froob.tap
    start_time: 1178159475
    stop_time: 1178159983

Since this entire file is optional, if you do include it you can include
which ever parts are of interest to you. Smolder can care about the
following keys of the YAML map:

=over

=item * file_order

This is a list of the TAP files from your test run in the order you desire
to display them. This will usually be the order in which they are run.
The path to the TAP file is relative to the directory of the TAP archive.

=item * start_time

The time the test suite started to run. This time is given in epoch
seconds (seconds since 01/01/1970).

=item * stop_time

The time the test suite finished its run. This time is given in epoch
seconds (seconds since 01/01/1970).

=back

=head2 Full Example

Here's a slightly more complicated example (written in Perl) that
demonstates not only saving the TAP output to files, but also generating
a F<meta.yml> file to go along with it. We do this with the L<TAP::Harness::Archive>
module which does most of the work for us:

    #!/usr/bin/perl
    use warnings;
    use strict;
    use TAP::Harness::Archive;

    my @files = glob('t/*.t');
    my $harness = TAP::Harness::Archive->new({
        lib     => [ 'lib', 'blib/lib', 'blib/arch' ],
        archive => 'my_test_run.tar.gz',
    });
    $harness->runtests(@files);

Or you can use the F<runtests> utility that comes with L<TAP::Harness>
to this with the C<--archive> or C<-a> arguments.

    ]$ runtests t/*.t --archive my_test_run.tar.gz

=head1 RUNNING YOUR TESTS

Smolder tries as hard as possible to not dictacte how you write or
structure your tests. It even tries hard not to care how you run your
tests too much. But it does need some help to get the right information
in the right format (a TAP Archive)

=head2 Running

=head3 prove

The easiest way to run your tests for Smolder is to use the C<prove>
utility that comes with the L<Test::Harness> Perl module.  It has a
C<--archive> option that tells it to generate an archive of the TAP files.

    ]$ prove --archive my_test_run.tar.gz

=head3 Module::Build::TAPArchive

If you are using L<Module::Build> in Perl you could instead use the
L<Module::Build::TAPArchive> subclass which provides an extra build
action C<test_archive>.

    ]$ perl Build.PL && ./Build test_archive --archive_file my_test_run.tar.gz

=head3 Full Diagnostic Messages

Many times a failing test will output diagnostics messages giving more
information (ie, expected vs. received return values, etc). TAP output
is expected to be on STDOUT, but diagnostic information is usually on STDERR.
To capture all of this, simply use the C<--merge> flag for C<prove>.

=head3 SmokeRunner::Multi

Sometimes you have many different projects or different branches of the
same project that you would like to test from an SVN source checkout.
The Perl module L<SmokeRunner::Multi> was designed for just this purpose.

It can be used simply to run tests and output them to your screen, or
create TAP archives and even automatically upload it to a running Smolder
server.

=head3 Buildbot

Buildbot (L<http://buildbot.net>) is a neat Python tool that makes creating
a build farm nice and easy. With it you can setup a master build server
that has multiple slave build servers (running different platforms and
architectures). This is overkill for lots of scenarios, but is really
nice if your project needs to run on lots of systems.

Having Buildbot submit the test results is essentially the same as anything
else. You need to create a TAP archive and have it uploaded to Smolder.

=head2 Uploading to Smolder

The easiest way to automate the uploading of test results to a running
Smolder is to use the F<smolder_smoke_signal> utiltiy that comes with
Smolder. It takes a TAP archive file and uploads it to the Smolder server
of your choice.

    ]$ smolder_smoke_signal --server smolder.foo.com \
       --username myself --password s3cr3t --file test_report.tar.gz \
       --project MyProject

Or you can use the C<LWP> Perl library directly (and there's probably a way
to do it just using C<curl> from the command line.

    LWP::UserAgent->new()->post(
        'http://smolder.project.org/app/developer_projects/add_report/$project_id',
        Content_Type => 'form-data',
        Content      => [
            architecture => '386',
            platform     => 'Linux',
            comments     => $comments,
            username     => 'my-user',
            password     => 's3cr3t',
            report_file  => ['tap_archive.tar.gz'],
        ]
    );

=head2 Altogether Now

Typically, your automated test/upload code can be a bash script as simple
as this that you can run from cron:

    !#/bin/bash
    prove --archive test_run.tar.gz
    smolder_smoke_signal --server smolder.foo.com \
       --username myself --password s3cr3t --file test_run.tar.gz \
       --project MyProject

Pretty easy.

=head1 CONFIGURATION

TODO




