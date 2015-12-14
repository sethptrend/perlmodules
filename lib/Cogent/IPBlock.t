#!/usr/bin/perl

#unit tests for functionally drawn from IP blocks table in Starfish (on cyclops)
use lib '../';

use Test::More;
use Cogent::DNS;


BEGIN
{
use_ok(Cogent::IPBlock);#Put it under cogent because it's using the dca05 DB
#want to overload new to take either nothing -> grab it's own db ref or take a db ref to use
ok(my $ipblock = Cogent::IPBlock->new());
my $dns = Cogent::DNS->new();
ok(my $ipblock2 = Cogent::IPBlock->new($dns));
#could add some dies testing functionality later, but that's not something that is likely to ever be coded wrong and still pass other tests
#this retrival is keying on an IP address
ok(my $ipref = $ipblock->getIP('10.27.63.2'));
ok($ipref->{user} =~ /gmalette/);






done_testing();
}
