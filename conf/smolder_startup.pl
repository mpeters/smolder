# load our Perl Modules
use Apache::DBI;
#$Apache::DBI::DEBUG=1;
use DBI;

use Carp;
#$SIG{__DIE__} = \*Carp::confess;
#$SIG{__WARN__} = \*Carp::cluck;

BEGIN{ $DBI::connect_via = 'connect_cached'; };
# The above line requires a little explanation.  We need to connect to the
# database during startup to get table information for the Class::DBI
# objects.  Apache::DBI will skip the connection cache during startup to
# avoid forking problems, but this causes errors from Class::DBI about
# the database handle being DESTROY'd without an explicit disconnect.
# This is because Class::DBI expects the handles to be persistent.  To fix
# this, we use a cheat to make DBI do a connect_cached during startup
# (as opposed to using Apache::DBI) and then explicitly disconnect that
# at the end of this file and tell it to use Apache::DBI after that.  Phew.

use Smolder::DB;
use Smolder::Control;
use Smolder::Control::Public;
use Smolder::Control::Public::Projects;
use Smolder::Control::Public::Graphs;
use Smolder::Control::Public::Auth;
use Smolder::Control::Admin;
use Smolder::Control::Admin::Projects;
use Smolder::Control::Admin::Developers;
use Smolder::Control::Developer;
use Smolder::Control::Developer::Prefs;
use Smolder::Control::Developer::Projects;
use Smolder::Control::Developer::Graphs;

# don't let things get out of control
# 10 clients == 355MB total worse-case scenario
use Apache::SizeLimit;
$Apache::SizeLimit::MAX_PROCESS_SIZE  = 37000;  # 37MB 
$Apache::SizeLimit::MIN_SHARE_SIZE    = 1500;   # 1.5MB
$Apache::SizeLimit::CHECK_EVERY_N_REQUESTS = 3;

# Disconnect before fork and then switch to using Apache::DBI
Smolder::DB->db_Main()->disconnect();
$DBI::connect_via = 'Apache::DBI::connect';


1;
