# $HeadURL: svn://hhcv-srcctrl.sys.cogentco.com/cogent/rtrtools/trunk/lib/NetInv.pm $
# $Id: NetInv.pm 818 2014-03-14 12:49:08Z sphillips $

package NetInv;

use File::Basename;
use Getopt::Long;
use English;
use IO::File;
use strict;
use warnings;
use DBI;
use Data::Dumper;
use POSIX;

use MarkUtil;
use NetInv::Device;
use NetInv::NetPort;
use NetInv::Cricket;
use NetInv::Ick;

my $DBNAME="netinv";     # production  DB

# for on dev DB for now

if ($ENV{'NETINV_DEV'}) {
    $DBNAME="netinv-dev";  # development DB
    warn "Database has been overridden to $DBNAME";
}

my $DBHOST="cyclops.sys.cogentco.com";

my $DBUSER="netinv";
my $DBPASSWD="a7fb2ac7";

my $DBUSERRO="netinv-ro";
my $DBPASSWDRO="aa955840a53f3a91ef54e62c1ce100f8";

my $dryrun=0;
#my $debug=0;
my $errstr;


######################################################################
sub dbname {
    return ($DBNAME);
}

######################################################################
sub dbhost {
    return ($DBHOST);
}

######################################################################
sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {
        dbh     => undef,
        update  => 1
    };
    bless($self,$class);

    my $ro = shift;

    if ($self->Connect($ro)) {
        return $self;
    } else {
        # An error occured so return undef
        return undef;
    }

}

######################################################################
# Disconnect from the database when the object is destroyed
sub DESTROY {	

    my $self = shift;
    $self->Disconnect();
}


sub dbh {
    my $self = shift;
    return $self->{dbh};
}

######################################################################
sub update {
    my $self = shift;

    if (@_) { $self->{update} = shift; }
    return $self->{update};
}

######################################################################
# Connect to the database
sub Connect {
    my $self = shift;
    my $ro = shift;
    my $rv;

    my $dbusr = $DBUSER;
    my $dbpass = $DBPASSWD;

    if (defined($ro)) {
	&DebugPR(0,"NetInv::Connect -- Opening DB Read Only\n");
	$dbusr = $DBUSERRO;
	$dbpass = $DBPASSWDRO;
    }

    my $dbspec="DBI:mysql:database=$DBNAME;host=$DBHOST\n;";
    $self->{dbh}=DBI->connect($dbspec, $dbusr, $dbpass,{ PrintError=>0 });

    if ($self->{dbh}) {
	print "DEVELOPMENT DB in use!\n" if ($DBNAME eq "netinv-dev");
        $rv=1;
    } else {
        $rv=0
    }

    return $rv;
}

#####################################################################
sub quote {
    my $self = shift;
    my ($str) = @_;

    if (!defined($str)) {
        $str="";
    }
    return $self->{dbh}->quote($str);
}
######################################################################
#Disconnect from the database
sub Disconnect {
    my $self = shift;
    if ($self->{dbh}) {
        $self->{dbh}->disconnect();
    }

    undef $self->{dbh};
}

######################################################################
# 
sub DoSQL {
    my $self = shift;
    my $sql = shift;
    
    my $rv;

    my $noisy = 1; 

    $noisy = 0 if ( @_ );
    
    &DebugPR(3,"NetInv-DoSQL: executing $sql\n");

    if ($self->update) {
        $rv = $self->{dbh}->do($sql);
        if (($main::debug || $noisy) && !defined($rv)) {
            $errstr = "$DBI::errstr\nQUERY: $sql";
            &perr("$errstr\n");
        }
    } else {
        print ("No Updates - Would have executed:\n$sql\n");
        $rv = 1;
    }

    return $rv;
}

######################################################################
sub getLastID {
    my $self = shift;

    my $id = $self->{dbh}->selectrow_array("SELECT LAST_INSERT_ID()");

    return $id;
}

######################################################################
sub AddRecord {
    my $self = shift;
    my($table,$record,$keyfield,$quiet)=@_;
    my $setclause = "";

    foreach my $key (keys(%$record)) {
        if (defined($record->{$key})) {
            $setclause .= "$key=".$self->quote($record->{$key}).",\n";
        } elsif ($key eq 'entrydate') {
	    $setclause .= "entrydate=NOW(),\n";
	} elsif ($key eq 'createdate') {
	    $setclause .= "createdate=NOW(),\n";
	}
    }

    $setclause =~ s/,\n$//;    #remove trailing comma

    my $qry = "INSERT INTO $table set $setclause \n";

    my $id;
    if ($self->update) {
        &DebugPR(2,"AddRecord: Adding $qry\n");
        if ($self->DoSQL($qry,$quiet)) {
            if ($keyfield) {
                ($id) = $self->{dbh}->selectrow_array("SELECT LAST_INSERT_ID()");
            } else {
                $id=1;
            }
        } else {
            undef($id);
        }
    } else {
        print ("No Updates - Would have executed:\n$qry\n");
        $id=1;
    }
    return $id;
}

######################################################################
sub DeleteRecord {
    my $self = shift;
    my($table,$keyfield,$value)=@_;

    my $qry = "DELETE FROM $table WHERE $keyfield = ";
    $qry .= $self->quote($value);

    return $self->DoSQL($qry);
}


######################################################################
sub UpdateRecord {
    my $self = shift;
    my($table,$keyfield,$record)=@_;
    my $setclause = "";
    my $whereclause = '';
    foreach my $key (keys(%$record)) {
        if ($key eq $keyfield) {
            $whereclause = "$key=".$self->quote($record->{$key});
        } else {
	    if (defined($record->{$key})) {
		$setclause .= "$key=".$self->quote($record->{$key}).",\n";
	    } elsif ($key eq 'entrydate') {
		$setclause .= "entrydate=NOW(),\n";
	    } elsif ($key eq 'createdate') {
		$setclause .= "createdate=NOW(),\n";
	    }
	}
    }

    $setclause =~ s/,\n$//;   #remove trailing comma

    return(undef) if ($whereclause eq '');
    
    my $qry = "UPDATE $table SET $setclause WHERE $whereclause";

    my $rv;

    if ($self->update) {
        &DebugPR(2,"Updating $qry\n");
        my $rv = $self->DoSQL($qry);
    } else {
        print ("No Updates - Would have executed:\n$qry\n");
    }

    return $rv;
}

