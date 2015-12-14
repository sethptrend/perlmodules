#Seth Phillips
#7/29/13
#Status object for parsing
#Status.t house the unit tests for this module

package Parsing::Status;

use strict;

use NetInv::CiscoHW;



sub new{
	my $proto = shift;
	my $self = {
		contenttype => undef,
		chassis => undef,
		hw => NetInv::CiscoHW->new(),
		seenflags => {},
		instatus => {},
		intipmtu => {},
		flash => {},
		router => undef,
	};
	bless($self, ref($proto) || $proto);
	return $self;
}

sub ParseLine {
	my ($self, $ln) = @_;

	study $ln;

	die "Line does not start with !: $ln\n" unless $ln =~ /^\!/;


	#ideally the order below doesn't matter until the catch-alls


	if ($ln =~ /^\!Flash: (\S+):\s+(.*)/) {
		my $dir = $1;
		my $line = $2;
		return 1 if $line =~ /Directory of $dir/;
		push(@{$self->{flash}{$dir}}, $line);
		return 1;
	}

	
	if($ln =~ /^\!RANCID-CONTENT-TYPE:\s+(\S+)/) {
		$self->{contenttype} = $1;
		return 1;
	}


	if ($ln =~ /^\!Chassis type:\s+(.*)/) {
                $self->{chassis}=$1;
                my($ch,$ty) = split(/\s+-\s+/,$self->{chassis});
                if (defined($ch)) {
                    $self->{hw}->chassis($ch);
                    $self->{chassis} = $ch;
                } else {
                    $self->{hw}->chassis($self->{chassis});
                }
                if (defined($ty)) {
                    $ty =~ s/^a //;
                    $self->{hw}->chassisclass($ty);
                } else {
                    $self->{hw}->chassisclass($ch);
                }

                return 1;
         }
	
	if ($ln =~ /^\!CPU:\s+(\S.+)/) {
                my $cpu = $1;
                next if ($cpu =~ /Slave/);

                if ($self->{hw}->chassisclass =~ /6500/ ||
                    $self->{hw}->chassisclass =~ /7600/) {
                    if ($cpu =~ /R7000, SR71000/) {
                        $cpu="SUP720";
                    } elsif ($cpu =~ /M8500/) {
                        $cpu="RSP720";
                    } elsif ($cpu =~ /R7000, R7000/) {
                        $cpu="SUP2";
                    } elsif ($cpu =~ /R5000, R5000/) {
                        $cpu="SUP1A";
                    }
                } elsif ($self->{hw}->chassisclass =~ /7200/) {
                    if ($cpu =~ /NPE-G2/) {
                        $cpu="NPE-G2";
                    } elsif ($ln =~ /(NPE\d\d\d)/) {
                        $cpu=$1;
                    }
                } elsif ($self->{hw}->chassisclass =~ /12000/) {
                    if ($cpu =~ /R5000/) {
                        $cpu="GRP";
                    } elsif ($cpu =~ /MPC7457/) {
                        $cpu="PRP2";
                    }
                } elsif ($self->{hw}->chassisclass =~ /2600/ ) {
                    $cpu = "MPC860";
                }

                $self->{hw}->rp($cpu);
                return 1;
            }



	if ($ln =~ /^\!Image: Compiled: (.*)/) {
                $self->{seenflags}->{'Compiled'} = $1;
                return 1;
            }
	if ($ln =~ /^\!INT: (\S+)\s+(\S+.*)/) { # Process interface status
                $self->{intstatus}->{$1} = $2;
                return 1;
            }
	if ($ln =~ /^\!INT-IPMTU: (\S+)\s+(\d+)/) {
		$self->{intipmtu}->{$1} = $2;
		return 1;
	    }























	####catch - alls


	#really generic version of seenflags grabber - might get rid of more of the above
	if ($ln =~ s/^\!(.*): //) {
		my $prop = $1;
		$prop =~ s/\s+$//;#trailing whitespace in property name - makes tables pretty and data structures ugly
		$self->{seenflags}{$prop} = $ln;
		return 1;
	}







	if($ln =~ /^!/){return 1;}



	return 0; #zero if it skips all filters
}


sub contenttype {
	my $self = shift;
	if(@_) { $self->{contenttype} = shift;}
	return $self->{contenttype};
}

sub chassis {
	my $self = shift;
	if(@_) {$self->{chassis} = shift;}
	return $self->{chassis};
}

sub hw {
        my $self = shift;
        if(@_) { $self->{hw} = shift;}
        return $self->{hw};
}

sub seenflags {
	my $self = shift;
	return $self->{seenflags};
}

sub intstatus {
	my $self = shift;
	return $self->{intstatus};
}

sub intipmtu {
	my $self = shift;
	return $self->{intipmtu};
}

sub flash {
	my $self = shift;
	return $self->{flash};
}

sub router {
	my $self = shift;
	$self->{router} = shift if @_;
	return $self->{router};
}



1;

