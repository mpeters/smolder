package Smolder::TestData;
use strict;
use warnings;
use base 'Exporter';
use Smolder::Conf qw(HostName Port);
use Smolder::DB;
use File::Spec::Functions qw(catfile);
use File::Copy qw(copy);
use LWP::UserAgent;

our @EXPORT_OK = qw(
  create_project
  delete_projects
  create_developer
  delete_developers
  create_preference
  delete_preferences
  create_smoke_report
  delete_smoke_reports
  delete_tags
  logout
  is_smolder_running
  base_url
  db_field_value
);

=head1 NAME

Smolder::TestData

=head1 SYNOPSIS

    use Smolder::TestData qw(create_project delete_projects);
    my $proj1 = create_project();
    my $proj2 = create_project();
    delete_projects();

=head1 DESCRIPTION

This module provides some routines that are useful for testing.

=head1 ROUTINES

=head2 create_project

Will create a L<Smolder::DB::Project> object and return it.
Name-value args may be passed in to override the defaults.

    my $proj1 = create_project();
    my $proj2 = create_project(name => 'stuff');

=head2 delete_projects

Will delete all projects that were created by L<create_project>.

=cut

# used as a closure to increment by various routines
my $count = 0;
{

    my @projects;

    sub create_project {
        my %args = @_;
        require DateTime;
        require Smolder::DB::Project;

        # set some defaults
        %args = (
            name       => "Testing" . $count++,
            start_date => DateTime->now(),
            public     => 1,
            %args,
        );
        my $proj = Smolder::DB::Project->create(\%args);
        push(@projects, $proj);
        return $proj;
    }

    sub delete_projects {
        foreach my $proj (@projects) {
            if ($proj && ref $proj ne 'Class::DBI::Object::Has::Been::Deleted') {
                $proj->delete();
            }
        }
    }
}

=head2 create_developer

Will create a L<Smolder::DB::Developer> object and return it.
Name-value args may be passed in to override the defaults.

    my $proj1 = create_project();
    my $proj2 = create_project(name => 'stuff');

=head2 delete_developers

Will delete all developers that were created by L<create_developer>.

=cut

{
    my @developers = ();

    sub create_developer {
        my %args = @_;
        require Smolder::DB::Developer;

        # set some defaults
        %args = (
            username   => 'testing_' . $count++,
            fname      => 'Name' . $count++,
            lname      => 'Developer' . $count++,
            email      => 'test_' . $count++ . '@test.com',
            password   => 'testing',
            admin      => 0,
            preference => create_preference(),
            %args,
        );
        my $dev = Smolder::DB::Developer->create(\%args);
        push(@developers, $dev);
        return $dev;
    }

    sub delete_developers {
        foreach my $dev (@developers) {
            if ($dev && ref $dev ne 'Class::DBI::Object::Has::Been::Deleted') {
                $dev->delete();
            }
        }
    }

}

=head2 create_preference

Will create a L<Smolder::DB::Preference> object and return it.
Name-value args may be passed in to override the defaults.

    my $proj1 = create_project();
    my $proj2 = create_project(name => 'stuff');

=head2 delete_preferences

Will delete all preferences that were created by L<create_preference>.

=cut

{
    my @preferences = ();

    sub create_preference {
        my %args = @_;
        require Smolder::DB::Preference;

        # set some defaults
        %args = (
            email_type => 'full',
            email_freq => 'daily',
            %args,
        );
        my $pref = Smolder::DB::Preference->create(\%args);
        push(@preferences, $pref);
        return $pref;
    }

    sub delete_preferences {
        foreach my $pref (@preferences) {
            if ($pref && ref $pref ne 'Class::DBI::Object::Has::Been::Deleted') {
                $pref->delete();
            }
        }
    }

}

=head2 create_smoke_report

Will create a L<Smolder::DB::SmokeReport> object and return it.
Name-value args may be passed in to override the defaults.
You must provide both a project and a developer upon creation.

    my $report  = create_smoke_report(
        project     => $project,
        developer   => $dev,
    );
    my $report2 = create_smoke_report(
        platform    => 'Windows NT',
        project     => $project,
        developer   => $dev,
    );

=head2 delete_smoke_reports

Will delete all test reports create by L<create_smoke_report>.

=cut

{
    my @reports;

    sub create_smoke_report {
        my %args = @_;
        require Smolder::DB::SmokeReport;

        my $tags = delete $args{tags} || [];

        # set some defaults
        %args = (
            file         => catfile(Smolder::Conf->test_data_dir, 'test_run_bad_yml.tar.gz'),
            architecture => 'x386',
            platform     => 'Linux',
            %args,
        );
        my $report = Smolder::DB::SmokeReport->upload_report(%args);

        # now add any tags
        $report->add_tag($_) foreach (@$tags);

        return $report;
    }

    sub delete_smoke_reports {
        foreach my $report (@reports) {
            if ($report && ref $report ne 'Class::DBI::Object::Has::Been::Deleted') {
                $report->delete();
            }
        }
    }
}

=head2 delete_tags

Delete the tags with the given names

  delete_tags('foo', 'bar');

=cut

sub delete_tags {
    my @tags = @_;
    my $sth  = Smolder::DB->db_Main->prepare_cached('DELETE FROM smoke_report_tag WHERE tag = ?');
    foreach my $t (@tags) {
        $sth->execute($t);
    }
}

=head2 is_smolder_running

Returns true if Smolder is up and running. Else returns false.  Perfect to
use in controller tests that will skip the test if it's not running.

=cut

sub is_smolder_running {
    _can_reach_url('http://' . HostName . ':' . Port . '/app');
}

sub _can_reach_url {
    my $url = shift;

    # Create a user agent object
    use LWP::UserAgent;
    my $ua = LWP::UserAgent->new;
    $ua->timeout(10);
    my $res = $ua->get($url);

    # Check the outcome of the response
    return $res->is_success;
}

=head2 base_url

Returns the base url for the dynamic portions of the site.

=cut

sub base_url {
    return 'http://' . HostName . ':' . Port . '/app';
}

=head2 db_field_value 

Returns the value for a given database field given the table, field and id.

    db_field_value('developer', 'password', '23');

=cut

sub db_field_value {
    my ($table, $field, $id) = @_;
    my $sth = Smolder::DB->db_Main->prepare_cached("SELECT $field FROM $table WHERE id = ?");
    $sth->execute($id);
    my $row = $sth->fetchrow_arrayref();
    $sth->finish();
    return $row->[0];
}

1;
