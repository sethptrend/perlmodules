#Seth Phillips
#interface to the danadev tables inheriting from Connection.pm
#12/2/13


use strict;
use warnings;
use lib '../lib';

package Connection::Netinv;
use Connection::Connection;
our @ISA = ('Connection::Connection');
#DO NOT INCLUDE OTHER LIBRARIES HERE, NO CIRCULAR BS


#only overwritten portion is the constructor which defines the database
sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {
        dbh     => undef,
        update  => 1,
#in the base class these are undefined . . . basically base class functions should not work unless inherited
        dbname => "netinv",
        dbhost => 'cyclops.sys',
        dbusr => 'netinv',
        dbpass => 'a7fb2ac7',
        dbusrro => undef,
        dbpassro => undef,
        dbtype => 'mysql'
    };
    bless($self,$class);

    my $ro = shift;

    if ($self->Connect($ro)) {
        return $self;
    }
        # An error occured so return undef
        return undef;

}

#Netinv specific functions - also note these are specific to netinv's use on 1ctc
#takes old orderid, neworderid, returns filename to be run by runconfig
#now takes cdr as third argument
sub OrderChangeConfig {
	my $self = shift;
	my $oldid = shift // 0;
	my $newid = shift // 0;
	die "Missing arguments in call to OrderChangeConfig\n"  unless $newid and $oldid;
	my $ret = "/opt/perlapps/websocket1ctc/configs/$newid";#base directory for configs
	my $rancid = '/mnt/rancid/';#base dir for rancid files (append grp/configs/routername for config)
	my $burst = 50000;
 	my $cdr = shift // 100;
	 my $rate = $cdr * 1000000.0;
	$rate += 10**(length($rate)-2);
	if($cdr>=100){$burst = "2000000";}
	
	#search the port database for all the routers that need changes, we'll parse full router configs for actual changes, so just need to grab routers here
	my $ports = $self->GetRecords('netports', 'descr', "%$oldid%", 'adminstat', '1');
	return 0 unless defined($ports);
	my %routers;
	foreach my $portrec (@$ports)
	{
		$routers{$portrec->{hostname}} = 1;
	}



	open my $outfile, ">", $ret or die "Could not open output file\n";
	#on each router, parse for places that need changes
	foreach my $router (keys(%routers)){
		#print "Searching for router record for $router\n";
		my $routerrec = $self->GetRecord('devices', 'hostname', $router);
		next unless defined($routerrec);
		#print "Found record for $router\nOpening $rancid".$routerrec->{rancidgrp} . "\/configs\/$router\n";
		open my $rfile, "<", $rancid . $routerrec->{rancidgrp} . "\/configs\/$router" or
		die "Failed to open rancid file for $router";
		my @rfile =  <$rfile>;
		my @lastheader = ();
		print $outfile "!On $router\n";
		my @sec1;#new mls
		my @sec2; #new maps
		my @sec3; #no SP followed by SP
		my @sec4; #no maps
		my @sec5; #no mlss
		my @sec6; #everything else - don't care about order
		foreach my $line (@rfile)
		{
			#skip comment lines
			next if($line =~ /^!/);
			$lastheader[0] = $line if $line =~ /^\S/;#any line that doesn't have trailing whitespace is a header
			$lastheader[1] = $line if $line =~/^ \S/;#line starts with 1 space, making us 2 deep
			#print $line if $line =~ /$oldid/;

			#out policer
			if($line =~ /mls qos.*$oldid-2/)
			{
				push @sec5, "no $line";
				push @sec1, "mls qos aggregate-policer $newid-2 $rate $burst $burst conform-action set-dscp-transmit af31 exceed-action drop\n";
			}
			#in policer
			elsif($line =~/mls qos.*$oldid/)
			{
				 push @sec5, "no $line";
				push @sec1, "mls qos aggregate-policer $newid $rate $burst $burst conform-action transmit exceed-action drop\n";

			}
			#policer aggregate 1-109991505 cir 2100000 bc 50000 conform-action set-dscp-transmit af31 exceed-action drop
			#for ports on the 3400 platform, which is any device notated by na11/nsw11 or na31/nsw31, we use the policer aggregate command.
			elsif($line =~/policer aggregate $oldid/)
			{
				push @sec5, "no $line";
				push @sec1, "policer aggregate $newid cir $rate bc $burst conform-action set-dscp-transmit af31 exceed-action drop\n";
			}
			#in map
			elsif($line =~ /policy-map ratelimitin-$oldid/)
			{
				push @sec4, "no $line";
				push @sec2, "policy-map ratelimitin-$newid\n".
				 " description Rate-Limiting $newid Ingress\n".
				 " class IP-traffic\n   police agregate $newid-2\n";
			}
			#out map
			elsif($line =~ /policy-map ratelimitout-$oldid/)
			{
				push @sec4, "no $line";
                                push @sec2, "policy-map ratelimitout-$newid\n".
                                 " description Rate-Limiting $newid Egress\n".
                                 " class IP-traffic\n   police agregate $newid\n";
			}
			#service policy statement
			elsif($line =~ /service-policy.*$oldid/)
			{
				push @sec3, "$lastheader[0] no $line";
				$line =~ s/$oldid/$newid/g;
				push @sec3, $line;
			}
			#fix description for CAP
			elsif($line =~ /description.*CAP.*$oldid/)
			{
				my $cdrm;
				if($cdr < 1000){$cdrm = $cdr . 'M';}
				else {$cdrm = ($cdr / 1000.0) . 'G'}
				$line =~ s/CAP:\w+/CAP:$cdrm/;
				$line =~ s/$oldid/$newid/g;
				push @sec6, "$lastheader[0]$line";
			}
			elsif($line =~ /description.*CIR.*$oldid/)
                        {
                                my $cdrm;
                                if($cdr < 1000){$cdrm = $cdr . 'M';}
                                else {$cdrm = ($cdr / 1000.0) . 'G'}
                                $line =~ s/CIR:\w+/CIR:$cdrm/;
                                $line =~ s/$oldid/$newid/g;
                                push @sec6, "$lastheader[0]$line";
                        }

			#fix description
			elsif($line =~ /description.*$oldid/)
			{
				next if $lastheader[0] =~ /policy-map/;
				if($line eq $lastheader[1]){
				$line =~ s/$oldid/$newid/g;
				push @sec6, "$lastheader[0]"   . "$line";}
				else
				{
					$line =~ s/$oldid/$newid/g;
					push @sec6, "$lastheader[0]$lastheader[1]$line";}
			}
			elsif($line =~ /^ip route .*$oldid/)
			{
				$line  =~ s/$oldid/$newid/g;
				push @sec6, "$line";
			}
			#we don't care at all about these lines (handled above)
			elsif($line =~ /police aggregate.*$oldid/){}
			#catch stuff we haven't messed with
			elsif($line =~ /$oldid/)
			{
				print $outfile "!Found unhandled line: $line";
			}
		}
		#print the sections in order
		print $outfile join('',@sec1,@sec2,@sec3,@sec4,@sec5,@sec6);
		print $outfile "!\n";
		close $rfile;
	}


	close $outfile;
	return $ret;
}

