# $HeadURL: svn://hhcv-srcctrl.sys.cogentco.com/cogent/rtrtools/trunk/lib/BGPPeer.pm $
# $Id: BGPPeer.pm 2599 2015-06-26 16:57:50Z sphillips $

package BGPPeer;

use Data::Dumper;
use IO::File;
use English;
use POSIX;
use strict;
use warnings;
use Carp;

use Cogent::Desc;
use BGPPeer::AFI;
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
	hostname       => "unk",
	ip             => "unk", # Neighbor IP Address
	peergroup      => 0,
	peersession    => 0,
	asn            => 0,     # Neighbor AS number
	softreconfig   => 0,     # default to none
	localas        => 0,     # default to none
	descr          => undef,
	adminstat      => 1,     # default to noshut
	addrfam        => {}     # Hash to BGPPeer::AFI objects
    };

    bless($self,$class);

    $self->{descr} = new Cogent::Desc;

    return $self;

}
######################################################################
sub hostname {
    my $self = shift;
    if (@_) { $self->{hostname} = shift; }
    return $self->{hostname};
}
######################################################################
sub ip {
    my $self = shift;
    if (@_) { $self->{ip} = shift; }
    return $self->{ip};
}
######################################################################
sub peergroup {
    my $self = shift;
    if (@_) { $self->{peergroup} = shift; }
    return $self->{peergroup};
}
######################################################################
sub peersession {
    my $self = shift;
    if (@_) { $self->{peersession} = shift; }
    return $self->{peersession};
}
######################################################################
sub asn {
    my $self = shift;
    if (@_) { $self->{asn} = shift; }
    return $self->{asn};
}
######################################################################
sub softreconfig {
    my $self = shift;
    if (@_) { $self->{softreconfig} = shift; }
    return $self->{softreconfig};
}
######################################################################
sub localas {
    my $self = shift;
    if (@_) { $self->{localas} = shift; }
    return $self->{localas};
}
######################################################################
sub descr {
    my $self = shift;
    if (@_) { $self->{descr}->descr(shift); }
    return $self->{descr}->descr;
}
######################################################################
sub adminstat {
    my $self = shift;
    if (@_) { $self->{adminstat} = shift; }
    return $self->{adminstat};
}
######################################################################
#
# addrfam - pointer to hash to BGPPeer::AFI objects
#
# ->addrfam = return hash pointer
# ->addrfam(key) = return BGPPeer::AFI object (if it exists)
# ->addrfam(key,ptr) = add BGPPeer:AFI object to hash  hash{key} = obj
#
sub addrfam {
    my $self = shift;
    my @opts = @_;
    if (@opts) { 
	my $key = shift(@opts);
	my $hptr = $self->addrfam;
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
    return ($self->{addrfam});
}
######################################################################
sub addrfams {
    my $self = shift;

    my @keys = keys(%{$self->addrfam});
    if (!(@keys)) {
	@keys = ();
    }
    return(sort(@keys));
}
######################################################################
sub gendesc {
    my $self = shift;
    return $self->{descr}->gendesc;
}
######################################################################
sub validdesc {
    my $self = shift;
    my $loud = 0;
    
    if (@_) { $loud = shift; }
    
    my $msg;

    if (($msg = $self->{descr}->validdesc) && $loud) {
        print $self->hostname . "-" . $self->ip . ": " . $msg . "\n";
    }
    return ($msg);
}
######################################################################
sub valid {
    my $self = shift;
    if (@_) { $self->{descr}->valid(shift); }
    return $self->{descr}->valid;
}
######################################################################
sub category {
    my $self = shift;
    if (@_) { $self->{descr}->category(shift); }
    return $self->{descr}->category;
}
######################################################################
sub peertype {
    my $self = shift;
    if (@_) { $self->{descr}->peertype(shift); }
    return $self->{descr}->peertype;
}
######################################################################
sub company {
    my $self = shift;
    if (@_) { $self->{descr}->company(shift); }
    return $self->{descr}->company;
}
######################################################################
sub orderno {
    my $self = shift;
    if (@_) { $self->{descr}->orderno(shift); }
    return $self->{descr}->orderno;
}
######################################################################
sub misc {
    my $self = shift;
    if (@_) { $self->{descr}->misc(shift); }
    return $self->{descr}->misc;
}
######################################################################
sub prov {
    my $self = shift;
    if (@_) { $self->{descr}->prov(shift); }
    return $self->{descr}->prov;
}
######################################################################
sub rvw {
    my $self = shift;
    if (@_) { $self->{descr}->rvw(shift); }
    return $self->{descr}->rvw;
}
######################################################################
sub facility {
    my $self = shift;
    if (@_) { $self->{descr}->facility(shift); }
    return $self->{descr}->facility;
}
######################################################################
sub iscogent {
    my $self = shift;

    my $rv = 0;
    
    $rv = 1 if (exists($cogentas{$self->asn}));

    return $rv;
}
######################################################################
#
# Parses config for a peer.
#
sub ParseConfig {
    my $self = shift;
    my $confptr = shift;
    my $addrfam = shift;
    my $policyptr = shift;
    my $sessionptr = shift;
    my $groupsptr = shift;
    my $usedgroupsptr = shift;
    my $aclptr = shift;
    my $chassis = shift;

    my @errorstr = ();

    my $ip = $self->ip;

    my $ln;

    my $afi = undef;

    my $version = 0;

    if (defined($addrfam)) {
	$afi = $self->afi($afi,$addrfam);
    }

    if (defined($addrfam) && $self->peergroup) {
	#need to cheat and add peergroup here
	#as it isn't explicitly renamed w/i 
	#addr family

	if (exists($groupsptr->{$self->peergroup})) {
	    # Apply the peergroup to a peer if we have any
	    # addr family specific stuff for it.
	    unshift(@{$confptr},"neighbor $ip peer-group " . $self->peergroup);
	}
    }

    while ($ln = shift(@{$confptr})) {
	&DebugPR(2,"$modname-ParseConfig: Line $ln \n");

	my $isno = 0;
	if ($ln =~ /^no /) {
	    &DebugPR(3,"$modname-ParseConfig: Found 'no' \n");
	    $isno = 1;
	}


	if ($ln =~ /^neighbor $ip (.+)/ ||
	    $ln =~ /^no neighbor $ip (.+)/) {  
	    $ln = $1;                         
	} else {
	    &DebugPR(2,"$modname-ParseConfig: Different peer, backing up. \n");
	    &DebugPR(3,"$modname-ParseConfig: Stopping- Line $ln \n");
	    # we must be done, put whatever we got from the config back
	    unshift(@{$confptr},$ln);
	    last;
	}

	# Need to unwind peers that are entirely defined by a peergroup
	if ( $ln =~ /^peer-group (.+)/) { 
	    my $pgname = $1;

	    &DebugPR(3,"$modname-ParseConfig: Applying peer-group $pgname\n");

	    $usedgroupsptr->{$ip} = $pgname;

	    if (exists($groupsptr->{$pgname})) {
		my @pushopts = @{$groupsptr->{$pgname}};
		
		while (@pushopts) {
		    my ($isno,$opts) = @{pop(@pushopts)};

		    unshift(@{$confptr},"$isno" . "neighbor $ip " . $opts);  # Apply the peergroup to a peer
		}
	    } else {
		push(@errorstr,
		     &ErrorPR($self->hostname,
			      "WARN-PEER",
			      "$ip is trying to use a peer-group $pgname that isn't defined")
		    );
	    }
	    # Should now be ready for next section to do tests on this peer
	    next;
	}

	if ($ln =~ /^remote-as (\d+)(\.(\d+))?/)  { 
	    my $asn = $1;

	    if (defined($3)) {  # Convert AS-DOT -> AS-PLAIN
		$asn = ($asn * 65536) + $3;
	    }

	    $self->asn($asn);
	    &DebugPR(2,"$modname-ParseConfig: Found remote-as $asn\n");


	    if (exists($usedgroupsptr->{$ip})) {
		$self->peergroup($usedgroupsptr->{$ip});
	    }
	    next;
	}

	if ($ln =~ /^inherit peer-policy (\S+)/) { 
	    my $pgname = $1;
	    &DebugPR(3,"$modname-ParseConfig: Applying peer-policy $pgname\n");
	    if (exists($policyptr->{$pgname})) {
		my @pushopts = @{$policyptr->{$pgname}};

		$afi = $self->afi($afi);
		$afi->peerpolicy($pgname);

		while (@pushopts) {
		    unshift(@{$confptr},"neighbor $ip " . pop(@pushopts));  # Apply the peerpolicy
		}
	    } else {
		push(@errorstr,
		     &ErrorPR($self->hostname,
			      "WARN-PEER",
			      $self->asn . " ( $ip ) is trying to use a peer-policy $1 that isn't defined")
		    );
	    }
	    next;
	}

	if ($ln =~ /^inherit peer-session (.+)/) { 
	    my $pgname = $1;
	    &DebugPR(3,"$modname-ParseConfig: Applying peer-session $pgname\n");
	    if (exists($sessionptr->{$pgname})) {
		my @pushopts = @{$sessionptr->{$pgname}};

		$self->peersession($pgname);

		while (@pushopts) {
		    unshift(@{$confptr},"neighbor $ip " . pop(@pushopts));  # Apply the peersession
		}
	    } else {
		push(@errorstr,
		     &ErrorPR($self->hostname,
			      "WARN-PEER",
			      $self->asn . " ( $ip ) is trying to use a peer-session $1 that isn't defined")
		    );
	    }
	    next;
	}

	if ($ln =~ /^soft-reconfiguration (.+)/) {
	    &DebugPR(2,"Found soft-reconfig\n");
	    $self->softreconfig($1);
	    push(@errorstr,
		 &ErrorPR($self->hostname,
			  "WARN-PEER",
			  $self->asn . " ( $ip ) has soft-reconfig enabled")
		);
	    next;
	}
	if ($ln =~ /^local-as (.+)/) {
	    &DebugPR(2,"$modname-ParseConfig: Found local-as\n");
	    $self->localas($1);
	    next;
	}

	if ($ln =~ /^description (.+)/) {
	    &DebugPR(2,"$modname-ParseConfig: Found peer description\n");
	    $self->descr($1);
	    next;
	}

	if ($ln =~ /^shutdown/) {
	    &DebugPR(2,"$modname-ParseConfig: Found shutdown peer\n");
	    $self->adminstat(0);
	    next;
	}

	if ($ln =~ /^version (.+)/) {
	    &DebugPR(2,"$modname-ParseConfig: Found version\n");
	    $version = $1;
	    next;
	}

	if ($ln =~ /^activate/) {
	    &DebugPR(2,"$modname-ParseConfig: Found " . 
		     ($isno ? 'no ' : '') . "$addrfam activate\n");
            # Don't need $afi = $self->afi($afi); as this commands only
	    # exists in address family config
	    if ($isno) {
		$afi->activate(0);
	    } else {
		$afi->activate(1);
	    }
	    next;
	}

	if ($ln =~ /^remove-private-as/) {
	    &DebugPR(2,"$modname-ParseConfig: Found remove-private-as\n");
	    if ($chassis =~ /12\d\d\d/) {  
		push(@errorstr,
		     &ErrorPR($self->hostname,
			      "ERROR-PEER",
			      $self->asn . " ( $ip ) has remove-private-as enabled")
		    );
	    }
	    next;
	}

	if ($ln =~ /^maximum-prefix\s+(\d+)(\s+(\d+))*/) {
	    if (defined($self)) {
		$afi = $self->afi($afi);
		if (!($afi->maxprefix)) { # prevent peergroup or template
		    $afi->maxprefix($1);  # from clobbering peer specific
		}
	    }
	    &DebugPR(2,"$modname-ParseConfig: Found maximum-prefix $1 ");
	    if (defined($3)) {
		&DebugPR(2,"$3 ");
	    }
	    &DebugPR(2,"\n");
	    next;
	}

	# check for prefix-list, route-map, distribute-list, filter-list

	$self->CheckBGPACL($ln,$aclptr,$afi);

    } # while same neighbor 

    # Look for Errors
    &DebugPR(2,"$modname-ParseConfig: Done with neighbor, doing Error checking\n");


    if ($self->descr eq 'unk') {
	if (!$self->iscogent) {
	    push(@errorstr,
		 &ErrorPR($self->hostname,
			  "WARN-PEER",
			  $self->asn . " ( $ip ) missing description")
		);
	}
    } else {
	my $msg;
	if (($msg = $self->validdesc) && 
	    ($self->adminstat)) {
	    push(@errorstr,
		 &ErrorPR($self->hostname,
			  "WARN-PEER",
			  $self->asn . " ( $ip ) Description $msg")
		);
	}
    }

#    if (!$version ||
#	$version ne '4') {
#	push(@errorstr,
#	     &ErrorPR($self->hostname,
#		      "WARN-PEER",
#		      $self->asn . " ( $ip ) missing version 4")
#	    );
#    }

    if ($self->localas ne '0') {
	my $msg;

	$msg = $self->asn . " ( $ip ) has local-as " . $self->localas . " enabled";

	if ($self->descr ne 'unk') {
	    $msg .= " for peer " . $self->descr;
	}

	push(@errorstr,
	     &ErrorPR($self->hostname,
		      "WARN-PEER",
		      $msg)
	    );
    }

    &DebugPR(3,"$modname-ParseConfig: Leaving BGP peer " . $self->asn . "\n") if $main::debug > 3;
    return(\@errorstr);

}


######################################################################
#
# Parses config for a peer.
#
sub ParseXRConfig {
    my $self = shift;
    my $confptr = shift;
    my $groupsptr = shift;
    my $usedgroupsptr = shift;
    my $aclptr = shift;
    my $chassis = shift;

    my @errorstr = ();

    my $ip = $self->ip;

    my $ln;

    my $version = 0;

    while ($ln = shift(@{$confptr})) {
	&DebugPR(2,"$modname-ParseXRConfig: Line $ln \n");

	# Need to unwind peers that are entirely defined by a peergroup
	if ( $ln =~ /^use neighbor-group (.+)/) { 
	    my $pgname = $1;
	    &DebugPR(3,"$modname-ParseXRConfig: Applying neighbor-group $pgname\n");

	    # in XR we can have multiple neighbor-groups applied
	    if (!exists($usedgroupsptr->{$ip})) {
		$usedgroupsptr->{$ip} = [];
	    }
	    push(@{$usedgroupsptr->{$ip}},$pgname);
	    
	    if (exists($groupsptr->{$pgname})) {
		unshift(@{$confptr},@{$groupsptr->{$pgname}});  # Apply the neighbor group to a peer
	    } else {
		push(@errorstr,
		     &ErrorPR($self->hostname,
			      "WARN-PEER",
			      "$ip is trying to use a neighbor-group $pgname that isn't defined")
		    );
	    }
	    # Should now be ready for next section to do tests on this peer
	    next;
	}
	# Need to unwind peers that are entirely defined by a peergroup
	# session-groups need to be treated exactly like neighbor-groups in parsing, i added session-group- as a prefix for them in the tabl
	 if ( $ln =~ /^use session-group (.+)/) {
            my $pgname = "session-group-" . $1;
            &DebugPR(3,"$modname-ParseXRConfig: Applying group $pgname\n");

            # in XR we can have multiple neighbor-groups applied
            if (!exists($usedgroupsptr->{$ip})) {
                $usedgroupsptr->{$ip} = [];
            }
            push(@{$usedgroupsptr->{$ip}},$pgname);

            if (exists($groupsptr->{$pgname})) {
                unshift(@{$confptr},@{$groupsptr->{$pgname}});  # Apply the neighbor group to a peer
            } else {
                push(@errorstr,
                     &ErrorPR($self->hostname,
                              "WARN-PEER",
                              "$ip is trying to use a group $pgname that isn't defined")
                    );
            }
            # Should now be ready for next section to do tests on this peer
            next;
        }elsif( $ln =~ /^use af-group (.+)/) { #need to unwind af-group - this should actually be found under an address-family section, but it's ok to check for it here (if nothing else stops more errors)
            my $pgname = "af-group-" . $1;
            &DebugPR(3,"$modname-ParseXRConfig: Applying group $pgname\n");

            # in XR we can have multiple neighbor-groups applied
            if (!exists($usedgroupsptr->{$ip})) {
                $usedgroupsptr->{$ip} = [];
            }
            push(@{$usedgroupsptr->{$ip}},$pgname);

            if (exists($groupsptr->{$pgname})) {
		#testing not unwinding af-groups as a source of ccheck slowdown:
                #unshift(@{$confptr},@{$groupsptr->{$pgname}});  # Apply the neighbor group to a peer
            } else {
                push(@errorstr,
                     &ErrorPR($self->hostname,
                              "WARN-PEER",                                                                                                                      "$ip is trying to use a group $pgname that isn't defined")                                                              );
            } 
            # Should now be ready for next section to do tests on this peer 
            next;
        }


	if ($ln =~ /^remote-as (\d+)/)  { 
	    my $asn = $1;
	    $self->asn($asn);
	    &DebugPR(2,"$modname-ParseXRConfig: Found remote-as $asn\n");
	    #so the below code made peergroup = the chain of groups that reached a remote AS statment . . . the latter part seems fail
	    #if (exists($usedgroupsptr->{$ip})) {
	#	my $groups = join(',',@{$usedgroupsptr->{$ip}});
	#	$self->peergroup($groups);
	 #   }
	    next;
	}


	if ($ln =~ /^description (.+)/) {
	    &DebugPR(2,"$modname-ParseXRConfig: Found peer description\n");
	    $self->descr($1);
	    next;
	}

	if ($ln =~ /^shutdown/) {
	    &DebugPR(2,"$modname-ParseXRConfig: Found shutdown peer\n");
	    $self->adminstat(0);
	    next;
	}

	if ($ln =~ /^remove-private-as/) {
	    &DebugPR(2,"$modname-ParseXRConfig: Found remove-private-as\n");
	    if ($chassis =~ /12\d\d\d/) {  
		push(@errorstr,
		     &ErrorPR($self->hostname,
			      "ERROR-PEER",
			      $self->asn . " ( $ip ) has remove-private-as enabled")
		    );
	    }
	    next;
	}


	if ($ln =~ /^address-family (.+) /) { 
            &DebugPR(2,"ParseXRBGP Found address-family $1\n");
	    my $addrfam = $1;

	    if ($addrfam eq 'ipv4 unicast') {
		$addrfam = 'ipv4';
	    }

	    my $afi = $self->afi(undef,$addrfam);
	    $afi->activate(1);

            $ln = shift(@{$confptr});
            if (ref($ln)) {
                my @c2 = @{$ln};
                while ($ln = shift(@c2)) {
                    next if &referr($ln,$self->hostname);

		    $self->CheckXRBGPACL($ln,$aclptr,$afi);
		    if ($ln =~ /^\s*maximum-prefix\s+(\d+)(\s+(\d+))*/) {
			if (defined($self)) {
			    $afi->maxprefix($1);
			}
			&DebugPR(2,"$modname-ParseXRConfig: Found maximum-prefix $1 ");
			if (defined($3)) {
			    &DebugPR(2,"$3 ");
			}
			&DebugPR(2,"\n");
			next;
		    } # maxprefix
                    if( $ln =~ /^\s*use af-group (.+)/) { #need to unwind af-group 
            my $pgname = "af-group-" . $1;
            &DebugPR(3,"$modname-ParseXRConfig: Applying group $pgname\n");

            # in XR we can have multiple neighbor-groups applied
            if (!exists($usedgroupsptr->{$ip})) {
                $usedgroupsptr->{$ip} = [];
            }
            push(@{$usedgroupsptr->{$ip}},$pgname);

            if (exists($groupsptr->{$pgname})) {
		#Testing removing unwind
                #unshift(@{$confptr},@{$groupsptr->{$pgname}});  # Apply the neighbor group to a peer
            } else {
                push(@errorstr,
                     &ErrorPR($self->hostname,
                              "WARN-PEER",                                                                                                                      "$ip is trying to use a group $pgname that isn't defined")                                                              );
            }
            # Should now be ready for next section to do tests on this peer
            next;
                    }#use af-group

		    # check for prefix-list, route-map, distribute-list, filter-list
		    $self->CheckXRBGPACL($ln,$aclptr,$afi);

                }
            } else {
                # opps, wasn't a ref, put it back
                unshift(@{$confptr},$ln);
            }
            &DebugPR(2,"ParseXRBGP done with address-family $addrfam\n");
            next;
        }

    } # while same neighbor 

    #push full peer group list
    if (exists($usedgroupsptr->{$ip})) {
                my $groups = join(',',@{$usedgroupsptr->{$ip}});
                $self->peergroup($groups);
    }


    # Look for Errors

    if ($self->descr eq 'unk') {
	if (!$self->iscogent) {
	    push(@errorstr,
		 &ErrorPR($self->hostname,
			  "WARN-PEER",
			  $self->asn . " ( $ip ) missing description")
		);
	}
    } else {
	my $msg;
	if (($msg = $self->validdesc) && 
	    ($self->adminstat)) {
	    push(@errorstr,
		 &ErrorPR($self->hostname,
			  "WARN-PEER",
			  $self->asn . " ( $ip ) Description $msg")
		);
	}
    }

    if ($self->localas ne '0') {
	my $msg;

	$msg = $self->asn . " ( $ip ) has local-as " . $self->localas . " enabled";

	if ($self->descr ne 'unk') {
	    $msg .= " for peer " . $self->descr;
	}

	push(@errorstr,
	     &ErrorPR($self->hostname,
		      "WARN-PEER",
		      $msg)
	    );
    }

    &DebugPR(3,"$modname-ParseXRConfig: Leaving BGP peer " . $self->asn . "\n") if $main::debug > 3;
    return(\@errorstr);

}




######################################################################
#
# afi - AFI specific info.  return afi handle it exists (generally the case)
#       if it doesn't try to create it 
#
sub afi {
    my $self = shift;
    my $afi = shift;
    my $addrfam = shift;

    return($afi) if defined($afi);

    my $fake = 0;

    if (!defined($addrfam)) {
        # if we have an AFI specific command but haven't seen 
	# an AFI definition, it means we're on an old box and it's
	# ipv4 by default, so create that
	#
	$addrfam = 'ipv4';
	$fake = 1;
    }

    if (exists($self->{addrfam}->{$addrfam})) {
	$afi = $self->{addrfam}->{$addrfam};
    } else {
	$afi = new BGPPeer::AFI;
	$afi->addrfam($addrfam);
	$self->{addrfam}->{$addrfam} = $afi;
	if ($fake) {
	    $afi->activate(1); # "up" by default on non-addr fam boxes
	}
    }

    return($afi);
}

######################################################################
#
#
sub CheckBGPACL {
    my $self = shift;
    my $ln = shift;
    my $aclptr = shift;
    my $afi = shift;

    if (!defined($aclptr)) {
	$aclptr = $ln;
	$ln = $self;
	$self=undef;
    }

    if ($ln =~ /^(prefix-list) (.+) (in|out)/) {
	my $acltype = $1;
	my $aclname = $2;
	my $acldirection = $3;
	&DebugPR(2,"Found applied $acltype $aclname $acldirection\n");

	if (defined($self)) {
	    $afi = $self->afi($afi);
	    if (!defined($afi->prefixlist($acldirection))) {
		&DebugPR(3,"updating prefixlist\n");
		$afi->prefixlist($acldirection,$aclname);
	    }
	}

	if (defined($afi)) {
	    my $type = '';

	    if (ref($afi)) { $type = $afi->addrfam; }
	    else { $type = $afi; }

	    if ($type =~ /ipv4/) {
		$acltype = 'ipv4-' . $acltype;
	    } elsif ($type =~ /ipv6/) {
		$acltype = 'ipv6-'  . $acltype;
	    } else {
		&Carp::cluck("Unidentified Addr family " . $type . "\n");
	    }
	} else { # We'll assume ipv4 if no AFI - not great but best I got
	    $acltype = 'ipv4-' . $acltype;
	}

	$aclptr->UsedACL($acltype,$aclname,$acldirection);

	return($acltype,$aclname,$acldirection);
    }

    if ($ln =~ /^(route-map) (.+) (in|out)/) {
	my $acltype = $1;
	my $aclname = $2;
	my $acldirection = $3;
	&DebugPR(2,"Found applied $acltype $aclname $acldirection\n");
	if (defined($self)) {
	    $afi = $self->afi($afi);
	    #trying dropping the overwrite prevent
	    #if (!defined($afi->routemap($acldirection))) {
		&DebugPR(3,"updating routemap\n");
		$afi->routemap($acldirection,$aclname);
	    #}
	}
	$aclptr->UsedACL($acltype,$aclname,$acldirection);
	return($acltype,$aclname,$acldirection);
    }
				
    if ($ln =~ /^(distribute-list) (.+) (in|out)/) {
	my $acltype = $1;
	my $aclname = $2;
	my $acldirection = $3;
	&DebugPR(2,"Found applied $acltype $aclname $acldirection\n");
	if (defined($self)) {
	    $afi = $self->afi($afi);
	    if (!defined($afi->distributelist($acldirection))) {
		&DebugPR(3,"updating distribute list\n");
		$afi->distributelist($acldirection,$aclname);
	    }
	}
	$aclptr->UsedACL('access-list',$aclname,$acldirection);
	return($acltype,$aclname,$acldirection);
    }
	
    if ($ln =~ /^(filter-list) (.+) (in|out)/) {
	my $acltype = $1;
	my $aclname = $2;
	my $acldirection = $3;
	&DebugPR(2,"Found applied $acltype $aclname $acldirection\n");
	if (defined($self)) {
	    $afi = $self->afi($afi);
	    if (!defined($afi->filterlist($acldirection))) {
		&DebugPR(3,"updating filter list\n");
		$afi->filterlist($acldirection,$aclname);
	    }
	}
	$aclptr->UsedACL('as-path',$aclname,$acldirection);
	return($acltype,$aclname,$acldirection);
    }
    return(0);
}


######################################################################
#
#
sub CheckXRBGPACL {
    my $self = shift;
    my $ln = shift;
    my $aclptr = shift;
    my $afi = shift;

    if (!defined($aclptr)) {
	$aclptr = $ln;
	$ln = $self;
	$self=undef;
    }

    if ($ln =~ /^\s*(route-policy) (.+) (in|out)$/) {
	my $acltype = $1;
	my $aclname = $2;
	my $acldirection = $3;

	my $aclextra = undef;

	if ($aclname =~ /(\S+)\((.+)\)/) {  # options given to route-policy
	    $aclname = $1;
	    $aclextra = $2;

	    $aclextra =~ s/\s+//g;

	    my @extras = split(/,/,$aclextra);

	    foreach my $pset (@extras) {
		$self->CheckXRBGPACL("prefix-list $pset $acldirection",$aclptr,$afi);
	    }
	}

	&DebugPR(2,"Found applied $acltype $aclname $acldirection\n");
	if (defined($self)) {
	    $afi = $self->afi($afi);
	    #if (!defined($afi->routemap($acldirection))) {
		&DebugPR(3,"updating routemap\n");
		$afi->routemap($acldirection,$aclname);
	    #}
	}
	$aclptr->UsedACL($acltype,$aclname,$acldirection);
	return($acltype,$aclname,$acldirection);
    }



    if ($ln =~ /^\s*(prefix-list) (.+) (in|out)/) {
	my $acltype = $1;
	my $aclname = $2;
	my $acldirection = $3;
	&DebugPR(2,"Found applied $acltype $aclname $acldirection\n");

	if (defined($self)) {
	    $afi = $self->afi($afi);
	    if (!defined($afi->prefixlist($acldirection))) {
		&DebugPR(3,"updating prefixlist\n");
		$afi->prefixlist($acldirection,$aclname);
	    }
	}

	if (defined($afi)) {
	    my $type = '';

	    if (ref($afi)) { $type = $afi->addrfam; }
	    else { $type = $afi; }

	    if ($type =~ /ipv4/) {
		$acltype = 'ipv4-' . $acltype;
	    } elsif ($type =~ /ipv6/) {
		$acltype = 'ipv6-'  . $acltype;
	    } else {
		&Carp::cluck("Unidentified Addr family " . $type . "\n");
	    }
	} else { # We'll assume ipv4 if no AFI - not great but best I got
	    $acltype = 'ipv4-' . $acltype;
	}

	$aclptr->UsedACL($acltype,$aclname,$acldirection);

	return($acltype,$aclname,$acldirection);
    }

				
    if ($ln =~ /^\s*(distribute-list) (.+) (in|out)/) {
	my $acltype = $1;
	my $aclname = $2;
	my $acldirection = $3;
	&DebugPR(2,"Found applied $acltype $aclname $acldirection\n");
	if (defined($self)) {
	    $afi = $self->afi($afi);
	    if (!defined($afi->distributelist($acldirection))) {
		&DebugPR(3,"updating distribute list\n");
		$afi->distributelist($acldirection,$aclname);
	    }
	}
	$aclptr->UsedACL('access-list',$aclname,$acldirection);
	return($acltype,$aclname,$acldirection);
    }
	
    if ($ln =~ /^\s*(filter-list) (.+) (in|out)/) {
	my $acltype = $1;
	my $aclname = $2;
	my $acldirection = $3;
	&DebugPR(2,"Found applied $acltype $aclname $acldirection\n");
	if (defined($self)) {
	    $afi = $self->afi($afi);
	    if (!defined($afi->filterlist($acldirection))) {
		&DebugPR(3,"updating filter list\n");
		$afi->filterlist($acldirection,$aclname);
	    }
	}
	$aclptr->UsedACL('as-path',$aclname,$acldirection);
	return($acltype,$aclname,$acldirection);
    }
    return(0);
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
