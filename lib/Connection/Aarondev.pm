#Seth Phillips
#interface to the danadev tables inheriting from Connection.pm
#12/2/13


use strict;
use warnings;
use lib '../lib';

package Connection::Aarondev;
use Connection::Connection;
our @ISA = ('Connection::Connection');
#DO NOT INCLUDE OTHER LIBRARIES HERE, NO CIRCULAR BS


#only overwritten portion is the constructor which defines the database
sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {
        dbh     => undef,
        update  => 1,
#in the base class these are undefined . . . basically base class functions should not work unless inherited
        dbname => "aarondev",
        dbhost => 'cyclops.sys',
        dbusr => 'aaronw',
        dbpass => 'oline123',
        dbusrro => undef,
        dbpassro => undef,
        dbtype => 'mysql'
    };
    bless($self,$class);

    my $ro = shift;

    if ($self->Connect($ro)) {
        return $self;
    }
        # An error occured so return undef
        return undef;

}

#Aarondev specific functions

sub GetHighestBundleCore{
 my $self = shift;
 my $rec = $self->GetCustomRecord('SELECT * FROM `bundlecore` order by bundleid desc;');
 return 0 unless $rec;
 return $rec->{bundleid};
}

sub AddFreeBundleCore{
 my $self = shift;
 my $id = $self->GetHighestBundleCore();
 return 0 unless $id < 2999; #think we're not going over 3k, not sure it matters much
 $id++;
 $self->DoSQL("INSERT INTO bundlecore VALUES ($id, '', '', 0, '');");
 return $id;
}

sub GetHighestBundleCustomer{
 my $self = shift;
 my $rec = $self->GetCustomRecord('SELECT * FROM `bundlecustomer` order by bundleid desc;');
 return 0 unless $rec;
 return $rec->{bundleid};
}

sub AddFreeBundleCustomer{
 my $self = shift;
 my $id = $self->GetHighestBundleCustomer();
 return 0 unless $id < 4999; #Customers get 4000-4999
 $id++;
 $self->DoSQL("INSERT INTO bundlecustomer VALUES ($id, '', 0, '');");
 return $id;
}



1;