######################################################################
sub GetHubs {
    my $self = shift;
    my $region = shift;

    my $qry = "SELECT * FROM hubs ";
    if (defined($region)) {
        $qry .= "WHERE hubs.region = $region ";
    }
    $qry .= "ORDER BY hub_id";

    my $devhash = $self->{dbh}->selectall_hashref($qry,'hub_id');

    return $devhash;
}       


##############################################################################
#$netinv->GetNetflowVars($ickref->{a_port_id});
#function to get variables needed for janines check
#takes a device id and returns a hashref
sub GetNetflowVars {
	my $self = shift;
	my $port_id = shift;
	my $qry = "SELECT flowintype,flowinrate,ip6flowintype,ip6flowinrate,rancidgrp,netports.intf,netports.hostname FROM netports inner join devices ON netports.dev_id=devices.dev_id where netports.port_id='$port_id';";
	my $sth = $self->{dbh}->prepare($qry);
	my $rv = $sth->execute;
   	my $entry_ref = $sth->fetchrow_hashref();
    	return $entry_ref;


}

#################################################################

#@list = Connection::Netinv->new()->GetICKListByHostname($hostname);
#takes a hostname (string) coverts to device id then searches icks for having that device ID
sub GetICKListByHostname {
	my $self = shift;
	my $hostname = shift;
	my @retlist;

	my $devrec = $self->GetRecord('netinv.devices', 'hostname', "$hostname%");
	return @retlist unless $devrec;
	my $ickrecs = $self->GetIndexRecords('netinv.ick', 'a_dev_id', $devrec->{dev_id});
	if(ref($ickrecs))
	{
	   for my $ickref (@$ickrecs){
			push @retlist, $ickref->{ick_id} if $ickref->{status} ne 'retired';
		}
	}
	$ickrecs = $self->GetIndexRecords('netinv.ick', 'z_dev_id', $devrec->{dev_id});
	if(ref($ickrecs))
        {
           for my $ickref (@$ickrecs){
                        push @retlist, $ickref->{ick_id}  if $ickref->{status} ne 'retired';
                }
        }


	return @retlist;
}

