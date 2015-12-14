# $HeadURL: svn://hhcv-srcctrl.sys.cogentco.com/cogent/rtrtools/trunk/lib/NetInv/NetPrefixList.pm $
# $Id: NetPrefixList.pm 304 2009-11-05 16:56:41Z marks $

package NetInv::NetPrefixList;

use File::Basename;
use Getopt::Long;
use English;
use IO::File;
use strict;
use Data::Dumper;
use POSIX;

use DBI;

use CiscoACL::PrefixList;
use NetInv;  # Not sure that I need this, but just in case

use MarkUtil;
use Digest::MD5 qw(md5_hex);

my %dbfields = (
      'prefixlist_id' => '$self->prefixlist_id',
      'checksum' => '$self->checksum',
      'dev_id' => '$self->dev_id',
      'hostname' => '$self->{plist}->hostname',
      'name' => '$self->{plist}->name',
      'descr' => '$self->{plist}->descr',
      'elements' => '$self->elements2Str',
      'entrydate' => '$self->entrydate',
      'changedate' => '$self->changedate'
		);


######################################################################
sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {
	prefixlist_id => undef,
	checksum => undef,
	dev_id => undef,
	plist => undef,
	entrydate => undef,
	changedate => undef,
    };
    bless($self,$class);

    $self->{plist} = new CiscoACL::PrefixList;

    return $self;
}
######################################################################
sub prefixlist_id {
    my $self = shift;
    if (@_) { $self->{peer_id} = shift; }
    return $self->{peer_id};
}
######################################################################
sub plist {
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
    
    my $key;
    my $str = '';
    foreach $key (sort(keys(%{$h}))) {
	if (defined($h->{$key})) {
	    $str .= $h->{$key};
	    &DebugPR(5,"Adding to checksum $key == " . $h->{$key} . "\n");
	} else {
	    &DebugPR(5,"Skipping as undef $key \n");

	}
    }

    &DebugPR(3,"Making checksum on $str\n");
    
    return($self->checksum(md5_hex($str)));
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

		$db->Audit('netpeers','','update',"Updating " . 
			 $self->{peer}->hostname . "-" . 
			 $self->{peer}->ip . "($peer_id)  $changes");
		$db->UpdateRecord('netpeers','peer_id',\%newrec);
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

    $str = "Dumping NetPrefixList  ";
    $str .= Data::Dumper->Dump([$self],[qw(*self)]);
    
    if (@_) { 
        print $str;
    }
    return($str);
}




1;
