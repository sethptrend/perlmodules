# $HeadURL: svn://hhcv-srcctrl.sys.cogentco.com/cogent/rtrtools/trunk/lib/Cogent/Jabber.pm $
# $Id: Jabber.pm 362 2010-11-03 19:18:42Z marks $

package Cogent::Jabber;

use strict;
use warnings;

use Net::Jabber;

use Data::Dumper;
use MarkUtil;

use Cogent::Jabber::MUC;

my $server = 'us.jabber.cogentco.com';
my $domain = 'cogentco.com';
my $port = 5222;
my $username = 'monitor.jabber-lib';
my $password = 'mv/48ilDP';

######################################################################
sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {
        jh       => new Net::Jabber::Client(),
	domain   => $domain || $server,
	server   => $server,
	username => $username,
	resource => undef
    };
    bless($self,$class);

    $self->resource(shift);

    &DebugPR(5,"Cogent::Jabber::New - connecting\n");

    my $stat = $self->Connect;

    &DebugPR(5,"Cogent::Jabber::New - connected\n");

    if (!($stat)) {
        return $self;
    } else {
        # An error occured so return undef
	&DebugPR(3,"Cogent::Jabber::New - $stat\n");
        return undef;
    }

}

######################################################################
# Disconnect from the Jabber server when the object is destroyed
sub DESTROY {   

    my $self = shift;
    $self->Disconnect();
    $self->{jh} = undef;
}
######################################################################
sub resource {
    my $self = shift;
    if (@_) { $self->{resource} = shift; }
    return $self->{resource};
}
######################################################################
sub server {
    my $self = shift;
    if (@_) { $self->{server} = shift; }
    return $self->{server};
}
######################################################################
sub domain {
    my $self = shift;
    if (@_) { $self->{domain} = shift; }
    return $self->{domain};
}
######################################################################
sub username {
    my $self = shift;
    if (@_) { $self->{username} = shift; }
    return $self->{username};
}
######################################################################
sub jid {
    my $self = shift;
    return ($self->username . '@' . $self->domain . '/' . $self->resource);
}
######################################################################
# Connect to the Jabber Server
sub Connect {
    my $self = shift;

    my $rv = 'No resource defined';

    return ($rv) if !defined($self->resource);  # must define resource

    if (!defined($self->{jh})) { # must be a reconnection
	$self->{jh} = new Net::Jabber::Client();
    }

    my $status = $self->{jh}->Connect(hostname=>$self->server,
				      port=>$port,
#### Need to fix TLS bug	      tls=>1
	);


    if (defined($status)) {
	&DebugPR(3,"Cogent::Jabber::Connect Connected to $server:$port\nAttempting AuthSend\n");

	my @result = $self->{jh}->AuthSend(username=>$self->username,
					   password=>$password,
					   resource=>$self->resource);

	if ($result[0] eq "ok") {
	    &DebugPR(2,"Cogent::Jabber::Connect Logged in to $server:$port\n");
	    $rv = 0;

#	    $self->{jh}->SetCallBacks(message=>\&Cogent::Jabber::RcvdMessage($self),
#				      presence=>\&Cogent::Jabber::RcvdPresence,
#				      iq=>\&Cogent::Jabber::RcvdIQ
#		);


	} else {
	    $rv = "Connect Authorization failed: $result[0] - $result[1]";
	}
    } else {
	$rv = "Jabber server is down or connection was not allowed.\n($!)";
    }

    return $rv;
}

######################################################################
#Disconnect from the database
sub Disconnect {
    my $self = shift;
    if (defined($self->{jh})) {
        $self->{jh}->Disconnect();
    }
    $self->{jh} = undef;
}
######################################################################
sub isconnected {
    my $self = shift;
    if (defined($self->{jh})) { return(1); }
    else                      { return(0); }
}
######################################################################
sub JoinRoom {
    my $self = shift;
    my $room = shift;

    my $mucserver = "conference." . $self->domain;

    return undef if !defined($room);

    &DebugPR(2,"Cogent::Jabber::JoinRoom Joining $room\n");

    my $mucptr = new Cogent::Jabber::MUC($self,$room,$self->resource);

    return($mucptr);
}

######################################################################
sub Process {
    my $self = shift;
    my $timeout = shift // 1;

    my $rv = undef;

    if ($self->isconnected) {
	&DebugPR(3,"Cogent::Jabber::Process checking for messages\n");
	$rv = $self->{jh}->Process($timeout);
    }

    return($rv);
}
######################################################################
sub Send {
    my $self = shift;
    my $hptr = shift;

    my $rv = undef;

    if (!defined($self->Process)) {
	warn "Disconnected from Jabber server\n";
	$self->Disconnect;
    } else {
	&DebugPR(3,"Cogent::Jabber::Send\n");
	$rv = $self->{jh}->MessageSend(%{$hptr});
	sleep(1);
    }
    return($rv);

}

######################################################################
sub RcvdMessage {
    my $self = shift;
    my $sid = shift;
    my $message = shift;

    if (!defined($sid)) {
	warn "RcvdMessage: sid not defined";
	return;
    }

    if (!defined($message)) {
	warn "RcvdMessage: message not defined";
	return;
    }

    
    my $type = $message->GetType();
    my $fromJID = $message->GetFrom("jid");
    
    my $from = $fromJID->GetUserID();
    my $resource = $fromJID->GetResource();
    my $subject = $message->GetSubject();
    my $body = $message->GetBody();
    
    print "===\n";
    print "Message: ($type)\n";
    print "   From: $from ($resource)\n";
    print "Subject: $subject\n";
    print "   Body: $body\n";
    print "===\n";
    print $message->GetXML(),"\n";
    print "===\n";

}
######################################################################
sub RcvdPresence {
#    my $self = shift;

    my $sid = shift;
    my $presence = shift;

    if (!defined($sid)) {
	warn "RcvdPresence: sid not defined";
	return;
    }

    if (!defined($presence)) {
	warn "RcvdPresence: presence not defined";
	return;
    }
    
    my $from = $presence->GetFrom();
    my $type = $presence->GetType();
    my $status = $presence->GetStatus();
    if (0) {
        print "===\n";
        print "Presence\n";
        print "  From $from\n";
        print "  Type: $type\n";
        print "  Status: $status\n";
        print "===\n";
        print $presence->GetXML(),"\n";
        print "===\n";
    }

}
######################################################################
sub RcvdIQ {
#    my $self = shift;

    my $sid = shift;
    my $iq = shift;

    if (!defined($sid)) {
	warn "RcvdIQ: sid not defined";
	return;
    }

    if (!defined($iq)) {
	warn "RcvdIQ: iq not defined";
	return;
    }

    
    my $from = $iq->GetFrom();
    my $type = $iq->GetType();
    my $query = $iq->GetQuery();
    my $xmlns = $query->GetXMLNS();
    if (0) {
        print "===\n";
        print "IQ\n";
        print "  From $from\n";
        print "  Type: $type\n";
        print "  XMLNS: $xmlns";
        print "===\n";
        print $iq->GetXML(),"\n";
        print "===\n";
    }
}


1; 
