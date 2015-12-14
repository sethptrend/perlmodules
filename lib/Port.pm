# $HeadURL: svn://hhcv-srcctrl.sys.cogentco.com/cogent/rtrtools/trunk/lib/Port.pm $
# $Id: Port.pm 1919 2015-04-10 15:03:57Z sphillips $

package Port;

use Data::Dumper;
use IO::File;
use English;
use POSIX;
use strict;
use warnings;
use RRDs;

use Route;
use Cogent::Desc;
use MarkUtil;
use Validation::Tests;

my %l2s = (
    "GigabitEthernet"    => "Gi",
    "TenGigabitEthernet" => "Te",
    "TenGigE"            => "Te",
    "HundredGigE"        => "Hu",
    "HundredGigEthernet" => "Hu",
    "Tunnel"             => "Tu",
    "POS"                => "PO",
    "ATM"                => "AT",
    "Serial"             => "Se",
    "Loopback"           => "Lo",
    "FastEthernet"       => "Fa",
    "VLAN"               => "Vl",
    "Vlan"               => "Vl",
    "Null"               => "Nu",
    "Port-channel"       => "Po",
    "Bundle-Ether"       => "Be",
    "Async"              => "As",
    "BRI"                => "Br",
    "BVI"                => "BV",
    "Ethernet"           => "Et"
    );

my %int2fac = (
    "GigabitEthernet"    => "GIGE",
    "TenGigabitEthernet" => "10GE-L",
    "TenGigE"            => "10GE-L",
    "HundredGigEthernet" => "100GE",
    "HundredGigE"        => "100GE",
    "FastEthernet"       => "FE",
    "Ethernet"           => "E"
    );

my %circ2bw = (# Circuit -> BW in Megabits/sec
	       "POTS"  => "0.064",   
	       "ISDN"  => "0.064",   
	       "DS0"   => "0.064",   # DS0 clear channel - 64
	       "DS1"   => "1.536",   # DS1 clear channel - 1.544
	       "E1"    => "2.048",   
	       "DS3"   => "44.5",   # DS3 clear channel - 44.736
	       "E3"    => "32.99",   
	       "OC3"   => "149",  # OC3c   - 155.52 (payload: 149.76 Mbit/s; overhead: 5.76 Mbit/s)
	       "STM1"  => "149",  
	       "OC12"  => "601",  # OC12c  - 622.08 (payload: 601.344 Mbit/s; overhead: 20.736 Mbit/s)
	       "STM4"  => "601",  
	       "OC48"  => "2405", # OC48c  - 2488.32 (payload: 2405.376 Mbit/s; overhead: 82.944 Mbit/s)
	       "STM16" => "2405", 
	       "OC192" => "9621", # OC192c - 9953.28 (payload: 9621.504 Mbit/s; overhead: 331.776 Mbit/s)
	       "STM64" => "9621", 
	       "10GE-L"  => "9950",  # LAN PHY uses a line rate of 10.3125 Gbit/s and a 64B/66B encoding.
	       "10GE-W"  => "9000",  # Maybe this should be 9621? if we ever get buffer's figured out
	       "100GE"   => "99500", #Temporary number here, just expermental
	       "TUN"   => "9950",
	       "E"     => "9",
	       "FE"    => "99",
	       "GIGE"  => "990",
	       "2GEC"  => "1950",
	       "3GEC"  => "2950",
	       "4GEC"  => "3950",
	       "20GEC" => "19950"
    );

my %circ2max = (# Circuit -> BW in Megabits/sec
		"POTS"  => "0.064",   
		"ISDN"  => "0.064",   
		"DS0"   => "0.064",
		"DS1"   => "1.536",
		"E1"    => "2.048",
		"DS3"   => "45", 
		"E3"    => "35",
		"OC3"   => "155",
		"STM1"  => "155",
		"OC12"  => "622",
		"STM4"  => "622",
		"OC48"  => "2500",
		"STM16" => "2500",
		"OC192" => "10000",
		"STM64" => "10000",
		"10GE-L"  => "10000",
		"10GE-W"  => "9200",
		"TUN"   => "10000",
		"E"     => "10",
		"FE"    => "100",
 		"GIGE"  => "1000",
		"2GEC"  => "2000",
		"3GEC"  => "3000",
		"4GEC"  => "4000",
		"20GEC" => "20000",
		"100GE" => "100000",
    );


my %rsvpbw = ( # RSVP bandwidth values
	       'DS3'    => '40000 40000',
	       'FE'     => '80000 80000',
	       'OC3'    => '100000 100000',
	       'STM1'   => '100000 100000',
	       'OC12'   => '500000 500000',
	       'STM4'   => '500000 500000',
	       'GIGE'   => '800000 800000',
	       'OC48'   => '1750000 1750000',
	       'STM16'  => '1750000 1750000',
	       'OC192'  => '8000000 8000000',
	       'STM192' => '8000000 8000000',
	       '10GE-W' => '8000000 8000000',
	       '10GE-L' => '8000000 8000000',
	       'BUN'    => '8000000 8000000',
	       '100GE'  => '80000000 80000000',

    );

# $cricketdatadir imported from MarkUtils - Not sure if I like that but there
# you are.  Not sure that any of the cricket stuff belongs in here at all
# actually.  Probably should be it's own .pm

my @fields = (
    'hostname',
    'intf',
    'intsuffix',
    'shint',
    'adminstat',
    'operstat',
    'descr',
    'speed',
    'ipaddr',
    'netmask',
    'secipaddr',
    'ip6addr',
    'encap',
    'duplex',
    'portspeed',
    'aclin',
    'aclout',
    'ip6aclin',
    'ip6aclout',
    'policyin',
    'policyout',
    'mtu',
    'ipmtu',
    'ip6mtu',
    'flowintype',
    'flowouttype',
    'flowinrate',
    'flowoutrate',
    'ip6flowintype',
    'ip6flowouttype',
    'ip6flowinrate',
    'ip6flowoutrate',
    'switchmode',
    'switchaccess',
    'allowedvlans'
    );

######################################################################
#
sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {
	hostname    => "unk",
	intf      => "unk",
	intsuffix => "unk", # point-to-point, etc
	shint     => "unk",
	adminstat => -1,
	operstat  => -1,
	preconfig => 0,
	descr      => undef,
	speed     => 0,
	ipaddr    => "unk",
	netmask   => "unk",
	secipaddr => [],    # Array of Arrays of secondary IP's & Netmasks 
	ip6addr   => [],    # Array of Arrays of IPv6 addresses 
	encap     => "unk", # Line encapulation
	duplex    => "unk", # duplex setting
	portspeed => 0, # hard coded speed setting
	isis      => 0,     # isis active on this interface
	v6_isis   => 0,     #v6 isis active on this interface
	isismetric => 0,    # isis metric value
        v6_isismetric   => 0,     #v6 isis metric value
	ospf      => 0,     # ospf active on this interface
	ospfcost  => 0,    # ospf cost value
	mpls      => 0,    # mpls active on this interface
	mplste    => 0,    # mpls te active on this interface
	rsvp      => undef,    # rsvp bandwidth
	aclin     => "unk", # Access group in
	aclout    => "unk", # Access group out
	ip6aclin     => "unk", # traffic-filter in
	ip6aclout    => "unk", # traffic-filter out
	policyin  => "unk", # Service Policy in
	policyout => "unk", # Service Policy out
	tunneldest => "unk",
	tunnelmode => "unk", 
	tunnelpaths => [],   # paths for tunnel
	mtu       => 0,
        ipmtu     => 0,
        ip6mtu    => 0,
	portstats => -1,
	inmin     => -1,
	inavg     => -1,
	in90      => -1,
	in95      => -1,
	inmax     => -1,
	incount   => -1,
	outmin     => -1,
	outavg     => -1,
	out90      => -1,
	out95      => -1,
	outmax     => -1,
	outcount   => -1,
	mergemin   => -1,
	mergeavg   => -1,
	merge90    => -1,
	merge95    => -1,
	mergemax   => -1,
	mergecount => -1,
	invol      => -1,
	outvol     => -1,
	volume     => -1,
	pinvol      => -1,
	poutvol     => -1,
	pvolume     => -1,
        flowintype => -1,
        flowouttype => -1,
        flowinrate => -1,
        flowoutrate => -1,
        ip6flowintype => -1,
        ip6flowouttype => -1,
        ip6flowinrate => -1,
        ip6flowoutrate => -1,
	switchmode => '',
	switchaccess => '',
	allowedvlans => []

    };

    bless($self,$class);

    $self->{descr} = new Cogent::Desc;

    return $self;

}
######################################################################
sub hostname {
    my $self = shift;
    if (@_) { $self->{hostname} = shift; }
    return $self->{hostname};
}

