use lib '../';

use warnings;
use strict;
use Connection::StarfishTest;
use Connection::DanaDev;

my $ddb = Connection::DanaDev->new();
my $sdb = Connection::StarfishTest->new();

#drop hubrr table and repopulate
$sdb->DoSQL("DELETE  FROM networkdbor.dbo.hubrr");
my $rrrecs = $ddb->GetTableRecords('danadev.hub_hierarchy');
for my $rrrec (@$rrrecs){

	$sdb->InsertValues('networkdbor.dbo.hubrr', 'server', $rrrec->{server_hub_id}, 'client', $rrrec->{client_hub_id});

}

#drop hubs table and repopulate
$sdb->DoSQL("DELETE  FROM networkdbor.dbo.hubs");
my $drecs = $ddb->GetTableRecords('danadev.hub_vars');
for my $drec (@$drecs){
	 $sdb->InsertValues('networkdbor.dbo.hubs', 'hub_id', $drec->{hub_id}, 'fullmesh', $drec->{bgp_fullmesh});

}
