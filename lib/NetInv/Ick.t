#!/usr/bin/perl

use lib '../';
use NetInv;
use Test::More;


BEGIN
{
use_ok(NetInv::Ick);
#all old code uses new with no db passing, make sure it's overloaded acceptably
ok(my $oldnew = NetInv::Ick->new());
#all new additions are for accessing information about icks from databases
ok(my $ick = NetInv::Ick->new(NetInv->new()));
#function to return a list of IP adresses associated with an ick id
ok(my @ips = $ick->getIPs('018416'));
#make sure an ip that i found was actually returned in the list
my $flag = 0;
 foreach my $ip (@ips){$flag= 1 if $ip eq '154.54.0.126'}
ok (  $flag);







done_testing();
}