######################################################################
sub intf {
    my $self = shift;
    if (@_) { $self->{intf} = shift; }
    return $self->{intf};
}
######################################################################
sub intsuffix {
    my $self = shift;
    if (@_) { $self->{intsuffix} = shift; }
    return $self->{intsuffix};
}
######################################################################
sub shint {
    my $self = shift;
    if (@_) { $self->{shint} = shift; }
    return $self->{shint};
}
######################################################################
sub adminstat {
    my $self = shift;
    if (@_) { $self->{adminstat} = shift; }
    return $self->{adminstat};
}
######################################################################
sub operstat {
    my $self = shift;
    if (@_) { $self->{operstat} = shift; }
    return $self->{operstat};
}
######################################################################
sub preconfig {
    my $self = shift;
    if (@_) { $self->{preconfig} = shift; }
    return $self->{preconfig};
}
######################################################################
sub descr {
    my $self = shift;
    if (@_) { $self->{descr}->descr(shift); }
    return $self->{descr}->descr;
}
######################################################################
#
# speed - Max linespeed of interface unless overridden by description line
#
sub speed {
    my $self = shift;
    if (@_) { $self->{speed} = shift; }
    return $self->{speed};
}
######################################################################
sub ipaddr {
    my $self = shift;
    if (@_) { $self->{ipaddr} = shift; }
    return $self->{ipaddr};
}
######################################################################
sub ip6addr {
    my $self = shift;
    if (@_) { $self->{ip6addr} = shift; }
    return $self->{ip6addr};
}
######################################################################
sub netmask {
    my $self = shift;
    if (@_) { $self->{netmask} = shift; }
    return $self->{netmask};
}
######################################################################
sub secipaddr {
    my $self = shift;
    if (@_) { $self->{secipaddr} = shift; }
    return $self->{secipaddr};
}
######################################################################
sub encap {
    my $self = shift;
    if (@_) { $self->{encap} = shift; }
    return $self->{encap};
}
######################################################################
sub valid {
    my $self = shift;
    if (@_) { $self->{descr}->valid(shift); }
    return $self->{descr}->valid;
}
######################################################################
sub category {
    my $self = shift;
    if (@_) { $self->{descr}->category(shift); }
    return $self->{descr}->category;
}
######################################################################
sub peertype {
    my $self = shift;
    if (@_) { $self->{descr}->peertype(shift); }
    return $self->{descr}->peertype;
}
######################################################################
sub facility {
    my $self = shift;
    if (@_) { $self->{descr}->facility(shift); }
    return $self->{descr}->facility;
}
######################################################################
sub nodeid {
    my $self = shift;
    if (@_) { $self->{descr}->nodeid(shift); }
    return $self->{descr}->nodeid;
}
######################################################################
sub virtual {
    my $self = shift;
    if (@_) { $self->{descr}->virtual(shift); }
    return $self->{descr}->virtual;
}
######################################################################
sub vc {
    my $self = shift;
    if (@_) { $self->{descr}->vc(shift); }
    return $self->{descr}->vc;
}
######################################################################
sub bandwidth {
    my $self = shift;
    if (@_) { $self->{descr}->bandwidth(shift); }
    return $self->{descr}->bandwidth;
}
######################################################################
sub company {
    my $self = shift;
    if (@_) { $self->{descr}->company(shift); }
    return $self->{descr}->company;
}
######################################################################
sub orderno {
    my $self = shift;
    if (@_) { $self->{descr}->orderno(shift); }
    return $self->{descr}->orderno;
}
######################################################################
sub shaul {
    my $self = shift;
    if (@_) { $self->{descr}->shaul(shift); }
    return $self->{descr}->shaul;
}
######################################################################
sub ckid {
    my $self = shift;
    if (@_) { $self->{descr}->ckid(shift); }
    return $self->{descr}->ckid;
}
######################################################################
sub pon {
    my $self = shift;
    if (@_) { $self->{descr}->pon(shift); }
    return $self->{descr}->pon;
}
######################################################################
sub re {
    my $self = shift;
    if (@_) { $self->{descr}->re(shift); }
    return $self->{descr}->re;
}
######################################################################
sub tik {
    my $self = shift;
    if (@_) { $self->{descr}->tik(shift); }
    return $self->{descr}->tik;
}
######################################################################
sub cir {
    my $self = shift;
    if (@_) { $self->{descr}->cir(shift); }
    return $self->{descr}->cir;
}
######################################################################
sub cap {
    my $self = shift;
    if (@_) { $self->{descr}->cap(shift); }
    return $self->{descr}->cap;
}
######################################################################
sub l2tp {
    my $self = shift;
    if (@_) { $self->{descr}->l2tp(shift); }
    return $self->{descr}->l2tp;
}
######################################################################
sub icb {
    my $self = shift;
    if (@_) { $self->{descr}->icb(shift); }
    return $self->{descr}->icb;
}
######################################################################
sub dnlk {
    my $self = shift;
    if (@_) { $self->{descr}->dnlk(shift); }
    return $self->{descr}->dnlk;
}
######################################################################
sub tohost {
    my $self = shift;
    if (@_) { $self->{descr}->tohost(shift); }
    return $self->{descr}->tohost;
}
######################################################################
sub ick {
    my $self = shift;
    if (@_) { $self->{descr}->ick(shift); }
    return $self->{descr}->ick;
}
sub nmp {
    my $self = shift;
    $self->{descr}->nmp(shift) if @_;
    return $self->{descr}->nmp;
}
######################################################################
sub misc {
    my $self = shift;
    if (@_) { $self->{descr}->misc(shift); }
    return $self->{descr}->misc;
}
######################################################################
sub prov {
    my $self = shift;
    if (@_) { $self->{descr}->prov(shift); }
    return $self->{descr}->prov;
}
######################################################################
sub rvw {
    my $self = shift;
    if (@_) { $self->{descr}->rvw(shift); }
    return $self->{descr}->rvw;
}
######################################################################
sub target {
    my $self = shift;
    if (@_) { $self->{descr}->target(shift); }
    return $self->{descr}->target;
}
######################################################################
#
# portspeed - hardcoded port speed (from "speed" command)
#
sub portspeed {
    my $self = shift;
    if (@_) { $self->{portspeed} = shift; }
    return $self->{portspeed};
}
######################################################################
sub isis {
    my $self = shift;
    if (@_) { $self->{isis} = shift; }
    return $self->{isis};
}
######################################################################
sub v6_isis {
    my $self = shift;
    if (@_) { $self->{v6_isis} = shift; }
    return $self->{v6_isis};
}

######################################################################
sub isismetric {
    my $self = shift;
    if (@_) { $self->{isismetric} = shift; }
    return $self->{isismetric};
}
######################################################################
sub v6_isismetric {
    my $self = shift;
    if (@_) { $self->{v6_isismetric} = shift; }
    return $self->{v6_isismetric};
}

######################################################################
sub ospf {
    my $self = shift;
    if (@_) { $self->{ospf} = shift; }
    return $self->{ospf};
}
######################################################################
sub ospfcost {
    my $self = shift;
    if (@_) { $self->{ospfcost} = shift; }
    return $self->{ospfcost};
}
######################################################################
sub mpls {
    my $self = shift;
    if (@_) { $self->{mpls} = shift; }
    return $self->{mpls};
}
######################################################################
sub mplste {
    my $self = shift;
    if (@_) { $self->{mplste} = shift; }
    return $self->{mplste};
}
######################################################################
sub rsvp {
    my $self = shift;
    if (@_) { $self->{rsvp} = shift; }
    return $self->{rsvp};
}
######################################################################
sub duplex {
    my $self = shift;
    if (@_) { $self->{duplex} = shift; }
    return $self->{duplex};
}
######################################################################
sub aclin {
    my $self = shift;
    if (@_) { $self->{aclin} = shift; }
    return $self->{aclin};
}
######################################################################
sub aclout {
    my $self = shift;
    if (@_) { $self->{aclout} = shift; }
    return $self->{aclout};
}
######################################################################
sub ip6aclin {
    my $self = shift;
    if (@_) { $self->{ip6aclin} = shift; }
    return $self->{ip6aclin};
}
######################################################################
sub ip6aclout {
    my $self = shift;
    if (@_) { $self->{ip6aclout} = shift; }
    return $self->{ip6aclout};
}
######################################################################
sub policyin {
    my $self = shift;
    if (@_) { $self->{policyin} = shift; }
    return $self->{policyin};
}
######################################################################
sub policyout {
    my $self = shift;
    if (@_) { $self->{policyout} = shift; }
    return $self->{policyout};
}
######################################################################
sub tunneldest {
    my $self = shift;
    if (@_) { $self->{tunneldest} = shift; }
    return $self->{tunneldest};
}
######################################################################
sub tunnelmode {
    my $self = shift;
    if (@_) { $self->{tunnelmode} = shift; }
    return $self->{tunnelmode};
}
######################################################################
sub tunnelpaths {
    my $self = shift;
    if (@_) { $self->{tunnelpaths} = shift; }
    return $self->{tunnelpaths};
}
######################################################################
sub mtu {
    my $self = shift;
    if (@_) { $self->{mtu} = shift; }
    return $self->{mtu};
}
######################################################################
sub ipmtu {
    my $self = shift;
    if (@_) { $self->{ipmtu} = shift; }
    return $self->{ipmtu};
}
######################################################################
sub ip6mtu {
    my $self = shift;
    if (@_) { $self->{ip6mtu} = shift; }
    return $self->{ip6mtu};
}
######################################################################
sub portstats {
    my $self = shift;
    if (@_) { $self->{portstats} = shift; }
    return $self->{portstats};
}
######################################################################
sub inmin {
    my $self = shift;
    if (@_) { $self->{inmin} = shift; }
    return $self->{inmin};
}
######################################################################
sub inavg {
    my $self = shift;
    if (@_) { $self->{inavg} = shift; }
    return $self->{inavg};
}
######################################################################
sub in90 {
    my $self = shift;
    if (@_) { $self->{in90} = shift; }
    return $self->{in90};
}
######################################################################
sub in95 {
    my $self = shift;
    if (@_) { $self->{in95} = shift; }
    return $self->{in95};
}
######################################################################
sub inmax {
    my $self = shift;
    if (@_) { $self->{inmax} = shift; }
    return $self->{inmax};
}
######################################################################
sub incount {
    my $self = shift;
    if (@_) { $self->{incount} = shift; }
    return $self->{incount};
}

