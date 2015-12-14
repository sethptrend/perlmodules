#Seth Phillips
#interface to the danadev tables inheriting from Connection.pm
#12/2/13


use strict;
use warnings;
use lib '../';

package Connection::DanaDev;
use Connection::Connection;
use NetInv;
our @ISA = ('Connection::Connection');



#only overwritten portion is the constructor which defines the database
sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {
        dbh     => undef,
        update  => 1,
#in the base class these are undefined . . . basically base class functions should not work unless inherited
        dbname => "danadev",
        dbhost => 'cyclops.sys',
        dbusr => 'dana',
        dbpass => 'php4m3',
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


#danadev specific functions
sub getpopcode {
	my $self = shift;
	my $hub = shift // 'xxxx';
	my $rec = $self->GetRecord('danadev.BGP_HUB_Communities', 'HUB', uc(substr($hub,0,3)));
	return 0 unless defined($rec);
	return $rec->{Community};
}

sub getcountrycode {
	my $self = shift;
	my $hub = shift // 'xxxx';
	my $hubrec = NetInv->new()->GetRecord('netinv.hubs', 'hub_id', uc($hub));
	return 0 unless $hubrec;
	my $rec = $self->GetRecord('danadev.BGP_Country_Communities', 'Domain', '.' . lc($hubrec->{country}));
	return 0 unless $rec;
	return '174:' . $rec->{Community};
}

sub getcustcomm {
	my $self = shift;
        my $hub = shift // 'xxxx';
        my $hubrec = NetInv->new()->GetRecord('netinv.hubs', 'hub_id', uc($hub));
        return 0 unless $hubrec;
	return '21001' if $hubrec->{region} eq 'NA';
	return '21101' if $hubrec->{region} eq 'EU';
	return '21201' if $hubrec->{region} eq 'AP';
	return 0;
}

sub getpeercomm {
        my $self = shift;
        my $hub = shift // 'xxxx';
        my $hubrec = NetInv->new()->GetRecord('netinv.hubs', 'hub_id', uc($hub));
        return 0 unless $hubrec;
        return '21000' if $hubrec->{region} eq 'NA';
        return '21100' if $hubrec->{region} eq 'EU';
	return '21200' if $hubrec->{region} eq 'AP';
	return 0;
}

sub getXRfullmesh {
	my $self = shift;
	my $region = shift;

	#it seems like it's safe to assume the region is real . . . lots of meh involved here (also only used in one place so less bad)
	my @ret;
	my $recs = $self->GetCustomRecords("SELECT hostname from netinv.devices join netinv.hubs on devices.hub_id=hubs.hub_id join danadev.core_devices on devices.dev_id=core_devices.dev_id where bgp_fullmesh=1 and region='$region' and chassis_type like 'ASR%' and status='Active'");
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
        my $recs = $self->GetCustomRecords("SELECT hostname from netinv.devices join netinv.hubs on devices.hub_id=hubs.hub_id join danadev.core_devices on devices.dev_id=core_devices.dev_id where bgp_fullmesh=1 and region='$region' and chassis_type not like 'ASR%' and status='Active'");
        for my $rec (@$recs)
        {
                push @ret, $rec->{hostname};
        }

        return @ret;




}


#echo getInterfaceTemplate($chassis,$prefix,$facility,$caveats,$vars,$rlimitTemplate);
#^^ dana's function that we're replicating
sub getInterfaceTemplate {
	my $self = shift;
	my $chassis = shift;
	my $prefix = shift;
	my $facility  = shift;
	my $caveats = shift;#this should be a searchable string
	#these two inputs are optional in dana's, probably getting cut in the perl version
	my $vars = shift;#questionable
	my $rlimittemplate = shift;#also questionable

	my $mod = '';
	my $ret = '';
	if($chassis) {
                $mod = " INNER JOIN `Interface_Chassis_Types` ON `Interface_Templates`.`ID`=`Interface_Chassis_Types`.`Interface_Templates_ID` WHERE  `Interface_Chassis_Types`.`Netinv_ciscohw_chassis` = '$chassis'";
        } elsif ($prefix  || $facility) {
                $mod = " WHERE ";
        }
        if($prefix ) {
                if($chassis ) {
                        $mod = $mod . " AND ";
                }
                $mod = $mod . "`Interface_Templates`.`Prefix` = '$prefix' ";
        }
        if($facility ){
                if($chassis  || $prefix ) {
                        $mod = $mod . " AND ";
                }
		$facility =~ s/-L//;
                $mod = $mod . "`Interface_Templates`.`Facility` = '" . $facility ."'";
        }

	#print "SQL: SELECT `Interface_Templates`.`Template`,`Interface_Templates`.`Caveat_Groupings_ID` FROM danadev.`Interface_Templates`  $mod\n";
	my $recs = $self->GetCustomRecords( "SELECT `Interface_Templates`.`Template`,`Interface_Templates`.`Caveat_Groupings_ID` FROM danadev.`Interface_Templates`  $mod");

	return '' unless $recs;#no sql results no joy

	return $recs->[0]->{Template} if (scalar @$recs) == 1;#only 1 result -> give it back, this could be wrong if the caveats don't match, but it's more of a net

	for my $rec (@$recs){
		if ( $rec->{Caveat_Groupings_ID} =~ /$caveats/  ){ return $rec->{Template}; }

	}



	return $ret;
}

#($POP, my $countrycode, my $continentcode, my $peercode) = $danadb->getCommunityByHub($token1);
sub getCommunityByHub {
	my $self = shift;
	my $hub = shift;

	return 0 unless $hub;#this is debatable, might even change to a die, but style dicates error return and handle later
	my $rec = $self->GetCustomRecord("SELECT country, region FROM netinv.hubs WHERE hub_id like '$hub%'");
	return 0 unless $rec;#hub doesn't exist, invalid input
	my $country = $rec->{country};
	my $region = $rec->{region};
	$rec = $self->GetCustomRecord("SELECT Community FROM danadev.BGP_HUB_Communities WHERE HUB='$hub'");
	return 0 unless $rec;#no entry in Dana table
	my $popcode = $rec->{Community};
	$rec = $self->GetCustomRecord("SELECT Community FROM danadev.BGP_Country_Communities WHERE Domain='.$country'");
	return 0 unless $rec;#no entry in Dana table
	my $countrycode = '174:' . $rec->{Community};
	my $contcode=0;
	my $peercode=0;#default zeroes for unknown regions
	if($region eq 'NA'){$contcode = 21001; $peercode= 21000;}
	elsif($region eq 'EU'){$contcode = 21101;$peercode=21100;}
	elsif($region eq 'AP'){$contcode=21201;$peercode=21200;}
	return ($popcode, $countrycode, $contcode, $peercode);	

}

#$bgpdb->Isfullbgp($hostname)
#hostname partial or full hostname like '$input\%'
#output is 1 or 0
sub Isfullbgp {
	my $self = shift;
	my $host = shift;
	my $rec = $self->GetCustomRecord("SELECT count(*) as cnt FROM danadev.core_devices left join netinv.devices on core_devices.dev_id=devices.dev_id WHERE hostname like '$host\%' and bgp_fullmesh=1");
	return $rec->{cnt};

}

# #my $query =
#"php-cgi -f /local/apache/www/data/opstools/dana/getRRbyHostname.php hostname=$hostname";                            #my $return = &query($query);
      #@returnlist = split( /\,/, $return );
#        @returnlist = $bgpdb->GetRRServers($hostname);
#used like $element->{peer}, $element->{type}
sub GetRRServers {
	my $self = shift;
	my $host = shift;
	my $recs = $self->GetCustomRecords("SELECT a.hostname as peer, peergroup as type FROM danadev.bgp_rrs left join netinv.devices as a on server_dev_id=a.dev_id left join netinv.devices as b on client_dev_id=b.dev_id WHERE b.hostname like '$host\%'");
	return @$recs;


}
#same input and output as above except it returns the Clients of host
sub GetRRClients {
	my $self = shift;
        my $host = shift;
        my $recs = $self->GetCustomRecords("SELECT a.hostname as peer, peergroup as type FROM danadev.bgp_rrs left join netinv.devices as a on client_dev_id=a.dev_id left join netinv.devices as b on server_dev_id=b.dev_id WHERE b.hostname like '$host\%'");
        return @$recs;
}

#$bgpdb->getrouterisislevel($hostname)
#for now this defaults to level-2 if it doesn't exist, i think that's fair
sub getrouterisislevel {
	my $self = shift;
	my $host = shift;
	my $rec = $self->GetCustomRecord("SELECT isis_level FROM netinv.devices join danadev.core_devices on devices.dev_id=core_devices.dev_id where hostname like '$host\%'");
	return $rec->{isis_level} if $rec;
	return 'level-2';#fail return
}



1;
