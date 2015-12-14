# $HeadURL: svn://hhcv-srcctrl.sys.cogentco.com/cogent/rtrtools/trunk/lib/NetInv/NetBGP.pm $
# $Id: NetBGP.pm 305 2009-11-05 16:59:49Z marks $

package NetInv::NetBGP;

use File::Basename;
use Getopt::Long;
use English;
use IO::File;
use strict;
use Data::Dumper;
use POSIX;

use DBI;

use BGPPeer;
use BGPPeer::AFI;
use NetInv;  # Not sure that I need this, but just in case
use NetInv::NetBGP::AFI;

use MarkUtil;
use Digest::MD5 qw(md5_hex);

my %dbfields = (
      'bgp_id' => '$self->bgp_id',
      'checksum' => '$self->checksum',
      'dev_id' => '$self->dev_id',
      'hostname' => '$self->{peer}->hostname',
      'ip' => '$self->{peer}->ip',
      'peergroup' => '$self->{peer}->peergroup',
      'peersession' => '$self->{peer}->peersession',
      'asn' => '$self->{peer}->asn',
      'category' => '$self->{peer}->category',
      'company' => '$self->{peer}->company',
      'orderno' => '$self->{peer}->orderno',
      'softreconfig' => '$self->{peer}->softreconfig',
      'localas' => '$self->{peer}->localas',
      'descr' => '$self->{peer}->descr',
      'rvw' => '$self->{peer}->rvw',
      'valid' => '$self->{peer}->valid',
      'adminstat' => '$self->{peer}->adminstat',
      'entrydate' => '$self->entrydate',
      'changedate' => '$self->changedate'
		);


######################################################################
sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {
	bgp_id => undef,
	checksum => undef,
	dev_id => undef,
	peer => undef,
	addrfam => {},  # Hash to NetInv::NetBGP::AFI objects
	entrydate => undef,
	changedate => undef,
    };
    bless($self,$class);

    $self->{peer} = new BGPPeer;
    
    return $self;
}
######################################################################
sub bgp_id {
    my $self = shift;
    if (@_) { $self->{bgp_id} = shift; }
    return $self->{bgp_id};
}
######################################################################
sub peer {
    my $self = shift;
    if (@_) { 
	$self->{peer} = shift; 
	$self->CreateNetBGP_AFI;
    }
    return $self->{peer};
}
######################################################################
sub checksum {
    my $self = shift;
    if (@_) { $self->{checksum} = shift; }
    return $self->{checksum};
}
######################################################################
sub dev_id {
    my $self = shift;
    if (@_) { $self->{dev_id} = shift; }
    return $self->{dev_id};
}
######################################################################
sub entrydate {
    my $self = shift;
    if (@_) { $self->{entrydate} = shift; }
    return $self->{entrydate};
}
######################################################################
sub changedate {
    my $self = shift;
    if (@_) { $self->{changedate} = shift; }
    return $self->{changedate};
}
######################################################################
#
# addrfam - pointer to hash to NetBGP::AFI objects
#
# ->addrfam = return hash pointer
# ->addrfam(key) = return pointer to NetBGP::AFI object (if it exists)
# ->addrfam(key,ptr) = add pointer to hash   hash{key} = ptr
#
sub addrfam {
    my $self = shift;
    my @opts = @_;
    if (@opts) { 
        my $key = shift(@opts);
        my $hptr = $self->addrfam;
        if (@opts) { 
            $hptr->{$key} = shift(@opts);
        } else {
            if (exists($hptr->{$key})) { 
                return $hptr->{$key}; 
            } else {
                return undef;
            }
        }
    }
    return ($self->{addrfam});
}
######################################################################
sub addrfams {
    my $self = shift;

    my @keys = keys(%{$self->addrfam});
    if (@keys) {
        return(sort(@keys));
    } else {
        return(()); # return empty array
    }
}
######################################################################
#
# Creates any associated NetInv::NetBGP::AFI objects necessary
# to match peer afi objects
#
sub CreateNetBGP_AFI {
    my $self = shift;

    &DebugPR(4,"NetInv-NetBGP-CreateNetBGP_AFI\n");

    my @famlist = $self->{peer}->addrfams;

    if (@famlist) {
	foreach my $fam (@famlist) {
	    &DebugPR(5,"NetInv-NetBGP-CreateNetBGP_AFI creating child AFI $fam\n");
	    my $addrfam = undef;
	    if (!defined($self->addrfam($fam))) {
		$addrfam = new NetInv::NetBGP::AFI;
		$self->addrfam($fam,$addrfam);
	    } else {
		$addrfam = $self->addrfam($fam);
	    }
	    $addrfam->afi($self->{peer}->addrfam($fam));
	}
    }
}
######################################################################
sub NetBGP2Hash {
    my $self = shift;
    
    my %h = ();

    my $key;

    foreach $key (keys(%dbfields)) {
	my $cmd = '$h{$key} = ' . $dbfields{$key} . ';';
	eval($cmd);
    }
    # Everything from inside peer is now part of the hash except
    # the AFI stuff, that should be in it's own objects
    #
    return(\%h);
}
######################################################################
sub Hash2NetBGP {
    my $self = shift;
    my $hptr = shift;

    return($self->peer) if !defined($hptr);

    my $key;

    foreach $key (keys(%dbfields)) {

	# each key should have a handler function from dbfields

	my $cmd = $dbfields{$key} . '($hptr->{$key});';
	eval($cmd);
    }

    # AFI objects need to be recreated by calling functions
    # not done here.

    return($self->peer);
}

