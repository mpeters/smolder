package Smolder::Control::Graphs;
use base 'Smolder::Control';
use strict;
use warnings;
use Smolder::Conf;
use Smolder::DB::Project;
use Smolder::DB::SmokeReport;
use DateTime;
use DateTime::Format::Strptime;
use File::Spec::Functions qw(catdir catfile);
use GD::Graph::area;
use GD::Graph::bars3d;
use GD::Graph::lines3d;
use GD::Graph::linespoints;
use GD::Text;
use HTML::FillInForm;

=head1 NAME

Smolder::Control::Graphs

=head1 DESCRIPTION

Controller module for generating graph images.

=cut

# allowable graph types
my %TYPE_MAP = (
    bar    => 'bars3d',
    line   => 'lines3d',
    area   => 'area',
    points => 'linespoints',
);

# corresponding color and legend for each data type
my %FIELDS = (
    total    => [qw(lblue Total)],
    pass     => [qw(green Pass)],
    fail     => [qw(red Fail)],
    todo     => [qw(lorange TODO)],
    skip     => [qw(lyellow Skip)],
    duration => [qw(lbrown Duration)],
);

sub setup {
    my $self = shift;
    $self->start_mode('start');
    $self->run_modes(
        [
            qw(
              start
              image
              )
        ]
    );
}

=head1 RUN MODES

=head2 start

Display the initial start form for a project's graph with some
reasonable defaults. Uses the F<Developer/Graphs/start.tmpl>
template.

=cut

sub start {
    my ($self, $tt_params) = @_;
    $tt_params ||= {};

    my $project = Smolder::DB::Project->retrieve($self->param('id'));
    return $self->error_message('Project does not exist')
      unless $project;

    # make sure ths developer is a member of this project
    return $self->error_message('Unauthorized for this project')
      unless $self->can_see_project($project);

    $tt_params->{project} = $project;

    # the defaults
    my %fill_data = (
        start => $project->graph_start_datetime->strftime(' %m/%d/%Y'),
        stop  => DateTime->today()->strftime('%m/%d/%Y'),
        pass  => 1,
        fail  => 1,
        type  => 'bar',
    );

    return HTML::FillInForm->new()->fill(
        scalarref => $self->tt_process($tt_params),
        fdat      => \%fill_data,
    );
}

=head2 image

Creates and returns a graph image to the browser based on the parameters
chosen by the user.

=cut

sub image {
    my $self  = shift;
    my $query = $self->query();

    my $project = Smolder::DB::Project->retrieve($self->param('id'));
    return $self->error_message('Project does not exist')
      unless $project;

    my ($start, $stop);
    my $dt_format = DateTime::Format::Strptime->new(pattern => '%m/%d/%Y',);
    if ($query->param('start')) {
        $start = $dt_format->parse_datetime($query->param('start'));
    } else {
        $start = $project->graph_start_datetime;
    }
    if ($query->param('stop')) {
        $stop = $dt_format->parse_datetime($query->param('stop'));
    } else {
        $stop = DateTime->today();
    }
    $self->log->debug("Graph starting $start and ending $stop");

    # which fields do we need to show?
    my @fields;
    if ($query->param('change')) {
        foreach my $field (keys %FIELDS) {
            push(@fields, $field) if ($query->param($field));
        }
    } else {

        # by default, show pass vs fail
        @fields = qw(pass fail);
    }

    my %search_params = (
        start => $start,
        stop  => $stop,
    );

    foreach my $extra_param (qw(tag architecture platform)) {
        $search_params{$extra_param} = $query->param($extra_param)
          if ($query->param($extra_param));
    }

    my $data = $project->report_graph_data(
        fields => \@fields,
        %search_params,
    );

    # send out our own headers
    # XXX - fix to use CGI.pm no Apache to send no-cache image/png headers'
    $self->header_type('none');

    # if we don't have any data, then just send the no_graph_data.png file
    if (scalar @$data == 0) {
        my $NO_DATA_FH;
        my $file = catfile(Smolder::Conf->get('HtdocsDir'), 'images', 'no_graph_data.png');
        open($NO_DATA_FH, '<', $file)
          or die "Could not open '$file' for reading: $!";
        local $/ = undef;
        print <$NO_DATA_FH>;
        close($NO_DATA_FH) or die "Could not close file '$file': $!";
    } else {

        # else create the graph and send it
        my @colors = map { $FIELDS{$_}->[0] } @fields;
        my @legend = map { $FIELDS{$_}->[1] } @fields;

        my $title = "'"
          . $project->name
          . "' Smoke Progress ("
          . $start->strftime('%m/%d/%Y') . ' - '
          . $stop->strftime('%m/%d/%Y') . ')';
        my $gd = $self->_create_progress_gd(
            colors => \@colors,
            data   => $data,
            legend => \@legend,
            title  => $title,
        );
        print $gd->png;
    }
}

sub _create_progress_gd {
    my ($self, %args) = @_;
    my $data   = $args{data};
    my $colors = $args{colors};
    my $legend = $args{legend};
    my $title  = $args{title};

    # what type of graph are we?
    my $type = $TYPE_MAP{$self->param('type')} || 'bars3d';

    # we just want to show the first, middle and last labels
    # on the X axis
    my $x_skip = int((scalar(@{$data->[0]}) - 1) / 2) + 1;

    # find the maximun value for the Y axis
    my $y_max = 0;
    for my $i (1 .. $#$data) {
        foreach my $point (@{$data->[$i]}) {
            $y_max = $point if ($point > $y_max);
        }
    }

    # now round up to the nearest 100
    $y_max = ($y_max + 100) - ($y_max % 100);

    my $class = 'GD::Graph::' . $type;
    my $graph = $class->new(600, 300);
    $graph->set(
        title                => $title,
        bgclr                => 'white',
        fgclr                => 'gray',
        textclr              => 'dgray',
        axislabelclr         => 'dgray',
        labelclr             => 'dgray',
        dclrs                => $colors,
        y_label              => '# of Tests',
        y_max_value          => $y_max,
        x_label_skip         => $x_skip,
        overwrite            => 1,
        legend_placement     => 'RT',
        legend_marker_width  => 20,
        legend_marker_height => 20,
        legend_spacing       => 8,
        x_labels_vertical    => 0,
    ) or die "Could not set graph attributes! - " . $graph->error();
    $graph->set_legend(@$legend);

    my $gd = $graph->plot($data)
      or die "Could not plot graph into GD object! - " . $graph->error();
    return $gd;
}

1;
