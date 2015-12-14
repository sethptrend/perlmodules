#Seth Phillips
#interface to the magical sql server server
#12/2/13


use strict;
use warnings;
use lib '../';

package Connection::Starfish;
use Connection::Connection;
use Digest::MD5 qw(md5 md5_hex);
our @ISA = ('Connection::Connection');
use Net::IP;



#only overwritten portion is the constructor which defines the database
sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {
        dbh     => undef,
        update  => 1,
#in the base class these are undefined . . . basically base class functions should not work unless inherited
        dbname => "TLG",
        dbhost => 'dca-05.ms.cogentco.com',
        dbusr => 'adminsf',
        dbpass => 'adminsf01',
        dbusrro => undef,
        dbpassro => undef,
        dbtype => 'Sybase'
    };
    bless($self,$class);

    my $ro = shift;

    if ($self->Connect($ro)) {
        return $self;
    }
        # An error occured so return undef
        return undef;

}

#function takes a router name and returns (ipv4, ipv6) l0 addresses
sub GetRouterLoopback0
{
	my $self = shift;
	my $name = shift;
	return (0,0) unless $name;
	#chope .atlas or .atlas.cogentco.com. off the end since it's this way in the db
	$name =~ s/\.atlas.*$//;
	$name =~ s/\.hades.*$//;

	my $ipv6;
	my $ipv4;


	my $rec = $self->GetCustomRecord('Select netaddr from Starfish.AdminSF.ip_block where descr like \'lo0.' . $name . '%\' and version like \'4\';');
	if($rec)
	{
		my $netip = Net::IP->new($rec->{netaddr});
		$ipv4 = $netip->short();
		$ipv4 =~ /::(\w+):(\w+)/;
		my $firstpair = $1;
		my $secondpair = $2;
		my ($oct1, $oct2, $oct3, $oct4);
		#do bad things here
		$oct1 = substr $firstpair, -4, 2 // 0;
		$oct2 = substr $firstpair, -2, 2 // 0;
		$oct3 = substr $secondpair, -4, 2 // 0;
		$oct4 = substr $secondpair, -2, 2 // 0; 
		$ipv4 = join("\.", (hex $oct1, hex $oct2, hex $oct3, hex $oct4));

	}
	else {$ipv4 = 0}

	$rec = $self->GetCustomRecord('Select netaddr from Starfish.AdminSF.ip_block where descr like \'lo0.' . $name . '%\' and version like \'6\';');	 
	if($rec)
        {
		my $netip = Net::IP->new($rec->{netaddr});
                $ipv6 = $netip->short();


        }
        else {$ipv6 = 0}


	return ($ipv4, $ipv6);
}


#####################################
##Subsection for use with the probes database log storage
######################################
##insertProbeData(name, datestring, tempstring, humiditystring)
##calculates md5 hash of given then inserst into table as hash, blah
sub insertProbeData {
my $self = shift or die;
my $name = shift;
my $datestring = shift // '';
my $tempstring = shift // '';
my $humiditystring = shift // '';
my $hash = md5_hex($name, $datestring, $tempstring, $humiditystring);

my $qry ="insert into [Starfish].[AdminSF].[probes_data] values (" . $self->quote($hash) . ", ".$self->quote( $name) . ", " . $self->quote($datestring). ", ". $self->quote($tempstring).", ". $self->quote($humiditystring).");";
#print $qry . "\n";
$self->DoSQL($qry);

}

##@targets = $db->GetProbesTargets();
#GetProbesTargets for returning an array of target hostnames like updtime01.blah
sub GetProbesTargets {
my $self = shift or die;
my @ret;
my $records = $self->GetCustomRecords("Select * from [Starfish].[AdminSF].[probes_targets]");
foreach my $record (@$records)
{
        push @ret, $record->{deviceName};
        }
        return @ret;

}

#in short the relevant information is (and this is almost entirely for audit purposes not editing):
#netaddr - converted for audit plus the actual record ID
#netmask - audit string - this is the one from the table (so -96 if v4 done INSIDE the function)
#ip version (4/6)- audit string
#order ID - audit string (is changing)
#target order id - both (what it changes to)
#blameuser - audit string
sub BlocksUpdateOrderID
{
 my $self = shift;
 my ($netaddr, $netmask, $version, $orderid, $macid, $user) = @_;
 my $displayIP;
	
 if($version =~ /4/){
	$netaddr =~ /(..)(..):(..)(..)$/;
	$displayIP = join('.', sprintf("%d", hex($1)), sprintf("%d", hex($2)),sprintf("%d", hex($3)),sprintf("%d", hex($4))) . '/' . ($netmask-96);
 } else {
	$displayIP = $netaddr . '/' . $netmask;

  }
my $qry = "UPDATE [Starfish].[AdminSF].[ip_block] SET orderid='$macid' WHERE netaddr='$netaddr';";
$self->DoSQL($qry);
$qry = "INSERT INTO [Starfish].[AdminSF].[sf_audit] ([user], [section], [action], [detail] ) VALUES ('$user', 'ip_block', 'edit', " . $self->quote("Changed IP block $displayIP from order id: $orderid -> $macid") . ");";
$self->DoSQL($qry);
return 0;
}

