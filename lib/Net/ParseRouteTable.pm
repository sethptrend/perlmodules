# This started as this guys stuff... but I had to fix it because it was
# fubar.  I'm starting to think I'd have been better off writing it from 
# scratch myself.  Removed Juniper crud to make it less confusing and easier
# to debug.
#
# Net::ParseRouteTable -  A Perl object for reading routing table data from
#	log files collected from a router's command-line interface
#
# Copyright (c) 2001  Sean McCreary <mccreary@pch.net>
#
# See COPYRIGHT section in pod text below for usage and distribution rights.
#
# old Id: ParseRouteTable.pm,v 1.7 2003/09/16 13:02:23 plonka Exp

# $HeadURL: svn://hhcv-srcctrl.sys.cogentco.com/cogent/rtrtools/trunk/lib/Net/ParseRouteTable.pm $
# $Id: ParseRouteTable.pm 431 2012-06-22 15:38:27Z hkilmer $

package Net::ParseRouteTable;

require 5;

use strict;
use Carp;
use IO::File;
use vars qw($VERSION
            $Revision
            $debug
           );

$VERSION = "0.01";
$Revision = substr(q$Revision: 431 $, 10);
$debug = $ENV{Net_ParseRouteTable_debug} || 0;
#$debug = 1;

## Creates an object that refers to a raw route table
sub new($$) {
    my ($class, $opts) = @_;
    my $self = {};

    return bless _init($self, $opts), $class;
}

## Does the actual work to initialize the object
sub _init($$) {
    my ($self, $opts) = @_;
    my $filename;
    my $fh;

## Copy options into object
    foreach my $option ( keys %{$opts} ) {
        $self->{$option} = $opts->{$option};
    }

## Open file
    if ( ! defined $self->{"handle"} ) {
        if ( ! ( $filename = $self->{"filename"} ) ) {
            croak("Must supply either a file handle or filename");
        }
        if ( $filename =~ /\.gz$/ ) { 
            open(INFILE,"gzip -dc $filename|") ||
                    die("Can't open $filename: $!\n");
        } else {
            open(INFILE,"< $filename") || die("Can't open $filename: $!\n");
        }
        $fh = \*INFILE;
        $self->{"handle"} = $fh;
    } else {
	$fh = $self->{"handle"};
    }
    $self->{"end_of_table"} = 0;

## Default parsing options
    if ( ! defined($self->{"parse"}) ) {
        %{$self->{"parse"}} = (
		"prefix"            => 1,
		"masklen"	    => 1,
		"nexthop"           => 1,
		"aspath"            => 1,
		"status_code"       => 1,
		"origin_code"       => 1,
		"med"               => 1,
		"locprf"            => 1,
		"weight"            => 1,
		"metric1"	    => 1,
		"metric2"           => 1,
		"best"		    => 1,
        );
    } 

## Seek to beginning of table
##    Look for column headers

    die "FH Not defined" if (!defined($fh));

    while(<$fh>) {      if (/Network\s+Next Hop\s+Metric LocPrf Weight Path/) {
				$self->{"type"} = "Cisco"; last;
			}
	}		
    if ( eof($fh) ) {
        croak "Route table not found";
    }

    return $self;
}

