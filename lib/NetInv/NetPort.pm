# $HeadURL: svn://hhcv-srcctrl.sys.cogentco.com/cogent/rtrtools/trunk/lib/NetInv/NetPort.pm $
# $Id: NetPort.pm 1919 2015-04-10 15:03:57Z sphillips $

package NetInv::NetPort;

use File::Basename;
use Getopt::Long;
use English;
use IO::File;
use strict;
use Data::Dumper;
use POSIX;

use DBI;

use Port;
use NetInv;  # Not sure that I need this, but just in case

use MarkUtil;

my %dbfields = (
      'port_id' => '$self->port_id',
      'active' => '$self->active',
      'checksum' => '$self->checksum',
      'dev_id' => '$self->dev_id',
      'hostname' => '$self->{port}->hostname',
      'intf' => '$self->{port}->intf',
      'intsuffix' => '$self->{port}->intsuffix',
      'shint' => '$self->{port}->shint',
      'adminstat' => '$self->{port}->adminstat',
      'operstat' => '$self->{port}->operstat',
      'descr' => '$self->{port}->descr',
      'speed' => '$self->{port}->speed',
      'ipaddr' => '$self->{port}->ipaddr',
      'netmask' => '$self->{port}->netmask',
      'secipaddr' => '$self->SecIP2Str',
      'ip6addr' => '$self->IP6Addr2Str',
      'encap' => '$self->{port}->encap',
      'duplex' => '$self->{port}->duplex',
      'portspeed' => '$self->{port}->portspeed',
      'aclin' => '$self->{port}->aclin',
      'aclout' => '$self->{port}->aclout',
      'ip6aclin' => '$self->{port}->ip6aclin',
      'ip6aclout' => '$self->{port}->ip6aclout',
      'policyin' => '$self->{port}->policyin',
      'policyout' => '$self->{port}->policyout',
      'mtu' => '$self->{port}->mtu',
      'ipmtu' => '$self->{port}->ipmtu',
      'ip6mtu' => '$self->{port}->ip6mtu',
      'valid' => '$self->{port}->valid',
      'category' => '$self->{port}->category',
      'peertype' => '$self->{port}->peertype',
      'facility' => '$self->{port}->facility',
      'nodeid' => '$self->{port}->nodeid',
      'virtual' => '$self->{port}->virtual',
      'vc' => '$self->{port}->vc',
      'bandwidth' => '$self->{port}->bandwidth',
      'company' => '$self->{port}->company',
      'orderno' => '$self->{port}->orderno',
      'shaul' => '$self->{port}->shaul',
      'ckid' => '$self->{port}->ckid',
      'pon' => '$self->{port}->pon',
      're' => '$self->{port}->re',
      'tik' => '$self->{port}->tik',
      'cir' => '$self->{port}->cir',
      'cap' => '$self->{port}->cap',
      'l2tp' => '$self->{port}->l2tp',
      'icb' => '$self->{port}->icb',
      'dnlk' => '$self->{port}->dnlk',
      'tohost' => '$self->{port}->tohost',
      'ick_id' => '$self->{port}->ick',
      'nmp' => '$self->{port}->nmp',
      'misc' => '$self->{port}->misc',
      'prov' => '$self->{port}->prov',
      'rvw' => '$self->{port}->rvw',
      'target' => '$self->{port}->target',
      'entrydate' => '$self->entrydate',
      'changedate' => '$self->changedate',
      'flowintype' => '$self->{port}->flowintype',
      'flowouttype' => '$self->{port}->flowouttype',
      'flowinrate' => '$self->{port}->flowinrate',
      'flowoutrate' => '$self->{port}->flowoutrate',
      'ip6flowintype' => '$self->{port}->ip6flowintype',
      'ip6flowouttype' => '$self->{port}->ip6flowouttype',
      'ip6flowinrate' => '$self->{port}->ip6flowinrate',
      'ip6flowoutrate' => '$self->{port}->ip6flowoutrate',
      'switchmode' => '$self->{port}->switchmode',
      'switchaccess' => '$self->{port}->switchaccess',
      'allowedvlans' => '(join ",", @{$self->{port}->allowedvlans})'
		);