######################################################################
#Seth - 8/14/13 added additional option key, val pairs to AND on
sub GetRecord {
    my $self = shift;
    my $table = shift;
    my $keyfield = shift;
    my $value = shift;
    my (@xkey, @xval);
    while(@_) { push @xkey, shift; push @xval, shift;}
    my $qry = "SELECT * FROM $table WHERE $keyfield like "
        .$self->quote($value);
    while(my $xkey = shift @xkey)
	{
		my $xval = shift @xval;
		$qry .= " AND $xkey like " . $self->quote($xval);
	}

    my $sth = $self->{dbh}->prepare($qry);
    my $rv = $sth->execute;

    my $entry_ref = $sth->fetchrow_hashref();

    return $entry_ref;
}

######################################################################
#Seth - GetIndexRecord - uses = instead of like and designed 
#specifically for xxx_id lookups
sub GetIndexRecord {
	my $self = shift;
	my $table = shift;
	my $keyfield = shift;
	my $value = shift;
	my $qry = "SELECT * FROM $table WHERE $keyfield=$value";
        my $sth = $self->{dbh}->prepare($qry);
        my $rv = $sth->execute;
        my $entry_ref = $sth->fetchrow_hashref();
        return $entry_ref;
}



#####################################################################
#Seth's addition to give the option of returning an array of records
#expanded 2/24 to have the additional check on extra fields
sub GetRecords {
        my $self = shift;
        my  ($table, $keyfield, $value) = (shift, shift, shift);
        my (@xkey, @xval);
        while(@_) { push @xkey, shift; push @xval, shift;}
        my $qry = "SELECT * FROM $table WHERE $keyfield like " . $self->quote($value);
        while(my $xkey = shift @xkey)
        {
                my $xval = shift @xval;
                $qry .= " AND $xkey like " . $self->quote($xval);
        }

        return $self->{dbh}->selectall_arrayref($qry, {Slice => {}});
}

######################################################################
#
# AddDevice - Add entry to device table
#
sub AddUpdateDevice {
    my $self = shift;
    my $dev = shift;

    my $hptr = $dev->DeviceHash;
    
    my $qry  = "SELECT * FROM devices ";
    $qry .= "WHERE hostname=" . $self->quote($hptr->{'hostname'});

    my $sth = $self->{dbh}->prepare($qry);
    my $rv = $sth->execute;

    my $entry_ref = $sth->fetchrow_hashref();

    my $dev_id = undef;

    if (defined($entry_ref)) {  # Exists, just build an update record
	 my %newrec = ();

	 $dev_id = $entry_ref->{'dev_id'};
	 
	 $hptr->{'dev_id'} = $dev_id;
	 $newrec{'dev_id'} = $dev_id;

	 delete($hptr->{'entrydate'});
	 delete($hptr->{'changedate'});

	 my $changes = '';

	 foreach my $key (keys(%$hptr)) {
	     if ($hptr->{$key} ne $entry_ref->{$key}) {
		 &DebugPR(2,"$key:'" . $hptr->{$key}. "' ne '" 
			  .  $entry_ref->{$key} . "'\n");
		 $newrec{$key} = $hptr->{$key};
		 $changes .= "$key='$newrec{$key}'  ";
	     }
	 }

	 if ($changes ne '') {
	     &DebugPR(1,"Updating existing $dev_id: " . $hptr->{'hostname'} .
		      " -- " . $changes . "\n");
	     $self->UpdateRecord('devices','dev_id',\%newrec);
	     $self->Audit('devices','','update',"Updating " . 
			$hptr->{'hostname'} . "($dev_id)  $changes");


	 }
     } else {
	 $dev_id = $self->AddRecord('devices',$hptr,'dev_id');
	 &DebugPR(1,"Added new device $dev_id: " . $hptr->{'hostname'} . "\n"); 
	 $self->Audit('devices','','insert',"Added new device: " . 
		      $hptr->{'hostname'} . "($dev_id)");
     }

    return($dev_id);
}

######################################################################
sub GetDevices {
    my $self = shift;
    my $qry = "SELECT * FROM devices ";

    my $key = shift;

    $key = 'dev_id' if (!defined($key));

    my $devhash = $self->{dbh}->selectall_hashref($qry,$key);

    return $devhash;
}
######################################################################
sub GetDevicesHW {
    my $self = shift;
    my $qry = "SELECT * FROM ciscohw ";

    my $key = shift;

    $key = 'dev_id' if (!defined($key));

    my $devhash = $self->{dbh}->selectall_hashref($qry,$key);

    return $devhash;
}

######################################################################
sub GetActiveDevices {
    my $self = shift;

    my $qry = "SELECT * FROM devices ";
    $qry   .= "WHERE status = 'Active' ";

    my $key = shift;

    $key = 'dev_id' if (!defined($key));

    my $devhash = $self->{dbh}->selectall_hashref($qry,$key);

    return $devhash;
}

######################################################################
sub GetMonitorDevices {
    my $self = shift;
    my $key = shift;

    $key = 'dev_id' if (!defined($key));

    my $qry = "SELECT * FROM devices ";
    $qry   .= "WHERE status = 'Active' AND ";
    $qry   .= "FIND_IN_SET('monitor',enable) > 0 ";

    my $devhash = $self->{dbh}->selectall_hashref($qry,$key);

    return $devhash;
}

######################################################################
sub GetRancidDevices {
    my $self = shift;
    my $key = shift;

    $key = 'dev_id' if (!defined($key));

    my $qry = "SELECT * FROM devices ";
    $qry   .= "WHERE status = 'Active' AND ";
    $qry   .= " hardware = 'cisco' AND ";
    $qry   .= "FIND_IN_SET('rancid',enable) > 0 ";

    my $devhash = $self->{dbh}->selectall_hashref($qry,$key);

    return $devhash;
}
######################################################################
sub GetDevRegion {
    my $self = shift;

    my $qry  = "SELECT dev_id,hostname,hubs.hub_id,country,region FROM devices,hubs ";
    $qry    .= "WHERE hubs.hub_id=devices.hub_id AND ";
    $qry    .=       "status = 'Active'";

    my $devhash = $self->{dbh}->selectall_hashref($qry,'hostname');

    return $devhash;

}

