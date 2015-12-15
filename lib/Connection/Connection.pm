#Seth Phillips
#Connection::Connection
#12/2/13
#New base class for DBI based objects to facilitate better object oriented design / less cut/paste

use strict;
use warnings;

package Connection::Connection;

use DBI;



######################################################################
sub dbname {
    my $self = shift;
    return ($self->dbname);
}

######################################################################
sub dbhost {
    my $self = shift;
    return ($self->dbhost);
}

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {
        dbh     => undef,
        update  => 1,
#in the base class these are undefined . . . basically base class functions should not work unless inherited
	dbname => undef,
	dbhost => undef,
	dbusr => undef,
	dbpass => undef,
	dbusrro => undef,
	dbpassro => undef,
	dbtype => undef
    };
    bless($self,$class);

    my $ro = shift;

    if ($self->Connect($ro)) {
        return $self;
    } else {
        # An error occured so return undef
        return undef;
    }

}

######################################################################
# Disconnect from the database when the object is destroyed
sub DESTROY {

    my $self = shift;
    $self->Disconnect();
}

sub dbh {
    my $self = shift;
    return $self->{dbh};
}

######################################################################
#the update variable defines whether the caller is allowed to run update commands - mostly deprecated
sub update {
    my $self = shift;

    if (@_) { $self->{update} = shift; }
    return $self->{update};
}

######################################################################
# Connect to the database
sub Connect {
    my $self = shift;
    my $ro = shift;
    my $rv;

    my $dbusr = $self->{dbusr};
    my $dbpass = $self->{dbpass};

    if (defined($ro)) {
        #&DebugPR(0,"$self->dbname::Connect -- Opening DB Read Only\n");
        $dbusr = $self->{dbusrro};
        $dbpass = $self->{dbpassro};
    }
    my $keyword = $self->{dbtype} eq 'mysql' ? 'host': 'server';
    my $dbspec="DBI:$self->{dbtype};database=$self->{dbname};$keyword=$self->{dbhost};";
    $self->{dbh}=DBI->connect($dbspec, $dbusr, $dbpass,{ PrintError=>0 });

    if ($self->{dbh}) {
        $rv=1;
    } else {
        $rv=0;
	print "Connect error " . $DBI::errstr . "\n" if defined($DBI::errstr);
    }

    return $rv;
}

