#Seth Phillips
#interface to the danadev tables inheriting from Connection.pm
#12/2/13


use strict;
use warnings;
use lib '../';

package Connection::TLG;
use Connection::Connection;
our @ISA = ('Connection::Connection');



#only overwritten portion is the constructor which defines the database
sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {
        dbh     => undef,
        update  => 1,
#in the base class these are undefined . . . basically base class functions should not work unless inherited
        dbname => "TLG",
        dbhost => 'dca-05.ms.cogentco.com',
        dbusr => 'LogoID_Script',
        dbpass => 'TUbr9tEtu92D',
        dbusrro => undef,
        dbpassro => undef,
        dbtype => 'Sybase'
    };
    bless($self,$class);

    my $ro = shift;

    if ($self->Connect($ro)) {
        return $self;
    }
        # An error occured so return undef
        return undef;

}

#tlg specific functions
sub getLogoIDbyOrder {
        my $self = shift;
        my $order = shift;
        return 0 unless defined($order);
	my $rec = $self->GetRecord('[V_SDScoreCard]', '[OrderID]', $order);
	return 0 unless defined($rec);
	return $rec->{GlobalLogoID};
}

sub getCustLogobyOrder {
	my $self = shift;
	my $order = shift;
        return 0 unless defined($order);
        my $rec = $self->GetRecord('[V_SDScoreCard]', '[OrderID]', $order);
        return 0 unless defined($rec);
        return ($rec->{CustomerName},$rec->{GlobalLogoID});
}


sub getInProgressOrders{
	my $self = shift;
	#note this returns in progress, I intentionally didn't weed out Off-net
	my $ret = $self->{dbh}->selectall_arrayref('select [OrderID] from [TLG].[dbo].[V_SDScoreCard] where [ProvOrderStatus] not in (\'Completed\',\'Deleted\',\'Cancelled\') and [ProvOrderStatus] not like \'Rejected%\' and [SDGoodOrder] like \'YES\' and [OnNetTypeInt]=1');
	return 0 unless ref($ret);
	return $ret;
}

sub getMacOrderListbyOrderID {
	my $self = shift;
	my $id = shift;
	my $sth = $self->{dbh}->prepare("select [MacOrderList] from TLG.mjain.OPM_Order_Details where [OrderId] like \'$id\'");
    	my $rv = $sth->execute;
	return 0 unless $rv;

    	my $entry_ref = $sth->fetchrow_hashref();
	return 0 unless ref($entry_ref);
	return $entry_ref->{'MacOrderList'};
}

sub pairMatches {
	my $self = shift;
	my $id1 = shift;
	my $id2 = shift;
	#print "Ids: $id1, $id2\n";
	my $rv1 = $self->GetRecord('[TLG].[dbo].[V_SDScoreCard]', 'OrderID', $id1);
	my $rv2 = $self->GetRecord('[TLG].[dbo].[V_SDScoreCard]', 'OrderID', $id2);
	return 0 unless $rv1;
	return 0 unless $rv2;
	#print "\t were found in db\n";
	return 0 unless $rv1->{'OnNetTypeInt'} eq '1';
	#print "\t matched type\n";
	return 0 unless $rv1->{'ProductCode'} eq $rv2->{'ProductCode'};
	#print "\t matched code\n";
	return 0 unless $rv1->{'CDR'} eq $rv2->{'CDR'};
	#print "\t matched cdr\n";
	return 0 unless $rv1->{'NodeID'} eq $rv2->{'NodeID'};
	#print "\t matched nodeid\n";
	
	return 1;
}

sub get2013Orders{
        my $self = shift;
        #note this returns in progress, I intentionally didn't weed out Off-net
        my $ret = $self->{dbh}->selectall_arrayref('select [OrderID] from [TLG].[dbo].[V_SDScoreCard] where ([OrderCompletedDt] between \'01/01/2013\' and \'12/31/2013\') and [SDGoodOrder] like \'YES\' and [OnNetTypeInt]=1');                                                                                  return 0 unless ref($ret);
        return $ret;
}


	
