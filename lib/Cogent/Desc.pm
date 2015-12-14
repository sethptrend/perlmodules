# $HeadURL: svn://hhcv-srcctrl.sys.cogentco.com/cogent/rtrtools/trunk/lib/Cogent/Desc.pm $
# $Id: Desc.pm 2599 2015-06-26 16:57:50Z sphillips $

package Cogent::Desc;

use Data::Dumper;
use IO::File;
use English;
use POSIX;
use strict;
use warnings;
use RRDs;

use MarkUtil;

my @fields = (
	'descr',
	'valid',
	'category',
	'peertype',
	'facility',
	'nodeid',
	'virtual',
	'vc',
	'bandwidth',
	'company',
	'orderno',
	'shaul',
	'ckid',
	'pon',
	're',
	'tik',
	'cir',
	'cap',
	'l2tp',
	'icb',
	'dnlk',
	'bkup',
	'tohost',
        'ick',
        'bid',
	'misc',
	'prov',
	'rvw',      
	'nmp',
	'target');

######################################################################
#
sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {
	descr     => "unk",
	valid     => 0,     # Is description valid by standards
	category  => "unk", # CORE, METRO, TRANSIT, CUST-R, etc
	peertype  => "unk", # PUBLIC | PRIVATE
	facility  => "unk", # E|FE|GIGE|OCx|DSx
	nodeid    => "unk", # Node ID
	virtual   => 0,     # VLAN | PVC 
	vc        => "unk", # VLAN id | Frame Relay DLCI | ATM vpi/vci
	bandwidth => 0,     # Subrate info in K|M
	company   => "unk", # Value in ^   ^
	orderno   => "UNK", # ID:<order_number>
	shaul     => "unk", # (<short_haul_hostname>)
	ckid      => "unk", # CKID:<circuit_id>
	pon       => "unk", # PON:<act_pon> 
	re        => "unk", # RE:<order> 
	tik       => "unk", # TIK:<Ticket#> 
	bid       => "unk", # BID:<bundle#> 
	cir       => 0,     # CIR:<Commited Rate> 
	cap       => 0,     # CAP:<Rate Limit> 
	l2tp      => 0,     # L2TP - Tunnel interface - Default's to 0
	icb       => 0,     # ICB - Default's to 0
	dnlk      => 0,     # Downlink to other node boxes
	bkup      => 0,     # Backup path or tunnel only pipe
	tohost    => "unk", # to <hostname>|hub-hub|FRAMEHOST
	ick       => 0,     # ICK:###### Cogent Internal Circuit 
	nmp       => 0,     # NMP:\S+ Something Dana and Janine wanted
	misc      => "unk", # BAD PORT, TEMP, SERVICE
	prov      => 0,     # In provisioning status (pos date)
	rvw       => 0,     # Review date
	target    => "unk", # Cricket target file name
    };

    bless($self,$class);

    return $self;

}
######################################################################
sub descr {
    my $self = shift;
    if (@_) { $self->{descr} = shift; }
    return $self->{descr};
}
######################################################################
sub valid {
    my $self = shift;
    if (@_) { $self->{valid} = shift; }
    return $self->{valid};
}
######################################################################
sub category {
    my $self = shift;
    if (@_) { $self->{category} = shift; }
    return $self->{category};
}
######################################################################
sub peertype {
    my $self = shift;
    if (@_) { $self->{peertype} = shift; }
    return $self->{peertype};
}
######################################################################
sub facility {
    my $self = shift;
    if (@_) { $self->{facility} = shift; }
    return $self->{facility};
}
######################################################################
sub nodeid {
    my $self = shift;
    if (@_) { $self->{nodeid} = shift; }
    return $self->{nodeid};
}
######################################################################
sub virtual {
    my $self = shift;
    if (@_) { $self->{virtual} = shift; }
    return $self->{virtual};
}
######################################################################
sub vc {
    my $self = shift;
    if (@_) { $self->{vc} = shift; }
    return $self->{vc};
}
######################################################################
sub bandwidth {
    my $self = shift;
    if (@_) { $self->{bandwidth} = shift; }
    return $self->{bandwidth};
}
######################################################################
sub company {
    my $self = shift;
    if (@_) { $self->{company} = shift; }
    return $self->{company};
}
######################################################################
sub orderno {
    my $self = shift;
    if (scalar @_) { 
	my $input = shift;
	$self->{orderno} = uc($input) if $input; }
    return $self->{orderno};
}
######################################################################
sub shaul {
    my $self = shift;
    if (@_) { $self->{shaul} = shift; }
    return $self->{shaul};
}
######################################################################
sub ckid {
    my $self = shift;
    if (@_) { $self->{ckid} = shift; }
    return $self->{ckid};
}
######################################################################
sub pon {
    my $self = shift;
    if (@_) { $self->{pon} = shift; }
    return $self->{pon};
}
######################################################################
sub re {
    my $self = shift;
    if (@_) { $self->{re} = shift; }
    return $self->{re};
}
######################################################################
sub tik {
    my $self = shift;
    if (@_) { $self->{tik} = shift; }
    return $self->{tik};
}
######################################################################
sub cir {
    my $self = shift;
    if (@_) { $self->{cir} = shift; }
    return $self->{cir};
}
######################################################################
sub cap {
    my $self = shift;
    if (@_) { $self->{cap} = shift; }
    return $self->{cap};
}
######################################################################
sub l2tp {
    my $self = shift;
    if (@_) { $self->{l2tp} = shift; }
    return $self->{l2tp};
}
######################################################################
sub icb {
    my $self = shift;
    if (@_) { $self->{icb} = shift; }
    return $self->{icb};
}
######################################################################
sub dnlk {
    my $self = shift;
    if (@_) { $self->{dnlk} = shift; }
    return $self->{dnlk};
}
######################################################################
sub bkup {
    my $self = shift;
    if (@_) { $self->{bkup} = shift; }
    return $self->{bkup};
}
######################################################################
sub tohost {
    my $self = shift;
    if (@_) { $self->{tohost} = shift; }
    return $self->{tohost};
}
######################################################################
sub ick {
    my $self = shift;
    if (@_) { $self->{ick} = shift; }
    return $self->{ick};
}
sub nmp {
    my $self = shift;
    if (@_) { $self->{nmp} = shift; }
    return $self->{nmp};
}
######################################################################
sub misc {
    my $self = shift;
    if (@_) { $self->{misc} = shift; }
    return $self->{misc};
}
######################################################################
sub prov {
    my $self = shift;
    if (@_) { $self->{prov} = shift; }
    return $self->{prov};
}
######################################################################
sub rvw {
    my $self = shift;
    if (@_) { $self->{rvw} = shift; }
    return $self->{rvw};
}
######################################################################
sub target {
    my $self = shift;
    if (@_) { $self->{target} = shift; }
    return $self->{target};
}
######################################################################
sub fieldlist {
    my $self = shift;

    return(@fields);
}
######################################################################
sub bid {
    my $self = shift;
    if (@_) { $self->{bid} = shift; }
    return $self->{bid};
}
######################################################################
sub tohostname {
    my $self = shift;
    my $tokptr = shift;
    my $opt = '';

    &DebugPR(4,"Testing To Hostname|hub-hub|FRAMEHOST\n");

    if (!(defined($opt = $self->gettok($tokptr)))) {
	return("ERROR-DESC: Ran out of tokens in " . $self->descr);
    }
    
    $opt =~ tr/a-z/A-Z/;  # deal with case issues
    if ($opt eq 'TO') {

	&DebugPR(5,"Found 'to' : " . Dumper($tokptr) . "\n") if $main::debug > 5;

	if (!(defined($opt = $self->gettok($tokptr)))) {
	    return("ERROR-DESC: Ran out of tokens in " . $self->descr);
	}

	if ($opt eq 'FRAMEHOST') {
	    $self->tohost($opt);
	} elsif ($opt =~ '\w\w\w\d\d\-\w\w\w\d\d') {
	    $self->tohost($opt);
	} elsif (&ishostname($opt)) {
	    $self->tohost($opt);
	} else {
	    return("ERROR-DESC: Invalid Hostname " .  $self->descr);
	}
    } else {
	return("ERROR-DESC: Missing 'to' in " . $self->descr);
    }
    
    return(0);
}
######################################################################
sub opttoks {
    my $self = shift;
    my $tokptr = shift;
    my $opt = '';

    my @newtok = ();

    &DebugPR(4,"Eating Optional tokens:\n" . Dumper($tokptr) . "\n") if $main::debug > 4;

    while (defined($opt = shift(@{$tokptr}))) {
	&DebugPR(6,"opttoks - Testing '$opt'\n");

	if ($opt =~ /^\((.+)\)/) {
	    &DebugPR(5,"Found shorthaul $1\n");
	    $self->shaul($1);
	} elsif ($opt =~ /^\"(.+)\"/ ||
		 $opt =~ /^\^(.+)\^/) {
	    &DebugPR(5,"Found company $1\n");
	    $self->company(&cleanstr($1));
	} elsif ($opt =~ /^PON:(\S+)/) {
	    &DebugPR(5,"Found PON $1\n");
	    $self->pon($1);
	} elsif ($opt =~ /^CKID:(\S+)/) {
	    &DebugPR(5,"Found CKID $1\n");
	    $self->ckid($1);
	} elsif ($opt =~ /^RE:(\S+)/) {
	    &DebugPR(5,"Found RE $1\n");
	    $self->re($1);
	} elsif ($opt =~ /^NETX:(\S+)/) {
	    &DebugPR(5,"Found NETX $1\n");
	    $self->netx($1);
	} elsif ($opt =~ /^TIK:(\S+)/) {
	    &DebugPR(5,"Found TIK $1\n");
	    $self->tik($1);
	} elsif ($opt =~ /^ID:(\S+)/) {
	    &DebugPR(5,"Found ID $1\n");
	    $self->orderno($1);
	} elsif ($opt =~ /^ICK:(\d\d\d\d\d\d)/) {
	    &DebugPR(5,"Found ICK $1\n");
	    $self->ick($1);
	} elsif ($opt =~ /^NMP:(\S+)/) {
	     &DebugPR(5,"Found NMP $1\n");
	    $self->nmp($1);
	} elsif ($opt =~ /^L2TP/) {
	    &DebugPR(5,"Found L2TP\n");
	    $self->l2tp(1);
	} elsif ($opt =~ /^ICB/) {
	    &DebugPR(5,"Found ICB\n");
	    $self->icb(1);
	} elsif ($opt =~ /^DNLK/) {
	    &DebugPR(5,"Found DNLK\n");
	    $self->dnlk(1);
	} elsif ($opt =~ /^BKUP/) {
	    &DebugPR(5,"Found BKUP\n");
	    $self->bkup(1);
	} elsif ($opt =~ /^CIR:(\S+)/) {
	    &DebugPR(5,"Found CIR $1\n");
	    my $bw = $1;
	    if (&iskmg($bw)) {
		&DebugPR(6,"Found Good CIR $bw\n");
		$self->cir(&kmg2m($bw));
	    } else {
		&DebugPR(6,"Unknown option $opt\n");
		push(@newtok,$opt);
	    }
	} elsif ($opt =~ /^RL:(\S+)/ || 
		 $opt =~ /^CAP:(\S+)/) {
	    &DebugPR(5,"Found RL/CAP $1\n");
	    my $bw = $1;
	    if (&iskmg($bw)) {
		&DebugPR(6,"Found Good RL/CAP $bw\n");
		$self->validbw($bw);
		$self->cap($self->bandwidth);
	    } else {
		&DebugPR(6,"Unknown option $opt\n");
		push(@newtok,$opt);
	    }
	} elsif ($opt =~ /^RVW:(\d{8})/) {
	    &DebugPR(5,"Found RVW $1\n");
	    $self->rvw($1);
	} elsif ($opt =~ /^BID:(\S+)/) {
	    &DebugPR(5,"Found BID $1\n");
	    $self->bid($1);
	} elsif ($opt eq 'PON:' ||
		 $opt eq 'CKID:' ||
		 $opt eq 'TIK:' ||
		 $opt eq 'NETX:' ||
		 $opt eq 'CIR:' ||
		 $opt eq 'RL:' ||
		 $opt eq 'CAP:' ||
		 $opt eq 'ID:' ||
		 $opt eq 'ICK:' ||
		 $opt eq 'NMP:' ||
		 $opt eq 'BID:' ||
		 $opt eq 'RVW:' ||
		 $opt eq 'RE:') {
	    &DebugPR(5,"Found a keyword (NMP, PON, CKID, RE, NETX, TIK, CIR, ID, ICK, CAP, RL, RVW, BID) w/o any data after the colon - Discarding it\n");
	} else {
	    # Don't know what it is so we'll return the unprocessed tokens
	    &DebugPR(6,"Unknown option $opt\n");
	    push(@newtok,$opt);
	}
    }

    return(@newtok);
}


