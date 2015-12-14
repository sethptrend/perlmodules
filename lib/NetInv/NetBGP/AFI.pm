# $HeadURL: svn://hhcv-srcctrl.sys.cogentco.com/cogent/rtrtools/trunk/lib/NetInv/NetBGP/AFI.pm $
# $Id: AFI.pm 1833 2015-04-03 14:49:25Z sphillips $

package NetInv::NetBGP::AFI;

use File::Basename;
use Getopt::Long;
use English;
use IO::File;
use strict;
use Data::Dumper;
use POSIX;
use Carp;

use DBI;

use BGPPeer;
use BGPPeer::AFI;
use NetInv;  # Not sure that I need this, but just in case
use NetInv::NetBGP;  # Not sure that I need this, but just in case

use MarkUtil;

my %dbfields = (
      'bgpafi_id' => '$self->bgpafi_id',
      'bgp_id' => '$self->bgp_id',
      'addrfam' => '$self->{afi}->addrfam',
      'peerpolicy' => '$self->{afi}->peerpolicy',
      'activate' => '$self->{afi}->activate',
      'maxprefix' => '$self->{afi}->maxprefix',
      'prefixlist' => '$self->h2Str("prefixlist")',
      'routemap' => '$self->h2Str("routemap")',
      'distributelist' => '$self->h2Str("distributelist")',
      'filterlist' => '$self->h2Str("filterlist")',
      'entrydate' => '$self->entrydate',
      'changedate' => '$self->changedate'
		);


