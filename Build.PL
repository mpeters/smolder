use strict;
use warnings;
use File::Spec::Functions qw(catdir);
use Config;
use lib 'lib';
use Smolder::Build;

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
        'CGI::Application::Plugin::Stream'           => 2.10,
        'CGI::Application::Plugin::TT'               => 1.04,
        'CGI::Application::Plugin::ValidateRM'       => 2.3,
        'Class::DBI'                                 => 3.0,
        'Class::DBI::AbstractSearch'                 => 0.07,
        'Class::DBI::SQLite'                         => 0,
        'Class::DBI::Plugin::RetrieveAll'            => 1.04,
        'Data::FormValidator'                        => 4.61,
        'Data::FormValidator::Constraints::DateTime' => 1.09,
        'Data::Random'                               => 0.05,
        'DateTime'                                   => 0.4501,
        'DateTime::Format::Strptime'                 => 0,
        'DBD::SQLite'                                => 1.20,
        'Digest::MD5'                                => 0,
        'Email::Valid'                               => 0,
        'Exception::Class'                           => 1.23,
        'File::MMagic'                               => 0,
        'File::ShareDir'                             => 1.00,
        'File::HomeDir'                              => 0.80,
        'File::Slurp'                                => 0,
        'File::Temp'                                 => 0.21,
        'File::Path'                                 => 2.04,
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
        'Net::Server::PreFork'                       => 0,
        'Pod::Usage'                                 => 0,
        'TAP::Harness::Archive'                      => 0.12,
        'Test::Harness'                              => 3.17,
        'Template::Plugin::Cycle'                    => 0,
        'Template::Plugin::Number::Format'           => 0,
        'URI::Escape'                                => 0,
        'URI::file'                                  => 0,
        'XML::Atom::SimpleFeed'                      => 0,
    },
    configure_requires => {
        'Module::Build'             => 0,
    },
    build_requires => {
        'Test::WWW::Mechanize'      => 1.22,
        'Test::Builder'             => 0.86,
        'Test::More'                => 0.86,
        'LWP::UserAgent'            => 0,
        'IPC::Run'                  => 0.82,
        'WWW::Mechanize'            => 0,
        'File::Find'                => 0,
        'File::Copy'                => 0,
        'Module::Build'             => 0,
    },
    add_to_cleanup     => ['data/*', 'logs/*', 'Smolder-*'],
    meta_add => {
        no_index => {
            file => [qw(
                lib/Smolder/AuthHandler.pm
                lib/Smolder/AuthInfo.pm
                lib/Smolder/Build.pm
                lib/Smolder/Conf.pm
                lib/Smolder/Constraints.pm
                lib/Smolder/Control.pm
                lib/Smolder/Control/Admin.pm
                lib/Smolder/Control/Developer.pm
                lib/Smolder/Control/Graphs.pm
                lib/Smolder/Control/Projects.pm
                lib/Smolder/Control/Public.pm
                lib/Smolder/Control/Admin/Developers.pm
                lib/Smolder/Control/Admin/Projects.pm
                lib/Smolder/Control/Developer/Prefs.pm
                lib/Smolder/Control/Public/Auth.pm
                lib/Smolder/DB/Developer.pm
                lib/Smolder/DB/Preference.pm
                lib/Smolder/DB/ProjectDeveloper.pm
                lib/Smolder/DB/Project.pm
                lib/Smolder/DB/SmokeReport.pm
                lib/Smolder/DB/TestFileComment.pm
                lib/Smolder/DB/TestFile.pm
                lib/Smolder/DB/TestFileResult.pm
                lib/Smolder/DB.pm
                lib/Smolder/Dispatch.pm
                lib/Smolder/Email.pm
                lib/Smolder/Mech.pm
                lib/Smolder/Redirect.pm
                lib/Smolder/Server.pm
                lib/Smolder/TAPHTMLMatrix.pm
                lib/Smolder/TestData.pm
                lib/Smolder/TestScript.pm
                lib/Smolder/Upgrade.pm
                lib/Smolder/Util.pm
                lib/Smolder/Upgrade/V0_1.pm
                lib/Smolder/Upgrade/V0_3.pm
                lib/Smolder/Upgrade/V1_1.pm
                lib/Smolder/Upgrade/V1_21.pm
                lib/Smolder/Upgrade/V1_24.pm
                lib/Smolder/Upgrade/V1_30.pm
                lib/Smolder/Upgrade/V1_37.pm
                lib/Smolder/Upgrade/V1_50.pm
            )],
        },
    },
);

$builder->add_build_element('templates');
$builder->add_build_element('sql');
$builder->add_build_element('htdocs');

$builder->create_build_script();
