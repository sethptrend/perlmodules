# $HeadURL: svn://hhcv-srcctrl.sys.cogentco.com/cogent/rtrtools/trunk/lib/Cogent/Template.pm $
# $Id: Template.pm 319 2009-12-11 20:27:44Z marks $

package Cogent::Template;

use strict;
use warnings;

use Data::Dumper;
use MarkUtil;

our $modname = 'Cogent::Template';

our $configmodsdir = '/local/scripts/ConfigMods/';

my $nafullmesh = 'NA_full-mesh_peer_list.txt';
my $eufullmesh = 'EU_full-mesh_peer_list.txt';

my $naXRfullmesh = 'NA-XR_full-mesh_peer_list.txt';
my $euXRfullmesh = 'EU-XR_full-mesh_peer_list.txt';

my %bgp_fm = (
    'EU' => {},
    'NA' => {}
    );

######################################################################
sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {
	bgpregion => ''
    };
    bless($self,$class);

    $self->ReadBGPTemplate("$configmodsdir/$nafullmesh","NA");
    $self->ReadBGPTemplate("$configmodsdir/$eufullmesh","EU");

    $self->ReadBGPTemplate("$configmodsdir/$naXRfullmesh","NA");
    $self->ReadBGPTemplate("$configmodsdir/$euXRfullmesh","EU");

    return $self;
}
######################################################################
sub DESTROY {
    my $self = shift;
}
######################################################################
sub bgpregion {
    my $self = shift;

    if (@_) { $self->{bgpregion} = shift; }
    return $self->{bgpregion};
}
######################################################################
sub ReadBGPTemplate {
    my $self = shift;
    my $fn = shift;
    my $region = shift;

    if (defined($fn) && defined($region)) {
	my $fh = new IO::File;

	if ($fh->open("< $fn")) {
	    my $ln;
	    while ($ln=$fh->getline) {
		chomp($ln);
		$ln =~ s/\s+$//;  # Remove Trailing Whitespace

		if ($ln =~ /neighbor (\d+\.\d+\.\d+\.\d+) peer-group internal/) {
		    $bgp_fm{$region}->{$1} = 1;
		}
	    }
	} else {
	    &perr("$modname: Can't open template file $fn\n");
	    return(undef);
	}
    } else {
	return(undef);
    }
    
}
######################################################################
sub IP2FMRegion {
    my $self = shift;
    my $ip = shift;

    my $region;

    if ($ip =~ /^\d+\.\d+\.\d+\.\d+$/) {
	foreach $region (keys %bgp_fm) {
	    if (exists($bgp_fm{$region}->{$ip})) {
		$self->bgpregion($region);
		return($region);
	    }
	}
    }
    return(undef);
}
######################################################################
sub Region2FM {
    my $self = shift;
    my $region = shift // $self->bgpregion;

    my %h = ();
    
    if (exists($bgp_fm{$region})) {
	%h = %{$bgp_fm{$region}};  # create a copy of the data to return
    }

    return(\%h);
}
######################################################################
#
# see if this has all the peers it should, return missing peer list
#
sub FMCheck {
    my $self = shift;
    my $hostip = shift;
    my @iplist = @_;

    my %regionip = %{$self->Region2FM};

    return(undef) if ((scalar keys(%regionip)) == 0);

    if (exists($regionip{$hostip})) {
	# first, remove our own entry
	delete($regionip{$hostip});
    } else {
	&perr("$modname-FMCheck: $hostip should exist in " . $self->bgpregion . " but doesn't\n");
	return(undef);
    }
    
    foreach my $ip (@iplist) {
	if (exists($regionip{$ip})) { # delete all the peers we found
	    delete($regionip{$ip});
	}
    }

    # Anything left is a missing peer...

    if (scalar keys(%regionip)) {
	return(join(', ',keys(%regionip)));
    } else {
	return(''); 
    }
}
######################################################################
sub dump {
    my $self = shift;
    my $str = '';

    $str = "Dumping $modname  ";
    $str .= Data::Dumper->Dump([$self],[qw(*self)]);
    
    if (@_) { 
        print $str;
    }
    return($str);
}


1;


