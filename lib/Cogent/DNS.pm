# $HeadURL: svn://hhcv-srcctrl.sys.cogentco.com/cogent/rtrtools/trunk/lib/Cogent/DNS.pm $
# $Id: DNS.pm 1833 2015-04-03 14:49:25Z sphillips $

package Cogent::DNS;

use File::Basename;
use English;
use IO::File;
use strict;
use DBI;
use Data::Dumper;
use POSIX;

use MarkUtil;
use Net::IP;

my $DBTYPE='Sybase';
my $DBNAME="Dynamo";
#my $DBHOST='iad-dbsrvr.ms.cogentco.com'; # Development
my $DBHOST='dca-05.ms.cogentco.com';    # Production
my $DBUSER='App_Dynamo';#Daisa is using: DynamoAppUser/psinet01
#my $DBUSER='guestuser';
my $DBPASSWD='VwycD.p38dCmcsMZ';
#my $DBPASSWD='guestuser';

my $dryrun=0;
my $debug=0;
my $errstr;

our %rrtypeid2type = ();
our %rrtype2id = ();

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
        update  => 1,
	cache   => undef
    };
    bless($self,$class);

    if ($self->Connect()) {
	$self->FillRRType();
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
    my $rv;

    my $dbusr = $DBUSER;
    my $dbpass = $DBPASSWD;

    my $dbspec;

    if ($DBTYPE eq 'mysql') {
	$dbspec="DBI:$DBTYPE:database=$DBNAME;host=$DBHOST";
    } elsif ($DBTYPE eq 'Sybase') {
	$dbspec="DBI:$DBTYPE:database=$DBNAME;server=$DBHOST";
    } else {
	die "No valid DBTYPE";
    }

#    $self->{dbh}=DBI->connect($dbspec, $dbusr, $dbpass,{ PrintError=>0 });
    $self->{dbh}=DBI->connect($dbspec, $dbusr, $dbpass, { AutoCommit=>1 });


    if (defined($self->{dbh})) {
        $rv=1;
    } else {
	print "Connect error " . $DBI::errstr . "\n";
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
# Fill the lookup hashes for later use
#
sub FillRRType {
    my $self = shift;

    my $qry = "SELECT rr_type_id,rr_type FROM rr_type ORDER BY rr_type_id ";

    my $sth = $self->{dbh}->prepare($qry);
    my $rv = $sth->execute;

    my @row = ();

    while (@row = $sth->fetchrow_array()) {
	if (defined($row[1]) &&
	    defined($row[0])) {
		$rrtypeid2type{$row[0]} = $row[1];
		$rrtype2id{$row[1]} = $row[0];
	    }
    }
}
######################################################################
# 
# Get a list of all the active in-addr.arpa. zones 
#
sub GetInaddrZones {
    my $self = shift;

    &DebugPR(3,"Cogent::DNS::GetInaddrZones Starting\n");

    my $qry  = "SELECT convert(varchar,[zone_id])as zone_id,[name],convert(varchar,[serial]) as serial FROM zone ";
    $qry .=    "WHERE [act_inact]=1 AND "; # 1 == 'TRUE'
    $qry .=          "[pri_sec] = 1 AND "; # 1 == 'TRUE'
    $qry .=          '[name] LIKE \'%.in-addr.arpa.\' ';

    my $zonehash = $self->{dbh}->selectall_hashref($qry,'name');

    &DebugPR(3,"Cogent::DNS::GetInaddrZones Finish\n");

    return $zonehash;
}
######################################################################
#
# Get a list of all the active ip6.arpa. zones
#
sub GetIP6arpaZones {
	my $self = shift;
	&DebugPR(3,"Cogent::DNS::GetIP6arpaZones Starting\n");
	my $qry  = "SELECT convert(varchar,[zone_id])as zone_id,[name],convert(varchar,[serial]) as serial FROM zone ";
	$qry .=    "WHERE [act_inact]=1 AND "; # 1 == 'TRUE'
	$qry .=          "[pri_sec] = 1 AND "; # 1 == 'TRUE'
	$qry .=          '[name] LIKE \'%.ip6.arpa.\' ';
	 my $zonehash = $self->{dbh}->selectall_hashref($qry,'name');
	&DebugPR(3,"Cogent::DNS::GetIP6arpaZones Finish\n");
	return $zonehash;
}
######################################################################
# 
# Get an array containing all the RR in a zone
#
sub GetRRforZone {
    my $self = shift;
    my $zone_id = shift;

    return(undef) if !defined($zone_id);

    &DebugPR(3,"Cogent::DNS::GetRRforZone $zone_id Starting\n");

    my $qry  = "SELECT rrecord_id,zone_id,name,data,IsActive FROM rrecord ";
    $qry .=    "WHERE zone_id = $zone_id ";

    my $hash_ref = $self->{dbh}->selectall_hashref($qry,['name','rrecord_id']);

    &DebugPR(3,"Cogent::DNS::GetRRforZone $zone_id Finishing\n");

    return($hash_ref);

}

######################################################################
# 
# 
#
sub UpdatePortsInAddrs {
    my $self = shift;
    my $inaddrptr = shift;
    
    &DebugPR(2,"Cogent::DNS::UpdatePortsInAddrs Starting\n");

    my %inaddr = %{$inaddrptr};

    #print Data::Dumper->Dump([\%inaddr],[qw(*inaddr)]);

	 my $dnszones4 = $self->GetInaddrZones;
	my $dnszones6 = $self->GetIP6arpaZones;
	my $dnszones = { %$dnszones4, %$dnszones6 };
    #print Data::Dumper->Dump([$dnszones],[qw(*dnszones)]);

    my $changecount = 0;

    my $zone = '';
    foreach $zone (keys (%inaddr)) {
	if (exists($dnszones->{$zone}) &&
	    exists($dnszones->{$zone}->{'zone_id'})) {
	    &DebugPR(3,"Cogent::DNS::UpdatePortsInAddrs - making changes for $zone\n");

	    my %inaddrzone = %{$self->GetRRforZone($dnszones->{$zone}->{'zone_id'})};
#	    if ($dnszones->{$zone}->{'zone_id'} == 52937) {
#		print "Zone 52937\n" . Data::Dumper->Dump([\%inaddrzone],[qw(*inaddrzone)]);
#	    }

	    my $ip;

	    my $updates = 0;

	    foreach $ip (keys (%{$inaddr{$zone}})) {
		&DebugPR(3,"Cogent::DNS::UpdatePortsInAddrs - Testing $ip\n");

		next if &skipip($zone,$ip);

		my %izone = ();
		
		# Delete any existing FQDN

#print "TEsting $ip.$zone\n";
		
		if (exists($inaddrzone{$ip . ' . ' .  $zone})) { 		# Delete any existing FQDN
		    print "Found FQDN $ip.$zone\n" . Dumper($inaddrzone{$ip . ' . ' .  $zone});
		}

		if (exists($inaddrzone{$ip})) {      # IP exists, update if necessary

		    my @hk= keys(%{$inaddrzone{$ip}});

		    if ($#hk > 0) {  # Multiple records
			# Delete the extras

			my $counter = 1;
			while ($counter <= $#hk) {
			    &DebugPR(4,"Cogent::DNS::UpdatePortsInAddrs - Deleting extra PTR record $ip\n");
			    $self->DeleteRecord('rrecord','rrecord_id',$hk[$counter]);
			    $self->Audit($dnszones->{$zone}->{'zone_id'},$hk[$counter],
					 'delete dup rrecord','');
			    $counter++;
			}
		    }

		    %izone = %{$inaddrzone{$ip}->{$hk[0]}};

		    # izone is a hash containing: rrecord_id, name, data, zone_id, IsActive

		    &DebugPR(4,"Cogent::DNS::UpdatePortsInAddrs - " . "diff of " . $inaddr{$zone}->{$ip} . " vs $izone{'data'} (and IsActive = $izone{'IsActive'})\n") if $main::debug > 4;

		    if (($izone{'name'} eq $ip) &&  # Be certain we have the right record
			(($inaddr{$zone}->{$ip} ne $izone{'data'}) 
			 || ($izone{'IsActive'} ne '1'))
			) {
			
			delete($izone{'name'});
			delete($izone{'zone_id'});
			
			$izone{'data'} = $inaddr{$zone}->{$ip};
			$izone{'date_changed'} = undef;
			$izone{'changed_by'} = 'Cogent::DNS.pm';
			$izone{'IsActive'} = 1;
			$izone{'rr_type_id'} = $rrtype2id{'PTR'};

			&DebugPR(4,"Cogent::DNS::UpdatePortsInAddrs - Updating rrecord $ip.$zone PTR $izone{'data'}\n");
			
			$self->UpdateRecord('rrecord','rrecord_id',\%izone);
			$self->Audit($dnszones->{$zone}->{'zone_id'},$izone{'rrecord_id'},'update rrecord',"$ip PTR $izone{'data'}");
			#record differs, update DB
			$updates++;
			$changecount++;
		    }

		} else {
		    # add new PTR record
		    
		    $izone{'zone_id'} = $dnszones->{$zone}->{'zone_id'};
		    $izone{'name'} = $ip;
		    $izone{'rr_type_id'} = $rrtype2id{'PTR'};
		    $izone{'data'} = $inaddr{$zone}->{$ip};
		    $izone{'date_changed'} = undef;
		    $izone{'entered_into_db'} = undef;
		    $izone{'IsActive'} = 1;
		    $izone{'changed_by'} = 'Cogent::DNS.pm';
		    
		    &DebugPR(4,"Cogent::DNS::UpdatePortsInAddrs - Adding PTR record $izone{'name'}.$zone PTR $izone{'data'}\n");
		    my $rrecord_id = $self->AddRecord('rrecord',\%izone,'rrecord_id');

		    if (defined($rrecord_id)) {
			$self->Audit($dnszones->{$zone}->{'zone_id'},$rrecord_id,'add rrecord',"$izone{'name'} PTR $izone{'data'}");
		    }

		    $updates++;
		    $changecount++;
		}
	    } # End foreach $ip in the zone

	    # if changes made, bump s/n of zone
	    if ($updates) {
		$self->BumpSerial($dnszones->{$zone}->{'zone_id'})
	    }
	} else {
	    # zone or zone_id doesn't exist in dynamo

	    if ($main::debug > 2) {
		my $key;
		foreach $key (sort {$a <=> $b} keys(%{$inaddr{$zone}})) {
		    print "Zone not in Dynamo - Not installing $key.$zone PTR " . $inaddr{$zone}->{$key} . "\n";
		}
	    } else {
		print "Zone not in Dynamo - $zone\n";
		 my $parent = $zone;
		 $parent =~ s/^\d+\.//;
		 if(exists($dnszones->{$parent})){ 
			print "Parent zone exists, would add $zone as sub to $parent\n";      
		 } else {
			print "Parent Zone not in Dynamo - $parent\n";
                 }
	    }
	}
    }
    &DebugPR(2,"Cogent::DNS::UpdatePortsInAddrs Ending\n");

    return($changecount);
}

######################################################################
# 
sub BumpSerial {
    my $self = shift;
    my $zone_id = shift;

    &DebugPR(3,"Cogent::DNS::BumpSerial Starting\n");

    my $qry = "SELECT convert(varchar,serial) AS serial ";
    $qry   .= "FROM zone ";
    $qry   .= "WHERE zone_id = $zone_id";

    my $sth = $self->{dbh}->prepare($qry);
    my $rv = $sth->execute;
    my $old;
    ($old) = $sth->fetchrow_array();

    if (defined($old)) {
          (my $oldprefix) = $old =~ /^(\d+)\d{2}$/;
          my $newprefix = strftime("%Y%m%d",localtime());
          my $newserial;

          if ($oldprefix < $newprefix) {
              $newserial = $newprefix . "01";
          } else {
              $newserial = ++$old;
          }
          
          $qry  = "UPDATE zone ";
          $qry .=    "SET serial=$newserial,date_changed=getdate(),";
          $qry .=        "changed_by='Cogent::DNS.pm' ";
          $qry .=   " WHERE zone_id=" . $zone_id;
        
          $self->DoSQL($qry);
          $self->Audit($zone_id,0,"update zone.serial",$newserial);
    }
    &DebugPR(3,"Cogent::DNS::BumpSerial Ending\n");
}
######################################################################
# 
# skipip - Returns a 1 if we're suppose to ignore this IP for some reason
#
sub skipip {
    my $zone = shift;
    my $ip = shift;

    my $rv = 0;

    return ($rv) if (!defined($zone) || !defined($ip));

    if ($zone eq '3.100.38.in-addr.arpa.') {
	# ignore CST test ip block 38.100.3.0/27
	
	if ($ip >= 0 && $ip <= 31) {
	    $rv = 1;
	}
    } elsif ($zone eq '10.28.66.in-addr.arpa.') {
	# ignore NOC test block 66.28.10.32/27

	if ($ip >= 32 && $ip <= 63) {
	    $rv = 1;
	}
    }

    return ($rv);
}

######################################################################
# 
sub DoSQL {
    my $self = shift;
    my $sql = shift;
    
    my $rv;

    my $noisy = 1; 

    $noisy = 0 if ( @_ );
    
    $self->DebugPR(3,"DEBUG: executing $sql\n");

    if ($self->update) {
        $rv = $self->{dbh}->do($sql);
        if ($noisy && !defined($rv)) {
            $errstr = "DoSQL - $DBI::errstr\nQUERY: $sql";
            $self->perr("$errstr\n");
        }
    } else {
        print ("No Updates - Would have executed:\n$sql\n");
        $rv = 1;
    }

    return $rv;
}

######################################################################
sub AddRecord {
    my $self = shift;
    my($table,$record,$keyfield)=@_;
    my $setclause = "";

    my @cols = ();
    my @vals = ();

    foreach my $key (keys(%$record)) {
	if (defined($record->{$key})) {
	    push(@cols,'[' . $key . ']');
	    push(@vals,$self->quote($record->{$key}));
	} elsif ($key eq 'entered_into_db') {
	    push(@cols,'[entered_into_db]');
	    push(@vals,'getdate()');
        } elsif ($key eq 'time') {
	    push(@cols,'[time]');
	    push(@vals,'getdate()');
	} elsif ($key eq 'date_changed') {
	    push(@cols,'[date_changed]');
	    push(@vals,'getdate()');
	}
    }

    my $qry = "INSERT INTO $table ";
    $qry   .= '(' . join(',',@cols) . ') ';
    $qry   .= ' VALUES ';
    $qry   .= '(' . join(',',@vals) . ') ';

    my $id;
    if ($self->update) {
        &DebugPR(2,"Cogent::DNS::AddRecord: Adding $qry\n");
        if ($self->DoSQL($qry)) {
            if ($keyfield) {

                if ($DBTYPE eq 'mysql') {
		    ($id) = $self->{dbh}->selectrow_array("SELECT LAST_INSERT_ID()");
		} elsif ($DBTYPE eq 'Sybase') {
		    $id = $self->{dbh}->last_insert_id(undef,undef,undef,undef);
		} else {
		    $id = $self->{dbh}->last_insert_id(undef,undef,undef,undef);
		}
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
	    } elsif ($key eq 'entered_into_db') {
		$setclause .= "entered_into_db=getdate(),\n";
	    } elsif ($key eq 'date_changed') {
		$setclause .= "date_changed=getdate(),\n";
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
sub GetRecord {
    my $self = shift;
    my $table = shift;
    my $keyfield = shift;
    my $value = shift;
    my (@xkey, @xval);
    while(@_) { push @xkey, shift; push @xval, shift;}
    my $qry = "SELECT * FROM $table WHERE $keyfield like "
        .$self->quote($value);
    foreach my $xkey (@xkey)
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
sub GetRecords {
	my $self = shift;
	my  ($table, $keyfield, $value) = (shift, shift, shift);
	my $qry = "SELECT * FROM $table WHERE $keyfield like " . $self->quote($value);
	return $self->{dbh}->selectall_arrayref($qry, {Slice => {}});
}

######################################################################
sub Audit {
    my $self = shift;
    my $zone_id = shift;
    my $rrecord_id = shift;
    my $transaction = shift;
    my $data = shift;

    my $rv = 1;

    my %auditrec = (
		    'username'    => 'Cogent::DNS.pm',
		    'zone_id'     => $zone_id,
		    'rrecord_id'  => $rrecord_id,
		    'transaction' => $transaction,
#		    'time'        => undef,
		    'data'        => $data
		    );

    &DebugPR(1,"Audit " . Dumper(%auditrec)) if $main::debug > 1;

#    $rv = $self->AddRecord('audit',\%auditrec);

    return($rv);
}




####################################################################
#Seth's addition to pull a rrecord and corresponding zone record from an IP address
sub GetZoneByIP {
	my $self = shift;
	my $ip = shift // undef;
	my ($zoneref, $rrecordref);
	return 0 unless defined($ip);
	$rrecordref = $self->GetRecord('[Dynamo].[dbo].[rrecord]', '[data]', $ip, '[isActive]', '1');
	return 0 unless $rrecordref;
	$zoneref = $self->GetRecord('[Dynamo].[dbo].[zone]', '[zone_id]', $rrecordref->{zone_id});
	return 0 unless $zoneref;




	return ($zoneref, $rrecordref);
}


###################################################################
#For hostchange, updating dynamo for cross zone name changes
#input: oldname, newname
#output: array of sql commands to run
sub CrossZoneHostchange {
	my @sqlupdates;
	my $self = shift;
	my $oldname = shift;
	my $newname = shift;
 	return 0 unless defined($oldname);
        return 0 unless defined($newname);

	$oldname =~ /([^.]+\.[^.]+)\.cogentco.com/;
	my $oldhub = $1;
	$newname =~ /([^.]+\.[^.]+)\.cogentco.com/;
	my $newhub = $1;
	my $rv = $self->GetRecord('[Dynamo].[dbo].[zone]', 'name', "$oldhub\%");
	return 0 unless $rv;
	my $oldzoneid = $rv->{zone_id};
	my $rv = $self->GetRecord('[Dynamo].[dbo].[zone]', 'name', "$newhub\%");
        return 0 unless $rv;
	my $newzoneid = $rv->{zone_id};
	#the assumption is that changes will be made which is not guaranteed, BUT bumping the serial is safe either way
	$self->BumpSerial($self->quote($oldzoneid));
	$self->BumpSerial($self->quote($newzoneid));
	$oldname =~ /^(.+)\.$oldhub/;
	my $oldprehub = $1;
	$newname =~ /^(.+)\.$newhub/;
	my $newprehub = $1;
	#make changes in old zone
	$rv = $self->GetRecords('[Dynamo].[dbo].[rrecord]', 'name', "\%$oldprehub");
	my $adata;
	my $cndata;
	my $aname;
	foreach my $row (@$rv) {
		next unless $row;#not really possible
		next unless $row->{zone_id} =~ /$oldzoneid/;
		my $id = $self->quote($row->{rrecord_id});
		if($row->{rr_type_id} =~ /1/) {
			#delete this entry
			$aname = $row->{name};
			$aname =~ s/$oldprehub/$newprehub/;
			$aname = $self->quote($aname);
			$adata = $self->quote($row->{data});
			push @sqlupdates, "UPDATE [Dynamo].[dbo].[rrecord] SET [isActive]=0 WHERE [rrecord_id] like $id";
		} elsif ($row->{rr_type_id}) {
			$cndata = $row->{data};
			$cndata =~ s/$oldprehub/$newprehub/;
			$cndata =~ /^(.*)$newprehub/;
			$cndata = $self->quote($cndata);
			push @sqlupdates,  "UPDATE [Dynamo].[dbo].[rrecord] SET [data]=" . $self->quote($1 . $newname . '.') . " WHERE [rrecord_id] like $id";
		}
	}
	#changes for new zone
	push @sqlupdates, "INSERT INTO [Dynamo].[dbo].[rrecord] (zone_id, name, rr_type_id, data, changed_by) VALUES (" . 
		$self->quote($newzoneid) . ", " .
		$aname . ", " .
		"1, " . 
		$adata . ", \'script\')"  ;
	push @sqlupdates, "INSERT INTO [Dynamo].[dbo].[rrecord] (zone_id, name, rr_type_id, data, changed_by) VALUES (" .
                $self->quote($newzoneid) . ", " .
                $self->quote($newprehub) . ", " .
		"2, " .
		$cndata . ", \'script\')"  ;
		
		


	


	



	return @sqlupdates;
}


sub PoolLookupIPv4 {
	my $self = shift;
	my $ip = shift // 0;
	return -1 unless $ip;
	my $hex = Net::IP->new($ip)->hexip();$hex=~s/^0x//;
	#$hex =~ s/^(\w+)/substr "000$1",-4/eg;
	 $hex=~s/(\w\w\w\w)$/:$1/;
 	my $qry = "SELECT pool FROM [Starfish].[AdminSF].[ip_block] WHERE netaddr like '\%$hex'";
    	my $sth = $self->{dbh}->prepare($qry);
    	my $rv = $sth->execute;

    	my $rec = $sth->fetchrow_hashref();
	return -2 unless $rec;



	return $rec->{pool};
}	
#uses caching of /30 addresses from Starfish
sub Pool30LookupIPv4 {
	my $self = shift;
	my $ip = shift // 0;
	#print $ip;
	return -1 unless $ip =~ /\d+\.\d+\.\d+\.\d+/;
	unless($self->{cache})
	{
		my $qry = "SELECT netaddr, pool FROM [Starfish].[AdminSF].[ip_block] WHERE netmask=126";
		$self->{cache} = $self->{dbh}->selectall_hashref($qry, 'netaddr');
	}
	my $hex = Net::IP->new($ip)->hexip();$hex=~s/^0x//;$hex=~s/(\w\w\w\w)$/:$1/;
	$hex =~ /^(\w+)/;
	my $nib = (substr "000$1",-4);
	$hex =~ s/^(\w+)/$nib/;
	#print $hex . "\n";
	my $index = uc("0000:0000:0000:0000:0000:0000:$hex");
	return -2 unless defined($self->{cache}->{$index});
	return $self->{cache}->{$index}->{pool};
}
#####################################################################
#
#Allows passing of the sql statement
sub GetCustomRecords{

     my $self = shift;
      my $qry = shift;
      return $self->{dbh}->selectall_arrayref($qry, {Slice => {}});
                                                                                      }
#same vein, just returns first record
sub GetCustomRecord{
                                                                                                                                             my $self = shift;                                                                my $qry = shift;

    my $sth = $self->{dbh}->prepare($qry);                                                                                                  my $rv = $sth->execute;

    my $entry_ref = $sth->fetchrow_hashref();
                                                                                                                                            return $entry_ref;



};



1;