######################################################################
sub eatlefttoks {
    my $self = shift;
    my $tokptr = shift;
    my $needorderno = shift;
    my $opt = '';

    my $rv = 0;

    &DebugPR(4,"Looking for leftover tokens:\n" . Dumper($tokptr) . "\n") if $main::debug > 4;

    my @tokens = ();

	@tokens = @$tokptr if ref $tokptr;

    $needorderno = 0 if !defined($needorderno);

    if ($#tokens != -1) { 
	$rv = "ERROR-DESC: Leftover tokens '" . join(';',@tokens) . 
	    "' in " . $self->descr;
    }

    # At this point we shouldn't have any tokens left and should already know the order number

    if ($needorderno) {
	if ($self->orderno eq 'UNK') {
	    $rv = "ERROR-DESC: Missing order number in " . $self->descr;

	    if ($#tokens != -1) { 
		$rv .= " - Extra tokens found (missing ID:?) '" . join(';',@tokens) . 
		    "' ";
	    }
	}
    }

    return($rv);
}

######################################################################
#
# validdesc
#
# Parse Valid description lines and return the tokens as an array
# As defined in 
# https://www.sys.cogentco.com/IPeng/documentation/design/intdesc.html
#
# Returns 0 on valid
# Returns error message on invalid
# 
# 5/19/03 - Inital version only checks for required fields
#

