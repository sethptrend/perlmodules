#!/usr/bin/perl

#Seth Phillips
#7/31/13


use strict;
use lib '../';
use Test::More;
use Test::Exception;
use Parsing::Router;
use Parsing::Status;

BEGIN{
	use_ok('Validation::StatusValidator');
	my $router = Parsing::Router->new() ;
	$router->Parse('testrtr') ;
	ok(ref($router->status));
	$router->status->router('testrtr');
	#tightly pairing validator with a status
	ok(my $validator = Validation::StatusValidator->new($router->status()));

	ok($validator->expectIOSType('IOS') == 0);
	ok($validator->expectIOSType('XR')=~ /ERROR\-RANCID/);
	#most of the below pass for the testrtr file, will have to come back and find some fail examples
	ok($validator->softwareMatch == 0);
	ok($validator->crash == 0);
	ok($validator->vtp == 0);
	ok($validator->mtu == 0);


	my $router2 = Parsing::Router->new();
	$router2->Parse('testxrrtr');
	ok(ref($router2->status));
	$router2->status->router('testxrrtr');
	ok(my $validator2 = Validation::StatusValidator->new($router2->status()));
	ok($validator2->expectIOSType('XR') == 0);
	ok($validator2->expectIOSType('IOS') =~ /ERROR\-RANCID/);
	ok($validator2->softwareMatch == 0);
	ok($validator2->crash == 0);
	ok($validator2->vtp == 0);
	ok($validator2->mtu == 0);

	done_testing();
}
