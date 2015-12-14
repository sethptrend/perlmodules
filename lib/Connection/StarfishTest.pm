#Seth Phillips
#interface to the danadev tables inheriting from Connection.pm
#12/2/13


use strict;
use warnings;
use lib '../';

package Connection::StarfishTest;
use Connection::Connection;
our @ISA = ('Connection::Connection');
use Digest::MD5 qw(md5 md5_hex);
use Digest::SHA1 qw(sha1_hex);
use JSON;



#only overwritten portion is the constructor which defines the database
sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {
        dbh     => undef,
        update  => 1,
#in the base class these are undefined . . . basically base class functions should not work unless inherited
        dbname => "[Starfish-TEST]",
        dbhost => 'hhcp-devdb2012.ms.cogentco.com',
        dbusr => 'AdminSF',
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



#sftest specific functions

	

#####################################
#Subsection for use with the probes database log storage
#####################################
#insertProbeData(name, datestring, tempstring, humiditystring)
#calculates md5 hash of given then inserst into table as hash, blah
sub insertProbeData {
my $self = shift or die;
my $name = shift;
my $datestring = shift // '';
my $tempstring = shift // '';
my $humiditystring = shift // '';
my $hash = md5_hex($name, $datestring, $tempstring, $humiditystring);

my $qry ="insert into [Starfish-TEST].[AdminSF].[probes_data] values (" . $self->quote($hash) . ", ".$self->quote( $name) . ", " . $self->quote($datestring). ", ". $self->quote($tempstring).", ". $self->quote($humiditystring).");";
#print $qry . "\n";
$self->DoSQL($qry);
                                                                                      
}

#@targets = $db->GetProbesTargets();
#GetProbesTargets for returning an array of target hostnames like updtime01.blah
sub GetProbesTargets {
my $self = shift or die;
my @ret;
my $records = $self->GetCustomRecords("Select * from [Starfish-TEST].[AdminSF].[probes_targets]");
foreach my $record (@$records)
{
	push @ret, $record->{deviceName};
}
return @ret;

}



#Functions dealing with net dbor
#addGoodResult
#takes a hash that contains hash of order, portA, portB, headports (array with 2 ports)
sub addGoodResult {
my $self = shift or die;
my $row = shift;
#group id will be a hash of the input
my $groupID = sha1_hex(encode_json($row));
#print "$groupID\n";
my $vlan = 0;
$vlan = $1 if $row->{headPorts}->[0]->{intf} =~ /\.(\d+)$/;
my $order_vc = $row->{order}->{OrderID};
my $vcType = $row->{order}->{'VC Type'};

$self->DoSQL("INSERT INTO [NetworkDBOR].[dbo].[vlans] VALUES ('$vlan', '$order_vc', '', '', CURRENT_TIMESTAMP, 'scripted', '$groupID', '$vcType', 'EoMPLS', 0);");

#the following is for the 2 PAIR entries:
#[vlan] (from other)
#      ,[continent] get hub, translate
#      ,[country] [NetInv].[dbo].[hubs] (country, region)
#      ,[hub] get hub
#      ,[dev_id] A/Z headPorts[x]  'dev_id' => '9692',
#      ,[port] 'port_id' => '322270',
#      ,[end_dev_id] 'portB' =>
#      ,[end_port]
#      ,[port_orderid] 'order' =>  'VC_PortOrder2' => '1-100023946',
#      ,[group_id] calcd
#      ,[assignlevel] manual
#      ,[assigned_time]

my @matches = ('', '');#so there are some odd rules here about matching a and z to portA and portB
   #decided to go with if hub with -A desc matches portA then that's priority 1, 
my @hubs = ('', '');
my $testhub;
$hubs[0] = $2 if $row->{headPorts}->[0]->{hostname} =~ /\w+\.(b\d+-\d+\.)?(\w\w\w\d\d)/;
$hubs[1] = $2 if $row->{headPorts}->[1]->{hostname} =~ /\w+\.(b\d+-\d+\.)?(\w\w\w\d\d)/;

#print @hubs;
if($row->{headPorts}->[0]->{orderno} =~ /-[Aa]$/){
$testhub = $2 if $row->{portA}->{hostname} =~ /\w+\.(b\d+-\d+\.)?(\w\w\w\d\d)/;
if($testhub eq $hubs[0]){ @matches =( 'A','B');}
else {@matches = ('B', 'A');}



}elsif($row->{headPorts}->[0]->{orderno} =~ /-[Zz]$/){
$testhub = $2 if $row->{portB}->{hostname} =~ /\w+\.(b\d+-\d+\.)?(\w\w\w\d\d)/;
if($testhub eq $hubs[0]){ @matches =( 'B','A');}
else {@matches = ('A', 'B');}

}else{#A/Z label not present, just check
$testhub = $2 if $row->{portA}->{hostname} =~ /\w+\.(b\d+-\d+\.)?(\w\w\w\d\d)/;
if($testhub eq $hubs[0]){ @matches =( 'A','B');}
else {@matches = ('B', 'A');}


}

#print @matches;

for my $i ( 0 .. 1)
{
my $hubrec = $self->GetRecord('[NetInv].[dbo].[hubs]', 'hub_id', $hubs[$i]);
my $side = 'port' . $matches[$i];
#trace parent port_id (ie the one without the dotted subinterface)
my $parentint =$row->{headPorts}->[$i]->{shint};
$parentint =~ s/\.\d+//;
my $portrec = $self->GetCustomRecord("Select [port_id] from [Netinv].[dbo].[netports] where dev_id='$row->{headPorts}->[$i]->{dev_id}' and shint='$parentint';");
my $parentid = $row->{headPorts}->[$i]->{port_id};
$parentid = $portrec->{port_id} if $portrec;
my $resqry = "INSERT INTO [NetworkDBOR].[dbo].[vlanReservations] VALUES ('$vlan',".
    " '$hubrec->{region}'".
", '$hubrec->{country}'".
", '$hubs[$i]'".
", '$row->{headPorts}->[$i]->{dev_id}'".
", '$parentid'".
", '$row->{$side}->{dev_id}'".
", '$row->{$side}->{port_id}'".
", '$row->{$side}->{orderno}'".
", '$groupID', 'manual', CURRENT_TIMESTAMP, 0, '', 0);";
#print "$resqry\n";
$self->DoSQL($resqry);




}

}



#some test functions to see how much better perl's dbi is than mssqli or w/e
#started with copy/paste from php, so code might look extra bad
#New search function for l2 to rule them all
sub GetSearchResults #($port, $router, $vlan, $orderid, $customer, $logoid)
{
	my $self = shift;
	my ($port, $router, $vlan, $orderid, $customer, $logoid) = @_;
	

        #base query - where 1 just so i can chain .= "and "s without setting them aside and then joining
        my $qry = "SELECT distinct vlanReservations.group_id from NetworkDBOR.dbo.vlanReservations left join [TLG].[dbo].[V_SiebelOrders] on port_orderid=ORDER_NUM join NetworkDBOR.dbo.vlans on vlanReservations.group_id=vlans.group_id join  netinv.dbo.netports as headport on vlanReservations.port=headport.port_id left join netinv.dbo.netports as endport on vlanReservations.end_port=endport.port_id where 1=1 ";
        if($port) { $qry .= " and (headport.shint='$port' or endport.shint='$port') ";}
        if($router) { $qry .= " and (headport.hostname like '%$router%' or endport.hostname like '%$router%') ";}
        if($vlan) { $qry .= " and vlanReservations.vlan=$vlan ";}
        if($orderid) { $qry .= " and (vlanReservations.port_orderid='$orderid' or vlans.order_vc='$orderid') ";}
        if($customer) { $qry .= " and V_SiebelOrders.Account='$customer' "; }
        if($logoid) { $qry.= " and V_SiebelOrders.GlobalLogoID='$logoid' "; }
                                                                                                         


        my  $DB_DATA = $self->GetCustomRecords($qry);
	print "$qry\n";
	print $DB_DATA;
        my @ret;
        for my $row (@$DB_DATA)
        {
	print $row->{group_id} . "\n";
	print $row;

         my $vlan_data = $self->GetCustomRecord("SELECT  NetworkDBOR.dbo.vlans.group_id,  NetworkDBOR.dbo.vlans.vlan, NetworkDBOR.dbo.vlans.vcType, NetworkDBOR.dbo.vlans.orderType, NetworkDBOR.dbo.vlans.mtu,  NetworkDBOR.dbo.vlans.order_vc, [TLG].[mjain].[TABLE_V_SiebelOrders].Account, [TLG].[mjain].[TABLE_V_SiebelOrders].GlobalLogoID from NetworkDBOR.dbo.vlans left join [TLG].[mjain].[TABLE_V_SiebelOrders] on [TLG].[mjain].[TABLE_V_SiebelOrders].ORDER_NUM=NetworkDBOR.dbo.vlans.order_vc where [group_id]='".$row->{group_id}."';");
           my     $reservation_data = $self->GetCustomRecords("SELECT NetworkDBOR.dbo.vlanReservations.dev_id, NetworkDBOR.dbo.vlanReservations.port, NetworkDBOR.dbo.vlanReservations.end_dev_id, NetworkDBOR.dbo.vlanReservations.end_port, NetworkDBOR.dbo.vlanReservations.port_orderid, NetworkDBOR.dbo.vlanReservations.localvlan, NetworkDBOR.dbo.vlanReservations.mode,NetworkDBOR.dbo.vlanReservations.tcagg, headport.shint as headshint, headport.hostname as headhostname, endport.shint as endshint, endport.hostname as endhostname from NetworkDBOR.dbo.vlanReservations left join [NetInv].[dbo].[netports] as headport on headport.port_id= NetworkDBOR.dbo.vlanReservations.port left join [NetInv].[dbo].[netports] as endport on endport.port_id=NetworkDBOR.dbo.vlanReservations.end_port where [group_id]='".$row->{group_id}."';");
                $vlan_data->{reservations} = [];
                for my $res (@$reservation_data)
                {
                        push @{$vlan_data->{reservations}},$res;
                }
                push @ret, $vlan_data;

        }




        return @ret;
}

#$bgpdb->getrouterisislevel($hostname)
#for now this defaults to level-2 if it doesn't exist, i think that's fair
sub getrouterisislevel {
        my $self = shift;
        my $host = shift;
        my $rec = $self->GetCustomRecord("SELECT isislevel FROM netinv.dbo.devices as nd join networkdbor.dbo.devices on nd.dev_id=devices.dev_id where hostname like '$host\%'");
        return $rec->{isis_level} if $rec;
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
	$self->DoSQL("DELETE FROM [Starfish-TEST].[AdminSF].[netinv_metacheck] WHERE errorclass='$input'");
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
	my $ignore = $self->GetCustomRecord("SELECT count(*) as c from [Starfish-TEST].[AdminSF].[netinv_metacheck_ignore] where hostname='$vals[0]' and errorclass='$vals[1]' and detail= '$vals[2]'");
	if($ignore->{c} == 0){
	$self->DoSQL("INSERT INTO [Starfish-TEST].[AdminSF].[netinv_metacheck] (hostname, errorclass, detail) values ('$vals[0]', '$vals[1]', '$vals[2]')");
	}

}









1;
