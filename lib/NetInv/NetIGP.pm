# $HeadURL: svn://hhcv-srcctrl.sys.cogentco.com/cogent/rtrtools/trunk/lib/NetInv/NetIGP.pm $
# $Id: NetIGP.pm 968 2014-08-29 17:43:00Z sphillips $

package NetInv::NetIGP;

use English;
use IO::File;
use strict;
use Data::Dumper;
use POSIX;

use DBI;

use NetInv;  # Not sure that I need this, but just in case

use MarkUtil;
use Digest::MD5 qw(md5_hex);

my %dbfields = (
      'igp_id'     => '$self->igp_id',
      'checksum'   => '$self->checksum',
      'port_id'    => '$self->port_id',
      'igptype'    => '$self->igptype',
      'metric'     => '$self->metric',
      'entrydate'  => '$self->entrydate',
      'changedate' => '$self->changedate'
    );


######################################################################
sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {
	igp_id => undef,
	checksum => undef,
	port_id => undef,
	igptype => undef,
	metric => undef,
	entrydate => undef,
	changedate => undef,
    };
    bless($self,$class);

    return $self;
}
######################################################################
sub igp_id {
    my $self = shift;
    if (@_) { $self->{igp_id} = shift; }
    return $self->{igp_id};
}
######################################################################
sub checksum {
    my $self = shift;
    if (@_) { $self->{checksum} = shift; }
    return $self->{checksum};
}
######################################################################
sub port_id {
    my $self = shift;
    if (@_) { $self->{port_id} = shift; }
    return $self->{port_id};
}
######################################################################
sub igptype {
    my $self = shift;
    if (@_) { 
	my $proto = shift;

        # enum('isis', 'ospf', 'v6-isis')

	if (defined($proto) 
	    && ($proto eq 'isis' 
		|| $proto eq 'ospf' || $proto eq 'v6-isis')) {
	    $self->{igptype} = $proto; 
	}
    }
    return $self->{igptype};
}
######################################################################
sub metric {
    my $self = shift;
    if (@_) { 
	my $metric = shift;
	
	if (defined($metric)) {
	    if ($metric eq "maximum") {
		$self->{metric} = 0;
	    } elsif (($metric =~ /^\d+$/) 
		     && ($metric > 0)) {
		$self->{metric} = $metric;
	    }
	}
    }
    return $self->{metric};
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
sub NetIGP2Hash {
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
sub Hash2NetIGP {
    my $self = shift;
    my $hptr = shift;

    return(undef) if !defined($hptr);

    my $key;

    foreach $key (keys(%dbfields)) {

	# each key should have a handler function from dbfields
	my $cmd = $dbfields{$key} . '($hptr->{$key});';
	eval($cmd);
    }

    return($self);
}

######################################################################
sub MakeChecksum {
    my $self = shift;
    
    my $h = $self->NetIGP2Hash;
    
    return($self->checksum(&h2Checksum($h)));  
}

######################################################################
#
# This should add this peer to the database or update it if it's already there
# Going to assume this is most useful talking about "self"
#

sub AddUpdateIGP {
    my $self = shift;
    my $db = shift;  # this is a NetInv
    my $updateonly = shift;

    $self->MakeChecksum;

    my $hptr = $self->NetIGP2Hash;

    my $igp_id= $self->igp_id;

    if (defined($igp_id)) {
	my $entry_ref = $db->GetRecord('netigp','igp_id',$igp_id);

	if (defined($entry_ref)) {  # Exists, just build an update record
	    my %newrec = ();

	    &DebugPR(2,"Updating existing igp # " . 
		     $self->igp_id . 
		     "-- port# " . 
		     $self->port_id . "\n") if $main::debug > 2;


	    delete($hptr->{'entrydate'});
	    delete($hptr->{'changedate'});
	
	    $newrec{'igp_id'} = $igp_id;

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
			 $self->igp_id . 
			 "-- port# " . 
			 $self->port_id . 
			 "\n   $changes\n") if $main::debug > 1;

		$db->UpdateRecord('netigp','igp_id',\%newrec);
		$db->Audit('netigp','','update',"Updating IGP#" . 
			   $self->igp_id . 
			   "(port# " . 
			   $self->port_id . 
			   ")  $changes");
	    }
	} else {

	    # The igp id we were handed is bogus.  
	    # Should never happen.  

	    &perr("IGP ID " . $igp_id  . "doesn't exist in the database\n");

#           Could just add it with this...
#	    $igp_id = undef;

	}
    } elsif (!defined($updateonly)) { 

# If we decide to just add screwed up igp id's from above, 
# change this from an else to an if:
# if (!defined($igp_id)) 
    
	&DebugPR(1,"Adding new igp for port# " . 
		 $self->port_id . "\n") if $main::debug > 1;


	$igp_id = $db->AddRecord('netigp',$hptr,'igp_id');
	$db->Audit('netigp','','insert',"Adding new igp# $igp_id for port# " . 
		   $self->port_id);

    }
    return($igp_id);
}


######################################################################
sub dump {
    my $self = shift;
    my $str = '';

    $str = "Dumping NetIGP  ";
    $str .= Data::Dumper->Dump([$self],[qw(*self)]);
    
    if (@_) { 
        print $str;
    }
    return($str);
}




1;