######################################################################
#
sub MakeChecksum {
    my $self = shift;
    
    my $h = $self->NetBGP2Hash;

    # basic hash.  Now we should get checksums for each of the AFI objects
    # if they exist and add them to the mix.

    foreach my $addrfam ($self->addrfams) {
	my $afi = $self->addrfam($addrfam);
	$h->{$addrfam . '-checksum'} = $afi->MakeChecksum;
    }
    
    return($self->checksum(&h2Checksum($h)));  
}


######################################################################
#
# This should add this peer to the database or update it if it's already there
# Going to assume this is most useful talking about "self"
#

sub AddUpdateNetBGP {
    my $self = shift;
    my $db = shift;  # this is a NetInv
    my $updateonly = shift;


    $self->MakeChecksum;  # this triggers checksums on AFI children as well

    my $hptr = $self->NetBGP2Hash;

    my $bgp_id= $self->bgp_id;

    if ($hptr->{'dev_id'} == 0) {
	my $dev_id = $db->Hostname2DevID($hptr->{'hostname'});
	    
	if (defined($dev_id)) {
	    $hptr->{'dev_id'} = $dev_id;
	}
    }

    if (defined($bgp_id)) {
	my $entry_ref = $db->GetRecord('netbgp','bgp_id',$bgp_id);

	if (defined($entry_ref)) {  # Exists, just build an update record
	    my %newrec = ();

	    &DebugPR(2,"Updating existing peer ip " . 
		     $self->{peer}->hostname . "-" . 
		     $self->{peer}->ip . "\n") if $main::debug > 2;


	    delete($hptr->{'entrydate'});
	    delete($hptr->{'changedate'});
	
	    $newrec{'bgp_id'} = $bgp_id;

	    my $changes = '';

	    foreach my $key (keys(%$hptr)) {
		if ($hptr->{$key} ne $entry_ref->{$key}) {
		    &DebugPR(2,"$key:'" . $hptr->{$key}. "' ne '" 
			     .  $entry_ref->{$key} . "'\n");
		    $newrec{$key} = $hptr->{$key};
		    $changes .= "'$key' = '$newrec{$key}'  ";
		}
	    }
	    if ($changes ne '') {
		&DebugPR(1,"Updating Changes " . 
			 $self->{peer}->hostname . "-" . 
			 $self->{peer}->ip . "\n   $changes\n") if $main::debug > 1;

		$db->UpdateRecord('netbgp','bgp_id',\%newrec);
		$db->Audit('netbgp','','update',"Updating " . 
			 $self->{peer}->hostname . "-" . 
			 $self->{peer}->ip . "($bgp_id)  $changes");
	    }
	} else {

	    # The peer id we were handed is bogus.  
	    # Should never happen.  

	    &perr("BGP ID " . $bgp_id  . "doesn't exist in the database\n");

#           Could just add it with this...
#	    $bgp_id = undef;

	}
    } elsif (!defined($updateonly)) { 

# If we decide to just add screwed up peer id's from above, 
# change this from an else to an if:
# if (!defined($bgp_id)) 
    
	&DebugPR(1,"Adding new BGP " . 
		 $self->{peer}->hostname . "-" . 
		 $self->{peer}->ip . "\n") if $main::debug > 1;


	# initial insert to get a bgp_id
	$bgp_id = $db->AddRecord('netbgp',$hptr,'bgp_id');
	$self->bgp_id($bgp_id);  # now that we have it, might as well save it
	$self->MakeChecksum;  # checksum is different now that we have a bgp_id
	my %newrec = ();
	$newrec{'bgp_id'} = $bgp_id;
	$newrec{'checksum'} = $self->checksum;
	$db->UpdateRecord('netbgp','bgp_id',\%newrec); # and update 

	$db->Audit('netbgp','','insert',"Adding new peer " . 
		   $self->{peer}->hostname . "-" . 
		   $self->{peer}->ip . "($bgp_id)");



    }

    # update any AFI children as well

    foreach my $addrfam ($self->addrfams) {
	my $afi = $self->addrfam($addrfam);
	$afi->bgp_id($bgp_id);
	$afi->GetBGPAFI_ID($db); # get existing record id if it exists
	$afi->AddUpdateNetBGPAFI($db,$updateonly);
    }

    return($bgp_id);
}


######################################################################
sub dump {
    my $self = shift;
    my $str = '';

    $str = "Dumping NetBGP  ";
    $str .= Data::Dumper->Dump([$self],[qw(*self)]);
    
    if (@_) { 
        print $str;
    }
    return($str);
}




1;
