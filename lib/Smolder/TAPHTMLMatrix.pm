package Smolder::TAPHTMLMatrix;
use strict;
use warnings;

use Test::TAP::Model::Visual;
use Test::TAP::Model::Consolidated;
use Carp qw/croak/;
use File::Spec;
use File::Path;
use URI::file;
use Template;
use Smolder::Conf qw(InstallRoot);
use Smolder::Control;

use overload '""' => "detail_html";

our $TMPL = Template->new(
    COMPILE_DIR  => File::Spec->catdir( InstallRoot, 'tmp' ),
    COMPILE_EXT  => '.ttc',
    INCLUDE_PATH => File::Spec->catdir( InstallRoot, 'templates' ),
    ABSOLUTE     => 1,
);

# use Smolder::Control's version
sub static_url {
    return Smolder::Control->static_url(shift);
}

sub new {
	my ( $pkg, @models ) = @_;

	my $ext = pop @models unless eval { $models[-1]->isa("Test::TAP::Model") };

	@models || croak "must supply a model to graph";

	my $self = bless {}, $pkg;

	$self->model(@models);
	
	$self;
}

sub title { 
    my ($self, $title) = @_;
    $self->{title} = $title if( $title );
    return $self->{title} || ("TAP Matrix - " . gmtime() . " GMT");
}

sub smoke_report { 
    my ($self, $report) = @_;
    $self->{smoke_report} = $report if( $report );
    return $self->{smoke_report};
}

sub tests {
	my $self = shift;
	[ sort { $a->name cmp $b->name } $self->model->test_files ];
}

sub model {
	my $self = shift;
	if (@_) {
		$self->{model} = $_[0]->isa("Test::TAP::Model::Consolidated")
			? shift
			: Test::TAP::Model::Consolidated->new(@_);
	}

	$self->{model};
}

sub tmpl_file {
	my $self = shift;
    my $file = shift;
    $self->{tmpl_file} = $file if $file;
    return $self->{tmpl_file}
}

sub tmpl_obj {
    my $self = shift;
    # use the package level var to hold the object
    # to use TT's in-memory caching
    return $TMPL;
}

sub detail_html {
	my $self = shift;
	$self->process_tmpl($self->tmpl_file);
}

sub test_detail_html {
	my ($self, $num) = @_;
    $self->detail_test_file($num);
	$self->process_tmpl($self->tmpl_file);
}

sub detail_test_file {
	my ($self, $num) = @_;
    if( $num ) {
        my $tests = $self->tests();
        $self->{detail_test_file} = $tests->[$num -1]->first_file;
    }
    return $self->{detail_test_file};
}

sub process_tmpl {
	my $self = shift;
    my $file = shift;
    my $output;
    my %params = (
        page         => $self,
        smoke_report => $self->smoke_report,
    );

    $self->tmpl_obj->process($file, \%params, \$output)
        or croak "Problem processing template file '$file': "
        , $self->tmpl_obj->error;
    return $output;
}

__END__

=pod

=head1 NAME

Smolder::TAPHTMLMatrix - Smolder derivative of L<Test::TAP::HTMLMatrix>.

=head1 SYNOPSIS

	use Smolder::TAPHTMLMatrix;
	use Test::TAP::Model::Visual;

	my $model = Test::TAP::Model::Visual->new(...);

	my $v = Smolder::TAPHTMLMatrix->new($model);

	print $v->detail_html;

=head1 DESCRIPTION

This module is a wrapper for a template and some visualization classes, that
knows to take a L<Test::TAP::Model> object, which encapsulates test results,
and produce a pretty html file.

=head1 METHODS

=over 4

=item new (@models)

@model is at least one L<Test::TAP::Model> object (or exactly one
L<Test::TAP::Model::Consolidated>)

=item detail_html

=item test_detail_html

Returns an HTML string for the corresponding template.

This is also the method implementing stringification.

=item model

=item tmpl_file

=item tmpl_obj

Just settergetters. You can override these for added fun.

=item title

A reasonable title for the page:

	"TAP Matrix - <gmtime>"

=item tests

A sorted array ref, resulting from $self->model->test_files;

=item detail_template

=item test_detail_template

=item summary_template

=item process_tmpl

Processes the L<Template> object returned from L<tmpl_obj> with the given
template and returns it.

=back

