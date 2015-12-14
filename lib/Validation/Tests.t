#!/usr/bin/perl

#Seth Phillips
#05/08/14
#CCheck tests as I need them


use warnings;
use strict;
use lib '../';
use Test::More;
use Test::Exception;
use Connection::Netinv;

BEGIN{
	use_ok('Validation::Tests');
	ok(!(Validation::Tests::ValidLoopback0('ccr41.iad02.atlas.cogentco.com', '66.28.1.9')));
#	print Validation::Tests::ValidLoopback0('agr11.okc01.atlas.cogentco.com', '154.54.66.143');
	ok(!(Validation::Tests::ValidLoopback0('agr11.okc01.atlas.cogentco.com', '154.54.66.143')));
	#sticking with the same two examples
	#correct information should give no error (although this allocation is missing)
	ok(!(Validation::Tests::ValidLoopback0ipv6('ccr41.iad02.atlas.cogentco.com', '66.28.1.9', '2001:550:0:1000:421c:109')));
	#made up some incorrect ipv6 to error on
	ok((Validation::Tests::ValidLoopback0ipv6('ccr41.iad02.atlas.cogentco.com', '66.28.1.9', '2001:550:0:1080:421c:109')));
	#ValidICK takes a ref to ICK record and validates it
	#print Validation::Tests::ValidICK(Connection::Netinv->new->GetRecord('netinv.ick', 'ick_id', '022434'));
	ok(!(Validation::Tests::ValidICK(Connection::Netinv->new->GetRecord('netinv.ick', 'ick_id', '022434'))));
	#000327 at the time has a mismatch on port type v ick type, built a test that should recognize it
	ok(Validation::Tests::ValidICK(Connection::Netinv->new->GetRecord('netinv.ick', 'ick_id', '000327')) =~ /does not match/);
	#ValidICKS looks at ALL active icks and spews the errors, i'm going to assume we'll see errors for the test case
	my $result =  Validation::Tests::ValidICKs();
	print $result;
	ok($result);
	my %hash = (a_port_id => 275899, z_port_id => 228864);#274822);
	$result = Validation::Tests::NetflowCheck(\%hash);
	#print $result;
	ok($result);
	$result = Validation::Tests::CancelDateCheck();
	#print $result;
	ok($result);

	done_testing();
}