#####################################################################
sub quote {
    my $self = shift;
    my ($str) = @_;

    if (!defined($str)) {
        $str="";
    }
    return $self->{dbh}->quote($str);
}
######################################################################
#Disconnect from the database
sub Disconnect {
    my $self = shift;
    if ($self->{dbh}) {
        $self->{dbh}->disconnect();
    }

    undef $self->{dbh};
}
######################################################################
#
sub DoSQL {
    my $self = shift;
    my $sql = shift;

    my $rv;

    my $noisy = 1;

    $noisy = 0 if ( @_ );

    #&DebugPR(3,"$self->dbname-DoSQL: executing $sql\n");

    if ($self->update) {
        $rv = $self->{dbh}->do($sql);
    } else {
        print ("No Updates - Would have executed:\n$sql\n");
        $rv = 1;
    }

    return $rv;
}
#####################################################################
#Seth 6/5/14 - Set Values
#takes db.table, index name, index value, (key,value) pairs to be assigned
sub SetValues {
   my $self = shift;
   my $table = shift;
   my $index = shift;
   my $id = shift;
   my %pairs = @_;
   my $qry = "Update " . $table . " SET " . join(", ", map {$_. "=".$self->quote($pairs{$_})} keys %pairs) . " WHERE " . $index . "=" . $self->quote($id); 
   #print "$qry\n";
   $self->DoSQL($qry);



}
#####################################################################
#Seth 4/13/15 - InsertValues
#Taking some of the length out of the code, trying to make use of the above function in more ways simply table followed by key,value pairs
sub InsertValues {
  my $self = shift;
  my $table = shift;
  my %pairs = @_;
  #note the string semi-randomizes the keys order, but the keys order matches the values order ALWAYS
  my $qry = "INSERT INTO $table (" . join(", ", keys %pairs) . ") VALUES (" . join(", ", map {$self->quote($_)} values %pairs) . ");";
  #print $qry;
  $self->DoSQL($qry);
  return $qry;#figure returning the query is more helpful for debugging
}
#same function with no key names
sub InsertValuesNoKeys {
  my $self = shift;
  my $table = shift;
  my @values = @_;
  #note the string semi-randomizes the keys order, but the keys order matches the values order ALWAYS
  my $qry = "INSERT INTO $table  VALUES (" . join(", ", map {$self->quote($_)} @values) . ");";
  #print $qry;
  $self->DoSQL($qry);
  return $qry;#figure returning the query is more helpful for debugging
}
######################################################################
#Seth - 8/14/13 added additional option key, val pairs to AND on
sub GetRecord {
    my $self = shift;
    my $table = shift;
    my $keyfield = shift;
    my $value = shift;
    my (@xkey, @xval);
    while(@_) { push @xkey, shift; push @xval, shift;}
    my $qry = "SELECT * FROM $table WHERE $keyfield like "
        .$self->quote($value);
    foreach my $xkey (@xkey)
        {
                my $xval = shift @xval;
                $qry .= " AND $xkey like " . $self->quote($xval);
        }

    my $sth = $self->{dbh}->prepare($qry);
    my $rv = $sth->execute;

    my $entry_ref = $sth->fetchrow_hashref();

    return $entry_ref;
}
#####################################################################
#Seth's addition to give the option of returning an array of records
sub GetRecords {
        my $self = shift;
        my  ($table, $keyfield, $value) = (shift, shift, shift);
         my (@xkey, @xval);
    while(@_) { push @xkey, shift; push @xval, shift;}
    my $qry = "SELECT * FROM $table WHERE $keyfield like "
        .$self->quote($value);
    foreach my $xkey (@xkey)
        {
                my $xval = shift @xval;
                $qry .= " AND $xkey like " . $self->quote($xval);
        }


        return $self->{dbh}->selectall_arrayref($qry, {Slice => {}});
}

#####################################################################
#
#Allows passing of the sql statement
sub GetCustomRecords{

     my $self = shift;
      my $qry = shift;
      return $self->{dbh}->selectall_arrayref($qry, {Slice => {}});
}
sub GetCustomRecord{

     my $self = shift;                                                                my $qry = shift;

    my $sth = $self->{dbh}->prepare($qry);
    my $rv = $sth->execute;

    my $entry_ref = $sth->fetchrow_hashref();

    return $entry_ref;



};

##################################################################
#GetTableRecords (and the lack of a single row grab because it makes little to no sense)
#in: table, out: array of hashes (the whole table)
sub GetTableRecords {
	my $self = shift;
	my $table = shift;
	my $qry = "SELECT * FROM $table;";
	return $self->{dbh}->selectall_arrayref($qry, {Slice => {}});

}


#The GetIndex versions are to use = instead of like
sub GetIndexRecords {
        my $self = shift;
        my  ($table, $keyfield, $value) = (shift, shift, shift);
         my (@xkey, @xval);
    while(@_) { push @xkey, shift; push @xval, shift;}
    my $qry = "SELECT * FROM $table WHERE $keyfield = "
        .$self->quote($value);
    foreach my $xkey (@xkey)
        {
                my $xval = shift @xval;
                $qry .= " AND $xkey = " . $self->quote($xval);
        }


        return $self->{dbh}->selectall_arrayref($qry, {Slice => {}});
}

sub GetIndexRecord {
    my $self = shift;
    my $table = shift;
    my $keyfield = shift;
    my $value = shift;
    my (@xkey, @xval);
    while(@_) { push @xkey, shift; push @xval, shift;}
    my $qry = "SELECT * FROM $table WHERE $keyfield = "
        .$self->quote($value);
    foreach my $xkey (@xkey)
        {
                my $xval = shift @xval;
                $qry .= " AND $xkey = " . $self->quote($xval);
        }

    my $sth = $self->{dbh}->prepare($qry);
    my $rv = $sth->execute;

    my $entry_ref = $sth->fetchrow_hashref();

    return $entry_ref;
}


1;