######################################################################
sub outmin {
    my $self = shift;
    if (@_) { $self->{outmin} = shift; }
    return $self->{outmin};
}
######################################################################
sub outavg {
    my $self = shift;
    if (@_) { $self->{outavg} = shift; }
    return $self->{outavg};
}
######################################################################
sub out90 {
    my $self = shift;
    if (@_) { $self->{out90} = shift; }
    return $self->{out90};
}
######################################################################
sub out95 {
    my $self = shift;
    if (@_) { $self->{out95} = shift; }
    return $self->{out95};
}
######################################################################
sub outmax {
    my $self = shift;
    if (@_) { $self->{outmax} = shift; }
    return $self->{outmax};
}
######################################################################
sub outcount {
    my $self = shift;
    if (@_) { $self->{outcount} = shift; }
    return $self->{outcount};
}

######################################################################
sub mergemin {
    my $self = shift;
    if (@_) { $self->{mergemin} = shift; }
    return $self->{mergemin};
}
######################################################################
sub mergeavg {
    my $self = shift;
    if (@_) { $self->{mergeavg} = shift; }
    return $self->{mergeavg};
}
######################################################################
sub merge90 {
    my $self = shift;
    if (@_) { $self->{merge90} = shift; }
    return $self->{merge90};
}
######################################################################
sub merge95 {
    my $self = shift;
    if (@_) { $self->{merge95} = shift; }
    return $self->{merge95};
}
######################################################################
sub mergemax {
    my $self = shift;
    if (@_) { $self->{mergemax} = shift; }
    return $self->{mergemax};
}
######################################################################
sub mergecount {
    my $self = shift;
    if (@_) { $self->{mergecount} = shift; }
    return $self->{mergecount};
}
######################################################################
sub invol {
    my $self = shift;
    if (@_) { $self->{invol} = shift; }
    return $self->{invol};
}
######################################################################
sub outvol {
    my $self = shift;
    if (@_) { $self->{outvol} = shift; }
    return $self->{outvol};
}
######################################################################
sub volume {
    my $self = shift;
    if (@_) { $self->{volume} = shift; }
    return $self->{volume};
}
######################################################################
sub pinvol {
    my $self = shift;
    if (@_) { $self->{pinvol} = shift; }
    return $self->{pinvol};
}
######################################################################
sub poutvol {
    my $self = shift;
    if (@_) { $self->{poutvol} = shift; }
    return $self->{poutvol};
}
######################################################################
sub pvolume {
    my $self = shift;
    if (@_) { $self->{pvolume} = shift; }
    return $self->{pvolume};
}
######################################################################
sub flowintype {
    my $self = shift;
    if (@_) { $self->{flowintype} = shift; }
    return $self->{flowintype};
}
######################################################################
sub flowouttype {
    my $self = shift;
    if (@_) { $self->{flowouttype} = shift; }
    return $self->{flowouttype};
}
######################################################################
sub flowinrate {
    my $self = shift;
    if (@_) { $self->{flowinrate} = shift; }
    return $self->{flowinrate};
}
######################################################################
sub flowoutrate {
    my $self = shift;
    if (@_) { $self->{flowoutrate} = shift; }
    return $self->{flowoutrate};
}
sub ip6flowintype {
    my $self = shift;
    if (@_) { $self->{ip6flowintype} = shift; }
    return $self->{ip6flowintype};
}
######################################################################
sub ip6flowouttype {
    my $self = shift;
    if (@_) { $self->{ip6flowouttype} = shift; }
    return $self->{ip6flowouttype};
}
######################################################################
sub ip6flowinrate {
    my $self = shift;
    if (@_) { $self->{ip6flowinrate} = shift; }
    return $self->{ip6flowinrate};
}
######################################################################
sub ip6flowoutrate {
    my $self = shift;
    if (@_) { $self->{ip6flowoutrate} = shift; }
    return $self->{ip6flowoutrate};
}
sub switchmode {
    my $self = shift;
    if (@_) { $self->{switchmode} = shift; }
    return $self->{switchmode};
}
sub switchaccess {
    my $self = shift;
    if (@_) { $self->{switchaccess} = shift; }
    return $self->{switchaccess};
}
sub allowedvlans {
    my $self = shift;
    return $self->{allowedvlans};

}



######################################################################
sub fieldlist {
    my $self = shift;

    return(@fields,$self->{descr}->fieldlist);
}
######################################################################
sub validdesc {
    my $self = shift;
    my $loud = 0;
    
    if (@_) { $loud = shift; }
    
    my $msg;

    if (($msg = $self->{descr}->validdesc) && $loud) {
	print $self->hostname . ": " . $msg . " (".$self->shint.")\n";
    }
    return ($msg);
}
######################################################################
sub facility2bandwidth {
    my $self = shift;
    my $rval = '';

    if (exists($circ2bw{$self->facility})) {
	$rval = $circ2bw{$self->facility};
    } else {
	$rval = 1000;  #default value
    }
    
    return ($rval);
}
######################################################################
sub facility2max { 
    my $self = shift;
    my $rval = '';

    if (exists($circ2max{$self->facility})) {  # Facility was defined in desc line
	$rval = $circ2max{$self->facility};
    } else {
	if (exists($int2fac{$self->porttype}) && exists($circ2max{$int2fac{$self->porttype}})) {
	    $rval = $circ2max{$int2fac{$self->porttype}};  # we know the facility max by the interface type
	} elsif ($self->facility eq 'PC' && 
		 $self->bandwidth > 0) {
	    $rval = $self->bandwidth;
	} elsif ($self->facility eq 'BUN' && 
		 $self->bandwidth > 0) {
	    $rval = $self->bandwidth;
	} else {
	    $rval = 1000;  #default value
	}
    }
    
    return ($rval);
}
######################################################################
sub facility2maxoctet {
    my $self = shift;
    my $rval = '';

    # Convert from Mbits/s to octets/sec for a total max value
    # suitable for Cricket

    $rval = &POSIX::ceil((($self->facility2max)*$mega)/8);

    return ($rval);
}
######################################################################
sub makespeed {
    my $self = shift;

    if ($self->speed eq '0') {
	$self->speed($self->facility2max($self->facility));
	$self->bandwidth(1) if ($self->bandwidth == 0);
    } else {
	$self->speed(&kmg2m($self->speed));
    }

}
######################################################################
sub makebw {
    my $self = shift;

    if ($self->bandwidth eq '0') {
	$self->bandwidth($self->facility2bandwidth($self->facility));
	$self->bandwidth(1) if ($self->bandwidth == 0);
    } else {
	$self->bandwidth(&kmg2m($self->bandwidth));
    }
}
######################################################################
sub long2short {
    my $self = shift;
    my $intf = shift;
    my $rval = '';

    return ($rval) if (!defined($intf));

    if ($intf =~ /^([A-Za-z\-]+)(\d+.*)/) {
	if (exists($l2s{$1})) {
	    $rval = $l2s{$1} . $2;
	} else {
	    $rval = $intf;
	}
    }
    
    return ($rval);
}
######################################################################
sub makeshort {
    my $self = shift;

    &DebugPR(5,$self->intf . "->" . $self->long2short($self->intf) . "\n") if $main::debug > 5;
    
    $self->shint($self->long2short($self->intf));
}
######################################################################
sub porttype {
    my $self = shift;
    my $rval = '';

    if ($self->intf =~ /^([A-Za-z\-]+)(\d+.*)/) {
	if (defined($1)) {
	    $rval = $1;
	} else {
	    $rval = $self->intf;
	}
    }

    return ($rval);
}
######################################################################
sub makeencap {
    my $self = shift;
    
    if ($self->encap eq 'unk') {
	if ($self->intf =~ /POS|Serial/) {
	    $self->encap("HDLC");
	} elsif ($self->intf =~ /ATM/) {
	    $self->encap("ATM");
	} elsif ($self->intf =~ /Ethernet/) {
	    $self->encap("Ethernet");
	}
    }
}
######################################################################
sub rtrport {
    my $self = shift;
    
    my $str = $self->hostname . '-' . $self->shint ;
    
    $str =~ s/\.atlas\.cogentco\.com//g;
    $str =~ s/\.atlas\.psi\.net//g;
    $str =~ s/\.hades\.cogentco\.com/\.hades/g;

    return ($str);
}
######################################################################
sub portrtr {
    my $self = shift;
    
    my $str = $self->shint . '-' . $self->hostname;
    
    $str =~ s/\.atlas\.cogentco\.com//g;
    $str =~ s/\.atlas\.psi\.net//g;
    $str =~ s/\.hades\.cogentco\.com/\.hades/g;

    return ($str);
}
######################################################################
#
# down -- "shutdown" the port
#
sub down {
    my $self = shift;

    $self->adminstat(0);
    $self->operstat(0);
}
######################################################################
#
# gone -- port is no longer in the network or status unknown
#
sub gone {
    my $self = shift;

    $self->adminstat(-1);
    $self->operstat(-1);
}
######################################################################
#
# maketarget - generate a target filename for rrd data.  Must be a
#              form that is allowed by the filesystem
# 
sub maketarget {
    my $self = shift;

    my $target;

    return (undef) if ($self->nocollect);

    if ($self->category eq 'PEER') {
	$target = $self->company;
	$target .= "-" . $self->orderno if ($self->peertype ne 'PUBLIC');
    } elsif ($self->category eq 'TRANSIT') {
	$target = $self->company;
	$target .= "-" . $self->orderno;
    } elsif ($self->category =~ /CUST/) {
	$target = $self->orderno;
	return (undef) if ($target eq 'unk');
    } else {
	$target = $self->hostname . '-' . $self->shint;
    }

    return (undef) if ($target eq 'unk');

    $target = lc($target); # Target file names are lower case
    $target =~ s/\'//g;    #Remove any single quotes out there
    $target =~ s/\"//g;    #double quotes
    $target =~ s'/'-'g;  #'; #if for some reason there is a / replace it with a -
    $target =~ tr/./-/;   #   No dots please
    $target =~ tr/:/-/;   #   no : either
    $target =~ s/\s+//g;    # Definitly no spaces
    $target =~ s/\t//g;   # Definitly no tabs
    $target =~ s/~//g;   # ~ is bad in a file name

    if ($target =~ /(^\S+)\+.*/) { # This order number field has a + sign
	my @s = split(/\+/,$target);
	$target = shift(@s);  #only use everything up to the first plus sign
    }

    return(undef) if ($target eq 'unk');
    return(undef) if ($target eq '---');

    return(undef) if ($target =~ /\s+/);

    $self->target($target);

    return($target);

}

