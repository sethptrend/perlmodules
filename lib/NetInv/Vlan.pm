#Seth Phillips
#8/14/2013

#Abstraction for the Vlans table in NetInv

use strict;
use NetInv;
package NetInv::Vlan;

sub new {
	my $proto = shift;
	my $db = shift // NetInv->new();
	my $self = {
			db => $db,
			table => undef,
		};
	bless($self, ref($proto) || $proto);
	$self->init();
	return $self;
}

sub search {
	 my $self = shift;
        my $host = shift;
        my $vlan = shift;
        my $hub = $host;
        #remove possible full qualification
        $hub =~ s/\.(atlas|hades)\.cogentco\.com//;
        #remove hostname down to just hub
        $hub =~ s/^.*\.//;
	$hub = uc $hub;
	my $rv = $self->{table}->{$hub}->{$vlan};
	return 0 unless $rv;
	return ($hub, $rv->[0], $rv->[1]);
}

sub searchSLOW {
	my $self = shift;
	my $host = shift;
	my $vlan = shift;
	my $hub = $host;
	#remove possible full qualification
	$hub =~ s/\.(atlas|hades)\.cogentco\.com//;
	#remove hostname down to just hub
	$hub =~ s/^.*\.//;
	my $rv = $self->{db}->GetRecord('netinv.vlans', 'hub_a', $hub, 'vlan', $vlan);
	return 0 unless $rv;
	return ($hub, $rv->{node_a}, $rv->{node_z});


}

sub init {
	my $self = shift;
	my $rv = $self->{db}->dbh->selectall_arrayref("SELECT * FROM netinv.vlans WHERE vlan BETWEEN 3499 AND 4100", {Slice => {}});
	foreach my $entry (@$rv){
		@{$self->{table}->{$entry->{hub_a}}{$entry->{vlan}}} = ($entry->{node_a} // '', $entry->{node_z} // '');
	}	
	return;
}

1;