#in:Hostname
#out: 0/1 if problems (mainly invalid hostname), (bid, nodenum) if successful, which might be confusing in print statements because the nodeNum is usually 0
#out: alters the device table
sub FixBuildingIDNodeNum {
	my $self = shift;
	my $hostname = shift;
	if($hostname =~ /([\w\d]+)\.((b\d{6}\-\d+)\.)?(\w{3}\d{2})(\.((atlas)|(hades))?\.cogentco\.com)?/)
	{
		my $building;
		my $buildingID;
		my $nodeNum;
		my $hub = uc($4);
		if($3){
			$building = $3;
			$building =~ s/^[b0]+//;
		} else {
			my $rec = $self->GetIndexRecord('netinv.hubs', 'hub_id', $hub);
			$building = $rec->{node_id} if $rec;
			return 2 unless $rec;
		}
		if($building =~ /(\d+)-(\d+)/){
		$nodeNum = $2;
		$buildingID = $1;
		$self->DoSQL("UPDATE netinv.devices SET BuildingID='$buildingID', NodeNum='$nodeNum' WHERE hostname='$hostname'");
		return ($buildingID, $nodeNum);
                }
		return 1;


	}
	return 0;
}

sub BundleCapacity {
	my $self = shift;
	my $bid = shift;

	my $rec = $self->GetCustomRecord("SELECT count(*) as count FROM ick where bundle_id=$bid and status in ('active', 'new', 'planning') and type like 'lag%';");
	return ($rec->{count} * 10) . "G";

}


#so we need an initial populate for mepid
#just pure iterated loop
sub populatemepids {
 my $self = shift;
 my $mep = 1;
 my $recs = $self->GetRecords('devices', 'status', 'Active', 'chassis_type', 'ASR%');
 for my $rec(@$recs){
  $self->DoSQL("UPDATE devices SET mepid=$mep WHERE dev_id=" . $rec->{dev_id});
  $mep++;
 }
 $recs = $self->GetRecords('devices', 'status', 'Planning', 'chassis_type', 'ASR%');
 for my $rec(@$recs){
  $self->DoSQL("UPDATE devices SET mepid=$mep WHERE dev_id=" . $rec->{dev_id});
  $mep++;
 }


 return 0;
}


#$dbnetinv->GetPortID($row->{a_hostname}, $row->{a_shint});
#GetPortID
#takes hostname, shint
#returns the port ID if exists, creates the port id if it doesn't but hostname exists
sub GetPortID {
 my $self = shift;
 my $hostname = shift;
 my $shint = shift;

 my $dev = $self->GetDevID($hostname);
 return 0 unless $dev; #not even touching invalid  or ambiguous device names
 
 my $rec = $self->GetCustomRecord("Select port_id from netinv.netports where dev_id=$dev and shint like " . $self->quote($shint).";");
 return 0 unless $rec;#temporarily doing this
 return $rec->{port_id};

}

#$dbnetinv->GetDevID($row->{a_hostname});
#GetDevID - returns device id if hostname like 'router%' matches ONCE on netinv.devices, 0 otherwise
sub GetDevID {
  my $self = shift;
  my $router = shift;
  my $rec = $self->GetCustomRecord("Select dev_id, COUNT(*) as count FROM netinv.devices WHERE hostname like '$router%';");
  return 0 unless $rec->{count}==1;
  return $rec->{dev_id};
}


1;
