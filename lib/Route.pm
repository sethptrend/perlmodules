# $HeadURL: svn://hhcv-srcctrl.sys.cogentco.com/cogent/rtrtools/trunk/lib/Route.pm $
# $Id: Route.pm 304 2009-11-05 16:56:41Z marks $

package Route;

use Data::Dumper;
use English;
use strict;
use warnings;

use NetAddr::IP;

use Port;

use MarkUtil;


######################################################################
#
# Structure to hold routes, either static or connected
#
sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {
	hostname          => "unk",
	rtype             => "unk", # static or connected
	cidr              => "unk", # prefix in cidr notation
	nexthopip         => "unk", # IP address of nexthop
        nexthopif         => "unk", # Interface of nexthop
	distance          => 0,
	permanent         => 0,
        tag               => "unk",
        name              => "unk",
	compnext          => 0,     # nexthopif value is computed
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
sub rtype {
    my $self = shift;
    if (@_) { $self->{rtype} = shift; }
    return $self->{rtype};
}
######################################################################
sub cidr {
    my $self = shift;
    if (@_) { $self->{cidr} = shift; }
    return $self->{cidr};
}
######################################################################
sub nexthopip {
    my $self = shift;
    if (@_) { $self->{nexthopip} = shift; }
    return $self->{nexthopip};
}
######################################################################
sub nexthopif {
    my $self = shift;
    if (@_) { $self->{nexthopif} = shift; }
    return $self->{nexthopif};
}
######################################################################
sub distance {
    my $self = shift;
    if (@_) { $self->{distance} = shift; }
    return $self->{distance};
}
######################################################################
sub permanent {
    my $self = shift;
    if (@_) { $self->{permanent} = shift; }
    return $self->{permanent};
}
######################################################################
sub tag {
    my $self = shift;
    if (@_) { $self->{tag} = shift; }
    return $self->{tag};
}
######################################################################
sub name {
    my $self = shift;
    if (@_) { $self->{name} = shift; }
    return $self->{name};
}
######################################################################
sub compnext {
    my $self = shift;
    if (@_) { $self->{compnext} = shift; }
    return $self->{compnext};
}
######################################################################
sub ParseStatic {
    my $self = shift;
    my $hostname = shift;
    my $ln = shift;

    my $rv = 1;

    return(1) if (!defined($hostname));
    return(1) if (!defined($ln));

    if ($ln =~ /^ip route \d+\.\d+\.\d+\.\d+ \d+\.\d+\.\d+\.\d+/) {
	&DebugPR(2,"Found ip route - $ln \n");

#ip route prefix mask {ip-address | interface-type interface-number [ip-address]} [distance] [name] [permanent] [tag tag]

	my @routeln = split(/ /,$ln);

	shift(@routeln); # remove 'ip'
	shift(@routeln); # remove 'route'

	$self->rtype('static');

#	&DebugPR(3,"processing prefix/mask\n" . Dumper(@routeln));
	# prefix mask
	my $net = new NetAddr::IP (shift(@routeln),shift(@routeln));
	$self->hostname($hostname);
	$self->cidr($net->cidr);


#	&DebugPR(3,"processing nexthop int?\n" . Dumper(@routeln));

	my $i = shift(@routeln);

	if ($i =~ /[a-zA-Z]\w+/) {   # Interface for nexthop
	    &DebugPR(3,"Found nexthop if - $i\n");
	    $self->nexthopif($i);     
	    $i = shift(@routeln);
	}

#	&DebugPR(3,"processing nexthop ip?\n" . Dumper(@routeln));
	if (defined($i)) {
	    if ($i =~ /\d+\.\d+\.\d+\.\d+/) {  # ip-address of nexthop
		&DebugPR(3,"Found nexthop ip - $i\n");
		$self->nexthopip($i); 
	    } else {
		unshift(@routeln,$i); # Wasn't an IP address, put it back
	    }
	}

	&DebugPR(3,"processing rest\n" . Dumper(@routeln)) if $main::debug > 3;

        # at this point we've got [distance] [name name] [permanent] [tag tag]

	while ($i = shift(@routeln)) {
	    if ($i =~ /\d+/) {
		$self->distance($i);
	    } elsif ($i eq 'permanent') {
		$self->permanent(1);
	    } elsif ($i eq 'tag') {
		$self->tag(shift(@routeln));
	    } elsif ($i eq 'name'){
		$self->name(shift(@routeln));
	    }
	}

	$rv = 0;
    } else {
	 &DebugPR(2,"Not handed a static route\n");
	$rv = 1;
    }

    &DebugPR(2,"Found ip route - Done\n");

    return($rv);
}
######################################################################
sub ParseV6Static {
    my $self = shift;
    my $hostname = shift;
    my $ln = shift;

    my $rv = 1;

    return(1) if (!defined($hostname));
    return(1) if (!defined($ln));

    if ($ln =~ /^ipv6 route [0-9a-fA-F]{1,4}:/) {
	&DebugPR(2,"Found ip route - $ln \n");

#ipv6 route ipv6-prefix/prefix-length {ipv6-address | interface-type interface-number [ipv6-address]} [administrative-distance] [administrative-multicast-distance | unicast | multicast] [tag tag]

	my @routeln = split(/ /,$ln);

	shift(@routeln); # remove 'ipv6'
	shift(@routeln); # remove 'route'

	$self->rtype('static');

#	&DebugPR(3,"processing prefix/mask\n" . Dumper(@routeln));
	# prefix mask
	my $net = new6 NetAddr::IP (shift(@routeln));
	$self->hostname($hostname);
	$self->cidr($net->cidr);


#	&DebugPR(3,"processing nexthop int?\n" . Dumper(@routeln));

	my $i = shift(@routeln);

	if (!(&isv6($i))) {   # not v6 ip == Interface for nexthop 
	    &DebugPR(3,"Found nexthop if - $i\n");
	    $self->nexthopif($i);     
	    $i = shift(@routeln);
	}

#	&DebugPR(3,"processing nexthop ip?\n" . Dumper(@routeln));
	if (defined($i)) {
	    if (&isv6($i)) {  # ip-address of nexthop
		&DebugPR(3,"Found nexthop ip - $i\n");
		$self->nexthopip($i); 
	    } else {
		unshift(@routeln,$i); # Wasn't an IP address, put it back
	    }
	}

	&DebugPR(3,"processing rest\n" . Dumper(@routeln)) if $main::debug > 3;

        # at this point we've got [administrative-distance] [administrative-multicast-distance | unicast | multicast] [tag tag]

	while ($i = shift(@routeln)) {
	    if ($i =~ /\d+/) {
		$self->distance($i);
	    } elsif ($i eq 'tag') {
		$self->tag(shift(@routeln));
	    }
	}

	$rv = 0;
    } else {
	 &DebugPR(2,"Not handed a static route\n");
	$rv = 1;
    }

    &DebugPR(2,"Found ip route - Done\n");

    return($rv);
}
######################################################################
sub ParseInt {
    my $self = shift;
    my $intf = shift; # "Port"

    return(1) if (!defined($intf));

    $self->rtype('connected');

    my $net = new NetAddr::IP ($intf->ipaddr,$intf->netmask);
    if (!defined($net)) {
	&perr("Route::ParseInt - Failed to parse " .$intf->ipaddr . " " . $intf->netmask  . "\n");
	return(1);
    }

    $self->hostname($intf->hostname);
    $self->nexthopif($intf->intf);
    $self->cidr($net->network->cidr);

    return(0);
}
######################################################################
sub ParseSec {
    my $self = shift;
    my $intf = shift; # "Port"
    my $secipptr = shift; # ptr to [ip,mask];

    return(1) if (!defined($secipptr));

    $self->rtype('connected');

    my $net = new NetAddr::IP ($secipptr->[0],$secipptr->[1]);
    if (!defined($net)) {
	&perr("Route::ParseSec - Failed to parse " . $secipptr->[0] . " " .$secipptr->[1] . "\n");
	return(1);
    }

    $self->hostname($intf->hostname);
    $self->nexthopif($intf->intf);
    $self->cidr($net->network->cidr);

    return(0);
}
######################################################################
sub ParseV6Int {
    my $self = shift;
    my $intf = shift; # "Port"
    my $ip6addrptr = shift; # ptr to [ip/mask];

    return(1) if (!defined($ip6addrptr));

    $self->rtype('connected');

    my $net = new NetAddr::IP ($ip6addrptr->[0]);
    if (!defined($net)) {
	&perr("Route::ParseV6Int - Failed to parse " . $ip6addrptr->[0] . "\n");
	return(1);
    }

    $self->hostname($intf->hostname);
    $self->nexthopif($intf->intf);
    $self->cidr($net->network->cidr);

    return(0);
}


######################################################################
sub dump {
    my $self = shift;
    my $str = '';

    $str = "Dumping Route  ";
    $str .= Data::Dumper->Dump([$self],[qw(*self)]);
    
    if (@_) { 
	print $str;
    }
    return($str);
}


1;
