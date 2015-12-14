use strict;
use warnings;
use lib '/local/scripts/lib';

use Validation::Tests;
 use Connection::Netinv;
use Connection::Starfish;
my @lines;
 my $devarr = Connection::Netinv->new()->GetCustomRecords("SELECT * from netinv.devices where status in ('Planning', 'Active')");
 for my $dev (@$devarr) {push @lines, split /\n/, Validation::Tests::RouterValidateExpectedServers($dev);}

my $db = Connection::Starfish->new();
$db->metacheckclear('WARN-HUBRR');
for my $line (@lines)
{
	print $line . "\n";
	$db->metachecklog($line);
}

