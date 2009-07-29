package Smolder::DB::Project;
use strict;
use warnings;
use base 'Smolder::DB';
use Smolder::DB::Developer;
use Smolder::Conf qw(DataDir);
use File::Path;
use File::Spec::Functions qw(catdir);

__PACKAGE__->set_up_table('project');
__PACKAGE__->has_many('project_developers' => 'Smolder::DB::ProjectDeveloper');
__PACKAGE__->has_many('smoke_reports'      => 'Smolder::DB::SmokeReport');

=head1 NAME

Smolder::DB::Project

=head1 DESCRIPTION

L<Class::DBI> based model class for the 'project' table in the database.

=head1 METHODS

=head2 ACCESSSOR/MUTATORS

Each column in the borough table has a method with the same name
that can be used as an accessor and mutator.

The following columns will return objects instead of the value contained in the table:

=cut

__PACKAGE__->has_a(
    start_date => 'DateTime',
    inflate    => sub { __PACKAGE__->parse_datetime(shift) },
    deflate    => sub { __PACKAGE__->format_datetime(shift) },
);

# make sure we delete any test_report directories associated with us
__PACKAGE__->add_trigger(
    after_delete => sub {
        my $self = shift;
        my $dir = catdir(DataDir, 'smoke_reports', $self->id);
        rmtree($dir) if (-d $dir);
    }
);

=over

=item start_date

This is a L<DateTime> object representing the datetime stored.

=back

=cut

=head2 OBJECT METHODS

=head3 developers

