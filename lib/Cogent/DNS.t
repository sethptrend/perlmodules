#!/usr/bin/perl

#Seth Phillips
#8/5/13
#some unit tests for Cogent::DNS functions I've used
#if you change Cogent::DNS and break this test, you WILL LIKELY BREAK my stuff

use strict;
use lib '../';#i'm 1 folder deep from lib for this class
use Test::More;
use Test::Exception;


BEGIN{
	use_ok('Cogent::DNS');
	ok(my $dns = Cogent::DNS->new());
	ok(my $rv = $dns->GetRecord('[Dynamo].[dbo].[zone]', 'name', "jfk01\.hades\.cogentco%"));
	ok($rv->{zone_id});
	ok( $rv = $dns->GetRecord('[Dynamo].[dbo].[zone]', 'name', "jfk01\.atlas\.cogentco%"));
	ok($rv->{zone_id});
	ok(my $row = $dns->GetRecord('[Dynamo].[dbo].[rrecord]', 'name', "\%na01.b005558-0"));
	ok( $row->{name});
	#double checking write access to Starfish db
#	ok($dns->DoSQL("UPDATE [Starfish].[AdminSF].[ip_block] SET [descr]=\'test\' WHERE [netaddr] like \'%0a00:1000\'"));
	
	#Getting dynamo entries by IP address takes IP, returns a reference to the zone record and a reference to the rrecord (hashes) - some usage in the tests below
	ok(my ($zoneref, $rrecordref) = $dns->GetZoneByIP('66.28.1.33'));
	ok($rrecordref->{name} eq 'lo0.mag01');
	ok($zoneref->{name} =~ /jfk01/);
	
	#added a function for hostchange cross zones, CrossZoneHostchange(oldname, newname) out: array of sql commands

	#function to get the pool an IP came from
	my $test = $dns->PoolLookupIPv4("66.28.1.9");
	ok('AEAS' eq $test);
	#0000:0000:0000:0000:0000:0000:0A18:2600 = 10.24.38.0
	ok('AEAI' eq $dns->Pool30LookupIPv4('10.24.38.0'));

	done_testing;
}
