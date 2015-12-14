#Seth Phillips
#7/30/13
#Config object for parsing
#Config.t houses the unit tests for this module

package Parsing::Config;

use strict;

sub new{
	my $proto = shift;
	my $self = {
	      top => {},
	      banner => [],
	      interfaces => {},
	      router => undef,
	};
	bless($self, ref($proto) || $proto);
	return $self;
}


sub ParseLine {
	my $self = shift;
	my $line = shift;
	my $aptr = shift;#array pointer


	die "Array pointer wasn't an array pointer" unless ref($aptr);

	
	return 0 if $line =~ /^\!/; #don't care about comment or status lines
	
	if($line =~/^banner (\S+) (\^)(.+)?/) {
		my $extra = $3;
		push @{$self->{banner}}, $line;
		return 1 if $extra =~ /\^/;
		my $go = 1;
		while($go and @{$aptr}){
			$line = shift(@{$aptr});
			if (ref($line)) {
				my @internal = @{$line};#not this is bad if there's more nesting in a banner than 1 level
				foreach (@internal) { 
					$go = 0 if /\^/;
					push @{$self->{banner}}, $_;
				}
			}	else {
				$go = 0 if $line =~ /\^/;
                                        push @{$self->{banner}}, $line;
			}
		}
		die "Banner Runaway" if $go;
		return 1;
	}
	if($line =~/^interface ([^\.]*)\.?(\d*)$/)
	{
		if($2)
		{
			$self->{interfaces}->{$1} = [] unless ref($self->{interfaces}->{$1});
			push  @{$self->{interfaces}->{$1}}, $2;
		}
		else{
		$self->interfaces->{$1} = $1;}
		#no return, just recording information
	} elsif($line =~ /^hostname (\S+)$/){ $self->{router} = $1} #no return just recording
	

	if (ref(${$aptr}[0])) {
		unless(defined($self->{top}->{$line})){
			$self->{top}->{$line} = shift @$aptr;
		} else {
			#push @{shift @$aptr}, @$self->{top}->{$line};
		}

		return 1;
	}
			


	$self->{top}->{$line} = 1;



return 1;


}

	

sub top{
	my $self = shift;
	return $self->{top};
}

sub banner{
	my $self = shift;
	return $self->{banner};
}
sub interfaces{
	my $self = shift;
	return $self->{interfaces};
}

sub GetPortVlans{
	my $self = shift;
	my $port = shift;
	my @retval;
	
	return 0 unless exists $self->interfaces->{$port};
	
	if(ref($self->interfaces->{$port})){
	#do one thing for ports with subinterfaces
	foreach my $vlan (@{$self->interfaces->{$port}}){push @retval, $vlan}
	}
	else{
	#handle ports without subints
	my @lines;
	 @lines = @{$self->top->{"interface $port"}} if ref($self->top->{"interface $port"});
	foreach my $line (@lines){
		if($line =~ /switchport.*access vlan (\d+)/){ push @retval, $1}
		elsif($line =~ /switchport trunk allowed vlan (.*)/){

			$line = $1;
			$line =~ s/add //;
			my @list = split(/,/, $line);
			foreach my $item (@list)
			{
				if($item =~/-/){
					 	$item =~ /(\d+)-(\d+)/;
						foreach my $subitem ($1 .. $2) {push @retval, $subitem}
				
					}
				else { push @retval, $item}
			}
		
			

		}
	}
	}
	
	return @retval;


}


1;
