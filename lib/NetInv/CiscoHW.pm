# $HeadURL: svn://hhcv-srcctrl.sys.cogentco.com/cogent/rtrtools/trunk/lib/NetInv/CiscoHW.pm $
# $Id: CiscoHW.pm 2595 2015-06-26 15:53:24Z sphillips $

package NetInv::CiscoHW;

use English;
use IO::File;
use strict;
use Data::Dumper;
use POSIX;
use Digest::MD5 qw(md5_hex);

use DBI;
use NetInv;  # Not sure that I need this, but just in case

use MarkUtil;

######################################################################
sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {
	dev_id => undef,
	chassis => undef,
	chassisclass => undef,
	rp => undef,
	runimage => undef,   
	rebootimage => undef,      
	stbyimage => undef,
	stbyrbimage => undef,
	checksum => undef,
	entrydate => undef,
	changedate => undef,
    };
    bless($self,$class);

    return $self;
}

######################################################################
sub dev_id {
    my $self = shift;
    if (@_) { $self->{dev_id} = shift; }
    return $self->{dev_id};
}
######################################################################
sub chassis {
    my $self = shift;
    if (@_) { $self->{chassis} = shift; }
    return $self->{chassis};
}
######################################################################
sub chassisclass {
    my $self = shift;
    if (@_) { 
	my $cclass = shift;
	$cclass =~ s/Series //;
	$self->{chassisclass} = $cclass; }
    return $self->{chassisclass};
}
######################################################################
sub rp {
    my $self = shift;
    if (@_) { $self->{rp} = shift; }
    return $self->{rp};
}
######################################################################
sub runimage {
    my $self = shift;
    if (@_) { $self->{runimage} = shift; }
    return $self->{runimage};
}
######################################################################
sub rebootimage {
    my $self = shift;
    if (@_) { $self->{rebootimage} = shift; }
    return $self->{rebootimage};
}
######################################################################
sub stbyimage {
    my $self = shift;
    if (@_) { $self->{stbyimage} = shift; }
    return $self->{stbyimage};
}
######################################################################
sub stbyrbimage {
    my $self = shift;
    if (@_) { $self->{stbyrbimage} = shift; }
    return $self->{stbyrbimage};
}
######################################################################
sub checksum {
    my $self = shift;
    if (@_) { $self->{checksum} = shift; }
    return $self->{checksum};
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
sub Hash2CiscoHW {
    my $self = shift;
    my $hptr = shift;

    if (defined($hptr)) {
	$self->dev_id($hptr->{'dev_id'});
	$self->chassis($hptr->{'chassis'});
	$self->chassisclass($hptr->{'chassisclass'});
	$self->rp($hptr->{'rp'});
	$self->runimage($hptr->{'runimage'});
	$self->rebootimage($hptr->{'rebootimage'});
	$self->stbyimage($hptr->{'stbyimage'});
	$self->stbyrbimage($hptr->{'stbyrbimage'});
	$self->entrydate($hptr->{'entrydate'});
	$self->changedate($hptr->{'changedate'});
	$self->checksum($hptr->{'checksum'});
        return($self);
    }
    return(undef);
}
######################################################################
sub CiscoHW2Hash {
    my $self = shift;
    
    my %h = ();

    $h{'dev_id'} = $self->dev_id;
    $h{'chassis'} = $self->chassis;
    $h{'chassisclass'} = $self->chassisclass;
    $h{'rp'} = $self->rp;
    $h{'runimage'} = $self->runimage;
    $h{'rebootimage'} = $self->rebootimage;
    $h{'stbyimage'} = $self->stbyimage;
    $h{'stbyrbimage'} = $self->stbyrbimage;
    $h{'entrydate'} = $self->entrydate;
    $h{'changedate'} = $self->changedate;
    $h{'checksum'} = $self->checksum;

    return(\%h);
}


######################################################################
sub MakeChecksum {
    my $self = shift;
    
    my $h = $self->CiscoHW2Hash;

    return($self->checksum(&h2Checksum($h)));
}


######################################################################
#
# This should add this HW to the database or update it if it's already there
# Going to assume this is most useful talking about "self"
#

sub AddUpdateCiscoHW {
    my $self = shift;
    my $db = shift;  # this is a NetInv
    my $updateonly = shift;

    $self->MakeChecksum;

    my $dev_id= $self->dev_id;
    my $hptr = $self->CiscoHW2Hash;

    if (!exists($hptr->{'dev_id'}) ||
	!defined($hptr->{'dev_id'}) || 
	$hptr->{'dev_id'} == 0) {
	return(undef);
    }

    my $entry_ref = $db->GetRecord('ciscohw','dev_id',$dev_id);

    if (defined($entry_ref)) {  # Exists, just build an update record
	my %newrec = ();

	&DebugPR(2,"Updating existing CiscoHW device " . 
		 $dev_id . "\n");

	delete($hptr->{'entrydate'});
	delete($hptr->{'changedate'});
        
	$newrec{'dev_id'} = $dev_id;

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
	    &DebugPR(1,"Updating Netinv::CiscoHW Changes " . 
		     $dev_id . "\n $changes\n");

	    $db->Audit('ciscohw','','update',"Updating ciscohw dev_id " . 
		       $dev_id . " $changes\n");
	    $db->UpdateRecord('ciscohw','dev_id',\%newrec);
	}

    } elsif (!defined($updateonly)) { 
	&DebugPR(1,"Adding new Netinv::CiscoHW dev_id = " . 
		     $dev_id . "\n");


	$dev_id = $db->AddRecord('ciscohw',$hptr,'dev_id');

	$db->Audit('ciscohw','','insert',"Adding new ciscohw dev_id= $dev_id ");
    }
    return($dev_id);
}


######################################################################
sub dump {
    my $self = shift;
    my $str = '';

    $str = "Dumping CiscoHW ";
    $str .= Data::Dumper->Dump([$self],[qw(*self)]);
    
    if (@_) { 
        print $str;
    }
    return($str);
}


1;
