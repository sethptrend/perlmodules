use warnings;
use strict;
use lib '/local/scripts/lib';
use Connection::Netinv;
use Connection::Starfish;

my $cogentdb = Connection::Starfish->new();
my $netinvdb = Connection::Netinv->new();


my $liveicks = $cogentdb->GetIndexICKs('1', '1');#where 1=1 bro

foreach my $liveick (@$liveicks){

	$liveick->{ick_id}= sprintf("%06d", $liveick->{ick_id});
	next unless $liveick->{a_port_id};
	next unless $liveick->{z_port_id};
	#print "$liveick->{entrydate} $liveick->{changedate}\n";
	my $qry = "REPLACE INTO `netinv`.ickmirror ";
	$qry .="(ick_id, type, facility, bundle_id, status, a_transport, a_ckid, a_hostname,  a_dev_id, a_dev_id_valid, a_shint, a_port_id, a_port_id_valid, a_metric, z_transport, z_ckid, z_hostname, z_dev_id, z_dev_id_valid, z_shint, z_port_id, z_port_id_valid, z_metric, rtt, monitor, bkup, notes, entrydate, changedate, a_wavelength, z_wavelength, a_otn, z_otn, a_fec, z_fec) VALUES ";
	$qry .="('$liveick->{ick_id}', '$liveick->{type}', '$liveick->{facility}', '$liveick->{bundle_id}', '$liveick->{status}', '$liveick->{a_transport}', '$liveick->{a_ckid}', '$liveick->{a_hostname}', $liveick->{a_dev_id}, 1, '$liveick->{a_shint}', $liveick->{a_port_id}, 1, '$liveick->{a_metric}', '$liveick->{z_transport}', '$liveick->{z_ckid}', '$liveick->{z_hostname}', $liveick->{z_dev_id},1, '$liveick->{z_shint}', $liveick->{z_port_id}, 1, '$liveick->{z_metric}', 0, 0, 0, '', FROM_UNIXTIME($liveick->{entrydate}), FROM_UNIXTIME($liveick->{changedate}), '$liveick->{a_wavelength}', '$liveick->{z_wavelength}', '$liveick->{a_otn}', '$liveick->{z_otn}', '$liveick->{a_fec}', '$liveick->{z_fec}') ";
	print "$qry\n";
	$netinvdb->DoSQL($qry);

}
