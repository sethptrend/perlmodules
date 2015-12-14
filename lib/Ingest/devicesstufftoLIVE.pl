use lib '../';

use warnings;
use strict;
use Connection::Starfish;
use Connection::DanaDev;

my $ddb = Connection::DanaDev->new();
my $sdb = Connection::Starfish->new();

#drop bgprr and repopulate
$sdb->DoSQL("truncate table networkdbor.dbo.bgprr");

my $rrrecs = $ddb->GetTableRecords('danadev.bgp_rrs');
for my $rrrec (@$rrrecs){

	$sdb->InsertValues('networkdbor.dbo.bgprr', 'server', $rrrec->{server_dev_id}, 'client', $rrrec->{client_dev_id}, 'peergroup', $rrrec->{peergroup});

}

#drop devices and repopulate
$sdb->DoSQL("truncate table networkdbor.dbo.devices");

my $drecs = $ddb->GetTableRecords('danadev.core_devices');
for my $drec (@$drecs){
	 $sdb->InsertValues('networkdbor.dbo.devices', 'dev_id', $drec->{dev_id}, 'holddown', $drec->{holddown}, 'fullmesh', $drec->{bgp_fullmesh}, 'isislevel', $drec->{isis_level});

}
