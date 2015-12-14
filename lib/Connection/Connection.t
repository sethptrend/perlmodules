#!/usr/bin/perl



use strict;
use lib '../';#i'm 1 folder deep from lib for this class
use Test::More;
use Test::Exception;
use DBI;


BEGIN{
	print "Installed database drivers: " . join(/,/,DBI->installed_versions) . "\n";
	#danadev tests
        #use_ok('Connection::DanaDev');
        #ok(my $danadb = Connection::DanaDev->new());
	#ok($danadb->getpopcode( 'abc01') eq '11306');
	#ok($danadb->getcountrycode('dca01') eq '174:22013');
	#ok($danadb->getcustcomm('dca01') eq '21001');
	#ok($danadb->getpeercomm('dca01') eq '21000');

	use_ok('Connection::StarfishTest');
	ok(my $sftestdb = Connection::StarfishTest->new());


	use_ok('Connection::TLG');
	#global id related functions
	ok(my $tlgdb = Connection::TLG->new());
	ok( $tlgdb->getLogoIDbyOrder('1-110629655')=~ /G1QNGMK/);
	ok( $tlgdb->getCustLogobyOrder('1-110629655'));
	#1 ctc related functions
	ok(ref($tlgdb->getInProgressOrders));#function returns array reference
	ok($tlgdb->getMacOrderListbyOrderID('1-89165165'));#subject to change with tables
	ok($tlgdb->pairMatches('1-136794704','1-132349253'));#needed an example


	use_ok('Connection::Reporting');
	ok(my $reportingdb = Connection::Reporting->new());
	ok($reportingdb->getCustLogobyOrder('1-110629655'));

	#netinv function tests
	use_ok('Connection::Netinv');
	ok(my $netinv = Connection::Netinv->new());
	ok(my $testref = $netinv->GetNetflowVars('28'));
	ok($testref->{hostname});
	#appsdbdev tests
	use_ok('Connection::StarfishTest');
	ok(my $devdb = Connection::StarfishTest->new());
	can_ok($devdb, qw(metacheckclear metachecklog));
	#dca05 tests
	use_ok('Connection::Starfish');
	ok(my $starfishdb = Connection::Starfish->new());
	ok(my ($ipv4, $ipv6) = $starfishdb->GetRouterLoopback0('rcr21.b038092-0.ams03.atlas.cogentco'));
	ok($ipv4 eq '38.28.1.6');
	ok($ipv6 eq '2001:550:0:1000::261c:106');
	can_ok($starfishdb, qw(metacheckclear metachecklog));

	#Aarondev tests
	use_ok('Connection::Aarondev');
	ok(my $aarondb = Connection::Aarondev->new());
	ok($aarondb->GetHighestBundleCore > 2500);

	use_ok('Connection::DanaDev');
	ok(my $danadb = Connection::DanaDev->new());
	ok( $danadb->getCommunityByHub('ABC'));
        done_testing;
}

1;