#example call:
#BlocksFreeBlock($result->{netaddr}, $result->{netmask}, $result->{version}, $result->{orderid} ,'script')
#inputs:
#netaddr identifier, converted for audit
#netmask for audit
#version for proper audit conversion
#order id for audit
#username for audit
sub BlocksFreeBlock 
{
	my $self = shift;
 	my ($netaddr, $netmask, $version, $orderid, $user) = @_;
	my $displayIP;

 if($version =~ /4/){
        $netaddr =~ /(..)(..):(..)(..)$/;
        $displayIP = join('.', sprintf("%d", hex($1)), sprintf("%d", hex($2)),sprintf("%d", hex($3)),sprintf("%d", hex($4))) . '/' . ($netmask-96);
 } else {
        $displayIP = $netaddr . '/' . $netmask;

  }
  my @arrtime = localtime;
  my $qry = "UPDATE [Starfish].[AdminSF].[ip_block] SET [free_auto]='yes', [free_date]='" . ($arrtime[5] + 1900) . "-" . ($arrtime[4]+1).  "-$arrtime[3]" . " 23:59:59' WHERE [netaddr]='$netaddr';";
  $self->DoSQL( $qry);
  $qry = "INSERT INTO [Starfish].[AdminSF].[sf_audit] ([user], [section], [action], [detail] ) VALUES ('$user', 'ip_block', 'edit', " . $self->quote("Marked to be freed IP block $displayIP with order id: $orderid") . ");";
  $self->DoSQL($qry);


}