######################################################################
#
# nocollect - Ignore this port when it comes to SNMP collection
#
sub nocollect {
    my $self = shift;
    my $details=shift;

    my $rv = 0;

    $details = 0 if !defined($details);

    if (!($self->adminstat)) {
	print("Shutdown - skipping " .  $self->dump) if $details;
	$rv++;
    }
    if (!($self->valid)) {
	print("Descr not valid - skipping " .  $self->dump) if $details;
	$rv++;
    }
    if ($self->facility eq 'BGP') {
	print("BGP interface - skipping " .  $self->dump) if $details;
	$rv++;
    }

    if ($self->category eq "PEER" ||
	$self->category eq "TRANSIT" ) {
	if ($self->virtual) {  
	    if ($self->intf =~ /^[Aa][Ta][Mm]/ && 
		!($self->intf =~ /\./)) {
		# This is a top level ATM interface used for peering
		# don't skip it ;)
	    } else {
		print("Virtual interface - skipping " .  $self->dump) if $details;
		$rv++;;
	    }

	}
	if ($self->company eq 'unk' ) {
	    print("Company undefined - skipping " .  $self->dump) if $details;
	    $rv++;;
	}
	if ($self->peertype ne 'PUBLIC' && $self->orderno eq 'UNK' ) {
	    print("No order number - skipping " .  $self->dump) if $details;
	    $rv++;;
	}
    }

    if ($self->category eq "CORE" &&
	$self->virtual) {
	print("Virtual interface on CORE - skipping " .  $self->dump) if $details;
	$rv++;;
    }

    if ($self->category =~ /^CUST/) {
	if ($self->orderno eq 'UNK' || $self->orderno eq '??' ) {
	    print("Order number undefined - skipping " .  $self->dump) if $details;
	    $rv++;
	}
        
        # Customers always have a physical interface
	if ($self->facility eq 'TUN') { 
	    print("Ignore customer TUN ports - skipping " .  $self->dump) if $details;
	    $rv++;
	}

	if ($self->facility eq 'PVC') { 
	    print("Ignore customer PVC ports - skipping " .  $self->dump) if $details;
	    $rv++;
	}

    }

    return($rv);
}

######################################################################
#
#
sub getcricketlinedata {
    my $self = shift;
    my $start = shift;
    my $end = shift;
    my $datadirhead = shift;

    my %rv = ();

    return(undef) if ($self->target eq 'unk');  # no cricket data exists

    if (!defined($datadirhead)) {
	$datadirhead = $cricketdatadir;  # From MarkUtils
    }
    

    my $subd = $self->category;
    
    if ($subd eq 'PEER') {
	$subd .= "-" . $self->peertype;
    }

    my $datafile = "$datadirhead/$subd/" . lc($self->target) .  ".rrd";

    if (-e $datafile) {
	$start = '' if !defined($start);
	$end = '' if !defined($end);

	my @options = ($datafile,"AVERAGE");
	push(@options,"-s", $start) if ($start ne '');
	push(@options,"-e", $end) if ($end ne '');
	
	my $names;
	my $step;
	my $data;
	
	($start,$step,$names,$data) = RRDs::fetch(@options);

	$rv{'target'} = $self->target;
	$rv{'datafile'} = $datafile;

	$rv{'start'} = $start;  
	$rv{'step'} = $step;
	$rv{'names'} = $names;
	$rv{'in'} = [];
	$rv{'inhash'} = {};
	$rv{'out'} = [];
	$rv{'outhash'} = {};
	$rv{'mergemax'} = [];
	
	if (defined($data)) {

	    my $tstamp = $start;

	    my @in = ();
	    my %inhash = ();
	    my @out = ();
	    my %outhash = ();
	    my @mergemax = ();
	    my %maxhash = ();
	    my @inout = ();
	    my $invol = 0;
	    my $outvol = 0;
	    my $volume = 0;
	    my $pinvol = 0;
	    my $poutvol = 0;
	    my $pvolume = 0;


	    $rv{'data'} = $data; # raw data return;

	    foreach my $line (@$data) {

		# $line is a pointer to an array
		# $$line[0] = in Octets per sec
		# $$line[1] = out Octets per sec
		# $$line[2] = in Errors per sec
		# $$line[3] = out Errors per sec
		# $$line[4] = in UcastPackets per sec
		# $$line[5] = out UcastPackets per sec

		my $i = 0;
		my $o = 0;
		my $pin = 0;
		my $pout = 0;

                # (anything over 10.5 Gbps is wrong) -- unless it's 20G Etherchannel... 
		my $sanemax = (10.5 * $giga); # in bps

		# We look at things in Megabits;
		$sanemax = $sanemax/$mega;

		# if we know the line speed use it -- which should cover the 20GEC above

		if ($self->speed) {
		    $sanemax = ($self->speed) * 1.1;  
		}

		if (defined($$line[0])) {
		    $i = &oct2megb($$line[0]);

		    if ($i >= $sanemax) {
			&perr("ERROR: bogus value for $datafile at ($tstamp) -- IN (" 
			      . $$line[0] . " oct/sec) $i Mbps >= $sanemax Mbps\n");
			$i = 0;
		    }
		}
		push(@in,$i);
		$inhash{$tstamp} = $i;
		$invol  += ($i/8) * $step;  # volume in MBytes
		$volume += ($i/8) * $step;  # volume in MBytes

		if ($i && defined($$line[4])) {
		    $pin = $$line[4];
		}
		$pinvol += $pin * $step; # volume in packets
		$pvolume += $pin * $step; # volume in packets
		
		if (defined($$line[1])) {
		    $o = &oct2megb($$line[1]);

		    if ($o >= $sanemax) {
			&perr("ERROR: bogus value for $datafile at ($tstamp) -- OUT (" 
			      . $$line[1] . " oct/sec) $o Mbps >= $sanemax Mbps\n");
			$o = 0; 
		    }
		}
		push(@out,$o);
		$outhash{$tstamp} = $o;
		$outvol += ($o/8) * $step;  # volume in MBytes
		$volume += ($o/8) * $step;  # volume in MBytes

		if ($i && defined($$line[5])) {
		    $pout = $$line[5];
		}
		$poutvol += $pout * $step; # volume in packets
		$pvolume += $pout * $step; # volume in packets


		my $max = &max($i,$o);
		if ($max >= 0) {
		    $maxhash{$tstamp} = $max;
		    push(@mergemax,$max);
		    push(@inout,$i+$o);
		}

		$tstamp += $step;
	    }

	    $rv{'in'} = \@in;               # Mb/s
	    $rv{'inhash'} = \%inhash;       # Mb/s
	    $rv{'out'} = \@out;             # Mb/s
	    $rv{'outhash'} = \%outhash;     # Mb/s
	    $rv{'mergemax'} = \@mergemax;   # Mb/s
	    $rv{'inout'} = \@inout;         # Mb/s
	    $rv{'invol'}  = $invol;          # MBytes
	    $rv{'outvol'} = $outvol;          # MBytes
	    $rv{'volume'} = $volume;        # MBytes
	    $rv{'maxhash'} = \%maxhash;     # Mb/s
	    $rv{'pinvol'}  = $pinvol;        # Packets
	    $rv{'poutvol'} = $poutvol;       # Packets
	    $rv{'pvolume'} = $pvolume;       # Packets
	} else {
	    &perr("ERROR: getcricketlinedata - no data returned from rrdtool fetch @options\n");
	    return(undef);
	}
	return(\%rv);
    } else {
	&perr("ERROR: getcricketlinedata - Can't find data file $datafile\n");
	return(undef);
    }
}

