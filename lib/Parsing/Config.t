#!/usr/bin/perl
#Seth Phillips
#7/30/13
use strict;
use lib '../';#i'm 1 folder deep from lib for this class
use Test::More;
use Test::Exception;


BEGIN{
	#creation
	use_ok('Parsing::Config');
	ok(my $config = Parsing::Config->new());

	#decided to go very minimal here: ie. limit to just parsing

	#top level commands should be stored with value 1 in the top hash
	$config->ParseLine('access-list 2000 permit tcp 66.28.64.0 0.0.3.255 any eq telnet', ['some next line']);
	ok($config->top->{'access-list 2000 permit tcp 66.28.64.0 0.0.3.255 any eq telnet'});


	#multi level commands should be stored with a reference to the internal array in the top has
	$config->ParseLine('interface Vlan1', [['no ip address', 'switchport trunk allowed vlan 1194,1268,1410,1411-1414,2024,2030,2048,2054', 'shutdown'], 'some other line']);
	ok(ref($config->top->{'interface Vlan1'}));
	ok(exists($config->interfaces->{'Vlan1'}));
	#GetPortVlans takes an interface name and returns all vlans associated with it
	ok(my @vlan1vlans = $config->GetPortVlans('Vlan1'));	
	my $flag = 0;
	foreach my $vlan (@vlan1vlans) {$flag = 1 if $vlan eq 1412}
	ok($flag);

	
	#the banner should be stored in banner with a reference to the internal array of banner text
	$config->ParseLine('banner motd ^C', ['Cogent Communications     (na01.b001157-0.jfk02.atlas.cogentco.com)', 'Unauthorized Access is Prohibited', '', 'Quote goes here.', '^C', 'more random line']);
	ok(ref($config->{banner}));

	done_testing();
}