#the new ick tables needs (for confgen): GetICK, BundleCapacity (port / new calculation because 100 links now), GetICKListByHostname (port / new code)
sub GetICK {
	my $self = shift;
	my $ick = shift;
	my $result =  $self->GetCustomRecord("SELECT icks.[ick_id]
      ,[type]
      ,icks.[facility]
      ,[bundle_id]
      ,[status]
      ,DATEDIFF(SECOND,'1970-01-01', icks.[entrydate]) as entrydate
      ,DATEDIFF(SECOND,'1970-01-01', icks.[changedate]) as changedate
      ,[a_port_id]
      ,[z_port_id]
          ,a.[transport] as a_transport
      ,a.[dev_id] as a_dev_id
      ,a.[metric] as a_metric
      ,a.[wavelength] as a_wavelength
      ,a.[otn] as a_otn
      ,a.[fec] as a_fec                                                                                                   ,z.[transport] as z_transport
      ,z.[dev_id] as z_dev_id
      ,z.[metric] as z_metric
      ,z.[wavelength] as z_wavelength
      ,z.[otn] as z_otn
      ,z.[fec] as z_fec
      ,a.ckid as a_ckid
      ,z.ckid as z_ckid
      ,ap.shint as a_shint
          ,zp.shint as z_shint
          ,ap.hostname as a_hostname
          ,zp.hostname as z_hostname
   FROM [NetworkDBOR].[dbo].[icks] join networkdbor.dbo.ports as a on a_port_id=a.port_id join  netinv.dbo.netports as ap on ap.port_id=a.port_id join  networkdbor.dbo.ports as z on z_port_id=z.port_id join  netinv.dbo.netports as zp on zp.port_id=z.port_id where icks.ick_id=$ick ");
	$result->{ick_id} = sprintf("%06d", $result->{ick_id}) if $result;
     return $result;
}

#simple bundle capacity calc, for this iteration it still assumes 10g links
sub BundleCapacity {
        my $self = shift;
        my $bid = shift;
	my $sum = 0;

        #my $rec = $self->GetCustomRecord("SELECT count(*) as count FROM networkdbor.dbo.ick where bundle_id=$bid and status in ('active', 'new', 'planning') and type like 'lag%';");
	my $recs = $self->GetCustomRecords("SELECT facility FROM networkdbor.dbo.icks where bundle_id=$bid and status in ('active', 'new', 'planning') and type like 'lag%';");
	for my $rec (@$recs){
		$rec->{facility} =~ s/\D//g;
		$sum += $rec->{facility};
	}
        return $sum . 'G';

}


#dca->GetIndexICKs( - because the typical ick request is on a joined view not a single table
 #my $icks = $dca->GetIndexICKs('status', 'active', 'type', 'CORE');
sub GetIndexICKs {
	my $self = shift;
        my  ( $keyfield, $value) = ( shift, shift);
         my (@xkey, @xval);
    while(@_) { push @xkey, shift; push @xval, shift;}
    my $qry = "SELECT icks.[ick_id]
      ,[type]
      ,icks.[facility]
      ,[bundle_id]
      ,[status]
      ,DATEDIFF(SECOND,'1970-01-01', icks.[entrydate]) as entrydate
      ,DATEDIFF(SECOND,'1970-01-01', icks.[changedate]) as changedate
      ,[a_port_id]
      ,[z_port_id]
          ,a.[transport] as a_transport
      ,a.[dev_id] as a_dev_id
      ,a.[metric] as a_metric
      ,a.[wavelength] as a_wavelength
      ,a.[otn] as a_otn
      ,a.[fec] as a_fec                                                                                                   ,z.[transport] as z_transport
      ,z.[dev_id] as z_dev_id
      ,z.[metric] as z_metric
      ,z.[wavelength] as z_wavelength
      ,z.[otn] as z_otn
      ,z.[fec] as z_fec
      ,a.ckid as a_ckid
      ,z.ckid as z_ckid
      ,ap.shint as a_shint
          ,zp.shint as z_shint
          ,ap.hostname as a_hostname
          ,zp.hostname as z_hostname
   FROM [NetworkDBOR].[dbo].[icks] join networkdbor.dbo.ports as a on a_port_id=a.port_id join  netinv.dbo.netports as ap on ap.port_id=a.port_id join  networkdbor.dbo.ports as z on z_port_id=z.port_id join  netinv.dbo.netports as zp on zp.port_id=z.port_id ";

    $qry .= " WHERE $keyfield = "
        .$self->quote($value);
    foreach my $xkey (@xkey)
        {                                                                                                                       my $xval = shift @xval;
                $qry .= " AND $xkey = " . $self->quote($xval);
        }


        return $self->{dbh}->selectall_arrayref($qry, {Slice => {}});
}
	


#@list = Connection::Netinv->new()->GetICKListByHostname($hostname);
#takes a hostname (string) coverts to device id then searches icks for having that device ID
sub GetICKListByHostname {
        my $self = shift;
        my $hostname = shift;
        my @retlist;

        my $devrec = $self->GetRecord('netinv.dbo.devices', 'hostname', "$hostname%");
        return @retlist unless $devrec;
        my $ickrecs = $self->GetCustomRecords("SELECT  icks.[ick_id]
      ,status
  FROM [NetworkDBOR].[dbo].[ports] join networkdbor.dbo.icks on ports.ick_id=icks.ick_id where dev_id=$devrec->{dev_id}");
        if(ref($ickrecs))
        {
           for my $ickref (@$ickrecs){
                        push @retlist, sprintf("%06d",$ickref->{ick_id}) if $ickref->{status} ne 'retired';
                }
        }


        return @retlist;
}


# my @blocks =
# # `php-cgi -f /local/apache/www/data/opstools/dana/getIPBlockbyDescr.php x=ICK:$ick`
# #replacing this call in confgen
# # typyicall descr is going to be an ICK
sub getIPv4BlockbyDescr {
      my $self = shift;
      my $descr = shift;
      my $query = "SELECT [netaddr],[netmask] FROM [Starfish].[AdminSF].[ip_block] WHERE [descr] LIKE '%".$descr."%';";
      my $recs = $self->GetCustomRecords($query);
  	for my $rec (@$recs){
		next unless $rec->{netaddr} =~ s/^0000:0000:0000:0000:0000:0000://;
		#print "$rec->{netaddr}\n";
		$rec->{netaddr} =~ /(\w\w)(\w\w):(\w\w)(\w\w)/;
		return hex($1) . '.' . hex($2) . '.' . hex($3) . '.' . hex($4) . '/' . ($rec->{netmask} - 96);
		
	}
	return '';
}

#$bgpdb->getrouterisislevel($hostname)
#for now this defaults to level-2 if it doesn't exist, i think that's fair
sub getrouterisislevel {
        my $self = shift;
        my $host = shift;
        my $rec = $self->GetCustomRecord("SELECT isislevel FROM netinv.dbo.devices as nd join networkdbor.dbo.devices on nd.dev_id=devices.dev_id where hostname like '$host\%'");
        return $rec->{isislevel} if $rec;
        return 'level-2';#fail return
}
sub getXRfullmesh {
        my $self = shift;
        my $region = shift;

        #it seems like it's safe to assume the region is real . . . lots of meh involved here (also only used in one place so less bad)
        my @ret;                                                                                                        my $recs = $self->GetCustomRecords("SELECT hostname from netinv.dbo.devices join netinv.dbo.hubs on devices.hub_id=hubs.hub_id join networkdbor.dbo.devices as dbordevices on devices.dev_id=dbordevices.dev_id where fullmesh=1 and region='$region' and chassis_type like 'ASR%' and status='Active'");
        for my $rec (@$recs)
        {
                push @ret, $rec->{hostname};
        }

        return @ret;

                                                                                                                }
sub getIOSfullmesh {
      my $self = shift;
        my $region = shift;

        #it seems like it's safe to assume the region is real . . . lots of meh involved here (also only used in one place so less bad)
        my @ret;
        my $recs = $self->GetCustomRecords("SELECT hostname from netinv.dbo.devices join netinv.dbo.hubs on devices.hub_id=hubs.hub_id join networkdbor.dbo.devices as coredevices on devices.dev_id=coredevices.dev_id where fullmesh=1 and region='$region' and chassis_type not like 'ASR%' and status='Active'");
        for my $rec (@$recs)
        {
                push @ret, $rec->{hostname};
        }

        return @ret;
}
#$bgpdb->Isfullbgp($hostname)
#hostname partial or full hostname like '$input\%'
#output is 1 or 0
sub Isfullbgp {
        my $self = shift;
        my $host = shift;                                                                                               my $rec = $self->GetCustomRecord("SELECT count(*) as cnt FROM networkdbor.dbo.devices left join netinv.dbo.devices as nd on devices.dev_id=nd.dev_id WHERE hostname like '$host\%' and fullmesh=1");
        return $rec->{cnt};                                                                                                                                                                                                     }
# #my $query =
#"php-cgi -f /local/apache/www/data/opstools/dana/getRRbyHostname.php hostname=$hostname";                            #my $return = &query($query);
      #@returnlist = split( /\,/, $return );
#        @returnlist = $bgpdb->GetRRServers($hostname);
#used like $element->{peer}, $element->{type}
sub GetRRServers {
        my $self = shift;
        my $host = shift;
        my $recs = $self->GetCustomRecords("SELECT a.hostname as peer, peergroup as type FROM networkdbor.dbo.bgprr left join netinv.dbo.devices as a on server=a.dev_id left join netinv.dbo.devices as b on client=b.dev_id WHERE b.hostname like '$host\%'");
        return @$recs;


}
#same input and output as above except it returns the Clients of host
sub GetRRClients {
        my $self = shift;
        my $host = shift;
        my $recs = $self->GetCustomRecords("SELECT a.hostname as peer, peergroup as type FROM networkdbor.dbo.bgprr left join netinv.dbo.devices as a on client=a.dev_id left join netinv.dbo.devices as b on server=b.dev_id WHERE b.hostname like '$host\%'");
        return @$recs;
}

#$db->metacheckclear('WARN-HUBRR');
#delete the table where the errorclass is = input, basically lets seperate scripts "own" their own error space and still clear it each run
sub metacheckclear {
        my $self = shift;
        my $input = shift;
        return 0 unless $input;#actually need that input
        $self->DoSQL("DELETE FROM [Starfish].[AdminSF].[netinv_metacheck] WHERE errorclass='$input'");
}

#$db->metachecklog($line);
#check ccheck style $line into metacheck, later will compare with ignore list
sub metachecklog {
        my $self = shift;
        my $input = shift;
        print "got input $input\n";
        my @vals = split ': ', $input;
        return 0 unless scalar @vals;
        #code to search for the same error in ignore box goes here
        my $ignore = $self->GetCustomRecord("SELECT count(*) as c from [Starfish].[AdminSF].[netinv_metacheck_ignore] where hostname='$vals[0]' and errorclass='$vals[1]' and detail= '$vals[2]'");
        if($ignore->{c} == 0){
        $self->DoSQL("INSERT INTO [Starfish].[AdminSF].[netinv_metacheck] (hostname, errorclass, detail) values ('$vals[0]', '$vals[1]', '$vals[2]')");
        }

}

1;
