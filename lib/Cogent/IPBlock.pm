#Seth Phillips
#8/30/13

use lib '/local/scripts/lib/';
use strict;
use Cogent::DNS;
use Net::IP;
package Cogent::IPBlock;

sub new {
	my $proto = shift;
	my $self = {
		dbh => shift // undef,
		};
	$self->{dbh} = Cogent::DNS->new() unless defined($self->{dbh});
	return undef unless defined($self->{dbh});
	bless($self, ref($proto) || $proto);
	return $self;
}


sub getIP {
	my $self = shift;
	my $ip = shift // undef;
	my $ret=0;
	die "No ip address passed\n" unless defined($ip);
	my $flag = 0;
	my $mask = 0;
	until ($flag || $mask > 8){
		my $trymask = 255 - 2**$mask + 1;
		my @addr = split /\./, $ip;#breako into parts
		$addr[3] = ($addr[3]*1 & $trymask);
		#print  join ('.', @addr) . "\n";
		my $netip = new Net::IP( join ('.', @addr));
		my $hexip = $netip->hexip();
		$hexip =~ s/0x(.?.?..)(....)/$1:$2/;
		while (length($hexip) < 9) {$hexip = "0" . $hexip};
		$hexip = "0000:0000:0000:0000:0000:0000:" . $hexip;
		#print "$hexip\n";
		if ($ret = $self->{dbh}->GetRecord('[Starfish].[AdminSF].[ip_block]', '[netaddr]',$hexip )) {$flag = 1}
		$mask++;
	}
	

	return $ret;
		



	}









1;
