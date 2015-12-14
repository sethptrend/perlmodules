#Seth Phillips
#interface to the danadev tables inheriting from Connection.pm
#12/2/13


use strict;
use warnings;
use lib '../';

package Connection::Reporting;
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
        dbname => "Reporting",
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
	my $rec = $self->GetRecord('[V_OrderIDtoGLID]', '[OrderID]', $order);
	return 0 unless defined($rec);
	return $rec->{GLobalLogoID};
}

sub getCustLogobyOrder {
	my $self = shift;
	my $order = shift;
        return 0 unless defined($order);
        my $rec = $self->GetRecord('[V_OrderIDtoGLID]', '[OrderID]', $order);
        return 0 unless defined($rec);
        return ($rec->{CustomerName},$rec->{GlobalLogoID});
}