######################################################################
sub GetCricket {
    my $self = shift;
    my $qry = "SELECT * FROM cricket ";

    my $crickethash = $self->{dbh}->selectall_hashref($qry,'cricket_id');

    return $crickethash;
}
######################################################################
sub GetCricketCat {
    my $self = shift;

    my $qry = "SELECT DISTINCT category FROM netports,cricket ";
    $qry .= "WHERE cricket.active='Y' and netports.port_id=cricket.port_id ";
    $qry .= "ORDER BY category";

    my $cricketarr = $self->{dbh}->selectall_arrayref($qry);

    return $cricketarr;
}
######################################################################
sub GetActiveCricket {
    my $self = shift;
    my $qry = "SELECT * FROM cricket ";
    $qry   .= "WHERE active = 'Y' ";

    my $crickethash = $self->{dbh}->selectall_hashref($qry,'cricket_id');

    return $crickethash;
}
######################################################################
sub GetActiveCricketPorts {
    my $self = shift;
    my $category = shift;  # cricket category

    my $qry  = "SELECT cricket_id,cricket.target as ctarget,ports.*,";
    
    if (defined($category)) {
	if ($category =~ /CUST/) {
	    $qry .= "UPPER(CONCAT(ports.company,ports.orderno))";
	} elsif ($category =~ /PEER/) {
	    if ($category =~ /PUBLIC/) {
		$qry .= "UPPER(ports.company)";
	    } else {
		$qry .= "UPPER(CONCAT(ports.company,'-',ports.orderno))";
	    }
	} else {
	    $qry .= "UPPER(ports.target)";
	}
    } else {
	$qry .= "UPPER(ports.target)";
    }

    $qry .= " AS sortname \n";
    $qry .= "FROM cricket,netports = ports \n";
    $qry .= "WHERE cricket.active='Y' \n";
    if (defined($category)) {
	if ($category =~ /PEER/) {
	    $qry .=   "AND ports.category='PEER' \n";
	    if ($category =~ /PUBLIC/) {
		$qry .= "AND ports.peertype = 'PUBLIC' \n";
	    } else {
		$qry .= "AND ports.peertype = 'PRIVATE' \n";
	    }
	} else {
	    $qry .=   "AND ports.category=" . $self->quote($category) . " \n";
	}
    }
    $qry .=       "AND ports.port_id = cricket.port_id \n";
    $qry .= "ORDER BY sortname \n";

    return($self->DBCports2Harray($qry));
}


######################################################################
sub GetPorts {
    my $self = shift;
    my $wherecls = shift;

    my $qry = "SELECT port_id,dev_id,hostname,intf,checksum,company,orderno,active FROM netports ";

    if (defined($wherecls)) {
	$qry .= 'WHERE ';
	if ($wherecls eq 'Active') {
	    $qry .= "active = 'Y'";
	} else {
	    $qry .= $wherecls;
	}
    }

    my $porthash = $self->{dbh}->selectall_hashref($qry,'port_id');

    $porthash = {} if !defined($porthash);

    return $porthash;
}
######################################################################
#
# Get peers from devices that are active
#
sub GetPeers {
    my $self = shift;
    my $wherecls = shift;

    my $qry  = "SELECT bgp_id,netbgp.dev_id as dev_id,netbgp.hostname as hostname,ip, ";
    $qry    .=        "checksum,asn,company,orderno,category,descr ";
    $qry    .= "FROM netbgp,devices ";
    $qry    .= "WHERE netbgp.dev_id = devices.dev_id ";
    $qry    .=       "AND devices.status = 'active' ";

    if (defined($wherecls)) {
	if ($wherecls eq 'Active') {
	    $qry .= "AND adminstat = 1 ";
	} else {
	    $qry .= "AND $wherecls ";
	}
    }

    my $peerhash = $self->{dbh}->selectall_hashref($qry,'bgp_id');

    $peerhash = {} if !defined($peerhash);

    return $peerhash;
}
######################################################################
sub GetNetIGP {
    my $self = shift;
    my $wherecls = shift;

    my $qry = "SELECT igp_id,checksum,port_id,igptype,metric FROM netigp ";

    if (defined($wherecls)) {
	$qry .= "WHERE $wherecls ";
    }

    my $igphash = $self->{dbh}->selectall_hashref($qry,'igp_id');

    $igphash = {} if !defined($igphash);

    return $igphash;
}

######################################################################
sub GetActivePorts {
    my $self = shift;
    my $qry = "SELECT port_id,netports.hostname,intf,checksum ";
    $qry   .= "FROM netports,devices ";
    $qry   .= "WHERE netports.dev_id = devices.dev_id ";
    $qry   .=       "AND devices.status = 'active' ";
    $qry   .=       "AND netports.active = 'Y' ";

    my $porthash = $self->{dbh}->selectall_hashref($qry,'port_id');

    return $porthash;
}
######################################################################
sub GetActivePortIPs {
    my $self = shift;

    &DebugPR(4,"Starting NetInv->GetActivePortIPs\n"); 

    my $qry  = "SELECT port_id,netports.hostname,shint,ipaddr,netmask,secipaddr,ip6addr ";
    $qry    .= "FROM netports,devices ";
    $qry    .= "WHERE netports.dev_id = devices.dev_id ";
    $qry    .=       "AND devices.status = 'active' ";
    $qry    .=       "AND active = 'Y' AND adminstat=1 AND (ipaddr <> 'unk' OR ip6addr <> '[]')";

    my $porthash = $self->{dbh}->selectall_hashref($qry,'port_id');

    &DebugPR(4,"Done NetInv->GetActivePortIPs\n"); 

    return $porthash;
}
######################################################################
sub GetActivePortIP6 {
    my $self = shift;
    my $qry  = "SELECT port_id,netports.hostname,shint,ip6addr ";
    $qry    .= "FROM netports,devices ";
    $qry    .= "WHERE netports.dev_id = devices.dev_id ";
    $qry    .=       "AND devices.status = 'active' ";
    $qry    .=       "AND active = 'Y' AND adminstat=1 AND ip6addr <> '[]' ";

    my $porthash = $self->{dbh}->selectall_hashref($qry,'port_id');

    return $porthash;
}

