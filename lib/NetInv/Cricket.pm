# $HeadURL: svn://hhcv-srcctrl.sys.cogentco.com/cogent/rtrtools/trunk/lib/NetInv/Cricket.pm $
# $Id: Cricket.pm 304 2009-11-05 16:56:41Z marks $

package NetInv::Cricket;

use File::Basename;
use English;
use IO::File;
use strict;
use Data::Dumper;
use POSIX;

use MarkUtil;

my %dbfields = (
    'cricket_id'  => '$self->cricket_id',
    'port_id'     => '$self->port_id',
    'target'      => '$self->target',
    'automan'     => '$self->automan',
    'active'      => '$self->active',
    'createdate'  => '$self->createdate',
    'enabledate'  => '$self->enabledate',
    'disabledate' => '$self->disabledate',
    'changedate'  => '$self->changedate'
		);

######################################################################
sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {
	cricket_id => undef,
	port_id => undef,     # Maps to netports.port_id
	target => undef,      # Target file
	automan => undef,     # A/M Automatically genergated or manually generated
	active => undef,      # Y/N polling active?
	createdate => undef,
	enabledate => undef,
	disabledate => undef,
	changedate => undef,
    };
    bless($self,$class);

    return $self;
}

######################################################################
sub cricket_id {
    my $self = shift;
    if (@_) { $self->{cricket_id} = shift; }
    return $self->{cricket_id};
}
######################################################################
sub port_id {
    my $self = shift;
    if (@_) { $self->{port_id} = shift; }
    return $self->{port_id};
}
######################################################################
sub target {
    my $self = shift;
    if (@_) { $self->{target} = shift; }
    return $self->{target};
}
######################################################################
sub automan {
    my $self = shift;
    if (@_) { 
	my $stat = shift;

	# enum('A', 'M')

	if ($stat eq 'A' ||
	    $stat eq 'M') {
	    $self->{automan} = $stat;
	}
    }
    return $self->{automan};
}
######################################################################
sub active {
    my $self = shift;
    if (@_) { 
	my $stat = shift;

	# enum('Y', 'N')

	if ($stat eq 'Y' ||
	    $stat eq 'N') {
	    $self->{active} = $stat;
	}
    }
    return $self->{active};
}
######################################################################
sub createdate {
    my $self = shift;
    if (@_) { $self->{createdate} = shift; }
    return $self->{createdate};
}
######################################################################
sub enabledate {
    my $self = shift;
    if (@_) { $self->{enabledate} = shift; }
    return $self->{enabledate};
}
######################################################################
sub disabledate {
    my $self = shift;
    if (@_) { $self->{disabledate} = shift; }
    return $self->{disabledate};
}
######################################################################
sub changedate {
    my $self = shift;
    # this is autoset by DB, we shouldn't be messing with it
    return $self->{changedate};
}
######################################################################
sub Cricket2Hash {
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
sub Hash2Cricket {
    my $self = shift;
    my $hptr = shift;

    return(undef) if !defined($hptr);

    my $key;

    foreach $key (keys(%dbfields)) {
	my $cmd = $dbfields{$key} . '($hptr->{$key});';
	eval($cmd);
    }
    return();
}

######################################################################
#
# This should add this port to the database or update it if it's already there
# Going to assume this is most useful talking about "self"
#

sub AddUpdateCricket {
    my $self = shift;
    my $db = shift;  # this is a NetInv
    my $updateonly = shift;

    my $hptr = $self->Cricket2Hash;

    my $cricket_id= $self->cricket_id;

    if (defined($cricket_id)) {
        my $entry_ref = $db->GetRecord('cricket','cricket_id',$cricket_id);

        if (defined($entry_ref)) {  # Exists, just build an update record
            my %newrec = ();

	    &DebugPR(2,"AddUpdateCricket: Updating existing target # $cricket_id " . $self->target . "\n") if $main::debug > 2;

            delete($hptr->{'createdate'}); # Existing entry so we don't need to touch this.
            delete($hptr->{'changedate'}); # Autochanges
	    
	    if (!defined($hptr->{'disabledate'})) { # undef so ingore it
		delete($hptr->{'disabledate'});
	    }

            $newrec{'cricket_id'} = $cricket_id;

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
		my $auditmsg = $self->cricket_id . " -- " .
		    $self->target . " -- Changes $changes";

                &DebugPR(1,"AddUpdateCricket - $auditmsg\n");

                $db->Audit('cricket','','update',"Updating " . $auditmsg);
                $db->UpdateRecord('cricket','cricket_id',\%newrec);
            }

        } else {

            # The port id we were handed is bogus.  
            # Should never happen.  

            &perr("AddUpdateCricket: cricket ID " . $cricket_id  . "doesn't exist in the database\n");

#           Could just add it with this...
#           $cricket_id = undef;

        }
    } elsif (!defined($updateonly)) { 

# If we decide to just add screwed up cricket id's from above, 
# change this from an else to an if:
# if (!defined($cricket_id)) 
	
	&DebugPR(1,"AddUpdateCricket: Adding new interface to cricket" . 
		 $self->target . "\n") if $main::debug > 1;

        $cricket_id = $db->AddRecord('cricket',$hptr,'cricket_id');
        $db->Audit('cricket','','insert',"Adding new cricket target " . 
		   $self->target . " ($cricket_id)");

	return($cricket_id);
    }
}

######################################################################
sub Deactivate {
    my $self = shift;
    my $db = shift;  # this is a NetInv

    $self->active('N');
    $self->disabledate($datetime);
    
    $self->AddUpdateCricket($db,1);

}

######################################################################
sub dump {
    my $self = shift;
    my $str = '';

    $str = "Dumping Cricket  ";
    $str .= Data::Dumper->Dump([$self],[qw(*self)]);
    
    if (@_) { 
        print $str;
    }
    return($str);
}


1;
