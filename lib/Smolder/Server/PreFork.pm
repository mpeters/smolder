package Smolder::Server::PreFork;
use Smolder::Conf qw(PidFile LogFile DataDir);
use strict;
use warnings;
use base qw(Net::Server::PreFork);

sub configure_hook {
    my $self = shift;
    my $prop = $self->{server};

    # This all runs in the parent, before forking
    #

    # Use our pid file
    $prop->{pid_file} = PidFile;

    # Ensure that we fork
    $prop->{background} = 1;

    # Create data dir if needed
    if (not -e DataDir) {
        mkpath(DataDir) or die sprintf("Could not create %s: $!", DataDir);
    }

    unless (-e Smolder::DB->db_file) {

        # do we have a database? If not then create one
        Smolder::DB->create_database;
    } else {

        # upgrade if we need to
        require Smolder::Upgrade;
        Smolder::Upgrade->new->upgrade();
    }

    # preload our perl modules
    require Smolder::Dispatch;
    require Smolder::Control;
    require Smolder::Control::Admin;
    require Smolder::Control::Admin::Developers;
    require Smolder::Control::Admin::Projects;
    require Smolder::Control::Developer;
    require Smolder::Control::Developer::Graphs;
    require Smolder::Control::Developer::Prefs;
    require Smolder::Control::Developer::Projects;
    require Smolder::Control::Public;
    require Smolder::Control::Public::Auth;
    require Smolder::Control::Public::Graphs;
    require Smolder::Control::Public::Projects;
    require Smolder::Redirect;

    $self->SUPER::configure_hook();
}

sub post_configure_hook {
    my $self = shift;
    my $prop = $self->{server};

    # This all runs in the child, after forking
    #

    # Send warnings to our logs
    my $log_file = LogFile || devnull();
    my $ok = open(STDERR, '>>', $log_file);
    if (!$ok) {
        warn "Could not open logfile $log_file for appending: $!";
        exit(1);
    }
}

1;
