package Smolder::Control::DocSearch;
use base 'CGI::Application::Search';
use Smolder::Conf qw(InstallRoot);
use File::Spec::Functions qw(catfile catdir);

sub cgiapp_init {
    my $self = shift;
    my $self->param(
        SWISHE_INDEX        => catfile(InstallRoot, 'data', 'doc_search', 'swishe.index'),
        TEMPLATE            => 'DocSearch/search.tmpl',
        AJAX                => 1,
        TEMPLATE_TYPE       => 'TemplateToolkit',
        HIGHLIGHT_CLASS     => 'hilite',
        AUTO_SUGGEST        => 1,
        AUTO_SUGGEST_FILE   => catfile(InstallRoot, 'data', 'doc_search', 'swishe.words'),
        AUTO_SUGGEST_CACHE  => 1,
        AUTO_SUGGEST_LIMIT  => 10,
        DOCUMENT_ROOT       => catfile(InstallRoot, 'docs', 'html'),
    );
}

1;
