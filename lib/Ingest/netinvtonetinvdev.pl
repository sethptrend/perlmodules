#!/usr/bin/perl

use warnings;
use strict;

use lib '/local/scripts/lib/';

use Connection::Netinv;
my $netdb = Connection::Netinv->new();
my @tables = qw(devices hubs ccheck cricket netigp netports vlans ciscohw);

for my $table (@tables){
print "Copying table: $table from live to dev\n";
$netdb->DoSQL("REPLACE INTO `netinv-dev`.$table SELECT * FROM netinv.$table");
}
