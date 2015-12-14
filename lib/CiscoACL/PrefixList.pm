
# $HeadURL: svn://hhcv-srcctrl.sys.cogentco.com/cogent/rtrtools/trunk/lib/CiscoACL/PrefixList.pm $
# $Id $

#
# Object to store a Cisco style prefix list
#
# Can read in an array containing a cisco config and parse out prefix list
# Can generate commands for prefix-list from object data
#
#
#

package CiscoACL::PrefixList;

use Data::Dumper;
use IO::File;
use English;
use POSIX;
use strict;
use warnings;
use Carp;

use MarkUtil;

our $modname = "CiscoACL::PrefixList";


######################################################################
#
# 
#
sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {
        hostname    => "unk", # Box this prefix list lives on
	name      => "unk",   # Name
	descr     => "",      # Description
	type      => "unk",   # ipv4 or ipv6
	elements  => []       # this is an array containing an ordered 
	                      # list of elements
    };

    bless($self,$class);

    return $self;

}
######################################################################
sub hostname {
    my $self = shift;
    if (@_) { $self->{hostname} = shift; }
    return $self->{hostname};
}
######################################################################
sub name {
    my $self = shift;
    if (@_) { $self->{name} = shift; }
    return $self->{name};
}
######################################################################
sub descr {
    my $self = shift;
    if (@_) { $self->{descr} = shift; }
    return $self->{descr};
}
######################################################################
sub type {
    my $self = shift;
    if (@_) { $self->{type} = shift; }
    return $self->{type};
}
######################################################################
sub elements {
    my $self = shift;
    if (@_) { $self->{elements} = shift; }
    return $self->{elements};
}
######################################################################
#
# ip prefix-list \S+ permit|deny .*    (list ends with !)
#
# Seeing as the elements are just a list, we'll use the standard 
# list functions and see what else we need from that.
#
######################################################################
sub Push {
    my $self = shift;
    if (@_) { push(@{$self->{elements}},shift); }
}
######################################################################
sub Unshift {
    my $self = shift;
    if (@_) { unshift(@{$self->{elements}},shift); }
}
######################################################################
sub Pop {
    my $self = shift;
    return(pop(@{$self->{elements}}));
}
######################################################################
sub Shift {
    my $self = shift;
    return(shift(@{$self->{elements}}));
}
######################################################################
sub ParseConfig {
    my $self = shift;
    my $confptr = shift;
    my $hostname = shift;
    my $ln = shift(@{$confptr});
    &DebugPR(2,"$modname-ParseConfig: $hostname Line $ln \n");
    my $thislist = '';

    if ($ln =~ /^ip(v6)? prefix-list \S+ .+/) { # Process prefix list
	if ($ln =~ /^ipv6 prefix-list (\S+) (.+)/) {
	    $self->name($1);
	    $self->type('ipv6');
	    $thislist = 'ipv6 ';
	} elsif ($ln =~ /^ip prefix-list (\S+) (.+)/) {
	    $self->name($1);
	    $self->type('ipv4');
	    $thislist = 'ip ';
	} else {
	    carp "Unable to parse prefix list type\n";
	    return(undef);
	}
	$self->hostname($hostname);

	my $name = $self->name;
	$thislist .= "prefix-list $name";

        &DebugPR(2,"$modname: Found $thislist\n");
        my $go = 1;
	do {
            &DebugPR(2,"$modname: $name-Line $ln \n");
	    if ($ln =~ /^${thislist} (.+)/) { # Process prefix list

		my $l2 = $1;

		if ($l2 =~ /^description (.+)/) {
		    $self->descr($1);
		} else {
		    # Should be a line of
		    # permit|deny <network>/length [ge|le <Max prefix length>

		    my @elm = split(/ /,$l2);

		    $self->Push(\@elm);
		}
	    } else { 
		&DebugPR(3,"$modname: Stopping-Line $ln \n");
		# we must be done, put whatever we got from the config back
		$go = 0;
                unshift(@{$confptr},$ln);
	    }
	} while ($go && ($ln = shift(@{$confptr})));
    } else {
        &DebugPR(2,"$modname: not handed a prefix list\n");
	
	# put whatever was handed to us back on the pile.
	unshift(@{$confptr},$ln);
    }
}
######################################################################
#
# genconfig - generate configration for this object
# genconfig(1) - add a no prefix-list to remove the old one
# genconfig(1,1) - add a no prefix-list and allow le 32 or le 128
#
sub genconfig {
   my $self = shift;
   my $str = '';
   my $hostroute = 0;

   &DebugPR(3,"$modname: genconfig\n");

   my $header = '';

   if ($self->type eq 'ipv6') {
       $header = 'ipv6 prefix-list ' . $self->name;
   } elsif ($self->type eq 'ipv4') {
       $header = 'ip prefix-list ' . $self->name;
   }

   if (@_) {
       shift;
       $str .= "no $header\n";
   }

   if (@_) {
       $hostroute = 1;
   }
   
   if ($self->descr ne '') {
       $str .= "$header description " . $self->descr . "\n";
   }

   my @elm = @{$self->elements};

   my $e;

   foreach $e (@elm) {
       $str .= "$header " ;
       if (!$hostroute) {
	   $str .= join(' ',@{$e}) . "\n";
       } else {
	   # For blackhole server
	   if ($self->type eq 'ipv4') {
	       $str .= "permit " . $e->[1] . " le 32\n";
	   } elsif ($self->type eq 'ipv6') {
	       $str .= "permit " . $e->[1] . " le 128\n";
	   }
       }
   }

   return($str);
}
######################################################################
#
# compare this object to another Prefix List
#
sub compare {
   my $self = shift;
   my $them = shift;

   if (!defined($them)) {
       &DebugPR(2,"$modname-compare: No value given to compare\n");
       return(0);
   }

   if (ref($self) ne ref($them)) {
       &DebugPR(2,"$modname-compare: object type mismatch\n");
       return(0);
   }
   

   my $me = $self->genconfig;
   my $you = $them->genconfig;

   return($me eq $you);
}
######################################################################
sub dump {
    my $self = shift;
    my $str = '';

    $str = "$modname: Dumping prefix-list  ";
    $str .= Data::Dumper->Dump([$self],[qw(*self)]);
    
    if (@_) { 
	print $str;
    }
    return($str);
}


1;
