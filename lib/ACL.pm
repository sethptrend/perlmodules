# $HeadURL: svn://hhcv-srcctrl.sys.cogentco.com/cogent/rtrtools/trunk/lib/ACL.pm $
# $Id: ACL.pm 304 2009-11-05 16:56:41Z marks $

package ACL;

use Data::Dumper;
use IO::File;
use English;
use POSIX;
use strict;
use warnings;

use MarkUtil;


######################################################################
#
# 
#
sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {
	type      => "unk", # community-list,as-path,access-list,etc
	id        => "unk", # Name or number
	remark    => "",    # remark/comment/description if any
	used      => 0,     # Is this ACL used by something in the config
	created   => 0,     # simple flag to see if ACL is defined on the device
	standard  => 0,     # Tag to know if this is one of our standards
	elements  => []     # this is an array containing the list.
    };

    bless($self,$class);

    return $self;

}
######################################################################
sub type {
    my $self = shift;
    if (@_) { $self->{type} = shift; }
    return $self->{type};
}
######################################################################
sub id {
    my $self = shift;
    if (@_) { $self->{id} = shift; }
    return $self->{id};
}
######################################################################
sub remark {
    my $self = shift;
    if (@_) { $self->{remark} = shift; }
    return $self->{remark};
}
######################################################################
sub used {
    my $self = shift;
    if (@_) { $self->{used} = shift; }
    return $self->{used};
}
######################################################################
sub created {
    my $self = shift;
    if (@_) { $self->{created} = shift; }
    return $self->{created};
}
######################################################################
sub standard {
    my $self = shift;
    if (@_) { $self->{standard} = shift; }
    return $self->{standard};
}
######################################################################
sub elements {
    my $self = shift;
    if (@_) { $self->{elements} = shift; }
    return $self->{elements};
}
######################################################################
#
# ip community-list \d+ permit|deny .*
# ip as-path access-list \d+ permit|deny .*
# ip prefix-list \S+ permit|deny .*    (list ends with !)
# ip access-list \d+ permit|deny .*
# route-map (\S+) permit|deny (\d+)  ($1 = name, $2 = order)
#    match .*  (optional "match" uses other forms of ACL)
#              eg match community 90
#                 match ip address prefix-list permit-pop-subnets
#    set .*    (optional "set" sets attributes) 
######################################################################
#
# Seeing as the elements are just a list, we'll use the standard 
# list functions and see what else we need from that.
#
######################################################################
sub Push {
    my $self = shift;
    if (@_) { push(@{$self->{elements}},shift); }
}
######################################################################
sub Unshift {
    my $self = shift;
    if (@_) { unshift(@{$self->{elements}},shift); }
}
######################################################################
sub Pop {
    my $self = shift;
    return(pop(@{$self->{elements}}));
}
######################################################################
sub Shift {
    my $self = shift;
    return(shift(@{$self->{elements}}));
}
######################################################################
sub dump {
    my $self = shift;
    my $str = '';

    $str = "Dumping ACL  ";
    $str .= Data::Dumper->Dump([$self],[qw(*self)]);
    
    if (@_) { 
	print $str;
    }
    return($str);
}


1;
