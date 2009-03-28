use strict;
use warnings;
use Module::Build;
use File::ShareDir qw(dist_dir);
use File::Spec::Functions qw(catdir);
use lib './t/lib';

my $builder = Module::Build->new(
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
        'Class::DBI::Plugin::RetrieveAll'            => 1.04,
        'Config::ApacheFormat'                       => 0,
        'Data::FormValidator'                        => 4.63,
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
        'File::HomeDir'                              => 0.86,
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
        'TAP::Harness::Archive'                      => 0.12,
        'Template::Plugin::Cycle'                    => 0,
        'URI::Escape'                                => 0,
        'URI::file'                                  => 0,
        'XML::Atom::SimpleFeed'                      => 0,
    },
    build_requires => {
        'Test::WWW::Mechanize' => 1.24,
        'Test::Builder'        => 0.86,
        'Test::More'           => 0.86,
    },
    install_path => {
        templates => catdir(dist_dir('Smolder'), 'templates'),
        htdocs    => catdir(dist_dir('Smolder'), 'htdocs'),
    },
    create_makefile_pl => 'traditional',
    create_readme      => 1,
);

$builder->create_build_script()