######################################################################
sub dumpcricketstats {
    my $self = shift;
    my $delim = shift; # Field delimiter for data
    my $start = shift;
    my $end = shift;

    $delim = ' ' if !defined($delim);

    my $rv = undef;

    my $portdata;

    if ($self->target ne 'unk' && 
	defined($portdata = $self->getcricketlinedata($start,$end))) {

	my %rrd = %{$portdata};

	my $rrdstart = $rrd{'start'};
	my $step = $rrd{'step'};
	my $names = $rrd{'names'};
	my $data = $rrd{'data'};

	$rv  = "Target:      ". $rrd{'target'} . "\n";
	$rv .= "Start:       ". scalar gmtime($rrdstart) . " UTC ($rrdstart)\n";
	$rv .= "Step size:   $step seconds\n";
#       DS names from Cricket are useless
#	$rv .= "DS names:    ". join (", ", @$names) ."\n";
	$rv .= "Data points: " . ($#$data + 1) . "\n";
	
	$rv .= "\n";
#	$rv .=  "HEAD:${delim}YYYYMMDD${delim}HH:MM UTC${delim}(unixtime)${delim}In Octets/s${delim}Out Octets/s${delim}In Err/s${delim}Out Err/s${delim}In Pks/s${delim}Out Pks/s\n";

	$rv .=  "HEAD:${delim}YYYYMMDD${delim}HH:MM UTC${delim}(unixtime)${delim}In Mb/s${delim}Out Mb/s\n";

	foreach my $line (@$data) {
	    my $ln = '';
	    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = gmtime($rrdstart);
	    $year += 1900;
	    
	    $mon++;  # we get month of year back as (0 - 11)

	    $mon = 0 . $mon if ($mon < 10) ;
	    $mday = 0 . $mday if ($mday < 10) ;
	    $hour = 0 . $hour if ($hour < 10) ;
	    $min = 0 . $min if ($min < 10) ;

	    $ln = "DATA:$delim$year$mon$mday$delim$hour:$min UTC$delim($rrdstart)$delim";

	    
	    my $in = shift(@$line);
	    my $out = shift(@$line);

	    if (defined($in)) {
		$ln .= sprintf("%12.6f%s", &oct2megb($in),$delim);
	    } else {
		$ln .= sprintf("%12s%s","",$delim);
	    }

	    if (defined($out)) {
		$ln .= sprintf("%12.6f%s", &oct2megb($out),$delim);
	    } else {
		$ln .= sprintf("%12s%s","",$delim);
	    }

#
#  Only need this if you want to dump all the values... we only care about the first two
#
#           foreach my $val (@$line) {
#               if (defined($val)) {
#                   $ln .= sprintf("%12.6f%s", $val,$delim);
#               } else {
#                   $ln .= sprintf("%12s%s","",$delim);
#               }

	    $ln =~ s/$delim$//; #delete the final delimiter
	    $rv .= $ln . "\n";

	    $rrdstart += $step;  # move to next time point
	}
	$rv .= "\n";
    }
    return($rv);
}


######################################################################
sub genstats {
    my $self = shift;
    my $start = shift;
    my $end = shift;

    my $rv = 1;

    my $portdata;

    my $doneit = '';

    $doneit = $start if (defined($start));
    $doneit .= $end if (defined($end));


    return($rv) if ($self->portstats eq $doneit);

    if (($self->target ne 'unk') && 
	defined($portdata = $self->getcricketlinedata($start,$end))) {
	my @in = @{$portdata->{'in'}};
	my @out = @{$portdata->{'out'}};
	my @merge = @{$portdata->{'mergemax'}};

	$self->incount($#in+1);
	$self->outcount($#out+1);
	$self->mergecount($#merge+1);
	
	if ($self->incount > 0) {
	    $self->inmin(&min(@in));
	    $self->inavg(&mean(@in));
	    $self->in90(&percentile(90,@in));
	    $self->in95(&percentile(95,@in));
	    $self->inmax(&max(@in));
	}

	if ($self->outcount > 0) {
	    $self->outmin(&min(@out));
	    $self->outavg(&mean(@out));
	    $self->out90(&percentile(90,@out));
	    $self->out95(&percentile(95,@out));
	    $self->outmax(&max(@out));
	}

	if ($self->mergecount > 0) {
	    $self->mergemin(&min(@merge));
	    $self->mergeavg(&mean(@merge));
	    $self->merge90(&percentile(90,@merge));
	    $self->merge95(&percentile(95,@merge));
	    $self->mergemax(&max(@merge));
	}
	$self->invol($portdata->{'invol'});
	$self->outvol($portdata->{'outvol'});
	$self->volume($portdata->{'volume'});
	$self->pinvol($portdata->{'pinvol'});
	$self->poutvol($portdata->{'poutvol'});
	$self->pvolume($portdata->{'pvolume'});
	$self->portstats($doneit);
    } else {
	$rv = 0;
    }

    return($rv);
}

######################################################################
sub printportheader {
    my $self = shift;
    my $usage = shift;

    my $rv = '';

    $rv .= "PORT:\t";
    $rv .= "adminstat\t";
    $rv .= "hostname\t";
    $rv .= "intf\t";
    $rv .= "facility\t";
    $rv .= "speed\t";
    $rv .= "bandwidth\t";
    $rv .= "ckid\t";
    $rv .= "re\t";
    $rv .= "pon\t";
    $rv .= "shaul\t";
    $rv .= "vc\t";
    $rv .= "orderno\t";
    $rv .= "category\t";
    $rv .= "company\t";
    $rv .= "encap\t";
    $rv .= "ipaddr\t";
    $rv .= "netmask\t";
    $rv .= "valid\t";
    $rv .= "descr\t";
    $rv .= "target";

    if (defined($usage)) {
	$rv .= "\t";
	$rv .= "min-in\t";
	$rv .= "mean-in\t";
	$rv .= "90-in\t";
	$rv .= "95-in\t";
	$rv .= "max-in\t";
	$rv .= "min-out\t";
	$rv .= "mean-out\t";
	$rv .= "90-out\t";
	$rv .= "95-out\t";
	$rv .= "max-out\t";
	$rv .= "90-merge\t";
	$rv .= "95-merge\t";
	$rv .= "95-%used\t";
	$rv .= "max-%used\t";
	$rv .= "samples";
    }
    

    return($rv);
}

sub printport {
    my $self = shift;
    my $usage = shift;
    my $start = shift;
    my $end = shift;

    my $portdata;
    
    my $rv = '';

    $rv .= "PORT:\t";
    $rv .= $self->adminstat . "\t";
    $rv .= $self->hostname . "\t";
    $rv .= $self->shint . "\t";
    $rv .= $self->facility . "\t";
    $rv .= $self->speed . "\t";
    $rv .= $self->bandwidth . "\t";
    $rv .= $self->ckid . "\t";
    $rv .= $self->re . "\t";
    $rv .= $self->pon . "\t";
    $rv .= $self->shaul . "\t";
    $rv .= $self->vc . "\t";
    $rv .= $self->orderno . "\t";
    $rv .= $self->category . "\t";
    $rv .= $self->company . "\t";
    $rv .= $self->encap . "\t";
    $rv .= $self->ipaddr . "\t";
    $rv .= $self->netmask . "\t";
    $rv .= $self->valid . "\t";
    $rv .= $self->descr . "\t";
    $rv .= $self->target;

    if (defined($usage)) {
	if ($self->genstats($start,$end)) {
	    
	    $rv .= "\t";
	    
	    if ($self->incount > 0) {
		$rv .= sprintf("%12.6f\t",$self->inmin);
		$rv .= sprintf("%12.6f\t",$self->inavg);
		$rv .= sprintf("%12.6f\t",$self->in90);
		$rv .= sprintf("%12.6f\t",$self->in95);
		$rv .= sprintf("%12.6f\t",$self->inmax);
	    } else {
		$rv .= "\t";
		$rv .= "\t";
		$rv .= "\t";
		$rv .= "\t";
		$rv .= "\t";
            }

	    if ($self->outcount > 0) {
		$rv .= sprintf("%12.6f\t",$self->outmin);
		$rv .= sprintf("%12.6f\t",$self->outavg);
		$rv .= sprintf("%12.6f\t",$self->out90);
		$rv .= sprintf("%12.6f\t",$self->out95);
		$rv .= sprintf("%12.6f\t",$self->outmax);
	    } else {
		$rv .= "\t";
		$rv .= "\t";
		$rv .= "\t";
		$rv .= "\t";
		$rv .= "\t";
            }

	    if ($self->mergecount >0) {
		$rv .= sprintf("%12.6f\t",$self->merge90);
		$rv .= sprintf("%12.6f\t",$self->merge95);
		$rv .= sprintf("%6.3f\t",(($self->merge95/$self->bandwidth) * 100));
		$rv .= sprintf("%6.3f\t",(($self->mergemax/$self->bandwidth) * 100));
		$rv .= $self->mergecount ;
	    } else {
		$rv .= "\t";
		$rv .= "\t";
		$rv .= "\t";
		$rv .= "\t";
	    }
	} else {
	    $rv .= "\t";
	    $rv .= "\t";
	    $rv .= "\t";
	    $rv .= "\t";
	    $rv .= "\t";
	    $rv .= "\t";
	    $rv .= "\t";
	    $rv .= "\t";
	    $rv .= "\t";
	    $rv .= "\t";
	    $rv .= "\t";
	    $rv .= "\t";
	    $rv .= "\t";
	    $rv .= "\t";
	    $rv .= "\t";
	}
    }

    return($rv);
}
######################################################################
#
#
#
sub ParseInt {
    my $self = shift;
    my $ln = shift;
    my $confptr = shift;
    my $hostname = shift;
    my $chassis = shift;
    my $noisy = shift;

    my @errorstr = ();
    my $rv = '';

    my %seenflags = ();

    &DebugPR(2,"PORT: $hostname Line $ln \n");

    if ($ln =~ /^interface (preconfigure )?(\S+)\s*(.*)/) { # Process interface
	&DebugPR(2,"PORT: Found Interface\n");

	my $ln = '';

	if (defined($1)) {
	    &DebugPR(2,"$hostname preconfig interface \n");
	    $self->preconfig(1);
	}

	$self->hostname($hostname);
	$self->intf($2);
	if (defined($3)) {
	    $self->intsuffix($3);
	}
	$self->makeshort;
	$self->adminstat(1); # Assume it's up

	while (ref($confptr) && ($ln = shift(@{$confptr}))) {
	    #next if &referr($ln);
	    #this is the same concept as top level commands, the referr is just garbage unless debugging
	    next if ref($ln);

	    &DebugPR(2,"$hostname -Line $ln \n");
	    if ($ln =~ /^description (.+)/) {
		&DebugPR(2,"PORT: Found description\n");
		$self->descr($1);
		next;
	    }
	    if ($ln =~ /^shutdown/) {
		&DebugPR(2,"PORT: Found shutdown\n");
		$self->adminstat(0);
		$self->operstat(0);
		next;
	    }
	    #gather ipv4 monitor lines
             if ($ln =~ /^flow ipv4 monitor (\w+) sampler (\w+) ingress/)
	    {
		&DebugPR(2,"PORT: Found netflow ingress\n");
		$self->flowintype($1);
		$self->flowinrate($2);
		next;
	    }
	 if ($ln =~ /^flow ipv4 monitor (\w+) sampler (\w+) egress/)
            {
                &DebugPR(2,"PORT: Found netflow egress\n");
                $self->flowouttype($1);
                $self->flowoutrate($2);
                next;
            }
            #gather ipv6 monitor lines
             if ($ln =~ /^flow ipv6 monitor (\w+) sampler (\w+) ingress/)
            {
                &DebugPR(2,"PORT: Found netflow ingress\n");
                $self->ip6flowintype($1);
                $self->ip6flowinrate($2);
                next;
            }
         if ($ln =~ /^flow ipv6 monitor (\w+) sampler (\w+) egress/)
            {
                &DebugPR(2,"PORT: Found netflow egress\n");
                $self->ip6flowouttype($1);
                $self->ip6flowoutrate($2);
                next;
            }

	    if ($ln =~ /^speed (.+)/) {
		&DebugPR(2,"PORT: Found (port)speed\n");
		
		my $speed = $1;

		if ($speed eq 'nonegotiate') {
		    # GigE port locked to full speed

		    $self->portspeed(1000);

		} elsif ($speed eq 'auto') {
		    # Not locked to anything so do nothing
		} else {
		    $self->portspeed($speed);
		}
		next;
	    }
	    if ($ln =~ /^duplex (.+)/) {
		&DebugPR(2,"PORT: Found duplex\n");
		$self->duplex($1);
	    }
	    if ($ln =~ /^ip(v4)? address (\d+\.\d+\.\d+\.\d+) (\d+\.\d+\.\d+\.\d+) secondary/) {
		&DebugPR(2,"PORT: Found secondary IP\n");
		push (@{$self->secipaddr},[$2,$3]);
		next;
	    } elsif ($ln =~ /^ip(v4)? address (\d+\.\d+\.\d+\.\d+) (\d+\.\d+\.\d+\.\d+)$/) {
		&DebugPR(2,"PORT: Found IP\n");
		$self->ipaddr($2);
		$self->netmask($3);
		next;
	    }
	    if ($ln =~ /^ipv6 address (\S+)\s*(.*)/) {
		&DebugPR(2,"PORT: Found IPv6 address $1\n");
		&DebugPR(2,"PORT: Also found $2\n") if defined($2);
		push (@{$self->ip6addr},[$1]);
		next;
	    }
	#The XR syntax for this line ipv4 access-group xxx ingress/egress
	    if ($ln =~ /^ip(v4)? access-group (\S+)\s+(\S+)/) {
		&DebugPR(2,"PORT: Found access-group\n");
		if ($3 eq "in" or $3 eq "ingress") {
		    $self->aclin($2);
		} elsif ($3 eq "out" or $3 eq "egress") {
		    $self->aclout($2);
		}
		next;
	    }
	#the XR ipv6 access-group command (completely different from IOS ipv6 acl)
	    if ($ln =~ /^ipv6 access-group (\S+)\s+(\S+)/) {
                &DebugPR(2,"PORT: Found access-group\n");
                if ($3  eq "ingress") {
                    $self->ip6aclin($1);
                } elsif ($3 eq "egress") {
                    $self->ip6aclout($1);
                }
                next;
            }

	    if ($ln =~ /^ipv6 traffic-filter (\S+)\s+(\S+)/) {
		&DebugPR(2,"PORT: Found traffic-filter\n");
		if ($2 eq "in") {
		    $self->ip6aclin($1);
		} elsif ($2 eq "out") {
		    $self->ip6aclout($1);
		}
		next;
	    }
	    if ($ln =~ /^service-policy (\S+)\s+(\S+)/) {
		&DebugPR(2,"PORT: Found service-policy\n");
		if ($1 eq "input") {
		    $self->policyin($2);
		} elsif ($1 eq "output") {
		    $self->policyout($2);
		}
		next;
	    }
	    if ($ln =~ /^encapsulation (\S+)\s*(\S*)/) {
		&DebugPR(2,"PORT: Found encapsulation\n");
		$self->encap($1);
		if (defined($2) && $2 ne '') {
		    $self->vc($2);
		    if ($1 eq 'dot1Q') {
			$self->virtual('VLAN');
		    } else {
			$self->virtual($1);
		    }
		}
		next;
	    }
	    if ($ln =~ /^frame-relay interface-dlci (\d+)/) {
		&DebugPR(2,"PORT: Found frame-relay interface-dlci\n");
		$self->vc($1);
		$self->virtual("Frame-Relay");
		if ($self->encap ne "frame-relay") {
		    $self->encap("frame-relay");
		}
		next;
	    }

	    if ($ln =~ /^atm pvc (\d+) (\d+) (\d+) (\S+)/) {
		# VCD VPI VCI Encapsulation - may or may not
		# be a sub int.. so I think parsing here might
		# be broken as I think you can have multiple of
		# these lines
		&DebugPR(2,"PORT: Found an ATM PVC\n");
		$self->vc("$1 $2 $3");
		$self->encap($4);
		$self->virtual("ATM");
		next;
	    }
	    if ($ln =~ /^pvc (\S+) (\d+)\/(\d+)/) {
		# VCD VPI VCI Encapsulation - may or may not
		# be a sub int.. so I think parsing here might
		# be broken as I think you can have multiple of
		# these lines
		&DebugPR(2,"PORT: Found an ATM PVC\n");
		$self->vc("$1 $2/$3");
		$self->virtual("ATM");
		next;
	    }
	    if ($ln =~ /^pvc (\d+)\/(\d+)/) {
		# VCD VPI VCI Encapsulation - may or may not
		# be a sub int.. so I think parsing here might
		# be broken as I think you can have multiple of
		# these lines
		&DebugPR(2,"PORT: Found an ATM PVC\n");
		$self->vc("$1/$2");
		$self->virtual("ATM");

		$ln = shift(@{$confptr});
		if (ref($ln)) {
		    my @c2 = @{$ln};
		    while ($ln = shift(@c2)) {
			next if &referr($ln,$hostname);
			if ($ln =~ /^cbr (\S+)/) { 
			    &DebugPR(2,"PORT: cbr $1\n");
			    next;
			}
			if ($ln =~ /^encapsulation (\S+)/) { 
			    $self->encap($1);
			    &DebugPR(2,"PORT: Found an encap $1\n");
			    next;
			}
		    }
		} else {
		    # opps, wasn't a ref, put it back
		    unshift(@{$confptr},$ln);
		}
		next;
	    }
	    if ($ln =~ /^(no ip redirects)/ ||
		$ln =~ /^(no ip directed-broadcast)/ ||
		$ln =~ /^(no ip proxy-arp)/ ||
		$ln =~ /^(no ip unreachables)/ ||
		$ln =~ /^(no peer neighbor-route)/ ||
		$ln =~ /^(ppp ipcp neighbor-route disable)/ ||
		$ln =~ /^(no isis hello padding)/ ||
		$ln =~ /^(isis network point-to-point)/ ||
		$ln =~ /^(isis protocol shutdown)/ ||
		$ln =~ /^(ip ospf network point-to-point)/ ||
		$ln =~ /^(flowcontrol send off)/ ||
		$ln =~ /^(pos scramble-atm)/ ||
		$ln =~ /^(storm-control action shutdown)/ ||
		$ln =~ /^(spanning-tree bpdufilter enable)/ ||
		$ln =~ /^(spanning-tree bpdufilter disable)/ ||
		$ln =~ /^(spanning-tree bpduguard enable)/ ||
		$ln =~ /^(l2protocol-tunnel stp)/ ||
		$ln =~ /^(l2protocol-tunnel vtp)/ ||
		$ln =~ /^(l2protocol-tunnel cdp)/ ||
		$ln =~ /^(switchport trunk encapsulation dot1q)/ ||
		$ln =~ /^(no cdp enable)/ ||
		$ln =~ /^(tunnel mpls traffic-eng record-route)/ ||
		$ln =~ /^(record-route)/ ||
		$ln =~ /^(cdp)/ 
		) {
		&DebugPR(2,"PORT: Found $1\n");
		$seenflags{$1} = 1;
		next;
	    }

	    if ($ln =~ /^(mpls ip)/) {
		&DebugPR(2,"PORT: Found $1\n");
		$seenflags{$1} = 1;
		$self->mpls(1);
		next;
	    }

	    if ($ln =~ /^(mpls traffic-eng tunnels)/ ) {
		&DebugPR(2,"PORT: Found $1\n");
		$seenflags{$1} = 1;
		$self->mplste(1);
		next;
	    }

	    if ($ln =~ /^carrier-delay (\S+)/) {
		&DebugPR(2,"PORT: Found carrier-delay $1\n");
		$seenflags{'carrier-delay'} = $1;
		next;
	    }
	    if ($ln =~ /^port-type (\S+)/) {
		&DebugPR(2,"PORT: Found port-type $1\n");
		$seenflags{'port-type'} = $1;
		next;
	    }
	    if ($ln =~ /^crc (\d+)/) {
		&DebugPR(2,"PORT: Found crc $1\n");
		$seenflags{'crc'} = $1;
		next;
	    }
	    if ($ln =~ /^mtu (\d+)/) {
		&DebugPR(2,"PORT: Found mtu $1\n");
		$self->mtu($1);
		next;
	    }
	    if ($ln =~ /^ip(v4)? mtu (\d+)/) {
		&DebugPR(2,"PORT: Found ip mtu $2\n");
		$self->ipmtu($2);
		next;
	    }
	    if ($ln =~ /^ipv6 mtu (\d+)/) {
		&DebugPR(2,"PORT: Found ipv6 mtu $1\n");
		$self->ip6mtu($1);
		next;
	    }
	    if ($ln =~ /^clns mtu (\d+)/) {
		&DebugPR(2,"PORT: Found clns mtu $1\n");
		$seenflags{'clns mtu'} = $1;
		next;
	    }
	    if ($ln =~ /^storm-control broadcast level pps (\S+)/) {
		&DebugPR(2,"PORT: Found storm-control broadcast level pps $1\n");
		$seenflags{'storm-control broadcast level pps'} = $1;
		next;
	    }
	    if ($ln =~ /^storm-control broadcast level (\S+)/) {
		&DebugPR(2,"PORT: found storm-control broadcast level $1\n");
		$seenflags{'storm-control broadcast level'} = $1;
		next;
	    }
	    if ($ln =~ /^clock source (\S+)/) {
		&DebugPR(2,"PORT: Found clock source $1\n");
		$seenflags{'clock source'} = $1;
		next;
	    }
	    if ($ln =~ /^isis circuit-type (.+)/) {
		&DebugPR(2,"PORT: Found isis circuit-type $1\n");
		$seenflags{'isis circuit-type'} = $1;
		next;
	    }
	    if ($ln =~ /^isis password (\S+)/) {
		&DebugPR(2,"PORT: Found isis password $1\n");
		$seenflags{'isis password'} = $1;
		next;
	    }
#	    if (($ln =~ /^xconnect (\d+\.\d+\.\d+\.\d+) (\d+) encapsulation mpls/) ||
	    if ($ln =~ /^xconnect (\d+\.\d+\.\d+\.\d+) (\d+) pw-class mpls-l2vpn/) { 
		&DebugPR(2,"PORT: Found EoMPLS xconnect $1 $2\n");
		$seenflags{'EoMPLS xconnect'} = $1 .'-' . $2;
		$self->virtual("EoMPLS");
		$self->misc($ln);

                # check for MTU ref
		$ln = shift(@{$confptr});
		if (ref($ln)) {
		    my @c2 = @{$ln};
		    while ($ln = shift(@c2)) {
			next if &referr($ln,$hostname);
			if ($ln =~ /^mtu (\S+)/) { 
			    &DebugPR(2,"PORT: xconnect mtu $1\n");
			    next;
			}
		    }
		} else {
		    # opps, wasn't a ref, put it back
		    unshift(@{$confptr},$ln);
		}


		next;
	    }

	    if ($ln =~ /^mpls/) { 
		&DebugPR(2,"PORT: Found mpls\n");
		$seenflags{'mpls'} = 1;

                # check for MTU ref
		$ln = shift(@{$confptr});
		if (ref($ln)) {
		    my @c2 = @{$ln};
		    while ($ln = shift(@c2)) {
			next if &referr($ln,$hostname);
			if ($ln =~ /^mtu (\S+)/) { 
			    &DebugPR(2,"PORT: mpls mtu $1\n");
			    next;
			}
		    }
		} else {
		    # opps, wasn't a ref, put it back
		    unshift(@{$confptr},$ln);
		}
		next;
	    }


	    if ($ln =~ /^pos/) { 
		&DebugPR(2,"PORT: Found pos\n");

                # check for MTU ref
		$ln = shift(@{$confptr});
		if (ref($ln)) {
		    my @c2 = @{$ln};
		    while ($ln = shift(@c2)) {
			next if &referr($ln,$hostname);
			if ($ln =~ /^crc (\S+)/) { 
			    &DebugPR(2,"PORT: pos crc $1\n");
			    $seenflags{'pos crc'} = $1;
			    next;
			}
		    }
		} else {
		    # opps, wasn't a ref, put it back
		    unshift(@{$confptr},$ln);
		}
		next;
	    }

	    if ($ln =~ /^isis hello-interval (\S+)(\s+\S+)*/) {
		&DebugPR(2,"PORT: Found isis hello-interval $1\n");
		$seenflags{'isis hello-interval'} = $1;
		
		next;
	    }
	    if ($ln =~ /^isis hello-multiplier (\S+)(\s+\S+)*/) {
		&DebugPR(2,"PORT: Found isis hello-multiplier $1\n");
		$seenflags{'isis hello-multiplier'} = $1;
		
	    }
	    if ($ln =~ /^isis metric (\d+)(\s+\S+)*/) {
		&DebugPR(2,"PORT: Found isis metric $1\n");
		$seenflags{'isis metric'} = $1;
		$self->isismetric($1);

		next;
	    }
            if ($ln =~ /^isis ipv6 metric (\d+)(\s+\S+)*/) {
                &DebugPR(2,"PORT: Found v6_isis metric $1\n");
                $seenflags{'v6_isis metric'} = $1;
                $self->v6_isismetric($1);
                $self->v6_isis(1);

                next;
            }

	    if ($ln =~ /^ip router isis (\S+)/) {
		&DebugPR(2,"PORT: Found ip router isis $1\n");
		$seenflags{'ip router isis'} = $1;
		$self->isis($self->isis + 1);
		next;
	    }
	    if ($ln =~ /^clns router isis (\S+)/) {
		&DebugPR(2,"PORT: Found clns router isis $1\n");
		$seenflags{'clns router isis'} = $1;
		$self->isis($self->isis + 1);
		next;
	    }
	    if ($ln =~ /^ip rsvp bandwidth (\d+) (\d+)/) {
		&DebugPR(2,"PORT: Found ip rsvp bandwidth $1\n");
		$seenflags{'ip rsvp bandwidth'} = $1 . ' ' . $2;
		$self->rsvp($seenflags{'ip rsvp bandwidth'});
		next;
	    }
	    if ($ln =~ /^ip ospf authentication-key\s+(\S+\s*\S*)/) {
		&DebugPR(2,"PORT: Found ip ospf authentication-key $1\n");
		$seenflags{'ip ospf authentication-key'} = $1;
		$self->ospf($self->ospf + 1);
		next;
	    }
	    if ($ln =~ /^ip ospf hello-interval (\S+)/) {
		&DebugPR(2,"PORT: Found ip ospf hello-interval $1\n");
		$seenflags{'ip ospf hello-interval'} = $1;
		$self->ospf($self->ospf + 1);
		next;
	    }
	    if ($ln =~ /^ip ospf dead-interval (\S+)/) {
		&DebugPR(2,"PORT: Found ip ospf dead-interval $1\n");
		$seenflags{'ip ospf dead-interval'} = $1;
		$self->ospf($self->ospf + 1);
		next;
	    }
	    if ($ln =~ /^ip ospf cost (\S+)/) {
		&DebugPR(2,"PORT: Found ip ospf cost $1\n");
		$seenflags{'ip ospf cost'} = $1;
		$self->ospfcost($1);
		next;
	    }
	    if ($ln =~ /^switchport mode (.+)/) {
		&DebugPR(2,"PORT: Found switchport mode $1\n");
		$seenflags{'switchport mode'} = $1;
		$self->switchmode($1);
		next;
	    }
	    if ($ln =~ /^spanning-tree portfast\s*(\S*)/) {
		&DebugPR(2,"PORT: Found spanning-tree portfast\n");
		$seenflags{'spanning-tree portfast'} = 1;
		if (defined($1)) {
		    $seenflags{'spanning-tree portfast'} = $1;
		}
		next;
	    }
            if ($ln =~ /^switchport access vlan (\d+)/) {
                &DebugPR(2,"PORT: Found switchport access vlan $1\n");
                $seenflags{'switchport access vlan'} = $1;
		$self->switchaccess($1);
                next;
            }
	    #had to promote this ABOVE the set below so it doesn't get preemtped
	    if ($ln =~ /^switchport trunk allowed vlan (.*)/) {
                &DebugPR(2,"PORT: Found switchport trunk allowed vlan $1\n");
                $seenflags{'switchport trunk allowed vlan'} = $1;
                my $vlstring = $1;
                my @vlans = @{$self->allowedvlans};
                $vlstring =~ s/add//;#strip add
                $vlstring =~s/\s//;#strip whitespace
                for my $part (split /,/, $vlstring){#it's comma seperated
                        if($part =~ /(\d+)-(\d+)/){#it can be x-y or just x
                                for my $ind ($1 .. $2){#seems legit
                                        push @vlans, $ind;
                                        DebugPR(3, "PORT: Added vlan $ind to port\n");
                                }
                        }else{
                                push @vlans, $part;
                                DebugPR(3, "PORT: Added vlan $part to port\n");
                        }
                }
                $self->{allowedvlans} = \@vlans;
		DebugPR(3, "PORT: Currently allowed vlans would be: ". (join ",", @{$self->allowedvlans}). "\n");
                next;
            }
	    if ($ln =~ /^switchport (access|trunk)/) {
		my $switchporttype = $1;
		&DebugPR(2,"PORT: Found switchport $switchporttype\n");
		$seenflags{"switchport $switchporttype"} = 1;
		next;
	    }
	    if ($ln =~ /^(tunnel )?destination (.+)/) {
		&DebugPR(2,"PORT: tunnel destination $2\n");
		$self->tunneldest($2);
		next;
	    }
	    if ($ln =~ /^tunnel mode (.+)/) {
		&DebugPR(2,"PORT: tunnel mode $1\n");
		$self->tunnelmode($1);
		next;
	    }
	    if ($ln =~ /^(tunnel mpls traffic-eng )?path-option \d+ explicit name (\S+)/) {
		&DebugPR(2,"PORT: path-option $2\n");
		push (@{$self->tunnelpaths},$2);
		next;
	    }
	    if ($ln =~ /^(tunnel mpls traffic-eng \S+)\s+(.+)/) {
		&DebugPR(2,"PORT: $1 $2\n");
		$seenflags{$1} = $2;
		next;
	    }

	} # End of parsing loop
   }

# We've finished parsing the Interface, now do the checks to see if everything that
# should be there is



# Some things to ignore when complaining
#
# Ignore testlab routers
# Ignore verio routers
#
if ($self->intf =~ /Null|Async/ ||
            !&COIstandard($self->hostname)) {
            $self->validdesc(0);
        } else {
            if ($noisy) {
                my $descplaint = $self->validdesc($self->adminstat);
		 push (@errorstr, $self->hostname . ": $descplaint (" . $self->shint . ")") if $descplaint and $self->adminstat ;#dropped the caveat to avoid Missing Descriptions errors

		if($self->shint =~ /Lo0/) {
			my $loop0err = Validation::Tests::ValidLoopback0($self->hostname, $self->ipaddr);
			 push (@errorstr, $self->hostname . ": $loop0err (" . $self->shint . ")") if $loop0err;
			my $ipv6pass;
			if(ref($self->ip6addr) and ref( $self->ip6addr()->[0] ) ) #is there an ipv6 address?
			{
			  my $loop0v6err = Validation::Tests::ValidLoopback0ipv6($self->hostname, $self->ipaddr, $self->ip6addr()->[0]->[0]);
			  push (@errorstr, $self->hostname . ": $loop0v6err (" . $self->shint . ")") if $loop0v6err;
			
			}
			else #no ipv6 at all
			{
				push (@errorstr, $self->hostname . ": " . Validation::Tests::ValidLoopback0ipv6($self->hostname, $self->ipaddr, 'blank') . " (" . $self->shint . ")");
			}
		}
            } else {
                $self->validdesc(0);
            }
        }


	$self->makeencap;
	$self->makebw;
	$self->makespeed;
	if ($self->orderno ne "unk") {
	    my $s = $self->orderno;

	    $s =~ tr/a-z/A-Z/;
	    $self->orderno($s);
	}



    return($rv,\@errorstr);
}
######################################################################
sub rdnsname {
    my $self = shift;

    my $name = $self->shint;

    return(undef) if !defined($name);
    return(undef) if ($name eq 'unk');

    # not strictly needed from a dns/bind POV, but it 
    # seems traceroute doesn't like a / in there
    $name =~ tr|/|-|;
    $name =~ tr/:/-/;

    $name .= '.' . $self->hostname;
    $name = lc($name);


    return(undef) if ($name =~ /unk/);

    return($name);
}

######################################################################
#
# needcdp - determine if this port should have cdp active or not.
#
# ignore interfaces/boxes where it can't be configured

sub needcdp {
    my $self = shift;
    my $chassis = shift;
    my $seenflags = shift;

    # these don't have a cdp status
    if (($self->intf =~ /Loopback|Null|Vlan|VLAN|ATM|Port-channel|Bundle-Ether|BVI/) 
	|| ($self->facility eq 'TUN') 
	|| exists($seenflags->{'EoMPLS xconnect'})
	|| (($self->encap eq "frame-relay") 
	    && ($self->intsuffix ne "point-to-point"))
	) {
	return(-1);
    }

    # ASR Subints cannot run CDP

    if (($chassis =~ /ASR/) 
	&& ($self->intf =~ /\./)) {
	return(-1);
    }

    # no CDP on customer/Peer ports -- yes on everything else.
    if (($self->category =~ /CUST/
	 || $self->category eq 'PEER' 
	 || $self->category eq 'TCAGG') 
	) {
	if ($chassis =~ /ME-3400/) {
	    return(-1);
	} else {
	    return(0);
	}
    } else {
	return(1);
    }
}


######################################################################
#
# rsvpcheck - look for rsvp and confirm correct values (on a port expected to have rsvp
#
# 
# 

sub rsvpcheck {
    my $self = shift;

    my @err = ();

    if (!defined($self->rsvp)) {

    } else {
	if (exists($rsvpbw{$self->facility})) {
	    if ($rsvpbw{$self->facility} ne $self->rsvp) {
	    } 
	} elsif (($self->intf !~ /\./)
		 && ($self->intf !~ /[Vv][Ll][Aa][Nn]/)
	    ) {
	    # Should know the value for anything other than subints
	    &perr("Cannot determine correct rsvp size for '". $self->facility . "'\n");
	    &perr($self->dump);
	}
    }

    return(\@err);
}

sub rsvpgen {
    my $self = shift;
    my $chassis = shift;

    my $rv = undef;

    if (defined($chassis) &&
	exists($rsvpbw{$self->facility})) {
	if ($chassis =~ /ASR/) {
	    # code up asr auto code here
	} else {
	    $rv .= " ip rsvp bandwidth " . $rsvpbw{$self->facility} . "\n";
	}
    }

    return($rv);

}


######################################################################
sub gendesc {
    my $self = shift;
    return $self->{descr}->gendesc;
}


######################################################################
sub dump {
    my $self = shift;
    my $str = '';

    $str = "Dumping Port  ";
    $str .= Data::Dumper->Dump([$self],[qw(*self)]);
    
    if (@_) { 
	print $str;
    }
    return($str);
}


1;