######################################################################
sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {
	bgpafi_id => undef,
	bgp_id => undef,
	afi => undef,
	entrydate => undef,
	changedate => undef,
    };
    bless($self,$class);

    $self->{afi} = new BGPPeer::AFI;

    return $self;
}
######################################################################
sub bgpafi_id {
    my $self = shift;

    if (@_) { $self->{bgpafi_id} = shift; }
    return $self->{bgpafi_id};
}
######################################################################
sub bgp_id {
    my $self = shift;
    if (@_) { $self->{bgp_id} = shift; }
    return $self->{bgp_id};
}
######################################################################
sub afi {
    my $self = shift;
    if (@_) { $self->{afi} = shift; }
    return $self->{afi};
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
sub NetBGPAFI2Hash {
    my $self = shift;
    
    my %h = ();

    my $key;

    foreach $key (keys(%dbfields)) {
	my $cmd = '$h{$key} = ' . $dbfields{$key} . ';';
	eval($cmd);
    }
    return(\%h);
}
######################################################################
sub Hash2NetBGPAFI {
    my $self = shift;
    my $hptr = shift;

    return($self->peer) if !defined($hptr);

    my $key;

    foreach $key (keys(%dbfields)) {

	# each key should have a handler function from dbfields

	if ($key ne 'prefixlist' &&
	    $key ne 'distributelist' &&
	    $key ne 'filterlist' &&
	    $key ne 'routemap') {
	    my $cmd = $dbfields{$key} . '($hptr->{$key});';
	    eval($cmd);
	} else {
	    my $s = '$self->{afi}->' . $key . '($self->Str2h($key,$hptr->{$key}));';
	    eval ($s);
	}
    }

    return($self->peer);
}

######################################################################
sub MakeChecksum {
    my $self = shift;
    
    my $h = $self->NetBGPAFI2Hash;
    
    return(&h2Checksum($h));
}

######################################################################
#
# h2Str - hash of acl data
#
# So it's either {} or it's {key=>val,key=>val,...}
#

sub h2Str {
    my $self = shift;
    my $acltype = shift;

    if (!defined($acltype) || 
	($acltype ne 'prefixlist' &&
	 $acltype ne 'routemap' &&
	 $acltype ne 'filterlist' &&
	 $acltype ne 'distributelist')
	) {
	return undef ;
    }

    my $s = '$self->{afi}->' . $acltype;

    my $hptr = eval($s.';');
    my $rv = '{';
    my $key;
    
    foreach $key (sort keys(%{$hptr})) {
	$rv .= "'" . $key . "'=>'" . $hptr->{$key} . "',";
    }

    $rv =~ s/,$//; #remove trailing comma

    $rv .= '}';

    return($rv);
}

######################################################################
#
# Str2h - convert back to pointer to hash of a specific type
#

sub Str2h {
    my $self = shift;
    my $acltype = shift;
    my $str = shift;

    if (!defined($acltype) || 
	($acltype ne 'prefixlist' &&
	 $acltype ne 'routemap' &&
	 $acltype ne 'filterlist' &&
	 $acltype ne 'distributelist')
	) {
	return undef ;
    }

    my $s = '$self->{afi}->' . $acltype;

    
    my $rv = eval($s . ';'); 

    return($rv) if !defined($str);

    return($rv) if ($str eq '{}');

# Should look like {'key'=>'value'} || {'key'=>'value','key'=>'value'...}
    
    $str = s/^\{//; # remove leading {
    $str = s/\}$//; # remove trailing }


# Should look like 'key'=>'value' || 'key'=>'value','key'=>'value'...


    my @pairs = split(/\',\'/,$str);

# Should have an array of net,mask items

    my $item;

    foreach $item (@pairs) {
	my ($key,$value) = split(/\=\>/,$item);
	my $s2 = $s . ($key,$value);
	eval($s2 . ';');
    }

    $rv = eval($s . ';');
    return($rv);
}


######################################################################
#
# This should add this peer to the database or update it if it's already there
# Going to assume this is most useful talking about "self"
#

sub AddUpdateNetBGPAFI {
    my $self = shift;
    my $db = shift;  # this is a NetInv
    my $updateonly = shift;

    if (!defined($self->bgp_id)) {
	carp("NetInv::NetBGP::AFI::AddUpdateNetBGPAFI - bgp_id required but not defined on attempted database update - failing " . $self->dump);
	return(undef);
    }

    my $bgpafi_id= $self->bgpafi_id;

    if (!defined($bgpafi_id)) { # see if we can figure it out
	$bgpafi_id=$self->GetBGPAFI_ID($db); # get existing record id if it exisst
    }

    my $hptr = $self->NetBGPAFI2Hash;

    if (defined($bgpafi_id)) {
	my $entry_ref = $db->GetIndexRecord('netbgpafi','bgpafi_id',$bgpafi_id);

	if (defined($entry_ref)) {  # Exists, just build an update record
	    my %newrec = ();

	    &DebugPR(2,"Updating existing NetBGPAFI $bgpafi_id\n");

	    delete($hptr->{'entrydate'});
	    delete($hptr->{'changedate'});
	
	    $newrec{'bgpafi_id'} = $bgpafi_id;

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
		&DebugPR(1,"Updating Changes NetBGPAFI $bgpafi_id" . 
			 "\n   $changes\n");

		$db->UpdateRecord('netbgpafi','bgpafi_id',\%newrec);
		$db->Audit('netbgpafi','','update',"Updating bgpafi_id = " . 
			 "$bgpafi_id with:  $changes");

	    }

	} else {

	    # The peer id we were handed is bogus.  
	    # Should never happen.  

	    &perr("BGPAFI ID " . $bgpafi_id  . " doesn't exist in the database\n");

#           Could just add it with this...
#	    $bgpafi_id = undef;

	}
    } elsif (!defined($updateonly)) { 

# If we decide to just add screwed up peer id's from above, 
# change this from an else to an if:
# if (!defined($bgpafi_id)) 
    
	&DebugPR(1,"Adding new BGPAFI \n");

	$bgpafi_id = $db->AddRecord('netbgpafi',$hptr,'bgpafi_id');
	$db->Audit('netbgpafi','','insert',"Adding new BGPAFI " . 
		   "$bgpafi_id");
	$self->bgpafi_id($bgpafi_id);

    }
    return($bgpafi_id);
}

######################################################################
#
# Try to get the bgpafi_id from the bgp_id and family info
#
sub GetBGPAFI_ID {
    my $self = shift;
    my $db = shift;

    my $bgpafi_id = undef;

    &DebugPR(4,"NetInv-NetBGP-AFI-GetBGPAFI_ID\n");
    
    my $qry = "SELECT bgpafi_id FROM netbgpafi ";
    $qry   .= "WHERE bgp_id = " . $self->bgp_id;
    $qry  .= " AND addrfam = " . $db->quote($self->{afi}->addrfam);

    my $sth = $db->{dbh}->prepare($qry);
    my $rv = $sth->execute;

    ($bgpafi_id) = $sth->fetchrow_array;

    if (defined($bgpafi_id)) {
	&DebugPR(5,"NetInv-NetBGP-AFI-GetBGPAFI_ID-Found $bgpafi_id\n");
	$self->bgpafi_id($bgpafi_id);
    }

    return($bgpafi_id);
}

######################################################################
sub dump {
    my $self = shift;
    my $str = '';

    $str = "Dumping NetBGPAFI ";
    $str .= Data::Dumper->Dump([$self],[qw(*self)]);
    
    if (@_) { 
        print $str;
    }
    return($str);
}




1;
