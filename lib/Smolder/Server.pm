package Smolder::Server;
use strict;
use warnings;
use base 'CGI::Application::Server';
use Smolder::Conf qw(Port HostName);
use Smolder::Dispatch;
# load all of our controller modules so they are in memory
use Smolder::Control;
use Smolder::Control::Admin;
use Smolder::Control::Admin::Developers;
use Smolder::Control::Admin::Projects;
use Smolder::Control::Developer;
use Smolder::Control::Developer::Graphs;
use Smolder::Control::Developer::Prefs;
use Smolder::Control::Developer::Projects;
use Smolder::Control::Public;
use Smolder::Control::Public::Auth;
use Smolder::Control::Public::Graphs;
use Smolder::Control::Public::Projects;
use Smolder::Redirect;

sub new {
    my $class = shift;
    my $server = $class->SUPER::new(@_);
    $server->host(HostName);
    $server->port(Port);
    my $htdocs = catdir(Smolder::Conf->data_dir, 'htdocs'));

    $server->entry_points(
        {
            '/'    => 'Smolder::Redirect',
            '/app' => 'Smolder::Dispatch',
            #'/static' => $htdocs", # need to get this working
            '/js'     => $htdocs,
            '/style'  => $htdocs,
            '/images' => $htdocs,
        },
    );

    return $server;
}

sub print_banner {
    my $banner = "Smolder is running on " . HostName . ':' . Port;
    my $line = '#' x length $banner;
    print "$line\n$banner\n";
}

sub run {
    my $self = shift;

    # do we have a database? If not then create one

    # check the DB version to make sure that we don't need to upgrade
    
    return $self->SUPER::run();
    #return $self->SUPER::background();
}

1;
