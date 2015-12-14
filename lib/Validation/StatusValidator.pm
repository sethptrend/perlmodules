#Seth Phillips
#7/31/13


#object for validating parsed status

package Validation::StatusValidator;

use strict;

use NetInv::CiscoHW;
use Parsing::Status;


sub new{
	my $proto = shift;

	my $status = shift;
	my $self = {
		status => $status,
		router => undef,
		iostype => undef,
		};
	$self->{router} = $self->{status}->router;
	$self->{iostype} =  $self->{status}->seenflags->{IOS};

	die "Passed status: $self->{status}  not a ref" unless ref($self->{status});
	bless($self, ref($proto) || $proto);
	return $self;
}
#expectIOSType takes a string which it compares
sub expectIOSType
{
	my $self = shift;
	die "No argument passed" unless @_;
	my $expected = shift;

	return "$self->{router}: ERROR-RANCID: Expecting IOS config file but appers to be $self->{iostype}\n" unless $expected eq $self->{iostype};

	return 0;


}

#checks if Image: Software matches Image: Standby Software if they both exist
sub softwareMatch
{
	my $self = shift;
	return "$self->{router}: ERROR-IMAGE: Running Active and Standby Software differ\n"
	if (exists($self->{status}->seenflags->{'Image: Software'} )
			and exists($self->{status}->seenflags->{'Image: Standby Software'} )
			and $self->{status}->seenflags->{'Image: Software'} ne $self->{status}->seenflags->{'Image: Standby Software'});
	return 0;
}


sub crash{
	my $self = shift;
	
	foreach my $dir (keys %{$self->{status}->flash}){
		foreach my $line ( @{$self->{status}->flash->{$dir}}){
			return "$self->{router}: ERROR-CRASH: Crashinfo file found at $dir:$line\n" if $line =~ /crashinfo/;
		}
	}
	return 0;
}

sub vtp{
	my $self = shift;
	return "$self->{router}: ERROR-VTP: VTP Operating Mode == Server - need to add 'vtp mode transparent'\n" 
		if ($self->{status}->seenflags->{'VTP: VTP Operating Mode'} eq 'Server' and !($self->{status}->chassis =~ /28\d\d/));
	return 0;
}

sub mtu{
	my $self = shift;
	foreach my $intf (keys %{$self->{status}->intipmtu}){
		return "$self->{router}: ERROR-MTU: IPMTU for $intf is ".$self->{status}->intipmtu->{$intf}." < 1500 minimum\n"
			if  $self->{status}->intipmtu->{$intf} < 1500;
	}
	return 0;
}

1;
