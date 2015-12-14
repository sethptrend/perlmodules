#!/usr/bin/perl

#Seth Phillips
#8/5/13
#test suite for what i've used in NetInv


use strict;
use Test::More;
use Test::Exception;

BEGIN{
        #creation
	print "Note that failures could be due to data changes in database.  If that's the case, fix the test.\n";
        use_ok('NetInv');
	ok(my $db = NetInv->new());
	ok(my $nirv = $db->GetRecord('netinv.devices', 'hostname', "na01.b005558-0.sfo01\%"));
	ok($nirv->{hostname});
	#Old data, but so scratching this test
	#ok($db->GetRecord('netinv.vlans', 'hub_a', 'BOS01', 'hub_z', 'PHL03'));
	ok($db->dbh);
	#wanted a getpath function to translate hostname to path without code in main script
	ok($db->GetPath('mag21.mrs01') =~ /dist/);
	ok($db->Hostname2Status('mag21.ams03') =~ /Active/);
	#ok($db->CCheck('ccr01.den02.atlas: ERROR-DESC: blah blah blah (Gi1/1)'));

	


	done_testing();
}
