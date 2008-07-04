package Smolder::TAPHTMLMatrix;
use strict;
use warnings;

use Carp qw/croak/;
use File::Spec::Functions qw(catdir catfile);
use File::Path;
use URI::file;
use Template;
use Smolder::Conf qw(InstallRoot);
use Smolder::Control;
use Template::Plugin::Cycle;

our $TMPL = Template->new(
    COMPILE_DIR  => catdir( InstallRoot, 'tmp' ),
    COMPILE_EXT  => '.ttc',
    INCLUDE_PATH => catdir( InstallRoot, 'templates' ),
    FILTERS => {
        pass_fail_color => \&Smolder::Util::pass_fail_color,
        format_time     => \&Smolder::Util::format_time,
    },
);

# use Smolder::Control's version
sub static_url {
    return Smolder::Control->static_url(shift);
}

sub new {
	my ( $pkg, %args ) = @_;
    my $self = bless(\%args, $pkg);
	return $self;
}

sub report  { shift->{smoke_report} }
sub results { shift->{test_results} }

sub generate_html {
	my $self = shift;

    # where are we saving the results
    my $dir = catdir($self->report->data_dir, 'html');
    unless (-d $dir) {
        mkpath($dir) or croak "Could not create directory '$dir'! $!";
    }
    my $file = catfile($dir, 'report.html');

    my $meta = $self->{meta} || {};
    my $extra_props = $meta->{extra_properties} || {};

    # process the full report
    my $odd_even = Template::Plugin::Cycle->new(qw(odd even));
    $TMPL->process(
        'TAP/full_report.tmpl',
        {
            report           => $self->report,
            results          => $self->results,
            odd_even         => $odd_even,
            url_base         => Smolder::Util::url_base(),
            extra_properties => $extra_props,
        },
        $file,
    ) or croak $TMPL->error;

    # now generate the HTML for each individual file
    my $count = 0;
    foreach my $test (@{$self->results}) {
        my $save_file = catfile($dir, $count . '.html');
        $TMPL->process(
            'TAP/individual_test.tmpl',
            {
                report    => $self->report,
                test_file => $test->{label},
                tests     => $test->{tests},
                odd_even  => $odd_even,
                url_base  => Smolder::Util::url_base(),
            },
            $save_file,
        ) or croak "Problem processing template file '$file': ", $TMPL->error;
        $count++;
    }
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

