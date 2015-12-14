#seth Phillips
#7/31/13

package Parsing::Router;
use strict;

use ParseCisco;
use Parsing::Status;
use Parsing::Config;
use JSON;


sub new{
	my $proto = shift;
	my $self = {
		parsecisco => undef,
		status => undef,
		config => undef,
		filename => undef,
		interface => {},
		vlans => {},
		};
	bless($self, ref($proto) || $proto);
	return $self;
}

sub Parse {
	my $self = shift;
	$self->{filename} = shift;
	#ParseCisco requires main::debug, kind of abstracting this
	#our $main::debug = 0;
	$self->{parsecisco} = ParseCisco->new($self->{filename});

	die "ParseCisco failed - File: $self->{filename}\n" unless defined($self->{parsecisco});

	$self->{status} = Parsing::Status->new();
	$self->{config} = Parsing::Config->new();



	my $ln;
	my @config = @{$self->{parsecisco}->parsedconfig};

	die "Router file $self->{filename} was empty" unless scalar(@config);

	while(@config)
	{
		my $ln = shift @config;

		die "Parsed config was raw (wtf)" unless defined($ln);

		die "Ended up with ". encode_json($ln)." when string expected" if ref($ln); 
		
		study $ln;
		($self->{status}->ParseLine($ln) and next) if $ln =~ /^\!/;
		$self->{config}->ParseLine($ln, \@config) and next;

		die "Some unparsable line $ln\n" unless $ln =~ /^\!$/;
	}
	#grab hostname from Config and give it to Status
	$self->{status}->router($self->{config}->{router});

	#config parsing section for interfaces
	foreach my $int (keys %{$self->{config}->{interfaces}}){
		my @vlans;
		@vlans = $self->{config}->GetPortVlans($int);
		if(@vlans) {
		#	 $self->{interface}->{$int} = {};
		#	$self->{interface}->{$int}->{vlans} = [];
			@{$self->{interface}->{$int}->{vlans}} = @vlans;
			foreach my $vlan (@vlans){
				push @{$self->vlans->{$vlan}->{ports}}, $int}
			
		}
		
		

	}

	return 1;
}
	
sub filename{
	my $self = shift;
	return $self->{filename};
}

sub iostype{
	my $self = shift;
	return $self->{parsecisco}->iostype;
}

sub rawconfig{
	my $self = shift;
	return $self->{parsecisco}->rawconfig;
}

sub status{
	my $self = shift;
	return $self->{status};
}

sub config{
	my $self = shift;
	return $self->{config};
}
sub interface{
	my $self = shift;
	return $self->{interface};
}
sub vlans{
	my $self = shift;
	return $self->{vlans};
}
	
sub FindIPs{
	my $self = shift;
	my @ret;
	foreach my $line (keys %{$self->{config}->top})
	{
		next unless $line =~ /^interface (Loopback|Vlan)/;
		next unless ref($self->{config}->top->{$line});
		my @def = @{$self->{config}->top->{$line}};
		foreach my $defline (@def) {
			next unless $defline =~ /ip(v4)? address (\S+ \S+)/;
			push @ret, $2;}
	}
	
	return @ret;
}

sub FindVLANs{
	my $self = shift;
	my @ret;
	foreach my $line (keys %{$self->{config}->top})
        {
		next unless $line =~ /^interface (Vlan\d\d\d\d)/;
		push @ret, $1;
	}
	
	return @ret;
}



1;
