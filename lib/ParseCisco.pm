# $HeadURL: svn://hhcv-srcctrl.sys.cogentco.com/cogent/rtrtools/trunk/lib/ParseCisco.pm $
# $Id $

package ParseCisco;

use Data::Dumper;
use IO::File;
use English;
use strict;
use warnings;

use MarkUtil;

our $modname = 'ParseCisco';



######################################################################
#
#
sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {
	fname         => undef,         # Config file name
	fh            => new IO::File,  # File Handle 
	rawconfig     => [],
	parsedconfig  => [],
	iostype       => undef,
	debug         => $main::debug // 0,
    };

    bless($self,$class);

    my $fn = shift;

    if (defined($fn)) {
	$self->fname($fn);
	if ($self->ReadConfig) {
	    return $self;
	} else {
	    return undef;
	}
    } else {
	return $self;
    }

}

######################################################################
sub fname {
    my $self = shift;
    if (@_) { 
	my $fn = shift;
	if (-e $fn) {  # only change if file exists
	    $self->{fname} = $fn; 
	} else {
	    &DebugPR(3,"$modname-fname: File not found\n");
	    $self->{fname} = undef; 
	}
    }
    return $self->{fname};
}

######################################################################
sub rawconfig {
    my $self = shift;
    if (@_) { $self->{rawconfig} = shift; }
    return $self->{rawconfig};
}
######################################################################
sub parsedconfig {
    my $self = shift;
    if (@_) { $self->{parsedconfig} = shift; }
    return $self->{parsedconfig};
}
######################################################################
sub iostype {
    my $self = shift;
    if (@_) { $self->{iostype} = shift; }
    return $self->{iostype};
}
######################################################################
sub ReadConfig {
    my $self = shift;

    &DebugPR(3,"$modname-ReadConfig\n");

    return(0) if !defined($self->fname);

    if ($self->{fh}->open("< " . $self->fname)) {
	my $ln;

	&DebugPR(3,"$modname-ReadConfig: Reading file\n");

	my @sectconfig = ();
	my $subsec = undef;
	my $depth = undef; # Track amount of whitespace when it's found
	my $iscomplex = 0; # Track if whitespace changes

	while ($ln=$self->{fh}->getline) {
	    chomp($ln);
	    $ln =~ s/\s+$//;  # Remove Trailing Whitespace
	    &DebugPR(4,"$modname-ReadConfig: Stuffing config - '$ln'\n");
	    push(@{$self->rawconfig},$ln);
	    if ($ln =~ /^\!IOS:\s+(\S+)/) {
		$self->iostype($1);
	    }

	    # save some time and start doing the sectional config here.

	    if ($ln =~ /^(\s+)\S+/) {
		if (!defined($subsec)) { # first time we've seen whitespace.
		    $subsec = [];
		    $depth = $1;
		    $iscomplex = 0;
		}
		push(@{$subsec},$ln);
		
		if ($1 ne $depth) {
		    $iscomplex = 1;
		}
		next;
	    }

	    if (defined($subsec)) { # whitespace region ended
		if ($iscomplex) { # needs futher parsing
		    $subsec = $self->ParseSub($subsec);
		} else { # just one level of whitespace, remove it
		    my $c = scalar(@{$subsec});
		    while ($c) {
			$subsec->[$c-1] =~ s/^$depth//;
			$c--;
		    }
		}
		push(@sectconfig,$subsec);
		$subsec = undef;
		$depth = undef;
	    }
	    push(@sectconfig,$ln);

	}
	$self->{fh}->close;

	$self->parsedconfig(\@sectconfig);

	return(1);
    } else {
	&DebugPR(3,"$modname-ReadConfig: Failed to open" . $self->fname . "\n") if $self->{debug} > 3;
	return(0);
    }
}
######################################################################
sub ParseSub {
    my $self = shift;
    my $confptr = shift;
    my $depth = shift // '';
    my $level = shift // 0;
    my $rv = [];

    my $tracker = 0; # for debugging
    if ($depth eq '') {
	&DebugPR(4,"Parsing " . Dumper ($confptr)) if $self->{debug} > 4;
	$tracker = 1;
    }

    my $ln; 

    my $lastlevel = $level;

    &DebugPR(4,"$modname-ParseSub - level $level - Depth '$depth'\n");

    while ($ln = shift(@{$confptr})) {
	&DebugPR(5,"$modname-ParseSub - Processing '$ln'\n");
	
	$ln =~ /^(\s+)\S+/;  # starting whitespace

	if ($depth eq '') {
	    $depth = $1;
	}

	my $founddepth = $1;

	my $curlevel = (length($founddepth)-length($depth));
	&DebugPR(6,"$modname-ParseSub - curlevel = $curlevel\n");

	if ($curlevel == 0) { # same level, just push it on
	    $ln =~ s/^$depth//;  # remove whitespace
	    &DebugPR(6,"$modname-ParseSub - Same level, cleaning '$ln'\n");
	} elsif ($curlevel > 0) { 
            # deeper than original caller
	    # call ourselves again to create a pointer to 
	    # an array of stuff deeper

	    &DebugPR(6,"$modname-ParseSub - Going deeper\n");
	    unshift(@{$confptr},$ln);
	    $ln = $self->ParseSub($confptr,$founddepth,$curlevel);

	    if ($curlevel < $lastlevel) { 
		unshift(@{$ln},pop(@{$rv}));
	    }
	} elsif ($curlevel < 0) {
	    # Shallower than when we started

	    if ($level) { # we're in a recursion, back up
		&DebugPR(6,"$modname-ParseSub - Backing up\n");
		unshift(@{$confptr},$ln);
		&DebugPR(7,"$modname-ParseSub - Backup rv\n" . Dumper($rv)) if $self->{debug} > 7;
		return($rv);
	    } else { # we're at the top level 
		&DebugPR(6,"$modname-ParseSub - Shallower than when we entered\n");
		# we're shallower than the level we entered... in the first
		# place, so we need to 'back up' the depth to where 
		# we are now and put what was in rv inside this new level
		# (stupid cisco nonsense)
		# and start again.
		my $rv2 = [];
		push(@{$rv2},$rv);
		$depth = $founddepth;
		$rv=$rv2;
		$ln =~ s/^$depth//;  
		&DebugPR(7,"$modname-ParseSub - Shallower rv\n " . Dumper($rv)) if $self->{debug} > 7;
	    }

	}

	&DebugPR(6,"$modname-ParseSub - Pushing\n" . Dumper($ln)) if $self->{debug} > 6;
	push(@{$rv},$ln);

	$lastlevel = $curlevel;

	&DebugPR(7,"$modname-ParseSub - current rv\n" . Dumper($rv)) if $self->{debug} > 7;

    } # while loop

    &DebugPR(5,"$modname-ParseSub - Returning - '$depth'\n");

    if ($tracker) {
	&DebugPR(4,"Returning " . Dumper ($rv)) if $self->{debug} > 4;
    }
    return($rv);
}
######################################################################
sub PPush {
    my $self = shift;
    my $v = shift;

    push(@{$self->parsedconfig},$v);
}
######################################################################
sub PPop {
    my $self = shift;

    return(pop(@{$self->parsedconfig}));
}
######################################################################
sub PShift {
    my $self = shift;

    return(shift(@{$self->parsedconfig}));
}
######################################################################
sub PUnshift {
    my $self = shift;
    my $v = shift;

    unshift(@{$self->parsedconfig},$v);
}


1;