######################################################################
#
# IP2hostname - With no arg return a pointer to a hash of IP addr to hostname
#               With an IP address as an arg return just the hostname
#               
#
sub IP2Hostname {
    my $self = shift;
    my $ip = shift;
    my $rv = undef;

    my $qry;

    if (defined($ip)) {  # return hostname of IP
	
	$qry  = "SELECT hostname FROM netports ";
	$qry .= "WHERE active = 'Y' AND adminstat=1 AND ";
	$qry .=       "(ipaddr = " . $self->quote($ip) . " OR " ;
	$qry .=       "secipaddr LIKE " . $self->quote('%' . $ip . ',%') . ")" ;

	my $sth = $self->{dbh}->prepare($qry);
	my $rv = $sth->execute;

	($rv) = $sth->fetchrow_array;

	if (defined($rv)) {
	    # if we got a result, check to see if there is more than one entry
	    $rv = undef if defined($sth->fetchrow_array);

	    # we could elect to return a pointer to an array here
	    # but that's not really what I want to do at this point
	}
    } else { # return hash of all IP's to hostname

	my %ipaddrs = ();
	my $portlist = $self->GetActivePortIPs;

	my $key;
	foreach $key (keys(%{$portlist})) {
	    my %port = %{$portlist->{$key}};

	    $ipaddrs{$port{'ipaddr'}} = $port{'hostname'};

	    my $np = new NetInv::NetPort;

	    $np->Str2SecIP($port{'secipaddr'});
	    my $pport = $np->port;        

	    # insert any secondaries we find...
	    my @secarr = @{$pport->secipaddr};
        
	    if ($#secarr > -1) {
		my $arptr;
		foreach $arptr (@secarr) {
		    $ipaddrs{$arptr->[0]} = $port{'hostname'};
		}
	    }
	    undef($pport);
	    undef($np);
	}

	$rv = \%ipaddrs;
    }
    return($rv);
}

######################################################################
sub GetPortsDesc {
    my $self = shift;
    my $wherecls = shift;

    my $qry = "SELECT port_id,netports.dev_id,netports.hostname,shint,category,facility,tohost,ick_id,descr ";
    $qry    .= "FROM netports,devices ";
    $qry    .= "WHERE netports.dev_id = devices.dev_id ";
    $qry    .=       "AND devices.status = 'active' ";

    if (defined($wherecls)) {
	if ($wherecls eq 'Active') {
	    $qry .= " AND active = 'Y'";
	} else {
	    $qry .= " AND $wherecls";
	}
    }

    my $porthash = $self->{dbh}->selectall_hashref($qry,'port_id');

    $porthash = {} if !defined($porthash);

    return $porthash;
}
######################################################################
sub GetLivePorts {
    my $self = shift;
    my $region = shift;

    my $qry  = "SELECT ports.* FROM netports = ports ";
    if (!defined($region)) {
	$qry .= "WHERE ";
    } else {
	$qry  = ",devices = devs, hubs";
	$qry .= "WHERE hubs.region = $region AND ";
        $qry .=       "hubs.hub_id=devs.hub_id AND ";
	$qry .=       "devs.hostname = ports.hostname AND ";
    }
    $qry .=       "ports.active = 'Y' ";
    $qry .= "ORDER BY ports.hostname, ports.intf";


    return($self->DBports2array($qry));
}
######################################################################
sub GetPeerPorts {
    my $self = shift;
    my $wherecls = shift;

    my $qry  = "SELECT * FROM netports ";
    $qry .=    "WHERE category = 'PEER' AND active = 'Y' AND valid = 1 ";
    if (defined($wherecls)) {
	$qry .= " AND ( $wherecls ) ";
    }
    $qry .=    "ORDER BY peertype,company";

    return($self->DBports2array($qry));
}

######################################################################
sub GetEoMPLSxcon {
    my $self = shift;
    my $key = shift;

    my $qry = 'SELECT port_id,hostname,shint,adminstat,operstat,encap,vc,misc ';
    $qry   .= 'FROM netports ';
    $qry   .= "WHERE active = 'Y' AND adminstat = 1 AND ";
    $qry   .=       "(misc LIKE 'xconnect%' OR misc LIKE 'neighbor%') ";

    $key = 'port_id' if (!defined($key));

    my $porthash = $self->{dbh}->selectall_hashref($qry,$key);

    return $porthash;
}

######################################################################
sub GetL2Xcon {
    my $self = shift;
    my $qry = "SELECT * FROM l2xcon ORDER BY port_id";

    my $key = shift;

    $key = 'port_id' if (!defined($key));

    my $porthash = $self->{dbh}->selectall_hashref($qry,$key);

    return $porthash;
}


######################################################################
sub GetL3Xcon {
    my $self = shift;
    my $qry = "SELECT * FROM l3xcon ORDER BY port_id";

    my $key = shift;

    $key = 'port_id' if (!defined($key));

    my $devhash = $self->{dbh}->selectall_hashref($qry,$key);

    return $devhash;
}



######################################################################
sub GetActiveIck {
    my $self = shift;
    my $wherecls = shift;

    &DebugPR(1,"Starting NetInv->GetActiveIck\n"); 

    my $qry = "SELECT ick.*,";
    $qry   .= "aport.hostname as ahostname,aport.shint as ashint,aport.ipaddr as aipaddr, ";
    $qry   .= "zport.hostname as zhostname,zport.shint as zshint,zport.ipaddr as zipaddr ";
    $qry   .= "FROM ick,netports AS aport,netports AS zport ";
    $qry   .= "WHERE ick.status = 'active' ";
    $qry   .=      " AND a_port_id_valid = 1 AND z_port_id_valid = 1 ";
    $qry   .=      " AND a_port_id = aport.port_id AND z_port_id = zport.port_id ";


    if (defined($wherecls) && ($wherecls ne '' )) {
	$qry .= " AND " . $wherecls;
    }

    my $ickhash = $self->{dbh}->selectall_hashref($qry,'ick_id');

    if (!defined($ickhash)) {
	$ickhash = {};
	&DebugPR(0,"NetInv->GetActiveIck $DBI::errstr\nQUERY: $qry\n");
    }

    &DebugPR(1,"Exiting NetInv->GetActiveIck\n"); 

    return $ickhash;
}

