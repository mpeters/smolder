use strict;
use warnings;
use File::Spec::Functions qw(catdir);
use Config;
use lib 'lib';
use Smolder::Build;

my $SHARE_DIR = catdir($Config{installsitelib}, 'auto', 'share', 'Smolder');

my $builder = Smolder::Build->new(
    module_name       => 'Smolder',
    license           => 'perl',
    dist_author       => 'Michael Peters <mpeters@plusthree.com>',
    dist_version_from => 'lib/Smolder.pm',
    requires          => {
        'CGI::Application'                           => 4.21,
        'CGI::Application::Dispatch'                 => 2.15,
        'CGI::Application::Server'                   => 0.060,
        'CGI::Application::Plugin::JSON'             => 1.01,
        'CGI::Application::Plugin::LogDispatch'      => 1.02,
        'CGI::Application::Plugin::Stream'           => 2.06,
        'CGI::Application::Plugin::TT'               => 1.04,
        'CGI::Application::Plugin::ValidateRM'       => 2.3,
        'Class::DBI'                                 => 3.0,
        'Class::DBI::SQLite'                         => 0,
        'Class::DBI::Plugin::RetrieveAll'            => 1.04,
        'Config::ApacheFormat'                       => 0,
        'Data::FormValidator'                        => 4.61,
        'Data::FormValidator::Constraints::DateTime' => 1.09,
        'Data::Random'                               => 0.05,
        'DateTime'                                   => 0.4501,
        'DateTime::Format::MySQL'                    => 0,
        'DateTime::Format::Strptime'                 => 0,
        'DBD::SQLite'                                => 1.12,
        'Digest::MD5'                                => 0,
        'Email::Valid'                               => 0,
        'Exception::Class'                           => 1.23,
        'File::MMagic'                               => 0,
        'File::ShareDir'                             => 1.00,
        'File::HomeDir'                              => 0.80,
        'Getopt::Long'                               => 0,
        'GD::Graph'                                  => 0,
        'GD::Graph3d'                                => 0,
        'GD::Text'                                   => 0,
        'HTML::FillInForm'                           => 2.00,
        'HTML::FormatText::WithLinks'                => 0,
        'HTML::TagCloud'                             => 0.34,
        'IO::Scalar'                                 => 0,
        'IO::Zlib'                                   => 0,
        'JSON'                                       => 0,
        'MIME::Lite'                                 => 0,
        'Pod::Usage'                                 => 0,
        'TAP::Harness::Archive'                      => 0.12,
        'Template::Plugin::Cycle'                    => 0,
        'Template::Plugin::Number::Format'           => 0,
        'URI::Escape'                                => 0,
        'URI::file'                                  => 0,
        'XML::Atom::SimpleFeed'                      => 0,
    },
    configure_requires => {
        'Module::Build'             => 0,
        'Module::Build::TAPArchive' => 0,
    },
    build_requires => {
        'Test::WWW::Mechanize'      => 1.22,
        'Test::Builder'             => 0.86,
        'Test::More'                => 0.86,
        'LWP::UserAgent'            => 0,
        'WWW::Mechanize'            => 0,
        'IPC::Run'                  => 0.82,
        'File::Find'                => 0,
        'File::Copy'                => 0,
        'Module::Build'             => 0,
        'Module::Build::TAPArchive' => 0,
    },
    install_path => {
        templates => catdir($SHARE_DIR, 'templates'),
        sql       => catdir($SHARE_DIR, 'sql'),
        htdocs    => catdir($SHARE_DIR, 'htdocs'),
    },
    add_to_cleanup     => ['data/*', 'logs/*', 'Smolder-*'],
);

$builder->add_build_element('templates');
$builder->add_build_element('sql');
$builder->add_build_element('htdocs');

$builder->create_build_script();
