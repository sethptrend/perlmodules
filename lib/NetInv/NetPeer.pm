# $HeadURL: svn://hhcv-srcctrl.sys.cogentco.com/cogent/rtrtools/trunk/lib/NetInv/NetPeer.pm $
# $Id: NetPeer.pm 304 2009-11-05 16:56:41Z marks $

package NetInv::NetPeer;

use File::Basename;
use Getopt::Long;
use English;
use IO::File;
use strict;
use Data::Dumper;
use POSIX;

use DBI;

use BGPPeer;
use NetInv;  # Not sure that I need this, but just in case

use MarkUtil;
use Digest::MD5 qw(md5_hex);

my %dbfields = (
      'peer_id' => '$self->peer_id',
      'checksum' => '$self->checksum',
      'dev_id' => '$self->dev_id',
      'hostname' => '$self->{peer}->hostname',
      'ip' => '$self->{peer}->ip',
      'peergroup' => '$self->{peer}->peergroup',
      'peerpolicy' => '$self->{peer}->peerpolicy',
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
      'maxprefix' => '$self->{peer}->maxprefix',
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
	peer_id => undef,
	checksum => undef,
	dev_id => undef,
	peer => undef,
	entrydate => undef,
	changedate => undef,
    };
    bless($self,$class);

    $self->{peer} = new BGPPeer;

    return $self;
}
######################################################################
sub peer_id {
    my $self = shift;
    if (@_) { $self->{peer_id} = shift; }
    return $self->{peer_id};
}
######################################################################
sub peer {
    my $self = shift;
    if (@_) { $self->{peer} = shift; }
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
sub NetPeer2Hash {
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
sub Hash2NetPeer {
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
	    my $s = '$self->{peer}->' . $key . '($self->Str2h($key,$hptr->{$key}));';
	    eval ($s);
	}
    }

    return($self->peer);
}

######################################################################
sub MakeChecksum {
    my $self = shift;
    
    my $h = $self->NetPeer2Hash;
    
    return($self->checksum(&h2Checksum($h)));  
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

    my $s = '$self->{peer}->' . $acltype;

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

    my $s = '$self->{peer}->' . $acltype;

    
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

sub AddUpdatePeer {
    my $self = shift;
    my $db = shift;  # this is a NetInv
    my $updateonly = shift;

    $self->MakeChecksum;

    my $hptr = $self->NetPeer2Hash;

    my $peer_id= $self->peer_id;

    if ($hptr->{'dev_id'} == 0) {
	my $dev_id = $db->Hostname2DevID($hptr->{'hostname'});
	    
	if (defined($dev_id)) {
	    $hptr->{'dev_id'} = $dev_id;
	}
    }

    if (defined($peer_id)) {
	my $entry_ref = $db->GetRecord('netpeers','peer_id',$peer_id);

	if (defined($entry_ref)) {  # Exists, just build an update record
	    my %newrec = ();

	    &DebugPR(2,"Updating existing peer ip " . 
		     $self->{peer}->hostname . "-" . 
		     $self->{peer}->ip . "\n") if $main::debug > 2;


	    delete($hptr->{'entrydate'});
	    delete($hptr->{'changedate'});
	
	    $newrec{'peer_id'} = $peer_id;

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

		$db->UpdateRecord('netpeers','peer_id',\%newrec);
		$db->Audit('netpeers','','update',"Updating " . 
			 $self->{peer}->hostname . "-" . 
			 $self->{peer}->ip . "($peer_id)  $changes");

	    }

	} else {

	    # The peer id we were handed is bogus.  
	    # Should never happen.  

	    &perr("Peer ID " . $peer_id  . "doesn't exist in the database\n");

#           Could just add it with this...
#	    $peer_id = undef;

	}
    } elsif (!defined($updateonly)) { 

# If we decide to just add screwed up peer id's from above, 
# change this from an else to an if:
# if (!defined($peer_id)) 
    
	&DebugPR(1,"Adding new peer " . 
		 $self->{peer}->hostname . "-" . 
		 $self->{peer}->ip . "\n") if $main::debug > 1;


	$peer_id = $db->AddRecord('netpeers',$hptr,'peer_id');
	$db->Audit('netpeers','','insert',"Adding new peer " . 
		   $self->{peer}->hostname . "-" . 
		   $self->{peer}->ip . "($peer_id)");

    }
    return($peer_id);
}


######################################################################
sub dump {
    my $self = shift;
    my $str = '';

    $str = "Dumping NetPeer  ";
    $str .= Data::Dumper->Dump([$self],[qw(*self)]);
    
    if (@_) { 
        print $str;
    }
    return($str);
}




1;