######################################################################
sub Hostname2Dev {
    my $self = shift;
    my $hostname = shift;

    my $devref = undef;
    
    if (defined($hostname)) {
	$devref = $self->GetRecord('netinv.devices','hostname',$hostname.'%');
    }

    return($devref);
}
######################################################################
sub Hostname2DevID {
    my $self = shift;
    my $hostname = shift;

    my $dev_id = undef;
    
    if (defined($hostname)) {
	my $dev = $self->GetRecord('devices','hostname',$hostname);
	if (defined($dev)) {
	    $dev_id = $dev->{'dev_id'};
	}
    }

    return($dev_id);
}
######################################################################
sub Hostname2Status{
   my $self = shift;
   my $hostname = shift;
   my $dev = undef;
   $dev = $self->Hostname2Dev($hostname) if defined ($hostname);
   return $dev->{'status'} if defined ($dev);
   return 0;
}

######################################################################
sub GetValidLivePorts {
    my $self = shift;
    my $region = shift;

    my $qry  = "SELECT ports.* FROM netports = ports ";
    if (!defined($region)) {
	$qry .= "WHERE ";
    } else {
	$qry  = ",devices = devs, hubs";
	$qry .= "WHERE hubs.region = $region AND ";
        $qry .=       "hubs.hub_id=devs.hub_id AND ";
	$qry .=       "devs.hostname = ports.hostname AND ";
    }
    $qry .=       "ports.valid = 1 AND ports.active = 'Y' ";
    $qry .= "ORDER BY ports.hostname, ports.intf";


    return($self->DBports2array($qry));
}

######################################################################
sub DBports2array {
    my $self = shift;
    my $qry = shift;

    my $sth = $self->{dbh}->prepare($qry);
    my $rv = $sth->execute;
    if (!defined($rv)) {
	
	$errstr = "DBports2array DB Error: $DBI::errstr\nQUERY: $qry";
	&perr("$errstr\n");
    }

    my $entry_ref;

    my @netports = ();

    while (defined($entry_ref = $sth->fetchrow_hashref())) {
	my $port = new NetInv::NetPort;

	$port->Hash2NetPort($entry_ref);

	push(@netports,$port);
	
    }

    return(\@netports);
}

######################################################################
sub DBCports2Harray {
    my $self = shift;
    my $qry = shift;

    my $sth = $self->{dbh}->prepare($qry);
    my $rv = $sth->execute;
    if (!defined($rv)) {
	
	$errstr = "DBports2array DB Error: $DBI::errstr\nQUERY: $qry";
	&perr("$errstr\n");
    }

    my $entry_ref;

    my @cnetports = ();

    while (defined($entry_ref = $sth->fetchrow_hashref())) {
	my $cricket_id = $entry_ref->{'cricket_id'};
	my $ctarget = $entry_ref->{'ctarget'};
	my $nport = new NetInv::NetPort;

	$nport->Hash2NetPort($entry_ref);

	my %h = ();
	$h{'cricket_id'} = $cricket_id;
	$h{'ctarget'} = $ctarget;
	$h{'nport'} = $nport;

	push(@cnetports,\%h);
	
    }

    return(\@cnetports);
}


######################################################################
sub GetBurstablePorts {
    my $self = shift;
    my $region = shift;

    my $qry  = "SELECT ports.* FROM netports = ports ";
    if (!defined($region)) {
	$qry .= "WHERE ";
    } else {
	$qry  = ",devices = devs, hubs";
	$qry .= "WHERE hubs.region = $region AND ";
        $qry .=       "hubs.hub_id=devs.hub_id AND ";
	$qry .=       "devs.hostname = ports.hostname AND ";
    }
    $qry .=       "ports.valid = 1 AND ports.cir > 0 ";
    $qry .= "ORDER BY ports.company, ports.orderno";

    return($self->DBports2array($qry));
}
######################################################################
sub GetCustomerPorts {
    my $self = shift;
    my $region = shift;

    my $qry  = "SELECT ports.* FROM netports = ports ";
    if (!defined($region)) {
	$qry .= "WHERE ";
    } else {
	$qry .= ",devices = devs, hubs ";
	$qry .= "WHERE hubs.region = " . $self->quote($region) . " AND ";
        $qry .=       "hubs.hub_id=devs.hub_id AND ";
	$qry .=       "devs.hostname = ports.hostname AND ";
    }
    $qry .=       "ports.active = 1 AND ports.valid = 1 AND ";
    $qry .=       "ports.category LIKE 'CUST%' AND NOT(ports.intf LIKE 'Loopback%') ";
    $qry .= "ORDER BY ports.company, ports.orderno";

    return($self->DBports2array($qry));
}
######################################################################
sub GetCustomerPortsByCountry {
    my $self = shift;
    my $country = shift;

    my $qry  = "SELECT ports.* FROM netports = ports ";
    if (!defined($country)) {
	$qry .= "WHERE ";
    } else {
	$qry .= ",devices = devs, hubs ";
	$qry .= "WHERE hubs.country = " . $self->quote($country) . " AND ";
        $qry .=       "hubs.hub_id=devs.hub_id AND ";
	$qry .=       "devs.hostname = ports.hostname AND ";
    }
    $qry .=       "ports.active = 1 AND ports.valid = 1 AND ";
    $qry .=       "ports.category LIKE 'CUST%' AND NOT(ports.intf LIKE 'Loopback%') ";
    $qry .= "ORDER BY ports.company, ports.orderno";

    return($self->DBports2array($qry));
}

