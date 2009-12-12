package Smolder::Build;
use strict;
use warnings;
use base 'Module::Build';
use File::Temp;
use Cwd qw(cwd);
use File::Spec::Functions qw(catdir catfile tmpdir curdir rel2abs abs2rel splitdir);
use File::Find ();
use File::Copy qw(copy);
use File::Path qw(mkpath);

my $PORT     = '112234';
my $HOSTNAME = '127.0.0.1';

=head1 NAME

Smolder::Build

=head1 DESCRIPTION

L<Module::Build> subclass for Smolder specific testing and installation.

=head1 OVERRIDDEN ACTIONS

=head2 test

Make sure that we test against a new, empty SQLite db and that Smolder
is up and running before running the test files. Then make sure we shut
down Smolder when done.

=cut

sub ACTION_test {
    my $self = shift;
    $self->_wrap_test_action('test');
}

# TODO - handle optional Module::Build::TAPArchive features if we have it installed
#sub ACTION_test_archive {
#    my $self = shift;
#    $self->_wrap_test_action('test_archive');
#}

sub _wrap_test_action {
    my ($self, $action) = @_;
    my $cwd = cwd();

    # create a temporary database and conf file
    my $tmp_dir   = File::Temp->newdir(template => 'smolder-XXXXXX');
    my $share_dir = $self->_share_blib_dir;
    my $tmp_conf  = File::Temp->new(template => 'smolder-XXXXXX', suffix => '.conf', dir => tmpdir);
    my $log_dir   = rel2abs(catdir(curdir, 'blib', 'logs'));
    mkpath($log_dir) unless -d $log_dir;

    my $conf =
        "HostName '$HOSTNAME'\nPort '$PORT'\n"
      . "TemplateDir '"
      . catdir($share_dir, 'templates') . "'\n"
      . "HtdocsDir '"
      . catdir($share_dir, 'htdocs') . "'\n"
      . "SQLDir '"
      . catdir($share_dir, 'sql') . "'\n"
      . "DataDir '"
      . $tmp_dir->dirname . "'\n"
      . "PidFile '"
      . catfile($tmp_dir->dirname, 'smolder.pid') . "'\n"
      . "LogFile '"
      . catdir($log_dir, 'smolder.log') . "'\n";
    print $tmp_conf $conf;
    close $tmp_conf;
    $ENV{SMOLDER_CONF} = $tmp_conf->filename;

    # make sure we create a DB first. Smolder will do this when it starts,
    # but we still want to run some tests even if we fail to start smolder
    $self->depends_on('db');

    # our code needs to know it's running under the test harness
    $ENV{SMOLDER_TEST_HARNESS_ACTIVE} = 1;

    # start the smolder server
    my ($in, $out, $err);
    $ENV{PERL5LIB} = catdir($cwd, 'blib', 'lib');
    my @cmd = (
        $^X,
        "-I$ENV{PERL5LIB}",
        catfile($cwd, 'blib', 'script', 'smolder'),
        '--conf' => $tmp_conf->filename,
    );
    eval { require IPC::Run };
    die "IPC::Run needed to run Smolder test: $@" if $@;
    warn "Starting Smolder server\n";
    my $subprocess = IPC::Run::harness(\@cmd, \$in, \$out, \$err);
    $subprocess->start();

    my $tries = 0;
    while (!_is_smolder_running() && $tries < 5 && !$err) {
        $subprocess->pump_nb() if $subprocess->pumpable;
        sleep(2);
        $tries++;
    }
    if(!_is_smolder_running() ) {
        warn "Could not start Smolder server\n";
        warn "$err\n" if $err;
        warn "Trying tests anyway.\n";
    }

    my $method = "SUPER::ACTION_$action";
    eval {

        # make sure depends_on('code') doesn't get run since we've already taken care of it
        # with depends_on('db')
        local *Module::Build::TAPArchive::depends_on = sub {
            my ($self, @args) = @_;
            if ($args[0] && $args[0] ne 'code') {
                return $self->SUPER::depends_on(@args);
            }
        };
        $self->$method(@_);
    };

    $subprocess->kill_kill;
}

sub _is_smolder_running {
    my $url = "http://$HOSTNAME:$PORT/app";

    # Create a user agent object
    eval { require LWP::UserAgent };
    die "LWP::UserAgent neede to run Smolder tests: $@" if $@;
    my $ua = LWP::UserAgent->new;
    $ua->timeout(4);
    my $res = $ua->get($url);

    # Check the outcome of the response
    return $res->is_success;
}

=head1 EXTRA ACTIONS

=head2 smoke

Run the smoke tests and submit them to our Smolder server.

=cut

__PACKAGE__->add_property(no_update  => 0);
__PACKAGE__->add_property(tags       => '');
__PACKAGE__->add_property(server     => 'http://smolder.plusthree.com');
__PACKAGE__->add_property(project_id => 2);

