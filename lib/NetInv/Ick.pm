# $HeadURL: svn://hhcv-srcctrl.sys.cogentco.com/cogent/rtrtools/trunk/lib/NetInv/Ick.pm $
# $Id: Ick.pm 563 2013-08-30 18:57:50Z sphillips $

package NetInv::Ick;

use English;
use IO::File;
use strict;
use Data::Dumper;

use DBI;
use NetInv;  # Not sure that I need this, but just in case
use NetInv::NetPort;

use MarkUtil;

######################################################################
sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {
	ick_id => undef,
	status => undef,
	a_hostname => undef,
	a_dev_id => undef,
	a_dev_id_valid => undef,   
	a_shint => undef,      
	a_port_id => undef,
	a_port_id_valid => undef,
	a_metric => undef,      
	z_hostname => undef,
	z_dev_id => undef,
	z_dev_id_valid => undef,   
	z_shint => undef,      
	z_port_id => undef,
	z_port_id_valid => undef,
	z_metric => undef,      
	rtt => undef,
	monitor => undef,
	notes => undef,
	entrydate => undef,
	changedate => undef,
	db => (shift // undef),
    };
    bless($self,$class);

    return $self;
}

######################################################################
sub ick_id {
    my $self = shift;
    if (@_) { $self->{ick_id} = shift; }
    return $self->{ick_id};
}
######################################################################
sub status {
    my $self = shift;
    if (@_) { 
	my $stat = shift;

	# enum('new','provisioned','active',retired')

	if (defined($stat)
	    && ($stat =~ /new|provisioned|active|retired/)
	    ) {
	    $self->{status} = $stat; 
	}
    }
    return $self->{status};
}
######################################################################
sub a_hostname {
    my $self = shift;
    if (@_) { $self->{a_hostname} = shift; }
    return $self->{a_hostname};
}
######################################################################
sub a_dev_id {
    my $self = shift;
    if (@_) { $self->{a_dev_id} = shift; }
    return $self->{a_dev_id};
}
######################################################################
sub a_dev_id_valid {
    my $self = shift;
    if (@_) { $self->{a_dev_id_valid} = shift; }
    return $self->{a_dev_id_valid};
}
######################################################################
sub a_shint {
    my $self = shift;
    if (@_) { $self->{a_shint} = shift; }
    return $self->{a_shint};
}
######################################################################
sub a_port_id {
    my $self = shift;
    if (@_) { $self->{a_port_id} = shift; }
    return $self->{a_port_id};
}
######################################################################
sub a_port_id_valid {
    my $self = shift;
    if (@_) { $self->{a_port_id_valid} = shift; }
    return $self->{a_port_id_valid};
}
######################################################################
sub a_metric {
    my $self = shift;
    if (@_) { $self->{a_metric} = shift; }
    return $self->{a_metric};
}
######################################################################
sub z_hostname {
    my $self = shift;
    if (@_) { $self->{z_hostname} = shift; }
    return $self->{z_hostname};
}
######################################################################
sub z_dev_id {
    my $self = shift;
    if (@_) { $self->{z_dev_id} = shift; }
    return $self->{z_dev_id};
}
######################################################################
sub z_dev_id_valid {
    my $self = shift;
    if (@_) { $self->{z_dev_id_valid} = shift; }
    return $self->{z_dev_id_valid};
}
######################################################################
sub z_shint {
    my $self = shift;
    if (@_) { $self->{z_shint} = shift; }
    return $self->{z_shint};
}
######################################################################
sub z_port_id {
    my $self = shift;
    if (@_) { $self->{z_port_id} = shift; }
    return $self->{z_port_id};
}
######################################################################
sub z_port_id_valid {
    my $self = shift;
    if (@_) { $self->{z_port_id_valid} = shift; }
    return $self->{z_port_id_valid};
}
######################################################################
sub z_metric {
    my $self = shift;
    if (@_) { $self->{z_metric} = shift; }
    return $self->{z_metric};
}
######################################################################
sub rtt {
    my $self = shift;
    if (@_) { $self->{rtt} = shift; }
    return $self->{rtt};
}
######################################################################
sub monitor {
    my $self = shift;
    if (@_) { 
	my $m = shift;

	# enum('Y','N')

	if (defined($m) 
	    && ($m eq 'Y' 
		|| $m eq 'N')
	    ) {
	    $self->{monitor} = $m;
 	}
    }
    return $self->{monitor};
}
######################################################################
sub notes {
    my $self = shift;
    if (@_) { $self->{notes} = shift; }
    return $self->{notes};
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
sub Hash2Ick {
    my $self = shift;
    my $hptr = shift;

    if (defined($hptr)) {
	$self->ick_id($hptr->{'ick_id'});
	$self->status($hptr->{'status'});
	$self->a_hostname($hptr->{'a_hostname'});
	$self->a_dev_id($hptr->{'a_dev_id'});
	$self->a_dev_id_valid($hptr->{'a_dev_id_valid'});
	$self->a_shint($hptr->{'a_shint'});
	$self->a_port_id($hptr->{'a_port_id'});
	$self->a_port_id_valid($hptr->{'a_port_id_valid'});
	$self->a_metric($hptr->{'a_metric'});
	$self->z_hostname($hptr->{'z_hostname'});
	$self->z_dev_id($hptr->{'z_dev_id'});
	$self->z_dev_id_valid($hptr->{'z_dev_id_valid'});
	$self->z_shint($hptr->{'z_shint'});
	$self->z_port_id($hptr->{'z_port_id'});
	$self->z_port_id_valid($hptr->{'z_port_id_valid'});
	$self->z_metric($hptr->{'z_metric'});
	$self->rtt($hptr->{'rtt'});
	$self->monitor($hptr->{'monitor'});
	$self->notes($hptr->{'notes'});
	$self->entrydate($hptr->{'entrydate'});
	$self->changedate($hptr->{'changedate'});
        return($self);
    }
    return(undef);
}
######################################################################
sub Ick2Hash {
    my $self = shift;
    
    my %h = ();

    $h{'ick_id'} = $self->ick_id;
    $h{'status'} = $self->status;
    $h{'a_hostname'} = $self->a_hostname;
    $h{'a_dev_id'} = $self->a_dev_id;
    $h{'a_dev_id_valid'} = $self->a_dev_id_valid;
    $h{'a_shint'} = $self->a_shint;
    $h{'a_port_id'} = $self->a_port_id;
    $h{'a_port_id_valid'} = $self->a_port_id_valid;
    $h{'a_metric'} = $self->a_metric;
    $h{'z_hostname'} = $self->z_hostname;
    $h{'z_dev_id'} = $self->z_dev_id;
    $h{'z_dev_id_valid'} = $self->z_dev_id_valid;
    $h{'z_shint'} = $self->z_shint;
    $h{'z_port_id'} = $self->z_port_id;
    $h{'z_port_id_valid'} = $self->z_port_id_valid;
    $h{'z_metric'} = $self->z_metric;
    $h{'rtt'} = $self->rtt;
    $h{'monitor'} = $self->monitor;
    $h{'notes'} = $self->notes;
    $h{'entrydate'} = $self->entrydate;
    $h{'changedate'} = $self->changedate;

    return(\%h);
}


######################################################################
sub AddUpdate {
    my $self = shift;
    my $db = shift;  # this is a NetInv
    my $updateonly = shift;

    my $ick_id= $self->ick_id;
    my $hptr = $self->Ick2Hash;

    my $entry_ref = $db->GetRecord('ick','ick_id',$ick_id);

    if (defined($entry_ref)) {  # Exists, just build an update record
	my %newrec = ();

	&DebugPR(2,"Updating existing ICK " . 
		 $ick_id . "\n");

	delete($hptr->{'entrydate'});
	delete($hptr->{'changedate'});
        
	$newrec{'ick_id'} = $ick_id;

	my $changes = '';

	foreach my $key (keys(%$hptr)) {
	    if ($hptr->{$key} ne $entry_ref->{$key}) {
		&DebugPR(2,"$key: '" . $hptr->{$key}. "' ne '" 
			 .  $entry_ref->{$key} . "'\n");
		$newrec{$key} = $hptr->{$key};
		$changes .= "'$key' = '$newrec{$key}'  ";
	    }
	}
	if ($changes ne '') {
	    &DebugPR(1,"Updating Netinv::Ick Changes " . 
		     $ick_id . "\n $changes\n");

	    $db->Audit('ick','','update',"Updating ick_id " . 
		       $ick_id . " $changes\n");
	    $db->UpdateRecord('ick','ick_id',\%newrec);
	}

    } elsif (!defined($updateonly)) { 
	&DebugPR(1,"Adding new Netinv::Ick ick_id = " . 
		     $ick_id . "\n");


	$ick_id = $db->AddRecord('ick',$hptr,'ick_id');

	$db->Audit('ick','','insert',"Adding new ick ick_id= $ick_id ");
    }
    return($ick_id);
}


######################################################################
#
# Get a single Ick record
#

sub GetRecord {
    my $self = shift;
    my $db = shift;
    my $wherecls = shift;

    if (defined($self->ick_id)) {
        $wherecls = " ick_id=" . $self->ick_id;
    } elsif (!defined($wherecls)) {
        return(undef);
    }

    my $qry = "SELECT * FROM ick WHERE $wherecls";

    my $sth = $db->{dbh}->prepare($qry);
    my $rv = $sth->execute;

    my $entry_ref = $sth->fetchrow_hashref();

    if (defined($entry_ref)) {  # Exists, let's populate me ;)
        $self->Hash2Ick($entry_ref);
    }

    return $entry_ref;
}




######################################################################
sub dump {
    my $self = shift;
    my $str = '';

    $str = "Dumping Ick ";
    $str .= Data::Dumper->Dump([$self],[qw(*self)]);
    
    if (@_) { 
        print $str;
    }
    return($str);
}

######################################################################
sub getIPs {
	my $self = shift;
	my $ick = shift;
	die unless $self->{db};
	$self->{ick_id} = $ick;
	return 0  unless $self->GetRecord($self->{db});
	my @ips;

	if($self->{a_port_id_valid})
	{
		my $port = NetInv::NetPort->new();
		$port->GetRecord($self->{db}, " port_id=" . $self->{a_port_id});
		push @ips, $port->{port}->ipaddr if $port->{port}->ipaddr;
                push @ips, $port->{port}->ip6addr if  $port->{port}->ip6addr;
	}
 if($self->{z_port_id_valid})
        {
                my $port = NetInv::NetPort->new();
                $port->GetRecord($self->{db}, " port_id=" . $self->{z_port_id});
                push @ips, $port->{port}->ipaddr if $port->{port}->ipaddr;
		push @ips, $port->{port}->ip6addr if  $port->{port}->ip6addr;
        }





	return @ips;
}

1;
