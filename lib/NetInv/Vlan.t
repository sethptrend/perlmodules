#!/usr/bin/perl

#Seth Phillilps
#8/14/13


use strict;
use Test::More;

use lib '../', '/local/scripts/lib';


BEGIN{
	use_ok('NetInv::Vlan');
	use_ok('NetInv');
	my $db = NetInv->new();
	ok(my $vlandb = NetInv::Vlan->new($db));
	ok(NetInv::Vlan->new());
	#main abstraction in: hostname + vlan, out hub, host_a, host_z
	ok(my ($hub, $hosta, $hostz) = $vlandb->search("xxxx.iah02", 4051));#subject to 4051 IAH02 existing
	ok($hub);
	ok($hosta eq 'mag02.iah02');

done_testing();
}

