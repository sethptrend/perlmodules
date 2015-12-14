# $HeadURL: svn://hhcv-srcctrl.sys.cogentco.com/cogent/rtrtools/trunk/lib/BGPPeer/AFI.pm $
# $Id: AFI.pm 305 2009-11-05 16:59:49Z marks $

package BGPPeer::AFI;

use Data::Dumper;
use IO::File;
use English;
use POSIX;
use strict;
use warnings;

use Cogent::Desc;
use MarkUtil;

our $modname = 'BGPPeer';

our %cogentas = (
		 "174"   => 1,
		 "16631" => 1,
		 "2649"  => 1,
		 "4006"  => 1
		 );

######################################################################
#
# 
#
sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {
	addrfam        => undef,     # Address family active on this peer
	peerpolicy     => 0,
	activate       => 0,     
	maxprefix      => 0,
	prefixlist     => {},    
	routemap       => {},    
	distributelist => {},    # Access lists
	filterlist     => {},    # AS Path filter
    };

    bless($self,$class);

     return $self;

}
######################################################################
sub addrfam {
    my $self = shift;
    if (@_) { $self->{addrfam} = shift; }
    return $self->{addrfam};
}
######################################################################
sub peerpolicy {
    my $self = shift;
    if (@_) { $self->{peerpolicy} = shift; }
    return $self->{peerpolicy};
}
######################################################################
sub activate {
    my $self = shift;
    if (@_) { $self->{activate} = shift; }
    return $self->{activate};
}
######################################################################
sub maxprefix {
    my $self = shift;
    if (@_) { $self->{maxprefix} = shift; }
    return $self->{maxprefix};
}
######################################################################
sub prefixlist {
    my $self = shift;
    my @opts = @_;
    if (@opts) { 
	my $key = shift(@opts);
	my $hptr = $self->prefixlist;
	if (@opts) { 
	    $hptr->{$key} = shift(@opts);
	} else {
	    if (exists($hptr->{$key})) { 
		return $hptr->{$key}; 
	    } else {
		return undef;
	    }
	}
    }
    return $self->{prefixlist};
}
######################################################################
sub routemap {
    my $self = shift;
    my @opts = @_;

    if (@opts) { 
	my $key = shift(@opts);
	my $hptr = $self->routemap;
	if (@opts) { 
	    $hptr->{$key} = shift(@opts);
	} else {
	    if (exists($hptr->{$key})) { 
		return ($hptr->{$key}); 
	    } else {
		return undef;
	    }
	}
    }
    return $self->{routemap};
}
######################################################################
sub distributelist {
    my $self = shift;
    my @opts = @_;
    if (@opts) { 
	my $key = shift(@opts);
	my $hptr = $self->distributelist;
	if (@opts) { 
	    $hptr->{$key} = shift(@opts);
	} else {
	    if (exists($hptr->{$key})) { 
		return $hptr->{$key}; 
	    } else {
		return undef;
	    }

	}
    }
    return $self->{distributelist};
}
######################################################################
sub filterlist {
    my $self = shift;
    my @opts = @_;
    if (@opts) { 
	my $key = shift(@opts);
	my $hptr = $self->filterlist;
	if (@opts) { 
	    $hptr->{$key} = shift(@opts);
	} else {
	    if (exists($hptr->{$key})) { 
		return $hptr->{$key}; 
	    } else {
		return undef;
	    }
	}
    }
    return $self->{filterlist};
}

######################################################################
sub dump {
    my $self = shift;
    my $str = '';

    $str = "Dumping BGPPeer  ";
    $str .= Data::Dumper->Dump([$self],[qw(*self)]);
    
    if (@_) { 
	print $str;
    }
    return($str);
}


1;
