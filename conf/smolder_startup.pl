# load our Perl Modules
use DBI;

use Carp;
#$SIG{__DIE__} = \*Carp::confess;
#$SIG{__WARN__} = \*Carp::cluck;

use Smolder::DB;
use Smolder::Dispatch;
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
# 10 clients == 400MB total worse-case scenario
use Apache::SizeLimit;
$Apache::SizeLimit::MAX_PROCESS_SIZE  = 40000;  # 40MB 
#$Apache::SizeLimit::MIN_SHARE_SIZE    = 1500;   # 1.5MB
$Apache::SizeLimit::CHECK_EVERY_N_REQUESTS = 3;

# Disconnect before fork
Smolder::DB->db_Main()->disconnect();

##################################################################
#  Use this to check share modules
##################################################################
#use Smolder::Cleanup;
#Apache->server->register_cleanup(sub { Smolder::Cleanup->loaded_modules('preload-before.txt') } );


1;
