#!/usr/bin/perl

#Seth Phillips
#7/31/13


use lib '../';

use strict;

use Test::More;
use Test::Exception;
use JSON;

BEGIN
{
	use_ok('Parsing::Router');
	ok(my $router = Parsing::Router->new());

	#suite of tests performed on testrtr in directory
	lives_ok{$router->Parse('testrtr')};
	ok($router->filename eq 'testrtr');
	ok($router->iostype eq 'IOS');
	ok(ref($router->rawconfig));#not really a specific test, just making sure it returns SOME dump
	ok(ref($router->status));
	ok((my @ips = $router->FindIPs()) == 3);#scalar mode, there are 3 IPs  to find in testrtr
	ok((my @vlans = $router->FindVLANs()) == 2);#scalar mode, there are 2 IPS to find in testrtr
	#make sure the parser properly assigned vlans to interface fa0/6
	my $flag = 0;
	foreach my $vlan (@{$router->interface->{'FastEthernet0/6'}->{vlans}}) {$flag = 1 if $vlan eq 936}
	ok($flag);
	#make sure the parser properly created the reverse lookup for vlan 936
	$flag = 0;
	foreach my $port (@{$router->vlans->{936}->{ports}}) {$flag = 1 if $port eq 'FastEthernet0/6'}
	ok($flag);

	#suite of tests performed on testxrrtr in directory
	ok(my $xrrouter = Parsing::Router->new());
	lives_ok{$xrrouter->Parse('testxrrtr')};
	ok($xrrouter->filename eq 'testxrrtr');
	ok($xrrouter->iostype eq 'XR');
#	print encode_json($xrrouter->{config}->{top}->{'interface TenGigE0/0/0/0'}). "\n". encode_json($xrrouter->{config}->{top}->{'router isis COGENT'}). "\n";
	ok((my @xrips = $xrrouter->FindIPs()) == 2);
	ok(my $nr11test = Parsing::Router->new());
	ok($nr11test->Parse('nr11.b006523-1.bos01.atlas.cogentco.com'));


	done_testing();
}


