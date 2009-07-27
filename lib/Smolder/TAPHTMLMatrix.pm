package Smolder::TAPHTMLMatrix;
use strict;
use warnings;
use Carp qw/croak/;
use File::Spec::Functions qw(catdir catfile tmpdir);
use File::Path;
use URI::file;
use Template;
use Smolder::Conf qw(TemplateDir);
use Smolder::Control;
use Template::Plugin::Cycle;

our $TMPL = Template->new(
    COMPILE_DIR  => tmpdir(),
    COMPILE_EXT  => '.ttc',
    INCLUDE_PATH => TemplateDir,
    FILTERS      => {
        pass_fail_color => \&Smolder::Util::pass_fail_color,
        format_time     => \&Smolder::Util::format_time,
    },
);

# use Smolder::Control's version
sub static_url {
    return Smolder::Control->static_url(shift);
}

sub new {
    my ($pkg, %args) = @_;
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

    my $meta        = $self->{meta}             || {};
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
                is_muted  => $test->{is_muted},
            },
            $save_file,
        ) or croak "Problem processing template file '$file': ", $TMPL->error;
        $count++;
    }
}

__END__

=pod

=head1 NAME

Smolder::TAPHTMLMatrix

