# $HeadURL: svn://hhcv-srcctrl.sys.cogentco.com/cogent/rtrtools/trunk/lib/Cogent/ACL.pm $
# $Id: ACL.pm 304 2009-11-05 16:56:41Z marks $

package Cogent::ACL;

use strict;
use warnings;

use Data::Dumper;
use MarkUtil;

use ACL;

our $modname = 'Cogent::ACL';

######################################################################
sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {
        acls     => {
		'community-list'        => {},
		'as-path'               => {},
		'prefix-list'           => {},
		'access-list'           => {},
		'route-map'             => {},
		'access-list extended'  => {},
		'explicit-path'         => {},
		'class-map'             => {},
		'policy-map'            => {},
		'pseudowire-class'      => {}
	}
    };
    bless($self,$class);

    return $self;
}

######################################################################
sub DESTROY {
    my $self = shift;

    $self->{acls} = undef;
}
######################################################################
sub acls {
    my $self = shift;
    if (@_) { $self->{acls} = shift; }
    return $self->{acls};
}
######################################################################
sub FoundACL {
    my $self = shift;
    my $acltype = shift;
    my $aclname = shift;

    my $aclhptr = $self->acls;

    if (@_) {

	&DebugPR(3,"$modname-FoundACL: Creating/updating - $acltype -- $aclname\n");

	my $aclrule = shift;
	
	my $acl; 

	if (!(exists($aclhptr->{$acltype}->{$aclname}))) {
	    $acl = new ACL;

	    $acl->type($acltype);
	    $acl->id($aclname);
	    $aclhptr->{$acltype}->{$aclname} = $acl;
	    &DebugPR(5,"$modname-FoundACL: new entry for $acltype -> $aclname\n");
	}

	$acl = $aclhptr->{$acltype}->{$aclname};

	if ($aclrule =~ /remark\s+(\S.*)/) {
	    $acl->remark($1);
	}

	$acl->created(1);
	$acl->Push($aclrule);

    } else {
	if (exists($aclhptr->{$acltype}->{$aclname})) {
	    return($aclhptr->{$acltype}->{$aclname});
	} else {
	    return(undef);
	}
    }
}

######################################################################
sub CheckACL {
    my $self = shift;
    my $router = shift;
    my $ccerrorptr = shift;
    
    my %acls = %{$self->acls};
    
    my $acltype;
    my $aclname;

    foreach $acltype (sort(keys(%acls))) {
	foreach $aclname (sort(keys(%{$acls{$acltype}}))) {
	    my $acl = $acls{$acltype}->{$aclname};

	    if (defined($acl)) {
		if ($acl->used && !($acl->created)) {
		    if ($acl->used eq 'default') {
			push(@{$ccerrorptr},
			     &ErrorPR($router,
			     "WARN-ACL",
			     $acl->type . " " . 
			     $acl->id . " Template default never created or is empty")
			    );
		    } else {
			push(@{$ccerrorptr},
			     &ErrorPR($router,
			     "ERROR-ACL",
			     $acl->type . " " . 
			     $acl->id . " APPLIED but never created or is empty")
			    );
		    }
		} elsif ($acl->created && !($acl->used)) {
			push(@{$ccerrorptr},
			     &ErrorPR($router,
				 "WARN-ACL",
				 $acl->type . " " . 
				 $acl->id . " created but never used")
			    );
		}
	    }
	}
    }
}

######################################################################
sub UsedACL {
    my $self = shift;
    my $acltype = shift;
    my $aclname = shift;

    my $aclhptr = $self->acls;

    if (@_) {

	&DebugPR(3,"$modname-UsedACL: Creating/updating - $acltype -- $aclname\n");

	my $acldirection = shift;

	my $acl; 

	if (!(exists($aclhptr->{$acltype}->{$aclname}))) {
	    $acl = new ACL;

	    $acl->type($acltype);
	    $acl->id($aclname);
	    $aclhptr->{$acltype}->{$aclname} = $acl;
	    &DebugPR(5,"$modname-UsedACL: new entry for $acltype -> $aclname\n");
	}

	$acl = $aclhptr->{$acltype}->{$aclname};

	if (!($acl->used)) {
	    $acl->used($acldirection);
	} else {
	    my $used = $acl->used;
	    if ($used =~ /$acldirection/) {
		# Direction already noted, ignore
	    } else {
		$acl->used($used . "-$acldirection");
	    }
	}
    } else {
	if (exists($aclhptr->{$acltype}->{$aclname})) {
	    return($aclhptr->{$acltype}->{$aclname});
	} else {
	    return(undef);
	}
    }
}
######################################################################
sub dump {
    my $self = shift;
    my $str = '';

    $str = "Dumping $modname  ";
    $str .= Data::Dumper->Dump([$self],[qw(*self)]);
    
    if (@_) { 
        print $str;
    }
    return($str);
}


1;


