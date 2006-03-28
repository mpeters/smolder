# count objects in all tables and put results in dbcount.txt
use strict;
use warnings;
use Test::More qw(no_plan);

use Smolder::Conf qw(SmolderRoot);
use Smolder::DB;
use File::Spec::Functions qw(catfile);

open(COUNT, ">", catfile(SmolderRoot, "tmp", "dbcount.txt")) 
  or die $!;
my $dbh = Smolder::DB->db_Main();

my @tables = $dbh->tables('', '', '%');
ok(@tables);

foreach my $table (sort @tables) {
    next if( $table =~ /^.?sqlite_/ ); 
    my ($count) = $dbh->selectrow_array("select count(*) from $table");
    ok(defined $count);
    print COUNT "$table $count\n";
}
close COUNT;