sub validdesc {
    my $self = shift;

    $self->valid(0); # assume it's not valid

    &DebugPR(2,"Entering validdesc '" . $self->descr . "'\n") if $main::debug > 2;

    my $facility = '';

    my @out = ();
    my @opts = ();
    my $opt = '';
    my $descr = $self->descr;

    if ($self->descr eq 'unk') {
	return("ERROR-DESC: Missing Description") ;
    }

    my @tokens = $self->tokenize($self->descr);

    my $prefix = $self->gettok(\@tokens);
    &DebugPR(3,"Found Valid Prefix: $prefix\n");
    
  PREFIX: {
      ($prefix eq "CORE" ||
       $prefix eq "METRO" ||
       $prefix eq "EDGE" ||
       $prefix eq "MPLS" ||
       $prefix eq "L3" ||
       $prefix eq "XC" ||
       $prefix eq "NODE" ||
       $prefix eq "LAG" ||
       $prefix eq "SAT" ||
       $prefix eq "COED" ||
       $prefix eq "DCN")  && do {
	  &DebugPR(3,"Found $prefix\n");
	  $self->category($prefix);

	  if ($opt = $self->testfacility(\@tokens)) {
	      return($opt);
	  }

	  @tokens = $self->opttoks(\@tokens);  # need to eat the CAP: and other optional tokens here

	  if ($opt = $self->tohostname(\@tokens)) {
	      return($opt);
	  }

	  if ($opt = $self->eatlefttoks(\@tokens,0)) {
	      return($opt);
	  }

	  if ($self->ick == 0) {
#
# Don't want to fail this until all the router changes are made
#	      my $rv = "ERROR-DESC: Missing ICK number in " . $self->descr;
#	      return($rv);
	  }

	  last PREFIX;
      };
      ($prefix eq "LAG-CORE" ||
       $prefix eq "LAG-METRO" ||
       $prefix eq "LAG-EDGE" ||
       $prefix eq "LAG-XC" ||
        $prefix eq "LAG-SAT" ||
	 $prefix eq "LAG-COED" ||
       $prefix eq "LAG-NODE") && do {
	  &DebugPR(3,"Found $prefix\n");
	  $self->category($prefix);

	  if ($opt = $self->testfacility(\@tokens)) {
	      return($opt);
	  }

	  @tokens = $self->opttoks(\@tokens);  # need to eat the CAP: and other optional tokens here

	  if ($opt = $self->tohostname(\@tokens)) {
	      return($opt);
	  }

	  if ($opt = $self->eatlefttoks(\@tokens,0)) {
	      return($opt);
	  }

	  if ($self->bid eq "unk") {
	      my $rv = "ERROR-DESC: LAG missing BID in " . $self->descr;
	      return($rv);
	  } else {
	      my $rv = $self->bid;
	      &DebugPR(3,"Found BID $rv\n");
	  }

	  if ($self->ick == 0) {
#
# Don't want to fail this until all the router changes are made
#	      my $rv = "ERROR-DESC: Missing ICK number in " . $self->descr;
#	      return($rv);
	  }

	  last PREFIX;
      };
      $prefix =~ /^LAG-PEER-(PUBLIC|PRIVATE)$/  && do {
	  &DebugPR(3,"Found $prefix\n");
	  $self->category($prefix);

	  if ($prefix =~ /PUBLIC/) {
	      my $rv = "PUBLIC";
	      $self->peertype($rv);
	  } elsif ($prefix =~ /PRIVATE/) {
	      my $rv = "PRIVATE";
	      $self->peertype($rv);
	  } else {
	      return("ERROR-DESC: Peer missing PUBLIC|PRIVATE in '$descr'");
	  }

	  # PEER PUBLIC|PRIVATE <facility> "<company_name-ASN-hub>" \
	  # [<connection_order_number>] [OPTIONAL FIELDS...]

	  if ($opt = $self->testfacility(\@tokens)) {
	      return($opt);
	  }

	  @tokens = $self->opttoks(\@tokens);  # need to eat the CAP: and other optional tokens here

	  if (my $rv = $self->eatlefttoks(\@tokens,1)) {
	      return($rv);
	  }

	  if ($self->company) {
	      if (&testpeerdesc($self->company)) {
		  # peer name correct in company slot
	      } else {
		  return("ERROR-DESC: Peer info not in company_name-ASN-hub## format $descr");
	      }
	  } else {
	      return("ERROR-DESC: Can't find valid peer info in '$descr'");	
	  }

	  if ($self->bid eq "unk") {
	      my $rv = "ERROR-DESC: LAG missing BID in " . $self->descr;
	      return($rv);
	  } else {
	      my $rv = $self->bid;
	      &DebugPR(3,"Found BID $rv\n");
	  }

	  last PREFIX;
      };
      $prefix =~ /^PEER-(PUBLIC|PRIVATE)$/  && do {
	  &DebugPR(3,"Found $prefix\n");

	  if ($prefix =~ /PUBLIC/) {
	      my $rv = "PUBLIC";
	      $self->peertype($rv);
	  } elsif ($prefix =~ /PRIVATE/) {
	      my $rv = "PRIVATE";
	      $self->peertype($rv);
	  } else {
	      return("ERROR-DESC: Peer missing PUBLIC|PRIVATE in '$descr'");
	  }
	  $prefix = "PEER";
	  $self->category($prefix);

	  # PEER PUBLIC|PRIVATE <facility> "<company_name-ASN-hub>" \
	  # [<connection_order_number>] [OPTIONAL FIELDS...]

	  if ($opt = $self->testfacility(\@tokens)) {
	      return($opt);
	  }

	  @tokens = $self->opttoks(\@tokens);

	  if (my $rv = $self->eatlefttoks(\@tokens,1)) {
	      return($rv);
	  }

	  if ($self->company) {
	      if (&testpeerdesc($self->company)) {
		  # peer name correct in company slot
	      } else {
		  return("ERROR-DESC: Peer info not in company_name-ASN-hub## format $descr");
	      }
	  } else {
	      return("ERROR-DESC: Can't find valid peer info in '$descr'");	
	  }


	  last PREFIX;
      };
      $prefix eq 'LAG-PEER' && do {
	  &DebugPR(3,"Found $prefix\n");
	  $self->category($prefix);

	  # PEER PUBLIC|PRIVATE <facility> "<company_name-ASN-hub>" \
	  # [<connection_order_number>] [OPTIONAL FIELDS...]

	  if (!(defined($opt = $self->gettok(\@tokens)))) {
	      return("ERROR-DESC: Ran out of tokens in '$descr'");
	  }

	  if ($opt =~ /^(PUBLIC|PRIVATE)/) {
	      $self->peertype($opt);
	  } else {
	      return("ERROR-DESC: Peer missing PUBLIC|PRIVATE in '$descr'");
	  }

	  if ($opt = $self->testfacility(\@tokens)) {
	      return($opt);
	  }

	  @tokens = $self->opttoks(\@tokens);

	  if (my $rv = $self->eatlefttoks(\@tokens,1)) {
	      return($rv);
	  }

	  if ($self->company) {
	      if (&testpeerdesc($self->company)) {
		  # peer name correct in company slot
	      } else {
		  return("ERROR-DESC: Peer info not in company_name-ASN-hub## format $descr");
	      }
	  } else {
	      return("ERROR-DESC: Can't find valid peer info in '$descr'");	
	  }

	  if ($self->bid eq "unk") {
	      my $rv = "ERROR-DESC: LAG missing BID in " . $self->descr;
	      return($rv);
	  } else {
	      my $rv = $self->bid;
	      &DebugPR(3,"Found BID $rv\n");
	  }

	  last PREFIX;
      };
      $prefix eq 'PEER' && do {
	  &DebugPR(3,"Found $prefix\n");
	  $self->category($prefix);

	  # PEER PUBLIC|PRIVATE <facility> "<company_name-ASN-hub>" \
	  # [<connection_order_number>] [OPTIONAL FIELDS...]

	  if (!(defined($opt = $self->gettok(\@tokens)))) {
	      return("ERROR-DESC: Ran out of tokens in '$descr'");
	  }

	  if ($opt =~ /^(PUBLIC|PRIVATE)/) {
	      $self->peertype($opt);
	  } else {
	      return("ERROR-DESC: Peer missing PUBLIC|PRIVATE in '$descr'");
	  }

	  if ($opt = $self->testfacility(\@tokens)) {
	      return($opt);
	  }

	  @tokens = $self->opttoks(\@tokens);

	  if (my $rv = $self->eatlefttoks(\@tokens,1)) {
	      return($rv);
	  }

	  if ($self->company) {
	      if (&testpeerdesc($self->company)) {
		  # peer name correct in company slot
	      } else {
		  return("ERROR-DESC: Peer info not in company_name-ASN-hub## format $descr");
	      }
	  } else {
	      return("ERROR-DESC: Can't find valid peer info in '$descr'");	
	  }


	  last PREFIX;
      };
      $prefix =~ /^LAG-CUST-[R|W|T|P|C|D|V|U]$/  && do {
	  &DebugPR(3,"Found $prefix\n");
	  $self->category($prefix);

	  # CUST-{R|W|T|P|C|D|V|U} <facility> [<bandwidth>] ["<company_name>"]
	  # <connection_order_number> [OPTIONAL FIELDS...]

	  if ($opt = $self->testfacility(\@tokens)) {
	      return($opt);
	  }

	  @tokens = $self->opttoks(\@tokens);

	  if (my $rv = $self->eatlefttoks(\@tokens,1)) {
	      return($rv);
	  }

	  if ($self->bid eq "unk") {
	      my $rv = "ERROR-DESC: LAG missing BID in " . $self->descr;
	      return($rv);
	  } else {
	      my $rv = $self->bid;
	      &DebugPR(3,"Found BID $rv\n");
	  }

	  last PREFIX;
      };
      $prefix =~ /^CUST-[R|W|T|P|C|D|V|U]$/  && do {
	  &DebugPR(3,"Found $prefix\n");
	  $self->category($prefix);

	  # CUST-{R|W|T|P|C|D|V|U} <facility> [<bandwidth>] ["<company_name>"]
	  # <connection_order_number> [OPTIONAL FIELDS...]

	  if ($opt = $self->testfacility(\@tokens)) {
	      return($opt);
	  }

	  @tokens = $self->opttoks(\@tokens);

	  if (my $rv = $self->eatlefttoks(\@tokens,1)) {
	      return($rv);
	  }

	  last PREFIX;
      };
      ($prefix eq 'FLDENG' ||  
       $prefix eq "TCAGG") && do {
	  &DebugPR(3,"Found $prefix\n");
	  $self->category($prefix);

	  # FLDENG|TCAGG <facility>

	  if ($opt = $self->testfacility(\@tokens)) {
	      return($opt);
	  }

	  @tokens = $self->opttoks(\@tokens);

	  if (my $rv = $self->eatlefttoks(\@tokens,0)) {
	      return($rv);
	  }

	  last PREFIX;
      };
      $prefix eq 'SERVICE'  && do {
  	  &DebugPR(3,"Found $prefix\n");
	  $self->category($prefix);
	  
	  # SERVICE <purpose>

	  if ($#tokens == -1) { 
	      return("ERROR-DESC: Ran out of tokens in '$descr'");
	  }

	  $self->misc(join(' ',@tokens)); 

  	  last PREFIX;
      };
      ($prefix =~ /^PROV(:\d{8})?$/ || # This set does not require more than prefix
       $prefix eq "TEMP" || 
       $prefix eq "DIAL" || 
       $prefix eq "MGNT" || 
       $prefix eq "LOOP" || 
       $prefix eq "STOC")  && do {
	  &DebugPR(3,"Found $prefix\n");
	  if ($prefix =~ /^PROV/) {
	      $self->category('PROV');
	  } else {
	      $self->category($prefix);
	  }
      
	  # STOC [<description>]
	  # TEMP [<description>]
	  # DIAL [<description>]
	  # PROV[:YYYYMMDD] [<description>]
	  # MGNT [<description>]
	  # LOOP [<description>]

	  if ($self->category eq 'PROV') {
	      if (defined($1)) {
		  $self->prov($1);
	      } else {
		  $self->prov(99999999);  # no date specified so we insert max
	      }
	  } 

	  # I used to have a bit to parse optional tokens here but as I want the option of 
	  # generating a proper desc line, I pretty much have to leave this alone and just
	  # store the rest

	  if ($#tokens != -1) { 
	      $self->misc(join(' ',@tokens)); 
	  }

	  if ($self->prov && 
	      $self->prov < $date) {
	      return ("ERROR-DESC: PROV period " . $self->prov . " has exprired < $date");
	  } 

	  last PREFIX;
      }; 
      $prefix eq 'BAD'  && do {
  	  &DebugPR(3,"Found $prefix\n");
	  $self->category($prefix);
	  
	  # BAD PORT blah

	  if (!(defined($opt = $self->gettok(\@tokens)))) {
	      return("ERROR-DESC: Ran out of tokens in '$descr'");
	  }

  	  if ($opt eq 'PORT') {
	      
	      @tokens = $self->opttoks(\@tokens);

	      if ($#tokens != -1) { 
		  $self->misc(join(' ',@tokens)); 
	      }
  	  } else {
  	      return("ERROR-DESC: Missing PORT in '$descr'\n");
  	  }

  	  last PREFIX;
      };

      &DebugPR(3,"No match for $prefix\n");
      return ("ERROR-DESC: Invalid Prefix '$prefix' in '$descr'");
      }

    $self->valid(1);
    return(0);
}