sub ACTION_smoke {
    my $self = shift;
    my $p    = $self->{properties};
    if ($p->{no_update} or `svn update` =~ /Updated to/i) {

        $self->ACTION_test_archive();

        # now send the results off to smolder
        eval { require WWW::Mechanize };
        die "WWW::Mechanize neede to run Smolder smoke: $@" if $@;
        my $mech = WWW::Mechanize->new();
        $mech->get("$p->{server}/app");
        unless ($mech->status eq '200') {
            print "Could not reach $p->{server}/app successfully. Received status "
              . $mech->status . "\n";
            exit(1);
        }

        # now go to the add-smoke-report page for this project
        $mech->get("$p->{server}/app/public_projects/add_report/$p->{project_id}");
        if ($mech->status ne '200' || $mech->content !~ /New Smoke Report/) {
            print "Could not reach the Add Smoke Report form in Smolder!\n";
            exit(1);
        }
        $mech->form_name('add_report');
        my %fields = (
            report_file  => $p->{archive_file},
            platform     => `cat /etc/redhat-release`,
            architecture => `uname -m`,
        );
        $fields{tags} = $p->{tags} if $p->{tags};

        # get the comments from svn
        my @lines = `svn info`;
        @lines = grep { $_ =~ /URL|Revision|LastChanged/ } @lines;
        $fields{comments} = join("\n", @lines);
        $mech->set_fields(%fields);
        $mech->submit();

        my $content = $mech->content;
        if ($mech->status ne '200' || $content !~ /Recent Smoke Reports/) {
            print "Could not upload smoke report with the given information!\n";
            exit(1);
        }
        $content =~ /#(\d+) Added/;
        my $report_id = $1;

        print "\nReport successfully uploaded as #$report_id.\n";
        unlink($p->{archive_file}) if -e $p->{archive_file};

    } else {
        print "No updates to Smolder\n";
        exit(0);
    }
}

=head2 db

Create a new blank DB in the data/ directory (used for development)

=cut

sub ACTION_db {
    my $self = shift;
    $self->depends_on('build');
    require Smolder::DB;
    Smolder::DB->create_database();
}

=head2 update_smoke_html

Update all the HTML for the existing smoke reports. This is useful for development
and also upgrading when the report HTML template files have changed
and you want that change to propagate.

=cut

sub ACTION_update_smoke_html {
    my $self = shift;
    require Smolder::DB::SmokeReport;
    Smolder::DB::SmokeReport->update_all_report_html();
}

=head2 tidy

Run perltidy over all the Perl files in the codebase.

=cut

my $TIDY_ARGS =
    "--backup-and-modify-in-place "
  . "--indent-columns=4 "
  . "--cuddled-else "
  . "--maximum-line-length=100 "
  . "--nooutdent-long-quotes "
  . "--paren-tightness=2 "
  . "--brace-tightness=2 "
  . "--square-bracket-tightness=2 ";

sub ACTION_tidy {
    my $self = shift;
    system(qq(find lib/Smolder/ -name '*.pm' | xargs perltidy $TIDY_ARGS));
    system(qq(find t/ -name '*.t' | xargs perltidy $TIDY_ARGS));
    system(qq(perltidy bin/* $TIDY_ARGS));
}

=head2 tidy_modified

Run perltidy over all the Perl files that have changed and not been committed.

=cut

sub ACTION_tidy_modified {
    my $self = shift;
    system(
        qq{svn -q status | grep '^M.*\.\(pm\|pl\|t\)\$\$' | cut -c 8- | xargs perltidy $TIDY_ARGS});
}

# handle the extra file types that smolder needs (templates, sql, htdocs, etc)
sub process_templates_files {
    my $self = shift;
    $self->_copy_files('templates');
}

sub process_sql_files {
    my $self = shift;
    $self->_copy_files('sql');
}

sub process_htdocs_files {
    my $self = shift;
    $self->_copy_files('htdocs');
}

sub _copy_files {
    my ($self, $type) = @_;
    my $cwd              = cwd();
    my $start_dir        = rel2abs(catdir(curdir, $type));
    my $start_dir_length = scalar splitdir($start_dir);
    my $dest_dir         = catdir($self->_share_blib_dir, $type);

    mkpath($dest_dir) or die "Could not create directory $dest_dir: $!" unless -d $dest_dir;

    File::Find::find(
        sub {
            return if /^\./;                          # skip special files
            return if $File::Find::dir =~ /\.svn/;    # skip svn droppings
            return if -d;
            my $name     = $_;
            my @new_dirs = splitdir($File::Find::dir);
            @new_dirs = @new_dirs[$start_dir_length .. $#new_dirs];
            my $full_path = $dest_dir;
            foreach my $new_dir (@new_dirs) {
                $full_path = catdir($full_path, $new_dir);
                unless (-d $full_path) {
                    mkdir($full_path) or die "Could not create directory $full_path: $!";
                }
            }
            $full_path = $full_path ? catfile($full_path, $name) : catfile($dest_dir, $name);
            warn "Copying "
              . abs2rel($File::Find::name, $cwd) . " -> "
              . abs2rel($full_path,        $cwd) . "\n";
            copy($File::Find::name, $full_path)
              or die "Could not copy file $File::Find::name to $full_path: $!";
        },
        $start_dir
    );
}

sub _share_blib_dir {
    return rel2abs(catdir(curdir, 'blib', 'lib', 'auto', 'share', 'dist', 'Smolder'));
}

1;
