# $HeadURL: svn://hhcv-srcctrl.sys.cogentco.com/cogent/rtrtools/trunk/lib/Cogent/Jabber/MUC.pm $
# $Id: MUC.pm 362 2010-11-03 19:18:42Z marks $

package Cogent::Jabber::MUC;

use strict;
use warnings;

use Data::Dumper;
use MarkUtil;

use Cogent::Jabber;

######################################################################
sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {
	parent => undef,  # parent object
	room => undef,
	nick => undef
    };
    bless($self,$class);

    $self->{parent} = shift;
    $self->room(shift);
    $self->nick(shift);

    return(undef) if (!defined($self->{parent}));

    if (defined($self->room) && defined($self->nick)) {
	my $rv = $self->JoinRoom;
	if (defined($rv)) {
	    return($self);
	} else {
	    return(undef);
	}
    }
}

######################################################################
# Disconnect from the Jabber server when the object is destroyed
sub DESTROY {   
    my $self = shift;
    $self->LeaveRoom;
}
######################################################################
sub room {
    my $self = shift;
    if (@_) { $self->{room} = shift; }
    return $self->{room};
}
######################################################################
sub nick {
    my $self = shift;
    if (@_) { $self->{nick} = shift; }
    return $self->{nick};
}
######################################################################
sub mucserver {
    my $self = shift;

    return("conference." . $self->{parent}->domain);
}
######################################################################
sub roomjid {
    my $self = shift;

    return($self->room . '@' . $self->mucserver);
}
######################################################################
sub myroomjid {
    my $self = shift;

    return($self->roomjid . '/' . $self->nick);
}
######################################################################
sub JoinRoom {
    my $self = shift;

    return($self->{parent}->{jh}->MUCJoin( room   => $self->room,
					    server => $self->mucserver,
					    nick   => $self->nick,
					    history => "maxchars='0'"));

}

######################################################################
sub LeaveRoom {
    my $self = shift;

    return(undef) if (!defined($self->{parent}) ||
	!defined($self->{parent}->{jh}));

    my $rv = $self->{parent}->{jh}->PresenceSend(from => $self->{parent}->jid,
						  to => $self->myroomjid,
						  type => 'unavailable');

    sleep(1);
    return($rv);
}
######################################################################
sub Send {
    my $self = shift;
    my $msg = shift;
    
    return(undef) if !defined($msg);

    &DebugPR(3,"Cogent::Jabber::MUC::Sending $msg\n");
    my %mesg = (
#	from => $self->myroomjid,  # looks like they changed how you ID yourself
	from => $self->{parent}->jid,
	to=> $self->roomjid,
	type => 'groupchat',
	body=> $msg
    );

    &DebugPR(3,"Cogent::Jabber::MUC::Sending hash:\n" . Dumper(\%mesg)) if $main::debug > 3;

    my $rv = $self->{parent}->Send(\%mesg);
    return($rv);
}
######################################################################
sub Process {
    my $self = shift;

    return($self->{parent}->Process);
}



1; 
