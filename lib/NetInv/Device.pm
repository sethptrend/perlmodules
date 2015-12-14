# $HeadURL: svn://hhcv-srcctrl.sys.cogentco.com/cogent/rtrtools/trunk/lib/NetInv/Device.pm $
# $Id: Device.pm 224 2008-09-18 14:56:24Z marks $

package NetInv::Device;

use File::Basename;
use Getopt::Long;
use English;
use IO::File;
use strict;
use Data::Dumper;
use POSIX;

######################################################################
sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {
	dev_id => undef,
	hostname => undef,
	hub_id => undef,
	BuildingID => undef,
	NodeNum => undef,
	hardware => undef,
	rancidgrp => undef,   # Here until we have a better way of tracking
	status => undef,      # enum('Active', 'Inactive')
	enable => undef,
	login_id => undef,
	entrydate => undef,
	changedate => undef,
	changeid => undef,
    };
    bless($self,$class);

    return $self;
}

######################################################################
sub dev_id {
    my $self = shift;
    if (@_) { $self->{dev_id} = shift; }
    return $self->{dev_id};
}
######################################################################
sub hostname {
    my $self = shift;
    if (@_) { $self->{hostname} = shift; }
    return $self->{hostname};
}
######################################################################
sub hub_id {
    my $self = shift;
    if (@_) { $self->{hub_id} = shift; }
    return $self->{hub_id};
}
######################################################################
sub BuildingID {
    my $self = shift;
    if (@_) { $self->{BuildingID} = shift; }
    return $self->{BuildingID};
}
######################################################################
sub NodeNum {
    my $self = shift;
    if (@_) { $self->{NodeNum} = shift; }
    return $self->{NodeNum};
}
######################################################################
sub hardware {
    my $self = shift;
    if (@_) { $self->{hardware} = shift; }
    return $self->{hardware};
}
######################################################################
sub rancidgrp {
    my $self = shift;
    if (@_) { $self->{rancidgrp} = shift; }
    return $self->{rancidgrp};
}
######################################################################
sub status {
    my $self = shift;
    if (@_) { 
	my $stat = shift;

	# enum('Active', 'Inactive')

	if ($stat eq 'Active' ||
	    $stat eq 'Inactive') {
	    $self->{status} = $stat;
	}
    }
    return $self->{status};
}
######################################################################
sub enable {
    my $self = shift;
    if (@_) { $self->{enable} = shift; }
    return $self->{enable};
}
######################################################################
sub login_id {
    my $self = shift;
    if (@_) { $self->{login_id} = shift; }
    return $self->{login_id};
}
######################################################################
sub entrydate {
    my $self = shift;
    if (@_) { $self->{entrydate} = shift; }
    return $self->{entrydate};
}
######################################################################
sub changedate {
    my $self = shift;
    if (@_) { $self->{changedate} = shift; }
    return $self->{changedate};
}
######################################################################
sub changeid {
    my $self = shift;
    if (@_) { $self->{changeid} = shift; }
    return $self->{changeid};
}
######################################################################
sub DeviceHash {
    my $self = shift;
    
    my %h = ();

    $h{'dev_id'} = $self->dev_id;
    $h{'hostname'} = $self->hostname;
    $h{'hub_id'} = $self->hub_id;
    $h{'BuildingID'} = $self->BuildingID;
    $h{'NodeNum'} = $self->NodeNum;
    $h{'hardware'} = $self->hardware;
    $h{'rancidgrp'} = $self->rancidgrp;
    $h{'status'} = $self->status;
    $h{'enable'} = $self->enable;
    $h{'login_id'} = $self->login_id;
    $h{'entrydate'} = $self->entrydate;
    $h{'changedate'} = $self->changedate;
    $h{'changeid'} = $self->changeid;

    return(\%h);
}


1;