######################################################################

sub tokenize {
    my $self = shift;
    my @tokens = ();

    if (@_) {
	my $descr = shift;

	$descr =~ s/\s\s+/ /g;

	my $len = length($descr);

	my $count = 0;
	my @chars = ();

	while ($count < $len) {
	    push (@chars,substr($descr,$count,1));
	    $count++;
	}

	my $c = '';
	my $str = '';

	if ($len != 0) {
	    die "\@chars empty" if ($#chars == -1);
	}
	
	while (defined($c = shift(@chars))) {
	    if ($c eq '"') {
#		print("found a quote @chars\n");
		$str .= $c;
		my $go = 1;
		while ($go && defined($c = shift(@chars))) {
#		    print("waiting for end quote $c\n");
		    $str .= $c;
		    $go = 0 if ($c eq '"');
		}
	    } elsif ($c eq '^' ) {
#		print("found a caret @chars\n");
		$str .= $c;
		my $go = 1;
		while ($go && defined($c = shift(@chars))) {
#		    print("waiting for end quote $c\n");
		    $str .= $c;
		    $go = 0 if ($c eq '^');
		}
	    } elsif ($c eq '(' ) {
#		print("found a open paren @chars\n");
		$str .= $c;
		my $go = 1;
		while ($go && defined($c = shift(@chars))) {
#		    print("waiting for end quote $c\n");
		    $str .= $c;
		    $go = 0 if ($c eq ')');
		}
	    } elsif ($c eq ' ') {
#		print("Found Token $str\n");
		push (@tokens,$str);
		$str = '';
	    } else {
		$str .= $c;
	    }
	}
	if ($str ne '') {
#	    print("Found Final Token $str\n");
	    push (@tokens,$str);
	}
    }

    return (@tokens);
}


######################################################################
sub gettok {
    my $self = shift;
    my $tokptr = shift;
    my @out = ();
    my $opt = '';

    if (!(defined($opt = shift(@{$tokptr})))) {
	return(undef);
    }
    return($opt);
}


######################################################################
sub testfacility {
    my $self = shift;
    my $tokptr = shift;
    my $opt = '';

    my $facility;

    &DebugPR(5,"testfacility: enter\n");

    if (!defined($facility = $self->gettok($tokptr))) {
	return("ERROR-DESC: Ran out of facility tokens in " . $self->descr);
    } 

    if (($facility eq 'E') || 
	($facility eq 'FE') || 
	($facility eq 'GIGE') || 
	($facility eq '10GE-L') ||
	($facility eq '10GE-W') ||
	($facility eq '40GE-L') ||
	($facility eq '40GE') ||
	($facility eq '100GE') ||
	($facility eq '2GEC') || 
	($facility eq '3GEC') || 
	($facility eq '4GEC') ||
	($facility eq '20GEC') ||
	($facility eq 'DS0') || 
	($facility eq 'DS1') || 
	($facility eq 'DS3') || 
	($facility eq 'E1') || 
	($facility eq 'E3') || 
	($facility eq 'OC3') || 
	($facility eq 'STM1') || 
	($facility eq 'OC12') || 
	($facility eq 'STM4') || 
	($facility eq 'OC48') || 
	($facility eq 'STM16') || 
	($facility eq 'OC192') || 
	($facility eq 'STM64') || 
	($facility eq 'TUN') || 
	($facility eq 'ISDN') || 
	($facility eq 'POTS') || 
	($facility eq 'PC') || 
	($facility eq 'BUN') || 
	($facility eq 'BGP')) {
	&DebugPR(5,"Found Valid Circuit Facility\n");
	$self->facility($facility);

	return(0);
    } elsif (($facility eq 'VLAN') || 
	     ($facility eq 'PVC') || 
	     ($facility eq 'VC')) {
	&DebugPR(5,"Found valid virtual Facility VLAN/PVC/VC\n");

	$self->facility($facility);
	$self->virtual($facility);
	return(0);
    }
    return("ERROR-DESC: No valid Facility found in " . $self->descr);
}

######################################################################
sub validbw {
    my $self = shift;

    my $bw = shift;
    my $rv = 0;

    &DebugPR(5,"validbw: enter\n");

    return($rv) if !defined($bw);

    $bw =~ tr/a-z/A-Z/;

    &DebugPR(6,"validbw: testing $bw\n");

    $bw = &kmg2m($bw);

    if (defined($bw)) {

	$self->bandwidth($bw);

	$rv = 1;
	&DebugPR(5," w/bandwidth\n");
    }

    return($rv)


}
######################################################################
sub gendesc {
    my $self = shift;
    &DebugPR(5,"gendesc: enter\n");
    
    my $rv = undef;

    return($rv) if (!($self->valid));  # Only generate if we know we have good data

    $rv = $self->category;

    if ($self->category =~ /CORE|METRO|EDGE|SAT|COED|MPLS|L3|LAG|XC|NODE|TCAGG|PEER|CUST|FLDENG|DCN/) {
    
	$rv .= " " . $self->peertype if ($self->peertype ne 'unk');
	$rv .= " " . $self->facility;

	if ($self->facility ne 'BGP') {
	    
	    $rv .= " CAP:" . &m2kmg($self->cap) if ($self->cap);
	    $rv .= " CIR:" . &m2kmg($self->cir) if ($self->cir);

	    $rv .= " L2TP" if ($self->l2tp);

	    $rv .= " ICB" if ($self->icb);
	
	    if ($self->category =~ /CORE|METRO|SAT|COED|EDGE|MPLS|L3|LAG|XC|NODE|DCN/) {
		$rv .= " to " . $self->tohost; 
	    }
	    if (($self->ick) && ($self->ick ne '000000')) {
		$rv .= " ICK:" . sprintf("%06d",$self->ick);
	    }
	}

	$rv .= " ^" . $self->company . "^"  if ($self->company ne 'unk');
        $rv .= " NMP:" . $self->nmp if $self->nmp ne '0';
	$rv .= " ID:" . $self->orderno if ($self->orderno ne 'unk' && $self->orderno ne 'UNK' );

	if ($self->facility ne 'BGP') {
	    $rv .= " (" . $self->shaul . ")"  if ($self->shaul ne 'unk');
	    $rv .= " PON:" . $self->pon if ($self->pon ne 'unk');
	    $rv .= " CKID:" . $self->ckid if ($self->ckid ne 'unk');
	}
	$rv .= " RE:" . $self->re if ($self->re ne 'unk');
	$rv .= " TIK:" . $self->tik if ($self->tik ne 'unk');
	$rv .= " RVW:" . $self->rvw if ($self->rvw ne '0');
	$rv .= " BID:" . $self->bid if ($self->bid ne 'unk');
	if ($self->facility ne 'BGP') {
	    $rv .= " DNLK" if ($self->dnlk);
	}

    } else {
	$rv .= " PORT" if ($self->category eq "BAD");
	$rv .= ":" . $self->prov if ($self->category eq "PROV" && $self->prov ne '99999999');
	$rv .= " TIK:" . $self->tik if ($self->tik ne 'unk');
	$rv .= " RVW:" . $self->rvw if ($self->rvw ne '0');
	$rv .= " " . $self->misc if ($self->misc ne 'unk');
    }
    return($rv)
}

######################################################################
sub dump {
    my $self = shift;
    my $str = '';

    $str = "Dumping Description  ";
    $str .= Data::Dumper->Dump([$self],[qw(*self)]);
    
    if (@_) { 
	print $str;
    }
    return($str);
}


1;
