use strict;
use warnings;
use Test::More;
use Smolder::TestScript;
use Smolder::Conf qw(DBPlatform);

plan( tests => 2 );

SKIP: {
    skip( 'Not using MySQL', 2 ) if ( lc DBPlatform ne 'mysql' );
    use_ok("Smolder::DB");

    # A test to make sure that the isolation level for innodb tables needed
    # is READ-COMMITTED
    my $dbh       = Smolder::DB->db_Main();
    my $iso_level = $dbh->selectrow_array('SELECT @@global.tx_isolation');

    is( $iso_level, 'READ-COMMITTED', 'database isolation level' );
    $dbh->disconnect();
}