sub next_row($) {
    my $self = shift;
    my $fh = $self->{"handle"};
    my $data;				# Pointer to hash of parsed values

    if ( eot($self) ) {
        return undef;
    }
    if ( eof($fh) ) {
        return undef;
    }

    $self->{"row"} = <$fh>;

    carp "parsing '" . $self->{"row"} . "'\n" if $debug;

## Check for router prompt at end of table
    if ($self->{"row"} =~ /^[A-Za-z0-9\.\-]+(#)/) {
	carp "End of table found!\n" if $debug;
        $self->{"end_of_table"} = 1;
        return undef;
    } else {
        if ( $self->{"parse"}{"status_code"} ) {
            $data->{"status_code"} = _parse_status($self);
        }
        if ( $self->{"parse"}{"prefix"} || $self->{"parse"}{"masklen"} ) {
	    my $multiline = 0;
            ($data->{"prefix"}, $data->{"masklen"}, $data->{"nexthop"}, $data->{"best"}, $multiline)
		= _parse_prefix($self);

	    if ($multiline) {
		$self->{"row"} = <$fh>;
		carp "parsing2 '" . $self->{"row"} . "'\n" if $debug;
	    }

            if ( $self->{"parse"}{"nexthop"}
                         && ( ! defined($data->{"nexthop"}) ) ) {
                $data->{"nexthop"} = _parse_nexthop($self);
            }
        }
        if ( $self->{"parse"}{"aspath"} ) {
            ($data->{"aspath"}, $data->{"origin_code"}) = _parse_aspath($self);
        } elsif ( $self->{"parse"}{"origin_code"} ) {
            $data->{"origin_code"} = _parse_origin($self);
        }
        if ( $self->{"parse"}{"med"} ) {
            ($data->{"med"}) = _parse_med($self);
        }
        if ( $self->{"parse"}{"locprf"} ) {
            ($data->{"locprf"}) = _parse_locprf($self);
        }
        if ( $self->{"parse"}{"weight"} ) {
            ($data->{"weight"}) = _parse_weight($self);
        }
    }
    return $data;
}

sub _parse_prefix($) {
    my ($self) = @_;
    my ($network, $masklen, $nexthop, $best, $regexp, $multiline);
    $best = 0;
    $multiline = 0;
    $regexp = '(\d+\.\d+\.\d+\.\d+)(?:/|)((?:\d*|))\s+(\d+\.\d+\.\d+\.\d+)';

    if ($self->{"type"} eq "Cisco" && substr($self->{"row"}, 1,1) eq ">") {$best = 1;}
    if ( $self->{"row"} =~ m,${regexp},) {
        $network = $1;
        $masklen = $2;
        $nexthop = $3;
        carp "Found new prefix $network/$masklen" if $debug;
        if ( ! defined $network ) {
            carp "Can't determine network: $_\$";
        } elsif ( $masklen eq "" ) {
## Guess prefix length based on class of network
            $masklen = _guess_netmask($network);
            if ( $masklen eq "" ) {
                carp "Can't determine prefix length: $network";
            } else {
                carp "Using length $masklen for network $network" if $debug;
            }
        }
## Save new prefix for subsequent rows
        @{$self->{"old_prefix"}} = ($network, $masklen);
    } else {
	$regexp = '(\d+\.\d+\.\d+\.\d+)(?:/|)((?:\d*|))\r\n$';
	if ( $self->{"row"} =~ m,${regexp},) {
	    # Long line where Cisco wraps it to another line (which is stupid but there it is)

	    $network = $1;
	    $masklen = $2;
	    $multiline = 1;

	    carp "Found new prefix $network/$masklen" if $debug;
	    if ( ! defined $network ) {
		carp "Can't determine network: $_\$";
	    } elsif ( $masklen eq "" ) {
## Guess prefix length based on class of network
		$masklen = _guess_netmask($network);
		if ( $masklen eq "" ) {
		    carp "Can't determine prefix length: $network";
		} else {
		    carp "Using length $masklen for network $network" if $debug;
		}
	    }
	    undef $nexthop;
## Save new prefix for subsequent rows
	    @{$self->{"old_prefix"}} = ($network, $masklen);

	} else {
## Use previous prefix for current row
	    ($network, $masklen) = @{$self->{"old_prefix"}};
	    undef $nexthop;
	    carp "Reusing prefix $network/$masklen" if $debug;
	}
    }
    return ($network, $masklen, $nexthop, $best, $multiline);
}

## Determine class of network, return natural (classful) mask length
sub _guess_netmask($) {
    my $network = shift;
    my ($first_octet, $length);

    if ( $network =~ /^(\d+)/ ) {
        $first_octet = $1;
        if ( ! ( $first_octet & 0x80 ) ) {
## Class A networks have first bit = 0
##      Check for default route
            if ( $network eq "0.0.0.0" ) {
                $length = 0;
            } else {
                $length = 8;
            }
        } elsif ( ! ( $first_octet & 0x40 ) ) {
## Class B networks have first two bits = 10
            $length = 16;
        } elsif ( ! ( $first_octet & 0x20 ) ) {
## Class C networks have first three bits = 110
            $length = 24;
        } else {
## Multicast or experimental addresses have first three bits = 111
            carp "Invalid network: $network\n";
            $length = "";
        }
    } else {
        carp "Can't extract first octet from $network";
        $length = "";
    }
    return $length;
}

## Parse nexthop
##  Only called if _parse_prefix didn't find a nexthop, but doesn't depend
##	on prefix being absent from the line
sub _parse_nexthop($) {
    my ($self) = @_;
    my $nexthop;

    carp "Line read:  $self->{'row'}\n" if $debug > 4;
    if ( $self->{"row"} =~ /\s+\>?(\d+\.\d+\.\d+\.\d+\,?)\s+/ ) {
        $nexthop = $1;
    } elsif ($self->{"row"} =~ /\s+Reject\s+/ ) { carp "Not using Reject route: " . $self->{"row"} if $debug > 4;
    } else { carp "Nexthop not found: " . $self->{"row"}; }

    carp "Next Hop = $nexthop" if $debug > 4;
    return $nexthop;
}

sub _parse_aspath($) {
    my ($self) = @_;
    my ($aspath, $origin_code);
    my $data;

## The weight field moves around (up to 3 columns to the right), but at
##	least it is always present (unlike the MED and Local Pref fields)
##	Try parsing end of weight vaue with AS path
##	Trim off the first 54 characters to limit mistakes
    $data = substr( $self->{"row"}, 54 );
    if ( $data =~
## The AS path can be null!!
#	/\d+\s+((?:[1-9]\d* |\{[\d[\s|,]+\} )*)(e|i|E|I|\?)\s*$/
	/\d+\s+((?:[1-9]\d* |\{[\S]+\} )*)(e|i|E|I|\?)\s*$/
	## AS Set stuff messes us up!
            ) {
        $aspath = $1;
        $origin_code = $2;
## Trim trailing space from AS path
        $aspath =~ s/ $//;
    } else {
        carp "Can't determine AS path: " . $self->{"row"};
    }
    return ($aspath, $origin_code);
}

sub _parse_status($) {
    my $regexp;
    my ($self) = @_;
    my $status_code;
    $regexp = "...";

    if ( $self->{"row"} =~ /^(${regexp})/ ) {
        $status_code = $1;
    } else {
        carp "Can't determine status code: " . $self->{"row"};
    }
    return $status_code;
}

sub _parse_origin($) {
    my ($self) = @_;
    my $origin_code;

    if ( $self->{"row"} =~ /(e|i|E|I|\?)\s*$/ ) {
        $origin_code = $1;
    } else {
        carp "Can't determine origin code: " . $self->{"row"};
    }
    return $origin_code;
}

## Generic routine for extracting numeric value from a field with fuzzy
##	edges, including the possibility that no number actually appears in
##	the data file.
##	$field_end should be set to the column of the end of the
##	field.
##
## XXX  This routine assumes the columns will never be shifted so much that
##	the final column of any field is actually part of the previous field.
sub _parse_numeric($$) {
    my ($self,$field_end) = @_;
    my @data;
    my $index;
    my $value = "";

##	Break line into list of individual characters
    @data = split //, $self->{"row"};
##  Check for digit at $field_end
##  Look up to 3 columns to the right for a digit if none is found
    for ($index = $field_end; $index <= $field_end + 3; $index++) {
        last if $data[$index] =~ /\d/;
    }
##	Walk backwards looking for leading whitespace
    for ($index--; $index >= 0; $index--) {
        last if $data[$index] =~ /\s/;
    }
##	Add digits until next whitespace
    for ($index++; $index < @data; $index++) {
##	End search at first whitespace
        last if $data[$index] =~ /\s/;
        if ( $data[$index] =~ /\d/ ) {
            $value .= $data[$index];
        } else {
##	Abort if non-digit found
            carp "Unexpected character $data[$index] in " . $self->{"row"};
            $value = "";
            last;
        }
    } 
    return ($value, $index);
}

## The MED field:  Characters 38 through 43
sub _parse_med($) {
    my ($self) = @_;
     
    return _parse_numeric($self,43);
}

sub _parse_metric1($) {
    my ($self) = @_;

    return _parse_numeric($self,28);
} 

## The Local Pref field:  Characters 45 through 50
sub _parse_locprf($) {
    my ($self) = @_;
     
    return _parse_numeric($self,50);
}

sub _parse_metric2($) {
    my ($self) = @_;
    return _parse_numeric($self,39);
}

## The Weight field:  Characters 52 through 57-59
##	This field tends to migrate up to 3 columns to the right, but at
##	least it is always there.
sub _parse_weight($) {
    my ($self) = @_;
    my @data;
    my $index;
     
##      Break line into list of individual characters
    @data = split //, $self->{"row"};
##	Search for the first digit after column 56
    for ($index = 57; $index < @data; $index++) {
        last if $data[$index] =~ /\d/;
    }
##	Look for whitespace after that digit
    for ($index++; $index < @data; $index++) {
        last if $data[$index] =~ /\s/;
    }
## 	We've located the true end of the weight field, so we can use the
##	generic algorithm to extract the value
    return _parse_numeric($self,--$index);
}

sub eot($) {
    my ($self) = @_;

    return $self->{"end_of_table"};
}

sub eof($) {
    my ($self) = @_;
    my $fh = $self->{"handle"};

    return eof($fh);
}

sub DESTROY($) {
    my ($self) = @_;

    close ($self->{"handle"});
}

1;
__END__

=head1 NAME

Net::ParseRouteTable - Generic Perl Parser for Raw Routing Table Data

=head1 SYNOPSIS

  use Net::ParseRouteTable;

  my $table = new Net::ParseRouteTable \%options;

  $table->next_row();
  $table->eot();
  $table->eof();

  undef $table; # Destroys RouteTable object

=head1 DESCRIPTION

Net::ParseRouteTable is a Perl object for reading data from session logs of
a command-line session on a router.  This first version only supports the
output of `show ip bgp' from a Cisco router.

=head1 METHODS

=over 4

=item B<new> - Create a new routing table object

    $table = new Net::ParseRouteTable \%options;

Creates a new routing table object, opening the supplied raw data file and
seeking to the beginning of the first table of the appropriate type in the
file.  The parameter must be a hash, and the filename containing the raw
data must be stored under the key `filename' in that hash.

The user can optimize performance by disabling parts of the parser that would
spend time extracting undesired fields from the raw table.  To disable
specific field, include a hash under the key `parse' in the options passed
to new, e.g.

        %{$options{"parse"}} = (
		"prefix"            => 1,
		"masklen"	    => 1,
		"nexthop"           => 1,
		"aspath"            => 1,
		"status_code"       => 1,
		"origin_code"       => 1,
		"med"               => 1,
		"locprf"            => 1,
		"weight"            => 1,
        );

The keys in this hash correspond to columns in the input data.  Set the value
under each key to 0 to disable parsing of that field.  Note that the parser
will sometimes return the values of unrequested fields if extracting those
values did not require any extra work.

=item B<next_row> - Reading the Next Row

    $table->next_row();

Retrieves the next row from the table, returning a pointer to a hash of the
values parsed from that table row.  This function returns a pointer to a
hash, and each of the parsed values is stored under the column name.  For
example

        $data = $table->next_row();
	$nexthop = ${$data}{"nexthop"};

stores the next hop router's address in $nexthop.

=item B<eot> - Checking for the End of the Table

    $table->eot();

Predicate for determining if the parser has reached the end of the route
table.  Returns 0 for false and 1 for true.

=item B<eof> - Checking for the End of the Input File

    $table->eof();

Predicate for determining if the parser has reached the end of the input file.
Returns 0 for false and 1 for true.  Note that for a normal data file, eot()
will be true when eof() is true.  Otherwise, the data file is likely to be
incomplete.

=back

=head1 EXAMPLES

This code fragment demonstrates one way to use the ParseRouteTable object:

    %options = (
                "handle" => $filehandle,
               );
    $table = new Net::ParseRouteTable \%options;

    while ( ! $table->eof() ) {
        my $data = $table->next_row() || last;

        ## Do some work on $data

    }
    if ( ! $table->eot() ) {
        warn "Table did not end with a router prompt.  Possible truncated file\n
";
    }

=head1 BUGS

There are no bugs reported so far.  If you find one, please notify
Sean McCreary <mccreary@pch.net>.

The MED, local preference, and weight fields are particularly difficult to
parse.  If you require these fields, be sure to inspect the output of the
parser carefully.

=head1 COPYRIGHT

Copyright (c) 2001 Sean McCreary <mccreary@pch.net>  All rights reserved.

This software was produced with support from Packet Clearing House, a
nonprofit research institute supporting investigation and operations in
the area of Internet traffic exchange and global IP routing economics.
The latest release of this package may be downloaded from
<http://www.pch.net/software/route_table/Net-ParseRouteTable-Current.tgz>

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions
are met:

1. Redistributions of source code must retain the above copyright
notice, this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright
notice, this list of conditions and the following disclaimer in the
documentation and/or other materials provided with the distribution.

3. The name of the author may not be used to endorse or promote products
derived from this software without specific prior written permission

THIS SOFTWARE IS PROVIDED ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES,
INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL
THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

=cut
