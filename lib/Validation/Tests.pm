#Seth Phillips
#Validation::Tests
#05/08/14

#ccheck tests library

use lib '/local/scripts/lib/';

use Connection::Netinv;
use Cogent::DNS;
use Net::IP;
use Connection::Starfish;
use Date::Calc ;

package Validation::Tests;

{
#local static variables for Loop0 tests
my $netinv = Connection::Netinv->new();
my $hubs = $netinv->GetHubs();
my $dns = Cogent::DNS->new();
my $dca = Connection::Starfish->new();

sub ValidLoopback0 { #('ccr41.iad02.atlas.cogentco.com', '66.28.1.9') - hostname, ip addr
	#my $self = shift;
	my $hostname = shift;
	
	my $ipv4 = shift;
	#get hub and just bounce (no error) invalid names 
	return '' unless $hostname =~ /.+\.(\w\w\w\d\d)\.(atlas|hades).cogentco.com/;
	#Tor wanted to bounce routers that don't match because others might not support ipv6 at all (read na routers!)
	#blackhole
	#agr
	#ccr
	#rcr
	#ca
	#nr
	#mpd
	#mag
	#return '' unless $hostname =~ /^(blackhole|agr|ccr|rcr|ca|nr|mpd|mag)/;
	my $hub = uc($1);
	my $continent = $hubs->{$hub}->{region};
	if($hostname =~ /^(ccr|rcr|agr)/) { #Cogent / XXX core router
		my $pool = $dns->PoolLookupIPv4($ipv4);	
		return "ERROR-IP: Invalid ipv4 or unable to find pool - $ipv4" if $pool < 0;
		if($continent eq 'NA'){	#expect Cogent / NA core pool = AEAS
			return "ERROR-IP: ipv4 not in expected Cogent / NA core router loopback pool" unless $pool eq 'AEAS';
		} elsif($continent eq 'EU') { #expect Cogent / EU core pool = AEAR
			return "ERROR-IP: ipv4 not in expected Cogent / EU core router loopback pool" unless $pool eq 'AEAR';
		}
	} elsif($hostname =~ /^nr/) { #Cogent / XXX node router
		my $pool = $dns->PoolLookupIPv4($ipv4);
                return "ERROR-IP: Invalid ipv4 or unable to find pool - $ipv4" if $pool < 0;
		if($continent eq 'NA'){ #expect Cogent / NA Node router pool = AEBX
			 return "ERROR-IP: ipv4 not in expected Cogent / NA node router loopback pool" unless $pool eq 'AEBX';
		} elsif($continent eq 'EU') { #expect Cogent / EU node pool = AECE
			return "ERROR-IP: ipv4 not in expected Cogent / EU node router loopback pool" unless $pool eq 'AECE';
		}
	} elsif($hostname =~/^ca/) { #Cogent / XXX ca router
		my $pool = $dns->PoolLookupIPv4($ipv4);
                return "ERROR-IP: Invalid ipv4 or unable to find pool - $ipv4" if $pool < 0;
		if($continent eq 'NA'){ #expect Cogent / NA ca router pool = AEAU
			 return "ERROR-IP: ipv4 not in expected Cogent / NA ca  router loopback pool" unless $pool eq 'AEAU';
		} elsif($continent eq 'EU') { #expect Cogent / EU ca pool = AEAV
			return "ERROR-IP: ipv4 not in expected Cogent / EU ca router loopback pool" unless $pool eq 'AEAV';
		}
	}
	





	return '';
}
sub ValidLoopback0ipv6 {#('ccr41.iad02.atlas.cogentco.com', '66.28.1.9', '2001:550:0:1000:421c:109')
	my $hostname = shift // 0;
	my $ipv4 = shift // 0;
	my $ipv6 = shift // 0;
	return -1 unless $hostname and $ipv4 and $ipv6; #make sure these are passed, no die though
	return -2 unless $ipv4 =~ /\d+\.\d+\.\d+\.\d+/;#invalid ipv4
        #Tor wanted to bounce routers that don't match because others might not support ipv6 at all (read na routers!)
        #blackhole                                                                           #agr
        #ccr                                                                                 #rcr                                                                                 #ca
        #nr
        #mpd
        #mag
        return '' unless $hostname =~ /^(blackhole|agr|ccr|rcr|ca|nr|mpd|mag)/;
	my $netip = Net::IP->new($ipv4) or print "$ipv4 failed to create an IP object\n";
	
	my $hex = $netip->hexip();$hex=~s/^0x//;$hex=~s/(\w\w\w\w)$/:$1/;
	$hex =~ s/^0+//;
	$hex =~ s/:0+/:/;#strip leading zeroes for ipv6 format
	$hex =~ s/::/:0:/;#hex in this portion that's 0 needs to be there
	$hex = '2001:550:0:1000::' . $hex;
	$hex =~ s/:$/:0/;#if the final hex is 0 let it be just 0
	return "ERROR-IPV6: IPv6 should be $hex (was $ipv6)" unless $ipv6 =~ /$hex/i;
	return '';
}

#input is an ickref to validate, output is a string, \n seperated if multiple errors
sub ValidICK {
	my $ickref = shift // 0;
	$ickref->{ick_id} = sprintf("%06d", $ickref->{ick_id}) if $ickref;
	my $ret = '';
	return '' unless $ickref;#no error if no ick, wouldn't be anything to report
	my $ports = $netinv->GetIndexRecords('netinv.netports', 'ick_id', $ickref->{ick_id}, 'active', 'Y');
	my @ips;
	my $ipv6ret;
	my $continent;
	my $mismatches = 0;
	my $mismatch = '';
	for my $portref (@$ports)
	{
		$portref->{hostname} =~ /.+\.(\w\w\w\d\d)\.(atlas|hades).cogentco.com/;
        	my $hub = uc($1);
        	$continent //= $hubs->{$hub}->{region};	
		$continent = 'mismatch' unless $continent eq $hubs->{$hub}->{region} or $ickref->{type} ne 'CORE';
		push @ips, $portref->{ipaddr};
		my $ip6addr;
		 $ip6addr = $1 if $portref->{ip6addr} =~ /\[\[(.*)?\]/;
		#long winded statement of this port has to match the a or z side of the ick
		$ret .= "$portref->{hostname}: ERROR-ICK: $portref->{shint} incorrectly labeled as belonging to ICK: $ickref->{ick_id}\n" unless ( lc($portref->{hostname}) eq lc($ickref->{a_hostname}) and lc($portref->{shint}) eq lc($ickref->{a_shint}) ) or ( lc($portref->{hostname}) eq lc($ickref->{z_hostname}) and lc($portref->{shint}) eq lc($ickref->{z_shint}) );
		#check to make sure each port has type = ICK type
		unless  ($ickref->{type} eq $portref->{category}){
		$ret .=  "$portref->{hostname}: ERROR-ICK: $portref->{shint} has type $portref->{category} does not match ICK: $ickref->{ick_id} type $ickref->{type}\n" ;
		$mismatch = $portref->{category};
		$mismatches++;
		}


		#Check the ipv6 address for this port, uses the same L0 check for corde and edge ports
		if($ip6addr ) #is there an ipv6 address?
                        {
                          my $loop0v6err = Validation::Tests::ValidLoopback0ipv6($portref->{hostname}, $portref->{ipaddr}, $ip6addr);
                          $ipv6ret .= $portref->{hostname} . ": $loop0v6err (" . $portref->{shint} . ") ". uc($ickref->{type})."\n" if $loop0v6err;

                        }
                        else #no ipv6 at all
                        {
                                $ipv6ret .=  $portref->{hostname} . ": " . Validation::Tests::ValidLoopback0ipv6($portref->{hostname}, $portref->{ipaddr}, 'blank') . " (" . $portref->{shint} . ") ". uc($ickref->{type})."\n";
                        }
		### END of the ipv6 check
	}
	return $ret . "$ickref->{ick_id}: ERROR-ICK: $ickref->{ick_id} not seen on 2 ports\n" unless $#ips > 0;
	my @ip1 = split(/\./, $ips[0]);
	my @ip2 = split(/\./, $ips[1]);
	
	#ports in same ipv4 block validation
	unless ($ip1[0] eq $ip2[0] and $ip1[1] eq $ip2[1] and $ip1[2] eq $ip2[2] and int($ip1[3]/4) eq int($ip2[3]/4) and $ips[0] =~ /\d+\.\d+\.\d+\.\d+/ and $ips[1] =~ /\d+\.\d+\.\d+\.\d+/){
	#print "Mismaches=$mismatches , mismatch=$mismatch\n";
	if($mismatches==2 and $mismatch eq 'LAG-CORE')
	{	
		#$netinv->SetValues('netinv.ick', 'ick_id', $ickref->{ick_id}, 'type', 'LAG-CORE');
		$dca->SetValues('NetworkDBOR.dbo.icks', 'ick_id', $ickref->{ick_id}, 'type', 'LAG-CORE');
	}
	return $ret . "$ickref->{ick_id}: ERROR-ICK: $ickref->{ick_id} has ports in different /30 networks  ($ips[0], $ips[1])\n" ;
	}
	my $blockaddr = $ips[0];
	#print "$ip1[3]\n";
	my $blockoct = '.' . (int($ip1[3]/4)*4);
	$blockaddr =~ s/\.\d+$/$blockoct/;
	#print "$blockaddr\n";


	#pool validation
	my $pool = $dns->Pool30LookupIPv4($blockaddr);
	return $ret . "$ickref->{ick_id}: ERROR-ICK: Unable to find pool for ICK:$ickref->{ick_id} block:$blockaddr\n" if $pool < 0;
	#EDGE and CORE and EU and NA cases
	if($ickref->{type} eq 'CORE'){
		if($continent eq 'NA'){
			return $ret . "$ickref->{ick_id}: ERROR-ICK: IPv4 block not in NA core-to-core links pool ICK:$ickref->{ick_id} block:$blockaddr\n" unless $pool eq 'AEAO';
		}elsif($continent eq 'EU'){
			return $ret . "$ickref->{ick_id}: ERROR-ICK: IPv4 block not in EU core-to-core links pool ICK:$ickref->{ick_id} block:$blockaddr\n" unless $pool eq 'AEAX';
		}elsif($continent eq 'mismatch'){
			return $ret . "$ickref->{ick_id}: ERROR-ICK: IPv4 block not in core-to-core links pool ICK:$ickref->{ick_id} block:$blockaddr\n" unless $pool eq 'AEAX' or $pool eq 'AEAO';
		}
		

	}elsif($ickref->{type} eq 'EDGE'){
		if($continent eq 'NA'){
			return $ret . "$ickref->{ick_id}: ERROR-ICK: IPv4 block not in NA core-to-edge links pool ICK:$ickref->{ick_id} block:$blockaddr\n" unless $pool eq 'AECD';
                }elsif($continent eq 'EU'){
			return $ret . "$ickref->{ick_id}: ERROR-ICK: IPv4 block not in EU core-to-edge links pool ICK:$ickref->{ick_id} block:$blockaddr\n" unless $pool eq 'AECI';
                }

	}

	$ret = $ipv6ret unless $ret;#no ipv4 or other ick errors then we report our original v6
	return $ret;
}


#ValidICKS looks at ALL active icks and spews the errors
sub ValidICKs{
	my $ret = '';
	#CORE checks
	#my $icks = $netinv->GetIndexRecords('netinv.ick', 'status', 'active', 'type', 'CORE');
	my $icks = $dca->GetIndexICKs('status', 'active', 'type', 'CORE');
	#print scalar(@$icks) . " CORE links . . .\n";
	#my $count = 0;
	for my $ickref (@$icks)
	{
		$ret .= ValidICK($ickref);
	#	$count++;
	#	print "$count\n" unless $count % 100;
	#New core check for Janine goes here:
	#if the CORE ICK is from Core (rancid group = core)  to non-core
	#the interface on the core side needs to have flow ipv4 monitor nf_edge_v[46] sampler 1in10k ingress - this is the flowinrate and ip6flowinrate and flowintype and ip6flowintype in the ports table
		$ret .= NetflowCheck($ickref);	
	}
	#EDGE checks
	#$icks = $netinv->GetIndexRecords('netinv.ick', 'status', 'active', 'type', 'EDGE');
	$icks = $dca->GetIndexICKs('status', 'active', 'type', 'EDGE');
	#print scalar(@$icks) . " EDGE links . . .\n";
	#$count = 0;
	for my $ickref (@$icks)
        {
                $ret .= ValidICK($ickref);
	#	$count++;
         #       print "$count\n" unless $count % 100;

        }

	#report invalid descriptions for COED,CORE,EDGE,NODE ICKS without ICK id
	my $ports = $netinv->GetCustomRecords("SELECT * FROM netinv.netports where category in ('CORE','COED','NODE','EDGE') and ick_id='000000' and active='Y' and facility!='TUN';");
	for my $portref (@$ports)
	{
		#straightforward - the results are errors, print them
		my $error = $portref->{hostname} . ": ERROR-DESC: " . $portref->{shint} . " labeled as category " . $portref->{category} . " but no ICK given\n" unless $portref->{hostname} =~ /\.dev\d\d\./;
		$ret .= $error;

	}
	$ports = $dca->GetCustomRecords("SELECT hostname,netports.ick_id,shint FROM netinv.dbo.netports JOIN networkdbor.dbo.icks ON netports.ick_id=icks.ick_id WHERE NOT (ick.status='active') AND netports.active='Y';"); 
	for my $portref (@$ports)
	{
		$ret .= $portref->{hostname} . ": ERROR-ICK: " . $portref->{shint} . " labeled as ICK:" . $portref->{ick_id} . " which is not Active\n";


	}




	return $ret;
}

#function to do Janine's netinv check
#input ick reference, output error string or blank if no error
sub NetflowCheck
{
	my $ickref = shift;
	my $ret = '';
	return '' unless $ickref;#no ick passed = no error
	#print "$ickref->{a_port_id}\n$ickref->{z_port_id}\n";
	my $a_side = $netinv->GetNetflowVars($ickref->{a_port_id});
	my $z_side = $netinv->GetNetflowVars($ickref->{z_port_id});
	#print "$a_side->{rancidgrp} $z_side->{rancidgrp}\n";
	my $infos;
	return '' if $a_side->{rancidgrp} eq 'core' and $z_side->{rancidgrp} eq 'core';#no check if both core
	if($a_side->{rancidgrp} eq 'core')
	{
		$infos = $a_side;
	}
	elsif($z_side->{rancidgrp} eq 'core') {
		$infos = $z_side;
	}
	else
	{
		return '';#neither core
	}
	return '' unless $infos->{hostname} =~ /^\w\w\w[24]/;#filter only the 9010 and 9922s


	$ret .= "$infos->{hostname}: ERROR-NETFLOWV4: $infos->{intf} missing flow ipv4 monitor nf_edge_v4 sampler 1in10k ingress\n" unless $infos->{flowintype} eq 'nf_edge_v4' and $infos->{flowinrate} eq '1in10k';
	$ret .= "$infos->{hostname}: ERROR-NETFLOWV6: $infos->{intf} missing flow ipv6 monitor nf_edge_v6 sampler 1in10k ingress\n" unless $infos->{ip6flowintype} eq 'nf_edge_v6' and $infos->{ip6flowinrate} eq '1in10k';
	






	return $ret;
}


#CancelDateCheck
#Post parsing - check all the order ids of active (up/up) ports against their siebel cancel dates
#categorize as being mac'd, older than x days or newer than x days
sub CancelDateCheck {

	my $ret = '';
	my $threshold = 30;
	#terribly fun ways to define constants!  Perl -> do it however you feel like
	%months = qw(Jan 1 Feb 2 Mar 3 Apr 4 May 5 Jun 6 Jul 7 Aug 8 Sep 9 Oct 10 Nov 11 Dec 12);

	my $records = $dca->GetCustomRecords("SELECT [port_id],[active],[dev_id],[hostname],[intf],[adminstat],[operstat],[descr],tik,[orderno],[changedate],[CancellationDate],[TLG].[mjain].[OPM_Order_Details].OrderId as MACID" .
"  FROM [NetInv].[dbo].[netports] join [TLG].[mjain].[Order_Prov_Details] on orderno=[OrderId] left join [TLG].[mjain].[OPM_Order_Details] on orderno=MacOrderList where active='y' and adminstat=1 and operstat=1 and [CancellationDate] < CURRENT_TIMESTAMP;");

	my @today = (localtime)[5,4,3];
	$today[0] += 1900;
	$today[1]++;
	for my $record (@$records)
	{
		if($record->{MACID}){
			$ret .= "$record->{hostname}: WARN-MACDCANCEL: $record->{intf} has order $record->{orderno} mac'd by $record->{MACID}\n";


		}else{
			my @ymd;
			#print "$record->{CancellationDate}\n";
			#sql date looks like Jan 15 2015 12:00AM
			@ymd  = ($3, $1, $2) if $record->{CancellationDate} =~ /^(\w+)\s+(\d+)\s+(\d+)/;
			$ymd[1] = $months{$ymd[1]};
			my $error = 'WARN-NEWCANCEL';
			#print "@ymd - @today";
			my $dd = Date::Calc::Delta_Days(@ymd, @today);
			$error = 'WARN-OLDCANCEL' if($dd >$threshold);
			$ret .= "$record->{hostname}: $error: $record->{intf} has order $record->{orderno} cancelled $dd days ago\n";
			
		

		}

	}
	return $ret;
}


#implement tests to see if the cogentappsdb networkdbor tables conform to these creation rules (now inline)
sub RouterValidateExpectedServers {
	my $ret = '';#ccheck style error string
	my $device = shift;#hash pointer
	my $servers = $dca->GetCustomRecords("SELECT distinct server, peergroup FROM [NetworkDBOR].[dbo].[bgprr] where client='$device->{dev_id}'");
	my $devrr = $dca->GetIndexRecord('[NetworkDBOR].[dbo].[devices]', 'dev_id', $device->{dev_id});
	my $hubservers = 0; #
	if($device->{rancidgrp} eq 'core'){
		#should have NO servers
#                if($RANCIDGRP == 'core'){# settings are consistent across core devices
#                        Device_SetFullmesh($dev_id, '1');
#                        Device_SetISISlevel($dev_id, 'level-2');


#The logic for this alarm should key off of the device table "full mesh" field being set to 'true', but there being an RR Server... not 'core'. 
		if(@$servers and $devrr->{fullmesh}) {return "$device->{hostname}: WARN-HUBRR: core device has one or more RR servers\n";}
		return '';#leaving out core complaints on non-fullmesh core
	} elsif($device->{rancidgrp} eq 'node'){
#                } elseif($RANCIDGRP == 'node'){#settings are consistent across node devices
#                        Device_SetISISlevel($dev_id, 'level-1');
#                        #RR Servers are in hub (no b0-######) dist devices
#                        $sql = "SELECT dev_id FROM `$DBnetinv`.`devices` join `$DBnetinv`.hubs on devices.hub_id=hubs.hub_id where rancidgrp='dist' and status in ('Planning', 'Active') and node_id = BuildingID + '-' + NodeNum and devices.hub_id='$HUB'";
#                        $rrservers = My_RawRead($sql);
#                        foreach ($rrservers as $rrserver){
#                                Device_AddRR($rrserver[dev_id], $dev_id, 'pop');}
		 $hubservers = $netinv->GetCustomRecords("SELECT dev_id FROM netinv.`devices` join netinv.hubs on devices.hub_id=hubs.hub_id where rancidgrp='dist' and status in ('Planning', 'Active') and node_id = concat(BuildingID, '-', NodeNum) and devices.hub_id='$device->{hub_id}'");

	} elsif($device->{rancidgrp} eq 'dist'){
#new requirements 10/19 -
#'mag' and 'agr' "dist" devices in client hubs should get their feeds from the 'ccr' or 'rcr' "dist" (or core) device in the same HUB...  The (or core) is in paren because there should be no core devices in non full mesh hubs by definition, but we still have some legacy devices out there needing a rename/re-rancid.

		if($device->{hostname} =~ /^(agr|mag)/){
		  $hubservers =  $netinv->GetCustomRecords("SELECT dev_id FROM netinv.`devices`   where  status in ('Planning', 'Active') and (hostname like 'ccr%' or hostname like 'rcr%') and BuildingID='$device->{BuildingID}' and  NodeNum='$device->{NodeNum}' and hub_id='$device->{hub_id}'");
		} else {
		my @hubs;
		push @hubs, $device->{hub_id};
		my $serverhubs = $dca->GetRecords('[NetworkDBOR].[dbo].[hubrr]', 'client', $device->{hub_id});
		for my $serverhub (@$serverhubs){ push @hubs, $serverhub->{server};}
		  $hubservers = $netinv->GetCustomRecords("SELECT dev_id FROM netinv.`devices`  where rancidgrp='core' and status in ('Planning', 'Active')  and hub_id in ('" . join("', '", @hubs) . "')" );
          #      } elseif($RANCIDGRP =='dist'){#non fullmesh hub dist routers have servers from all hub server hub core
          #              Device_SetISISlevel($dev_id, 'level-1-2');
          #              foreach($hubbgp[servers] as $rrservhub){
          #                      $sql = "SELECT dev_id FROM `$DBnetinv`.`devices` where rancidgrp='core' and status in ('Planning', 'Active') and hub_id='" . $rrservhub[hub_id] . "'";
          #                      $rrservers = My_RawRead($sql);
           #             foreach ($rrservers as $rrserver){
           #                     Device_AddRR($rrserver[dev_id], $dev_id, 'internal');}
          #              }
		}
	} else { return '';}#no errors if not node/core/dist

		#could uncouple this but:
		 my %compare;
                for my $serv (@$servers){
                        $compare{$serv->{server}} = 1;
                }
                for my $hubserv (@$hubservers){
                        $compare{$hubserv->{dev_id}} += 2;
                }
                for my $dev_id (keys %compare){
			my $dev = $netinv->GetIndexRecord('netinv.devices', 'dev_id', $dev_id);
			next if $dev->{status} eq 'Decommissioned';
                        if($compare{$dev_id} == 1){ $ret .= "$device->{hostname}: WARN-HUBRR: device has unexpected RR server $dev->{hostname}\n";}
                        elsif($compare{$dev_id} == 2){ $ret .= "$device->{hostname}: WARN-HUBRR: device is missing expected RR server $dev->{hostname}\n";}
			#elsif($compare{$dev_id} == 3){ $ret .= "$device->{hostname}: WARN-NOTERROR: device properlymatches RR server $dev->{hostname}\n";}

		}
	return $ret;
}

#end local vars
}
1;