Returns an array of all L<Smolder::DB::Developer> objects associated with this
Project (using the C<project_developer> join table.

=cut

sub developers {
    my $self = shift;
    my $sth  = $self->db_Main->prepare_cached(
        qq(
        SELECT developer.* FROM developer, project_developer
        WHERE project_developer.project = ? AND project_developer.developer = developer.id
        ORDER BY project_developer.added
    )
    );
    $sth->execute($self->id);
    return Smolder::DB::Developer->sth_to_objects($sth);
}

=head3 has_developer

Return true if the given L<Smolder::DB::Developer> object is considered a member
of this Project.

    if( ! $project->has_developer($dev) ) {
        return "Unauthorized!";
    }

=cut

sub has_developer {
    my ($self, $developer) = @_;
    my $sth = $self->db_Main->prepare_cached(
        qq(
        SELECT COUNT(*) FROM project_developer
        WHERE project = ? AND developer = ?
    )
    );
    $sth->execute($self->id, $developer->id);
    my $row = $sth->fetchrow_arrayref();
    $sth->finish();
    return $row->[0];
}

=head3 admins 

Returns a list of L<Smolder::DB::Developer> objects who are considered 'admins'
for this Project

=cut

sub admins {
    my $self = shift;
    my $sth  = $self->db_Main->prepare_cached(
        qq(
        SELECT d.* FROM project_developer pd, developer d
        WHERE pd.project = ? AND pd.developer = d.id AND pd.admin = 1
        ORDER BY d.id
    )
    );
    $sth->execute($self->id);
    my @admins = Smolder::DB::Developer->sth_to_objects($sth);
    return @admins;
}

=head3 is_admin

Returns true if the given L<Smolder::DB::Developer> is considered an 'admin'
for this Project.

    if( $project->is_admin($developer) {
    ...
    }

=cut

sub is_admin {
    my ($self, $developer) = @_;
    if ($developer) {
        my $sth = $self->db_Main->prepare_cached(
            qq(
            SELECT admin FROM project_developer
            WHERE developer = ? AND project = ?
        )
        );
        $sth->execute($developer->id, $self->id);
        my $row = $sth->fetchrow_arrayref();
        $sth->finish();
        return $row->[0];
    } else {
        return;
    }
}

=head3 clear_admins

Removes the 'admin' flag from any Developers associated with this Project.

=cut

sub clear_admins {
    my ($self, @admins) = @_;
    my $sth;
    if (@admins) {
        my $place_holders = join(', ', ('?') x scalar @admins);
        $sth = $self->db_Main->prepare_cached(
            qq(
            UPDATE project_developer SET admin = 0
            WHERE project = ? AND developer IN ($place_holders)
        )
        );
    } else {
        $sth = $self->db_Main->prepare_cached(
            qq(
            UPDATE project_developer SET admin = 0
            WHERE project_developer.project = ?
        )
        );
    }
    $sth->execute($self->id, @admins);
}

=head3 set_admins

Given a list of Developer id's, this method will set each Developer
to be an admin of the Project.

=cut

sub set_admins {
    my ($self, @admins) = @_;
    my $place_holders = join(', ', ('?') x scalar @admins);
    my $sql = qq(
        UPDATE project_developer SET admin = 1
        WHERE project = ? AND developer IN ($place_holders)
    );
    my $sth = $self->db_Main->prepare_cached($sql);
    $sth->execute($self->id, @admins);
}

=head3 all_reports

Returns a list of L<Smolder::DB::SmokeReport> objects that are associate with this
Project in descending order (by default). You can provide optional 'limit' and 'offset' parameters
which will control which reports (and how many) are returned.

You can additionally specify a 'direction' parameter to specify the order in which they
are returned.

    # all of them
    my @reports = $project->all_reports();

    # just 5 most recent
    @reports = $project->all_reports(
        limit => 5
    );

    # the next 5
    @reports = $project->all_reports(
        limit   => 5,
        offset  => 5,
    );

    # in ascendig order
    @reports = $project->all_reports(
        direction   => 'ASC',
    );

=cut

sub all_reports {
    my ($self, %args) = @_;
    my $limit     = $args{limit}     || 0;
    my $offset    = $args{offset}    || 0;
    my $direction = $args{direction} || 'DESC';
    my $tag       = $args{tag};
    my @bind_vars = ($self->id);

    my $sql;
    if ($tag) {
        $sql = q/SELECT sr.* FROM smoke_report sr
        JOIN project p ON (sr.project = p.id)
        JOIN smoke_report_tag srt ON (srt.smoke_report = sr.id)
        WHERE p.id = ? AND srt.tag = ?/;
        push(@bind_vars, $tag);
    } else {
        $sql = q/SELECT sr.* FROM smoke_report sr
        JOIN project p ON (sr.project = p.id)
        WHERE p.id = ?/;
    }

    $sql .= " ORDER BY added $direction, sr.id DESC";
    $sql .= " LIMIT $offset, $limit " if ($limit);

    my $sth = $self->db_Main->prepare_cached($sql);
    $sth->execute(@bind_vars);
    return Smolder::DB::SmokeReport->sth_to_objects($sth);
}

=head3 report_count

The number of reports associated with this Project. Can also provide an
optional tag to use as well

=cut

sub report_count {
    my ($self, $tag) = @_;
    my @bind_vars = ($self->id);

    my $sql;
    if ($tag) {
        $sql = q/SELECT COUNT(*) FROM smoke_report sr
        JOIN project p ON (sr.project = p.id)
        JOIN smoke_report_tag srt ON (srt.smoke_report = sr.id)
        WHERE p.id = ? AND srt.tag = ?/;
        push(@bind_vars, $tag);
    } else {
        $sql = q/SELECT COUNT(*) FROM smoke_report sr
        JOIN project p ON (sr.project = p.id)
        WHERE p.id = ?/;
    }

    my $sth = $self->db_Main->prepare_cached($sql);
    $sth->execute(@bind_vars);
    my $row = $sth->fetchrow_arrayref();
    $sth->finish();
    return $row->[0];
}

=head3 report_graph_data

Will return an array of arrays (based on the given fields) that
is suitable for feeding to GD::Graph. To limit the date range
used to build the data, you can also pass a 'start' and 'stop'
L<DateTime> parameter.

    my $data = $project->report_graph_data(
        fields  => [qw(total pass fail)],
        start   => $start,
        stop    => DateTime->today(),
    );

=cut

sub report_graph_data {
    my ($self, %args) = @_;
    my $fields = $args{fields};
    my $start  = $args{start};
    my $stop   = $args{stop};
    my $tag    = $args{tag};
    my @data;
    my @bind_cols = ($self->id);

    # we need the date before anything else
    my $sql;
    if ($tag) {
        $sql =
            "SELECT "
          . join(', ', "added", @$fields)
          . " FROM smoke_report sr"
          . " JOIN smoke_report_tag srt ON (sr.id = srt.smoke_report)"
          . " WHERE sr.project = ? AND sr.invalid = 0 AND srt.tag = ?";
        push(@bind_cols, $tag);
    } else {
        $sql =
            "SELECT "
          . join(', ', "added", @$fields)
          . " FROM smoke_report sr"
          . " WHERE sr.project = ? AND sr.invalid = 0 ";
    }

    # if we need to limit by date
    if ($start) {
        $sql .= " AND DATE(sr.added) >= ? ";
        push(@bind_cols, $start->strftime('%Y-%m-%d'));
    }
    if ($stop) {
        $sql .= " AND DATE(sr.added) <= ? ";
        push(@bind_cols, $stop->strftime('%Y-%m-%d'));
    }

    # add optional args
    foreach my $extra_param qw(architecture platform) {
        if ($args{$extra_param}) {
            $sql .= " AND sr.$extra_param = ? ";
            push(@bind_cols, $args{$extra_param});
        }
    }

    # add the ORDER BY
    $sql .= " ORDER BY sr.added ";

    my $sth = $self->db_Main->prepare_cached($sql);
    $sth->execute(@bind_cols);
    while (my $row = $sth->fetchrow_arrayref()) {

        # reformat added - used to do this in SQL with DATE_FORMAT(),
        # but SQLite don't play that game
        my ($year, $month, $day) = $row->[0] =~ /(\d{4})-(\d{2})-(\d{2})/;
        $row->[0] = "$month/$day/$year";

        for my $i (0 .. scalar(@$row) - 1) {
            push(@{$data[$i]}, $row->[$i]);
        }
    }
    return \@data;
}

=head3 platforms

Returns an arrayref of all the platforms that have been associated with
smoke tests uploaded for this project.

=cut

sub platforms {
    my $self = shift;
    my $sth  = $self->db_Main->prepare_cached(
        q(
        SELECT DISTINCT platform FROM smoke_report
        WHERE platform != '' AND project = ? ORDER BY platform
    )
    );
    $sth->execute($self->id);
    my @plats;
    while (my $row = $sth->fetchrow_arrayref) {
        push(@plats, $row->[0]);
    }
    return \@plats;
}

=head3 architectures

Returns a list of all the architectures that have been associated with
smoke tests uploaded for this project.

=cut

sub architectures {
    my $self = shift;
    my $sth  = $self->db_Main->prepare_cached(
        q(
        SELECT DISTINCT architecture FROM smoke_report
        WHERE architecture != '' AND project = ? ORDER BY architecture
    )
    );
    $sth->execute($self->id);
    my @archs;
    while (my $row = $sth->fetchrow_arrayref) {
        push(@archs, $row->[0]);
    }
    return \@archs;
}

=head3 tags

Returns a list of all of tags that have been added to smoke reports for
this project (in the smoke_report_tag table).

    # returns a simple list of scalars
    my @tags = $project->tags();

    # returns a hash of the tag value and count, ie { tag => 'foo', count => 20 }
    my @tags = $project->tags(with_counts => 1);

=cut

sub tags {
    my ($self, %args) = @_;
    my @tags;
    if ($args{with_counts}) {
        my $sth = $self->db_Main->prepare_cached(
            q/
            SELECT srt.tag, COUNT(*) FROM smoke_report_tag srt
            JOIN smoke_report sr ON (sr.id = srt.smoke_report)
            WHERE sr.project = ? GROUP BY srt.tag ORDER BY srt.tag/
        );
        $sth->execute($self->id);
        while (my $row = $sth->fetchrow_arrayref()) {
            push(@tags, {tag => $row->[0], count => $row->[1]});
        }
    } else {
        my $sth = $self->db_Main->prepare_cached(
            q/
            SELECT DISTINCT(srt.tag) FROM smoke_report_tag srt 
            JOIN smoke_report sr ON (sr.id = srt.smoke_report) 
            WHERE sr.project = ? ORDER BY srt.tag/
        );
        $sth->execute($self->id);
        while (my $row = $sth->fetchrow_arrayref()) {
            push(@tags, $row->[0]);
        }
    }
    return @tags;

}

=head3 delete_tag

Deletes a tag in the smoke_report_tag table for Smoke Reports associated with this Project.

    $project->delete_tag("Something Old");

=cut

sub delete_tag {
    my ($self, $tag) = @_;

    # because SQL doesn't support multi-table deletes (with a USING clause)
    # we need to resort to doing this in 2 steps
    my $sth = $self->db_Main->prepare_cached(
        q/
        SELECT id FROM smoke_report_tag WHERE tag = ?
    /
    );
    $sth->execute($tag);
    my $tag_ids = $sth->fetchall_arrayref([0]);

    my $placeholders = join(', ', ('?') x scalar(@$tag_ids));
    $sth = $self->db_Main->prepare_cached(
        qq/
        DELETE FROM smoke_report_tag WHERE id IN ($placeholders)
    /
    );
    $sth->execute(map { $_->[0] } @$tag_ids);
}

=head3 change_tag

This method will change a tag of project's smoke reports into some other tag

    $project->change_tag('Something', 'Something Else');

=cut

sub change_tag {
    my ($self, $tag, $repl) = @_;

    # because SQL doesn't support multi-table updates (with a USING clause)
    # we need to resort to doing this in 2 steps
    my $sth = $self->db_Main->prepare_cached('SELECT id FROM smoke_report_tag WHERE tag = ?');
    $sth->execute($tag);
    my $tag_ids = $sth->fetchall_arrayref([0]);

    my $placeholders = join(', ', ('?') x scalar(@$tag_ids));
    $sth = $self->db_Main->prepare_cached(
        "UPDATE smoke_report_tag SET tag = ? WHERE id IN ($placeholders)");
    $sth->execute($repl, map { $_->[0] } @$tag_ids);
}

=head3 graph_start_datetime

Returns a L<DateTime> object that represents the real date for the value
stored in the 'graph_start' column. For example, if the current date
were March 17, 2006 and the project was started on Feb 20th, 2006 
then the following values would become the following dates:

    project => Feb 20th, 2006
    year    => Jan 1st,  2006
    month   => Mar 1st,  2006
    week    => Mar 13th, 2006
    day     => Mar 17th, 2006

=cut

sub graph_start_datetime {
    my $self = shift;
    my $dt;

    # the project's start date
    if ($self->graph_start eq 'project') {
        $dt = $self->start_date;

        # the first day of this year
    } elsif ($self->graph_start eq 'year') {
        $dt = DateTime->today()->set(
            month => 1,
            day   => 1,
        );

        # the first day of this month
    } elsif ($self->graph_start eq 'month') {
        $dt = DateTime->today()->set(day => 1);

        # the first day of this week
    } elsif ($self->graph_start eq 'week') {
        $dt = DateTime->today;
        my $day_diff = $dt->day_of_week - 1;
        $dt->subtract(days => $day_diff) if ($day_diff);

        # today
    } elsif ($self->graph_start eq 'day') {
        $dt = DateTime->today();
    }
    return $dt;
}

=head3 purge_old_reports 

This method will check to see if the C<max_reports> limit has been reached
for this project and delete the tap archive files associated with those
reports, also marking the reports as C<purged>.

=cut

sub purge_old_reports {
    my $self = shift;
    if ($self->max_reports) {

        # Delete any non-purged reports that pass the above limit
        my $sth = $self->db_Main->prepare_cached(
            q(
            SELECT id FROM smoke_report
            WHERE project = ? AND purged = 0
            ORDER BY added DESC
            LIMIT 1000000 OFFSET 
        ) . $self->max_reports
        );
        $sth->execute($self->id);
        my (@ids, $id);
        $sth->bind_col(1, \$id);
        push(@ids, $id) while ($sth->fetch);
        $sth->finish();

        foreach my $id (@ids) {
            my $report = Smolder::DB::SmokeReport->retrieve($id);
            $report->delete_files();
            $report->purged(1);
            $report->update();
        }
    }
}

=head3 most_recent_report

Returns the most recent L<Smolder::DB::SmokeReport> object that was added.

=cut

sub most_recent_report {
    my $self = shift;
    my $sth  = $self->db_Main->prepare_cached(
        q/
        SELECT * FROM smoke_report
        WHERE project = ?
        ORDER BY added DESC
        LIMIT 1
    /
    );
    $sth->execute($self->id);
    my ($report) = Smolder::DB::SmokeReport->sth_to_objects($sth);
    return $report;
}

=head3 app_prefix

Returns "/app/developer_projects" or "/app/public_projects" as appropriate for this project.

=cut

sub app_prefix {
    my $self = shift;

    return "/app/" . ($self->public ? "public_projects" : "developer_projects");
}

=head2 CLASS METHODS

=head3 all_names

Returns an array containing all the names of all existing projects.
Can receive an extra arg that is the id of a project who's name should
not be returned.

=cut

sub all_names {
    my ($class, $id) = @_;
    my $sql = "SELECT NAME FROM project";
    $sql .= " WHERE id != $id" if ($id);
    my $sth = $class->db_Main->prepare_cached($sql);
    $sth->execute();
    my @names;
    while (my $row = $sth->fetchrow_arrayref()) {
        push(@names, $row->[0]);
    }
    return @names;
}

1;
