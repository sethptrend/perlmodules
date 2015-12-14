use lib '../';
use warnings;
use strict;

use Connection::Netinv;
use Connection::Starfish;


my $dbnetinv = Connection::Netinv->new();
my $dbcogent = Connection::Starfish->new();


#something along the lines of:

#get the current table
#each row:
#get the a port_id (netinv function), z_port_id - this entails checking validity, making the port if the router is valid, etc, but netinv DB should do the work, not this script
#register the new row (dbtest function - obviously portable to dca05)


my $table = $dbnetinv->GetTableRecords('netinv.ick');
$dbcogent->DoSQL("Set IDENTITY_INSERT networkdbor.dbo.icks ON");#we're going to be inserting identities, hopefully this works for the whole session

for my $row (@$table){
	my $a_port = $dbnetinv->GetPortID($row->{a_hostname}, $row->{a_shint});
	my $z_port = $dbnetinv->GetPortID($row->{z_hostname}, $row->{z_shint});
	unless($a_port and $z_port) { #make sure both are defined for whatever reason
		print "A stuff: $row->{a_hostname} $row->{a_shint}\n";
		print "Z stuff: $row->{z_hostname} $row->{z_shint}\n";
		print "Ports: $a_port , $z_port \n";
		print "Either a or z port didn't belong to a real router or didn't have a creatable shint value.\n";
		next;
	}
	#a port row
	my %a_port;
	$a_port{port_id} = $a_port;
	$a_port{transport} = $row->{a_transport};
	$a_port{dev_id} = $dbnetinv->GetDevID($row->{a_hostname});
	$a_port{metric} = $row->{a_metric};
	$a_port{wavelength} = $row->{a_wavelength};
	$a_port{otn} = $row->{a_otn};
	$a_port{fec} = $row->{a_fec};
	$a_port{ick_id} = $row->{ick_id};
	$a_port{ckid} = $row->{a_ckid};
	$dbcogent->InsertValues('networkdbor.dbo.ports', %a_port);

	#z port row
	my %z_port;
	$z_port{port_id} = $z_port;
        $z_port{transport} = $row->{z_transport};
        $z_port{dev_id} = $dbnetinv->GetDevID($row->{z_hostname});
        $z_port{metric} = $row->{z_metric};
        $z_port{wavelength} = $row->{z_wavelength};
        $z_port{otn} = $row->{z_otn};
        $z_port{fec} = $row->{z_fec};
	$z_port{ick_id} = $row->{ick_id};
	$z_port{ckid} = $row->{z_ckid};

	$dbcogent->InsertValues('networkdbor.dbo.ports', %z_port);

	#ick row
	my %ick;
	$ick{ick_id} = $row->{ick_id};
	$ick{type} = $row->{type};
	$ick{facility} = $row->{facility};
	$ick{bundle_id} = $row->{bundle_id};
	$ick{status} = $row->{status};
	$ick{entrydate} = $row->{entrydate};
	$ick{changedate} = $row->{changedate};
	$ick{a_port_id} = $a_port;
	$ick{z_port_id} = $z_port;
	$dbcogent->InsertValues('networkdbor.dbo.icks', %ick);
#	print "\n";

}
