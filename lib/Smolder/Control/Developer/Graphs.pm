package Smolder::Control::Developer::Graphs;
use base 'Smolder::Control';
use strict;
use warnings;

use Smolder::Conf qw(InstallRoot);
use Smolder::DB::Project;
use Smolder::DB::SmokeReport;

use DateTime;
use DateTime::Format::Strptime;
use File::Spec::Functions qw(catdir);
use GD::Graph::area;
use GD::Graph::bars3d;
use GD::Graph::lines3d;
use GD::Graph::linespoints;
use GD::Text;
use HTML::FillInForm;

# allowable graph types
our %TYPE_MAP = (
    bar    => 'bars3d',
    line   => 'lines3d',
    area   => 'area',
    points => 'linespoints',
);

# corresponding color and legend for each data type
our @FIELDS = qw(total pass fail todo skip);
our %FIELDS = (
    total => [qw(lblue Total)],
    pass  => [qw(green Pass)],
    fail  => [qw(red Fail)],
    todo  => [qw(lorange TODO)],
    skip  => [qw(lyellow Skip)],
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

sub start {
    my ( $self, $tt_params ) = @_;
    $tt_params ||= {};

    my $project = Smolder::DB::Project->retrieve( $self->param('id') );
    return $self->error_message('Project does not exist')
      unless $project;

    $tt_params->{project} = $project;

    # the defaults
    my %fill_data = (
        start => $project->start_date->strftime(' %m/%d/%Y'),
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

sub image {
    my $self  = shift;
    my $query = $self->query();

    my $project = Smolder::DB::Project->retrieve( $self->param('id') );
    return $self->error_message('Project does not exist')
      unless $project;

    my $category = $query->param('category');

    my ( $start, $stop );
    my $dt_format = DateTime::Format::Strptime->new( pattern => '%m/%d/%Y', );
    if ( $query->param('start') ) {
        $start = $dt_format->parse_datetime( $query->param('start') );
    } else {
        $start = $project->start_date;
    }
    if ( $query->param('stop') ) {
        $stop = $dt_format->parse_datetime( $query->param('stop') );
    } else {
        $stop = DateTime->today();
    }

    # by default, show pass vs fail
    my @fields;

    # which fields do we need?
    if ( $query->param('change') ) {
        foreach my $field (@FIELDS) {
            push( @fields, $field ) if ( $query->param($field) );
        }
    } else {
        @fields = qw(pass fail);
    }

    my $data = $project->report_graph_data(
        fields   => \@fields,
        start    => $start,
        stop     => $stop,
        category => $category,
    );

    # handle empty data results and redirect to a 'no_graph_data.png' file
    if ( scalar @$data == 0 ) {
        $self->header_add( -uri => '/images/no_graph_data.png' );
        $self->header_type('redirect');
        return "no data";
    }

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

    $self->header_type('none');
    my $r = $self->param('r');
    $r->no_cache(1);
    $r->send_http_header('image/png');

    print $gd->png();
}

sub _create_progress_gd {
    my ( $self, %args ) = @_;
    my $data   = $args{data};
    my $colors = $args{colors};
    my $legend = $args{legend};
    my $title  = $args{title};

    # what type of graph are we?
    my $type = $TYPE_MAP{ $self->param('type') } || 'bars3d';

    # we just want to show the first, middle and last
    my $x_skip = int( ( scalar( @{ $data->[0] } ) - 1 ) / 2 ) + 1;

    my $class = 'GD::Graph::' . $type;
    my $graph = $class->new( 600, 300 );
    $graph->set(
        title                => $title,
        bgclr                => 'white',
        fgclr                => 'gray',
        textclr              => 'dgray',
        axislabelclr         => 'dgray',
        labelclr             => 'dgray',
        dclrs                => $colors,
        y_label              => '# of Tests',
        x_label_skip         => $x_skip,
        overwrite            => 1,
        legend_placement     => 'RT',
        legend_marker_width  => 20,
        legend_marker_height => 20,
        legend_spacing       => 8,
        x_labels_vertical    => 0,
      )
      or die "Could not set graph attributes! - " . $graph->error();
    $graph->set_legend(@$legend);

    # set the font to arial
    my $font = GD::Text->new();
    $font->font_path( catdir( InstallRoot, 'data', 'fonts' ) );
    $font->set_font( 'arial', 12 ) or croak( "Can't set font: " . $font->error );
    $font->is_ttf() or croak("Font didn't really load!");

    # setup fonts
    $graph->set_title_font( 'arialbd', 12 ) or croak( "Can't set font: " . $graph->error );
    $graph->set_legend_font( 'arial', 10 ) or croak( "Can't set font: " . $graph->error );
    $graph->set_x_label_font( 'arial', 10 ) or croak( "Can't set font: " . $graph->error );
    $graph->set_y_label_font( 'arial', 10 ) or croak( "Can't set font: " . $graph->error );
    $graph->set_x_axis_font( 'arial', 10 ) or croak( "Can't set font: " . $graph->error );
    $graph->set_y_axis_font( 'arial', 10 ) or croak( "Can't set font: " . $graph->error );
    $graph->set_values_font( 'arial', 10 ) or croak( "Can't set font: " . $graph->error );

    my $gd = $graph->plot($data)
      or die "Could not plot graph into GD object! - " . $graph->error();
    return $gd;
}

1;
