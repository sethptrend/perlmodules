use lib '../';
use warnings;
use strict;

use Connection::Netinv;
use Connection::Starfish;
use Digest::MD5 qw(md5_hex);
use JSON;


my $dbnetinv = Connection::Netinv->new();
my $dbcogent = Connection::Starfish->new();
my %typefull = ( 
			'Te', 'TenGigE',
			'Hu', 'HundredGigE',
			'Gi', 'GigabitEthernet',
			'Fa', 'FastEthernet',
			'Be', 'Bundle-Ether',
			'Vl', 'Vlan'
		);

sub CreatePortReturnPortID {
	my $hostname = shift;
	my $shint = shift;
	$shint = ucfirst($shint);
	$shint =~ s/G/Gi/ if $shint =~ /^G\d/;
	my $port = $dbnetinv->GetPortID($hostname, $shint);
        return $port if $port;#already exists, kick it back
	my $devicerecord = $dbnetinv->GetCustomRecord("SELECT hostname, dev_id, count(*) as count from netinv.devices where hostname like '$hostname%'");
	if($devicerecord->{count} == 1){
		if($shint =~ /([Tt]e|[Hh]u|[Gg]i|[Ff]a|[Bb]e|Vl)(\d+(\/\d+)?(\/\d+\/\d+)?)(\.\d+)?/){
			my $type = $1;
			my $intf = $shint;
			$intf =~ s/$type/$typefull{$type}/;
			my $checksum = md5_hex($hostname.$shint.$intf.$type.$typefull{$type});
			$dbnetinv->DoSQL("INSERT INTO netinv.netports SET active='N', checksum='$checksum', dev_id=$devicerecord->{dev_id},  hostname='$devicerecord->{hostname}', intf='$intf', shint='$shint', adminstat=0, operstat=0, descr='unk', ipaddr='unk', secipaddr='[]', ip6addr='[]'"); 
			my $newnetport = $dbnetinv->GetIndexRecord('netinv.netports', 'intf', $intf, 'dev_id', $devicerecord->{dev_id});
			$dbcogent->InsertValues('netinv.dbo.netports', 'port_id', $newnetport->{port_id}, 'active', 'N', 'checksum', $checksum, 'dev_id', $devicerecord->{dev_id}, 'hostname', $devicerecord->{hostname}, 'intf', $intf, 'shint', $shint, 'adminstat', '0', 'operstat', '0', 'descr', 'unk', 'ipaddr', 'unk', 'secipaddr', '[]', 'ip6addr', '[]');
			return $newnetport->{port_id};
		}
		print "Shint failed: $shint\n";
	} else{
		print "Didn't match hostname: $hostname\n";}

	#errors happened
        return 0;
}

#something along the lines of:

#get the current table
#each row:
#get the a port_id (netinv function), z_port_id - this entails checking validity, making the port if the router is valid, etc, but netinv DB should do the work, not this script
#register the new row (dbtest function - obviously portable to dca05)

#my %carelist;
#my $screwed = $dbcogent->GetCustomRecords("SELECT  [ick_id] FROM [NetworkDBOR].[dbo].[icks] where a_port_id=0 or z_port_id=0");
#for my $screw (@$screwed){ $carelist{sprintf("%06d",$screw->{ick_id})} = 1;}
my %donelist;
my $done = $dbcogent->GetCustomRecords("SELECT  [ick_id] FROM [NetworkDBOR].[dbo].[icks] where a_port_id>0 and z_port_id>0");
for my $drow (@$done) { $donelist{sprintf("%06d",$drow->{ick_id})} = 1 ; }
my $table = $dbnetinv->GetTableRecords('netinv.ick');
$dbcogent->DoSQL("Set IDENTITY_INSERT networkdbor.dbo.icks ON");#we're going to be inserting identities, hopefully this works for the whole session

for my $row (@$table){
	next if $donelist{$row->{ick_id}};
	next if $row->{status} eq 'retired'; #now we don't care about these
	print "ICK: $row->{ick_id}\n";
	my $a_port = $dbnetinv->GetPortID($row->{a_hostname}, $row->{a_shint});
	my $z_port = $dbnetinv->GetPortID($row->{z_hostname}, $row->{z_shint});
	unless($a_port) { $a_port = CreatePortReturnPortID($row->{a_hostname}, $row->{a_shint}); }
	 unless($z_port) { $z_port = CreatePortReturnPortID($row->{z_hostname}, $row->{z_shint}); }

	unless($a_port and $z_port) { #make sure both are defined for whatever reason
		print "A stuff: $row->{a_hostname} $row->{a_shint}, ";
		print "Z stuff: $row->{z_hostname} $row->{z_shint}, ";
		print "Ports: $a_port , $z_port, ";
		print "Status: $row->{status}, "; 
		print "\n";
		print encode_json($row) . "\n";
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
	$dbcogent->DoSQL("DELETE FROM networkdbor.dbo.ports WHERE port_id='$a_port'");
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
	$dbcogent->DoSQL("DELETE FROM networkdbor.dbo.ports WHERE port_id='$z_port'");
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
	$dbcogent->DoSQL("DELETE FROM networkdbor.dbo.icks WHERE ick_id=$ick{ick_id}");
	$dbcogent->InsertValues('networkdbor.dbo.icks', %ick);
#	print "\n";

}