######################################################################
sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {
	port_id => undef,
	active => 'Y',
	checksum => undef,
	dev_id => undef,
	port => undef,
	entrydate => undef,
	changedate => undef,
    };
    bless($self,$class);

    $self->{port} = new Port;


    return $self;
}
######################################################################
sub port_id {
    my $self = shift;
    if (@_) { $self->{port_id} = shift; }
    return $self->{port_id};
}
######################################################################
sub active {
    my $self = shift;
    if (@_) { $self->{active} = shift; }
    return $self->{active};
}
######################################################################
sub port {
    my $self = shift;
    if (@_) { $self->{port} = shift; }
    return $self->{port};
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
sub hostname {
    my $self = shift;
    if (@_) { $self->{port}->hostname(shift); }
    return $self->{port}->hostname;
}

######################################################################
sub NetPort2Hash {
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
sub Hash2NetPort {
    my $self = shift;
    my $hptr = shift;

    return($self->port) if !defined($hptr);

    my $key;

    foreach $key (keys(%dbfields)) {

	# each key should have a handler function from dbfields

	if ($key eq 'secipaddr') { # special case, encoded data
	    $self->{port}->secipaddr($self->Str2SecIP($hptr->{$key}));
	} elsif ($key eq 'ip6addr') { # special case, encoded data
	    $self->{port}->ip6addr($self->Str2IP6Addr($hptr->{$key}));
	} else {
	    my $cmd = $dbfields{$key} . '($hptr->{$key});';
	    eval($cmd);
	}
    }
    return($self->port);
}

######################################################################
sub MakeChecksum {
    my $self = shift;
    
    my $h = $self->NetPort2Hash;

    return($self->checksum(&h2Checksum($h)));
}

######################################################################
#
# SecIP2Str - Array of Array of IP & Netmask
#
# So it's either [] or it's [[ip,mask]...]
#

sub SecIP2Str {
    my $self = shift;

    my @arr = @{$self->{port}->secipaddr};
    my $rv = '[';
    
    my $aptr2;

    while ($aptr2 = shift(@arr)) {
	$rv .= "[" . $aptr2->[0] . "," . $aptr2->[1] . "],";
    }

    $rv =~ s/,$//; #remove trailing comma

    $rv .= ']';

    return($rv);
}

######################################################################
#
# Str2SecIP - convert back to Array of Array of IP & Netmask
#

sub Str2SecIP {
    my $self = shift;
    my $str = shift;
    
    my $rv = $self->{port}->secipaddr;


    return($rv) if !defined($str);

    return($rv) if ($str eq '[]');

# Should look like [[net,mask]] || [[net,mask],[net,mask]]
    
    $str =~ s/^\[//; # remove leading [
    $str =~ s/\]$//; # remove trailing ]

# Should look like [net,mask] || [net,mask],[net,mask]...

    $str =~ s/^\[//; # remove leading [
    $str =~ s/\]$//; # remove trailing ]

# Should look like net,mask || net,mask],[net,mask],...,[net,mask],[net,mask


    my @pairs = split(/\],\[/,$str);

# Should have an array of net,mask items

    my $item;

    foreach $item (@pairs) {
	my ($net,$mask) = split(/,/,$item);
	push(@{$rv},[$net,$mask]);
    }

    $self->{'port'}->secipaddr($rv);

    return($rv);
}

######################################################################
#
# IP6Addr2Str - Array of Array 
#
# So it's either [] or it's [[ipv6]...]
#

sub IP6Addr2Str {
    my $self = shift;

    my @arr = @{$self->{port}->ip6addr};
    my $rv = '[';
    
    my $aptr2;

    while ($aptr2 = shift(@arr)) {
	$rv .= "[" . $aptr2->[0] . "],";
    }

    $rv =~ s/,$//; #remove trailing comma

    $rv .= ']';

    return($rv);
}

######################################################################
#
# Str2SecIP - convert back to Array of Array of IP/Netmask
#

sub Str2IP6Addr {
    my $self = shift;
    my $str = shift;
    
    my $rv = $self->{port}->ip6addr;


    return($rv) if !defined($str);

    return($rv) if ($str eq '[]');
    &DebugPR(5,"Str2IP6Addr: Converting $str \n");

# Should look like [[net]] || [[net],[net]]
    
    $str =~ s/^\[//; # remove leading [
    $str =~ s/\]$//; # remove trailing ]

# Should look like [net] || [net],[net]...

    $str =~ s/^\[//; # remove leading [
    $str =~ s/\]$//; # remove trailing ]

# Should look like net || net],[net],...,[net],[net


    my @nets = split(/\],\[/,$str);

# Should have an array of net items

    my $item;

    foreach $item (@nets) {
	push(@{$rv},[$item]);
    }

    $self->{'port'}->ip6addr($rv);
    return($rv);
}


######################################################################
#
# Not sure if the db functions should go here or elsewhere :(
#
# We'll start with them here and see what happens
#

#
# This should add this port to the database or update it if it's already there
# Going to assume this is most useful talking about "self"
#

sub AddUpdatePort {
    my $self = shift;
    my $db = shift;  # this is a NetInv
    my $updateonly = shift;

    $self->MakeChecksum;

    my $hptr = $self->NetPort2Hash;

    if ((!defined($hptr->{'dev_id'}) || $hptr->{'dev_id'} == 0) &&
	defined($hptr->{'hostname'})) {
	my $dev_id = $db->Hostname2DevID($hptr->{'hostname'});
	    
	if (defined($dev_id)) {
	    $hptr->{'dev_id'} = $dev_id;
	}
    }

    my $port_id= $self->port_id;

    if (defined($port_id)) {
	my $entry_ref = $db->GetIndexRecord('netports','port_id',$port_id);

	if (defined($entry_ref)) {  # Exists, just build an update record
	    my %newrec = ();

	    &DebugPR(2,"Updating existing interface " . 
		     $self->{port}->hostname . "-" . 
		     $self->{port}->intf . "\n") if $main::debug > 2;


	    delete($hptr->{'entrydate'});
	    delete($hptr->{'changedate'});
	
	    $newrec{'port_id'} = $port_id;

	    my $changes = '';

	    # Make bandwidth a float instead of a string

	    if ($hptr->{'bandwidth'} ne 'unk') {
		$hptr->{'bandwidth'} += 0;   
	    }

	    foreach my $key (keys(%$hptr)) {
		if ($hptr->{$key} ne $entry_ref->{$key}) {
		    &DebugPR(2,"$key:'" . $hptr->{$key}. "' ne '" 
			     .  $entry_ref->{$key} . "'\n");
		    $newrec{$key} = $hptr->{$key};
		    $changes .= "'$key' = '$newrec{$key}'  ";
		}
	    }
	    
	    # Cause tunnel interfaces to get a new entry date
	    # when they re-activate.
	    
	    if ((lc($self->{port}->intf) =~ /tunnel/) &&
		($entry_ref->{'active'} eq 'N') && 
		($hptr->{'active'} eq 'Y')
		) {
		$newrec{'entrydate'} = undef;
	    }

	    if ($changes ne '') {
		&DebugPR(1,"Updating Changes " . 
			 $self->{port}->hostname . "-" . 
			 $self->{port}->intf . "\n   $changes\n") if $main::debug > 1;

		$db->UpdateRecord('netports','port_id',\%newrec);
		$db->Audit('netports','','update',"Updating " . 
			 $self->{port}->hostname . "-" . 
			 $self->{port}->intf . "($port_id)  $changes");

	    }

	} else {

	    # The port id we were handed is bogus.  
	    # Should never happen.  

	    &ErrorPR($self->{dev_id},"ERROR-CCHECK",  "Port ID " . $port_id  . "doesn't exist in the database\n");

#           Could just add it with this...
#	    $port_id = undef;

	}
    } elsif (!defined($updateonly)) { 

# If we decide to just add screwed up port id's from above, 
# change this from an else to an if:
# if (!defined($port_id)) 
    
	&DebugPR(1,"Adding new interface " . 
		 $self->{port}->hostname . "-" . 
		 $self->{port}->intf . "\n") if $main::debug > 1;


	$port_id = $db->AddRecord('netports',$hptr,'port_id');
	$db->Audit('netports','','insert',"Adding new interface " . 
		   $self->{port}->hostname . "-" . 
		   $self->{port}->intf . "($port_id)");

    }

    return($port_id);
}


######################################################################
#
# Deactivate this object
#
sub Deactivate {
    my $self = shift;
    my $db = shift;  # this is a NetInv

    $self->active('N');
    $self->{port}->gone;
    $self->MakeChecksum;

    # Only update an existing record...ignores non-existing records

    $self->AddUpdatePort($db,1); 

}
    

######################################################################
#
# Get a single NetPort record
#

sub GetRecord {
    my $self = shift;
    my $db = shift;
    my $wherecls = shift;

    if (defined($self->port_id)) {
	$wherecls = " port_id=" . $self->port_id;
    } elsif (!defined($wherecls)) {
	return(undef);
    }

    my $qry = "SELECT * FROM netports WHERE $wherecls";
    my $sth = $db->{dbh}->prepare($qry);
    my $rv = $sth->execute;
    my $entry_ref = $sth->fetchrow_hashref();

    if (defined($entry_ref)) {  # Exists, let's populate me ;)
	$self->Hash2NetPort($entry_ref);
    }

    return $entry_ref;
}



######################################################################
sub dump {
    my $self = shift;
    my $str = '';

    $str = "Dumping NetPort  ";
    $str .= Data::Dumper->Dump([$self],[qw(*self)]);
    
    if (@_) { 
        print $str;
    }
    return($str);
}




1;
