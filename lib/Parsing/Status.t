#!/usr/bin/perl
#Seth Phillips
#7/29/13
#7/30 - perhaps completely finished with this
use strict;
use lib '../';#i'm 1 folder deep from lib for this class
use Test::More;
use Test::Exception;


BEGIN{
	use_ok('Parsing::Status');
	ok(my $status = Parsing::Status->new());


	#parse status line testing
	dies_ok{$status->ParseLine('this line is does not start with !')};
	lives_ok{$status->ParseLine('!Image:     disk0:asr9k-px-4.2.3.CSCud37351-1.0.0')};
	ok($status->ParseLine('!RANCID-CONTENT-TYPE: cisco') and $status->contenttype eq 'cisco');
	ok($status->ParseLine('!Chassis type: WS-C3550-24 - a 3550 switch') and $status->chassis eq 'WS-C3550-24');
	ok($status->ParseLine('!CPU: PowerPC') and $status->hw->rp eq 'PowerPC');
	ok($status->ParseLine('!Image: Software: C3550-IPSERVICESK9-M, 12.2(35)SE3, RELEASE SOFTWARE (fc1)') and $status->seenflags->{'Image: Software'} eq 'C3550-IPSERVICESK9-M, 12.2(35)SE3, RELEASE SOFTWARE (fc1)');
	ok($status->ParseLine('!Image: Compiled: Fri 16-Mar-07 00:43 by antonino') and $status->seenflags->{Compiled} eq 'Fri 16-Mar-07 00:43 by antonino');
	ok($status->ParseLine('!Image: flash:/c3550-ipservicesk9-mz.122-35.SE3.bin') and $status->seenflags->{Image} eq 'flash:/c3550-ipservicesk9-mz.122-35.SE3.bin');#test is more based on an !Image that falls through the other things, this could easily end up being overwritten  presumably
	ok($status->ParseLine('!MTU: 1546') and $status->seenflags->{MTU} eq '1546');
	#the generalized form is that ^blah:[space] where : is the LAST : goes to seenflags->{blah}
	ok($status->ParseLine('!SDM Template: default') and $status->seenflags->{'SDM Template'} eq 'default');
	ok($status->ParseLine('!INT: Vlan1                        admin-down  down        1546   -     -      -       -') and $status->intstatus->{'Vlan1'} =~ /admin\-down\s+down/);
	ok($status->ParseLine('!INT-IPMTU: FastEthernet0/1              1500') and $status->intipmtu->{'FastEthernet0/1'} eq '1500');
	#going to want a new hash for Flash, lets call it flash with fields like status->flash->{dirname}->[arrayindex]
	ok($status->ParseLine('!Flash: zflash:     3  -rwx       36484  Jul 17 2013 04:15:50 +00:00  config.text') and $status->flash->{zflash}[0] =~ /config\.text/);

	ok($status->router('test') eq 'test');

	done_testing();
}