######################################################################
sub GetPortByOrderno {
    my $self = shift;
    my $orderno = shift;

    my $qry  = "SELECT * FROM netports ";
    $qry    .= "WHERE valid = 1 AND orderno = " . $self->quote(uc($orderno));
    $qry    .= " ORDER by active ";

    return($self->DBports2array($qry));
}
######################################################################
sub GetPortByOrdernos {
    my $self = shift;
    my $orderno = shift;
    my $wherecls = shift // '';

    my @orderlist = split(/\+/,$orderno);

    my $whereorder = '';

    foreach $orderno (@orderlist) {
	$whereorder .= "orderno = " . $self->quote(uc($orderno));
	$whereorder .= " OR ";
    }

    $whereorder =~ s/ OR $//; #get rid of trailing or

    my $qry  = "SELECT * FROM netports ";
    $qry    .= "WHERE active = 'Y' and valid = 1 AND ";
    $qry    .=       "( $whereorder ) ";
    $qry    .=       "$wherecls";

    return($self->DBports2array($qry));
}
######################################################################
sub GetPortByCatTarget {
    my $self = shift;
    my $category = shift;
    my $target = shift;

    my $qry  = "SELECT * FROM netports ";
    $qry    .= "WHERE valid = 1 AND target = " . $self->quote(lc($target));
    $qry    .= " AND category = " . $self->quote(uc($category));
    $qry    .= " ORDER by active,speed DESC";

    return($self->DBports2array($qry));
}
######################################################################
#
# GetPortByName - Lookup ports by the Interface-router name format we use
#
sub GetPortByName {
    my $self = shift;
    my $name = shift;
    my $globint = shift // 0;
    my $globhost = shift // 0;
    my $subintonly = shift // 0;

    &DebugPR(4,"Netinv-GetPortByName: name: $name\n"); 

    my ($shint,$host) = &splitinthost($name);
    

    if (defined($shint) && defined($host)) { 

	&DebugPR(4,"Netinv-GetPortByName: shint: $shint\n"); 
	&DebugPR(4,"Netinv-GetPortByName: host: $host\n"); 

	$shint .= '.' if $subintonly;

	$shint .= '%' if $globint;
	$host .= '%' if $globhost;

	my $qry  = "SELECT * FROM netports ";
	$qry    .= "WHERE active='Y' ";
	$qry    .= "  AND hostname LIKE " . $self->quote(lc($host));
	$qry    .= "  AND (shint LIKE " . $self->quote(lc($shint));
	$qry    .= "       OR intf LIKE " . $self->quote(lc($shint)) . ")";
	$qry    .= " ORDER by hostname,shint";

	&DebugPR(4,"Netinv-GetPortByName: QRY: $qry\n"); 

	return($self->DBports2array($qry));
    } else { return(undef); }
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
######################################################################
sub DeactivateDevice {
    my $self = shift;
    my $dev_id = shift;

    my %h = ();
    
    &DebugPR(3,"Deactivating $dev_id\n");

    $h{'dev_id'} = $dev_id;
    $h{'status'} = 'Inactive';
    $h{'enable'} = '';

    $self->UpdateRecord('devices','dev_id',\%h);
    $self->Audit('devices','','update',"Deactivating dev_id = $dev_id");

    # deactivate the ports on a deactivated device

    my $qry = "SELECT port_id FROM netports,devices ";
    $qry   .= "WHERE dev_id=$dev_id "; 
    $qry   .=       "AND netports.hostname = devices.hostname";

    my $porthash = $self->{dbh}->selectall_hashref($qry,'port_id');

    foreach my $port_id (keys(%{$porthash})) {
	$self->DeactivatePort($port_id);
    }

    # Remove peers 
    
    $self->CleanPeers($dev_id);

}
######################################################################
sub DeactivatePort {
    my $self = shift;
    my $port_id = shift;

    return() if !defined($port_id);

    &DebugPR(3,"DeactivatePort: Deactivating $port_id\n");

    my $href = $self->GetIndexRecord('netports','port_id',$port_id);
    
    if (defined($href)) {
	my $pent = new NetInv::NetPort;
	$pent->Hash2NetPort($href);
	$pent->Deactivate($self);

	# Deactivate Cricket Entry as well if it exists
	$self->DeactivateCricket($port_id,1);

    } else {
	&perr("DeactivatePort: Tried to deactivate $port_id that doesn't exist in DB\n");
    }
}
######################################################################
sub DeactivateCricket {
    my $self = shift;
    my $id = shift;
    my $useportid = shift;

    my $href = undef;

    if (defined($useportid)) {
	$href = $self->GetIndexRecord('cricket','port_id',$id);
    } else {
	$href = $self->GetRecord('cricket','cricket_id',$id);
    }

    return() if !defined($href);

    &DebugPR(3,"DeactivateCricket: Deactivating " . $href->{'cricket_id'});

    my $cent = new NetInv::Cricket;
    $cent->Hash2Cricket($href);
    $cent->Deactivate($self);

}

######################################################################
sub GetRancidGrp {
    my $self = shift;

    my @arr = ();
    
    my $qry = "SELECT * FROM choices ";
    $qry .=   "WHERE section='rancidgroup' ";

    my $hptr = $self->{dbh}->selectall_hashref($qry,'value');


    if (defined($hptr)) {
	foreach my $key (keys(%{$hptr})) {
	    push (@arr,$key) if ($key ne 'none');
	}
    }

    return(@arr);
}
######################################################################
sub Audit {
    my $self = shift;
    my ($tablename,$user,$transaction,$data) = @_;

    # Insert audit record here

    my %auditrec = ();

    $auditrec{'tablename'} = $tablename;
    $auditrec{'user'} = $user;
    $auditrec{'transaction'} = $transaction;
    $auditrec{'data'} = $data;

    $self->AddRecord('audit',\%auditrec);
    

    return(1);
}
######################################################################
sub CCheck {
    my $self = shift;
    my $str = shift;

    if (defined($str) &&
	($str =~ /(\S+):\s+(\S+):\s+(.+)/)) {

	my %h = ();

	if (defined($1) &&
	    defined($2) &&
	    defined($3)) {

	    $h{'hostname'} = $1;
	    $h{'errorclass'} = $2;
	    $h{'detail'} = $3;

	    $self->AddRecord('ccheck',\%h,'ccheck_id',1);
	}
    }
}
######################################################################
sub CCheckClear {
    my $self = shift;

    $self->DoSQL("TRUNCATE ccheck");
}

######################################################################
#
# Try to connect invalid ports/hosts with netports/devices table ids
#
sub UpdateICK2PortID {
    my $self = shift;

    &DebugPR(1,"Starting NetInv->UpdateICK2PortID\n"); 
    
    my $qry = "SELECT ick_id ";
    $qry   .= "FROM ick ";
    $qry   .= "WHERE status < 'retired' ";
    $qry   .=      " AND (a_port_id_valid = 0 OR z_port_id_valid = 0 ";
    $qry   .=         " OR a_dev_id_valid = 0 OR z_dev_id_valid = 0 ) ";


    my $sth = $self->{dbh}->prepare($qry);
    my $rv = $sth->execute;

    my $ick_id;

    my $count = -1;

    if (!defined($rv)) {
	$errstr = "$DBI::errstr\nQUERY: $qry";
	&perr("$errstr\n");
    }

    ($ick_id) = $sth->fetchrow_array;

    while (defined($ick_id)) {
	$count = 0 if ($count < 0);

	my $ick = new NetInv::Ick;

	$ick->ick_id($ick_id);
	$ick->GetRecord($self);

#	print $ick->dump;

	my $found = 0;

	my $dev_id;
	my $hostname;
	my $port_id;
	
	if (!defined($ick->a_dev_id_valid) || ($ick->a_dev_id_valid == 0)) {
	    &DebugPR(3,"NetInv->UpdateICK2PortID a_dev_id lookup " . $ick->a_hostname . "\n") if $main::debug > 3; 
	    ($dev_id,$hostname) = $self->HostnameLike2DevID($ick->a_hostname);
	    if (defined($dev_id)) {
		$ick->a_dev_id($dev_id);
		$ick->a_dev_id_valid(1);
		$ick->a_hostname($hostname);
		$found++;
	    }
	}

	if (!defined($ick->z_dev_id_valid) || ($ick->z_dev_id_valid == 0)) {
	    &DebugPR(3,"NetInv->UpdateICK2PortID z_dev_id lookup " . $ick->z_hostname . "\n")  if $main::debug > 3; 
	    ($dev_id,$hostname) = $self->HostnameLike2DevID($ick->z_hostname);
	    if (defined($dev_id)) {
		$ick->z_dev_id($dev_id);
		$ick->z_dev_id_valid(1);
		$ick->z_hostname($hostname);
		$found++;
	    }
	}

	if (defined($ick->a_dev_id_valid) 
	    && $ick->a_dev_id_valid
	    && (!defined($ick->a_port_id_valid) 
		|| ($ick->a_port_id_valid == 0))
	    ) {
	    &DebugPR(3,"NetInv->UpdateICK2PortID a_port_id lookup " . $ick->a_hostname . "-" . $ick->a_shint . "\n")  if $main::debug > 3; 
	    ($port_id) = $self->Shint2PortID($ick->a_dev_id,$ick->a_shint);
	    if (defined($port_id)) {
		$ick->a_port_id($port_id);
		$ick->a_port_id_valid(1);
		$found++;
	    }
	}

	if (defined($ick->z_dev_id_valid) 
	    && $ick->z_dev_id_valid
	    && (!defined($ick->z_port_id_valid) 
		|| ($ick->z_port_id_valid == 0))
	    ) {
	    &DebugPR(3,"NetInv->UpdateICK2PortID z_port_id lookup " . $ick->z_hostname . "-" . $ick->z_shint . "\n") if $main::debug > 3; 
	    ($port_id) = $self->Shint2PortID($ick->z_dev_id,$ick->z_shint);
	    if (defined($port_id)) {
		$ick->z_port_id($port_id);
		$ick->z_port_id_valid(1);
		$found++;
	    }
	}

	if ($found) {
	    &DebugPR(3,"NetInv->UpdateICK2PortID Update Record\n"); 
#	    print $ick->dump;
	    $ick->AddUpdate($self);
	    $count++;
	}

	($ick_id) = $sth->fetchrow_array;
    }

    &DebugPR(1,"Finished NetInv->UpdateICK2PortID\n"); 
    return($count);
}

######################################################################
#
# Try to find status problems or misconnects
#
sub UpdateICKStatus {
    my $self = shift;
    my $doretire = shift // 0;
    my $ccerrorptr = shift // [];

    # get the ports and stuff them into a hash

    my $qry = "SELECT port_id, hostname, shint, operstat, ipaddr, ick_id ";
    $qry   .= "FROM netports WHERE active = 'Y' AND ick_id > 0";

    my $porthash = $self->{dbh}->selectall_hashref($qry,'port_id');
    $porthash = {} if !defined($porthash);

    my $l3xcon = $self->GetL3Xcon;
    my %l3cks = %{$l3xcon};

    my %ick2port = (); # ick# for all ports that have ick# -> port mapping
    
    my $port_id;

    my $ick_id;
    foreach $port_id (sort(keys(%$porthash))) {
	$ick_id = $porthash->{$port_id}->{'ick_id'};
	if (!exists($ick2port{$ick_id})) {
	    $ick2port{$ick_id} = {};
	}
	$ick2port{$ick_id}->{$port_id} = $porthash->{$port_id};
    }

    $qry  = "SELECT * ";
    $qry .= "FROM ick ";
    $qry .= "WHERE status < 'retired' ";

    my $ickhash = $self->{dbh}->selectall_hashref($qry,'ick_id');
    my $count = 0;

    &DebugPR(1,"Starting NetInv->UpdateICKStatus\n"); 

    foreach $ick_id (sort(keys(%$ickhash))) {
	my %ick = %{$ickhash->{$ick_id}};

	my $changed = 0;
	my %h = ();
	$h{'ick_id'} = $ick{'ick_id'};

	my $a_good = 0;
	my $z_good = 0;
	my $bogus = 0;

	if (exists($porthash->{$ick{'a_port_id'}}) &&
	    ($porthash->{$ick{'a_port_id'}}->{'ick_id'} eq $ick{'ick_id'})) {
	    $a_good++;
	    $a_good++ if ($porthash->{$ick{'a_port_id'}}->{'operstat'} == 1);
	}
	if (exists($porthash->{$ick{'z_port_id'}}) &&
	    ($porthash->{$ick{'z_port_id'}}->{'ick_id'} eq $ick{'ick_id'})) {
	    $z_good++;
	    $z_good++ if ($porthash->{$ick{'z_port_id'}}->{'operstat'} == 1);
	}

	if (exists($porthash->{$ick{'a_port_id'}})                     # both ports need to exist
	    && exists($porthash->{$ick{'a_port_id'}}->{'ipaddr'})
	    && ($porthash->{$ick{'a_port_id'}}->{'ipaddr'} ne 'unk')   # and have IP addresses
	    && exists($porthash->{$ick{'z_port_id'}}) 
	    && exists($porthash->{$ick{'z_port_id'}}->{'ipaddr'})
	    && ($porthash->{$ick{'z_port_id'}}->{'ipaddr'} ne 'unk')
	    && (!exists($l3cks{$ick{'a_port_id'}})                      # before bogus test makes sense
		|| ($l3cks{$ick{'a_port_id'}}->{'rmt_port_id'} ne $ick{'z_port_id'})
		|| !exists($l3cks{$ick{'z_port_id'}})
		|| ($l3cks{$ick{'z_port_id'}}->{'rmt_port_id'} ne $ick{'a_port_id'}))) {
	    $bogus++; # L3 doesn't interconnect

	}

	if ($ick{'status'} eq "active") {
	    next if ($a_good && $z_good && !$bogus);

	    if (!($a_good || $z_good || $bogus)) { #neither a or z are good and it's !bogus
		if ($doretire) {
		    $changed++;
		    $h{'status'} = 'retired';
		}
	    } else { # it's bogus or one side is bad
		my %portops = ();
		if (defined($ick2port{$ick_id})) {
		    %portops = %{$ick2port{$ick_id}};
		    delete($portops{$ick{'a_port_id'}});
		    delete($portops{$ick{'z_port_id'}});
		    # now portops should just have the "unknown" values .. if any
		}

		my $portstr = '';
		foreach my $port_id (sort(keys(%portops))) {
		    $portstr .= &stripdom($portops{$port_id}->{'hostname'});
		    $portstr .= '-';
		    $portstr .= $portops{$port_id}->{'shint'} . ',';
		}
		$portstr =~ s/,$//; # remove trailing ,



	    }  
	} else {
	    if (($a_good == 2) && ($z_good)) { # found and up -> active
		$changed++;
		$h{'status'} = 'active';
	    } elsif (($ick{'status'} ne 'provisioned') 
		     && $a_good 
		     && $z_good ) { # Found but not up -> provisioned
		$changed++;
		$h{'status'} = 'provisioned';
	    }
	}

	if ($changed) {
	    &DebugPR(3,"NetInv->UpdateICKStatus Update Record\n"); 
	    $self->UpdateRecord('ick','ick_id',\%h);
	    $count++;
	}
    }

    &DebugPR(1,"Finished NetInv->UpdateICKStatus\n"); 
    return($count);
}

######################################################################
#
# Search for a single hostname that matches and return it's 
# dev_id and hostname
# 
# No match or multiple matches return undef
#
sub HostnameLike2DevID {
    my $self = shift;
    my $hostname = shift;

    my $dev_id = undef;

    &DebugPR(2,"Starting NetInv->HostnameLike2DevID\n"); 

    if (defined($hostname)) {
	$hostname .= '%';

	my $qry = "SELECT dev_id,hostname FROM devices WHERE hostname LIKE " 
	    . $self->quote($hostname);

	my $sth = $self->{dbh}->prepare($qry);
	my $rv = $sth->execute;

	($dev_id,$hostname) = $sth->fetchrow_array;
	if (defined($dev_id)) {
	    # if we got a result, check to see if there is more than one entry
	    $dev_id = undef if defined($sth->fetchrow_array);
	}
    }

    $hostname = undef if !defined($dev_id);

    &DebugPR(2,"Finishing NetInv->HostnameLike2DevID\n"); 

    return ($dev_id,$hostname);
}

######################################################################
#
# Search for PortID matching a Shint Name (on a Specific device)
#
sub Shint2PortID {
    my $self = shift;
    my $dev_id = shift;
    my $shint = shift;

    my $port_id = undef;

    &DebugPR(2,"Starting NetInv->Shint2PortID\n"); 

    return(undef) if (!defined($dev_id) || !defined($shint));

    my $qry = "SELECT port_id FROM netports ";
    $qry   .= "WHERE dev_id = " . $self->quote($dev_id);
    $qry  .= " AND shint LIKE " . $self->quote($shint);

    # Using LIKE for case insensitve check
	
    my $sth = $self->{dbh}->prepare($qry);
    my $rv = $sth->execute;

    ($port_id) = $sth->fetchrow_array;

    if (defined($port_id)) {
	# if we got a result, check to see if there is more than one entry
	$port_id = undef if defined($sth->fetchrow_array);
    }

    &DebugPR(2,"Finish NetInv->Shint2PortID\n"); 

    return($port_id);
}

#####################################################
#
# CleanPeers - Remove peer data for inactive devices
#
sub CleanPeers {
    my $self = shift;
    my $dev_id = shift // 0;
    my $count = 0;

    my $qry = "SELECT bgp_id FROM netbgp,devices ";
    $qry   .= "WHERE netbgp.dev_id = devices.dev_id AND devices.status='Inactive' ";

    if ($dev_id) {
	$qry .= "AND dev_id = " . $self->quote($dev_id);
    } 

    my $peerlist = $self->{dbh}->selectall_arrayref($qry);
    return(0) if ((!defined($peerlist)) || (!(scalar @{$peerlist})));

    my $peerptr;

    foreach $peerptr (@{$peerlist}) {
	my $peerid = shift(@{$peerptr});
	# get rid of the stats
        $self->DoSQL("DELETE FROM bgpstats WHERE bgp_id = $peerid");
	# get rid of the entry
	$self->DeleteRecord('netbgpafi','bgp_id',$peerid);
	$self->Audit('netbgpafi','','delete',"Removing inactive device peer - bgp_id $peerid");
	$self->DeleteRecord('netbgp','bgp_id',$peerid);
	$self->Audit('netbgp','','delete',"Removing inactive device peer - bgp_id $peerid");
	$count++;
    }

    return($count);
}


sub GetPath {

	my $self = shift;
	my $host = shift;
	my $device = $self->GetRecord('netinv.devices', 'hostname', "$host\%");
	return 0 unless $device;
	my $ret = "$MarkUtil::ranciddir\/$device->{rancidgrp}\/configs\/$device->{hostname}";
}

1;
