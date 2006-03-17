# count objects in all tables and compare results to dbcount.txt
# created by aaa_dbcount.t

use strict;
use warnings;
use Test::More qw(no_plan);
use Smolder::Conf qw(InstallRoot);
use File::Spec::Functions qw(catfile);
use Smolder::DB;

open(COUNT, "<", catfile(InstallRoot, "tmp", "dbcount.txt")) 
  or die $!;
my $dbh = Smolder::DB->db_Main();
                                  
while (<COUNT>) {
    chomp;
    my ($table, $count1) = split(' ', $_);
    my ($count2) = $dbh->selectrow_array("select count(*) from $table");
    is("$table $count2", "$table $count1", "Row count for '$table'");
}
close COUNT;
unlink(catfile(InstallRoot, "tmp", "dbcount.txt"));

