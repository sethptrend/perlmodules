# $HeadURL: svn://hhcv-srcctrl.sys.cogentco.com/cogent/rtrtools/trunk/lib/MarkUtil.pm $
# $Id: MarkUtil.pm 2679 2015-07-07 11:09:10Z sphillips $

package MarkUtil;

use Data::Dumper;
use English;
use File::Basename;
use Getopt::Long;
use IO::File;
use POSIX;
use Term::ReadKey;
use Term::ReadLine;
use Date::Calc qw ( :all );
use Digest::MD5 qw(md5_hex);

use Net::IPv6Addr;

use Net::DNS;

use RRDs;
use strict;
use warnings;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw($date $datetime $longdate $ranciddir $cricketdatadir @cricketsubdirs $webrptdir &oct2megb $kilo $mega $giga $terra $peta $exa $zetta $yota &cleanstr &stripdom &perr &DebugPR &error &referr &reftest &testpeerdesc &gethub &cleandquote &percentile &min &max &median &mean &GetCharRsp &GetCharRspNLF &ishostname &lastmonth &yesterday &makecircgraph &getrrddata &strippath &iskmg &kmg2m &m2kmg &COIstandard &ErrorPR &h2Checksum &dnsptrlookup &dnsalookup &ccode &longdatenow &sec2dhms &dhms2str &datetimenow &IsPrivateASN &isv6 &ipv6short &ipv6ptr &isxr &As2NameHash &splitinthost);

#@EXPORT_OK = qw(...);         # symbols to export on request
#%EXPORT_TAGS = tag => [...];  # define names for sets of symbols

#In other files which wish to use ModuleName:

#use ModuleName;               # import default symbols into my package
#use ModuleName qw(...);       # import listed symbols into my package
#use ModuleName ();            # do not import any symbols

# exported package globals go here

our $date = POSIX::strftime('%Y%m%d',POSIX::localtime(time));
our $datetime = POSIX::strftime('%Y%m%d%H%M%S',POSIX::localtime(time));
our $longdate = POSIX::strftime('%b %d, %Y %H:%M %Z',POSIX::localtime(time));

our $webrptdir = '/local/apache/www/data/IPeng/reports';

our $ranciddir = "/local/rancid/var";
our $cricketdatadir = "/local/cricket/production/cricket-data";  
our @cricketsubdirs = ("pr",
		      "core",
		      "ca",
		      "building",
		      "layer2",
		      "arc",
		      "cwdm",
		      "oob",
		      "peering"
		      );

our %colorcode = (
		  'gray'       => '#808080',
		  'red'        => '#FF0000',
		  'orange/red' => '#FF6400',
		  'orange'     => '#FFC000',
		  'yellow'     => '#F0F000',
		  'green'      => '#00F000',
		  'aqua'       => '#00C0FF',
		  'light blue' => '#0090FF',
		  'blue'       => '#2020FF',
		  'purple'     => '#8C00FF'
		  );



# Based on Powers of 10 for line data

our $kilo     = (10**3);
our $mega     = (10**6);
our $giga     = (10**9);
our $terra    = (10**12);
our $peta     = (10**15);
our $exa      = (10**18);
our $zetta    = (10**21);
our $yota     = (10**24);

######################################################################
#
# oct2megb - Convert octets to megabits
#
sub oct2megb {
    my($octets) = shift;

    return(($octets * 8)/$mega);

}

######################################################################
#
# cleanstr - Removes the crud from a (typically improrted) string
#
sub cleanstr {
    my @in = @_;
    my @out = ();

    my $str;
    foreach $str (@in) {
	chomp($str);                  # Remove Trailing \n if it exists
	$str =~ s/^\s+//;             # trim left
	$str =~ s/\s+$//;             # trim right
	$str =~ tr/\x00-\x1f/A-Z/;    # Remove lower control chars
	$str =~ tr/\x7b-\x7f/B-F/;    # Remove upper control chars
	push(@out,$str);
    }

    if ($#out == -1) {
	return('');
    } elsif ($#out == 0) {   # if one element return a scalar
	return($out[0]);
    } else {
	return(@out);
    }
}


######################################################################
#
# cleandquote - returns a string in double quotes, with any double quotes inside
#               converted to single quotes (and single quotes removed
#
sub cleandquote {
    my($str) = @_;
    

    if (defined($str)) {
	$str =~ s/\'//g;  #Remove any single quotes out there
	$str =~ s/\"/\'/g; #Replace " with '
    } else {
        $str = '';
    }

    $str = '"' . $str . '"';
    
    return($str);
}


######################################################################
#
# strippath - We don't care about the whole path, we just want the last bit
#
sub strippath {
    my $str = shift;

    my @pathnames = split(/\//,$str);

    return (pop(@pathnames));

}


######################################################################
#
# stripdom - foo.com. bits from a domain name.
#
sub stripdom {
    my $str = shift;

    if ($str =~ /\.(com|net|org)\s*$/) { # if it doesn't end in in a TLD
	my @dom = split(/\./,$str);      # we've probably already stripped

	pop(@dom);
	pop(@dom);

	$str = join('.',@dom);
    }
    
    return ($str);

}
######################################################################
#
# COIstandard - returns 0 if exempt from Cogent standards, otherwise 1
#
sub COIstandard {
    my $hostname = shift;

    &DebugPR(3,"MarkUtil-COIStandard - '$hostname'");

    my $rv = 1;

#    if (
    if ($hostname =~ /dev\d+\.(atlas|hades)\.cogentco\.com$/ || 
	$hostname eq "route-server.dca01.atlas.cogentco.com" || 
	$hostname =~ /anet\.cogentco\.com$/ || 
	$hostname =~ /verio\.net$/) {
	$rv = 0;
    }

    &DebugPR(3," - " . ($rv ? "is" : "non") .  " standard\n") if $main::debug > 3;
    return ($rv);
}
######################################################################
#
# gethub - Assume we're given a router name, return the hub portion
#          return '' if we don't know what it is.
#
sub gethub {
    my $str = shift;

    $str = &stripdom($str);

    if ($str =~ /\.([A-Za-z]{3}\d\d)\./) {
	$str = $1;
    } else {
	&DebugPR(4,"Can't find hub in $str\n");
	$str = '';
    }
    
    return ($str);

}

######################################################################
#
# testpeerdesc - confirm that peer description is in the format
#                company_name-ASN-hub
#

sub testpeerdesc {
    my $str = shift;


    &DebugPR(6,"testpeerdesc - $str\n");
    if (defined($str) && $str =~ /^\S+\-\d+\-[A-Za-z]{3}\d\d$/) {
	return(1);
    } 

    return(0);
}

######################################################################
# Stats functions
######################################################################

######################################################################
#
# percentile(X,LIST) - Returns the number from included LIST that is
#                      at X percentile
#

sub percentile {
    my $percentile = shift;
    my @a = @_;
        
    my $count = 0;

    $count = $#a + 1;

    return undef if $count == 0;

    my $num = $count*$percentile/100;

    @a = sort {$a <=> $b} @a;

    my $index = &POSIX::ceil($num) - 1;

    return wantarray
        ? ($a[$index],$index) : $a[$index];
}
######################################################################
#
# min - Takes in an array of numeric values, returns the lowest value
#

sub min {
    my @a = @_;
    my $min = undef;

    foreach (@a) {
	$min = $_ if !defined($min);
        if ($_ < $min) {
            $min = $_ ;
        }
    }

    $min = 0 if ($min eq ''); 
    return($min);
}

######################################################################
#
# max - Takes in an array of numeric values, returns the highest value
#

sub max {
    my @a = @_;
    my $max = undef;

    foreach (@a) {
	$max = $_ if !defined($max); 
        if ($_ > $max) {
            $max = $_ ;
        }
    }

    return($max);
}

######################################################################
#
# median - Returns the median value from a list;
#

sub median {
    my @a = @_;
        
    my $count = 0;

    $count = $#a + 1;

    return undef if $count == 0;

    @a = sort {$a <=> $b} @a;

    if ($count % 2) {   ##Even or odd
        return $a[($count-1)/2];
    }
    else {
        return (($a[($count)/2] + $a[($count-2)/2] ) / 2);
    }
}

######################################################################
#
# mean - Returns the mean value from a list;
#

sub mean {
    my @a = @_;
        
    my $count = 0;
    my $sum = 0;

    $count = $#a + 1;

    return undef if $count == 0;

    foreach (@a) {
        $sum += $_;
    }

    return ($sum/$count);
}


######################################################################
#
# GetCharRsp - Prompt for a single char response...Return upcase response
#

sub GetCharRsp {
    my($prompt)=@_;
    my($rsp);

    print "$prompt ";
    ReadMode 3;
    $rsp = ReadKey(0);
    ReadMode 0;
    print "\n";

    $rsp =~ tr/a-z/A-Z/;
    return ($rsp);
}

######################################################################
#
# GetCharRspNLF - Get a single char response...Return upcase response
#

sub GetCharRspNLF {
    my($rsp);

    ReadMode 3;
    $rsp = ReadKey(0);
    ReadMode 0;

    $rsp =~ tr/a-z/A-Z/;
    return ($rsp);
}
######################################################################
#
# ishostname - Validates a hostname by doing a dns lookup?
#
sub ishostname {
    my $host = shift;
    my $rval = 1;

    #need to write code to validate hostnames

    return($rval);
}

######################################################################
#
# isxr - By Cogent standard, is this an XR box
#
sub isxr {
    my $host = shift;
    my $rval = 0;
    
    return($rval) if !defined($host);
    if ($host =~ /^blackhole\.(fra03|dca01)/) { return 1;}

    if ($host =~ /ccr2/ || $host =~ /ccr4/ || $host =~ /ccr1/ ||
	$host =~ /mpd2/ ||
	$host =~ /mag2/ || $host =~ /mag1/ ||
	$host =~ /^nr2/ || $host =~ /^nr1/ ||
	$host =~ /rcr2/ || $host =~ /rcr1/ || $host =~ /^rcr4/ ||
	$host =~ /^agr2/ || $host =~ /^agr1/ ||
	$host =~ /^rr1/ || $host =~ /^rr2/ ||
	$host =~ /leif/) {
	$rval = 1;
    }

    return($rval);
}

######################################################################
#
#  - By Cogent standard, is this an XR box
#
sub splitinthost {
    my $name = shift;

    if ($name =~ /^(\S+)\-(\S+\.b\d+-\d+\.\S+)/ || # match the - in buildings
        $name =~ /^(\S+)\-(c-root\.\S+)/ || # - in c-root
        $name =~ /^(\S+)\-(res-gw\.\S+)/ || # - in res-gw
        $name =~ /^(\S+)\-(\S+)/) { 

	return($1,$2);
    }

    return(undef);

}

######################################################################
#
# sortip - Used by sort to sort ip addresses
#
# Need to make this "strict" safe
#
#sub sortip {
#    
#    @a = split(/\./,$a);
#    @b = split(/\./,$b);

#    $rv = $a[0] <=> $b[0];
#    $rv = $a[1] <=> $b[1] if (!$rv);
#    $rv = $a[2] <=> $b[2] if (!$rv);
#    $rv = $a[3] <=> $b[3] if (!$rv);
#    return ($rv);
#}



######################################################################
#
# lastmonth 
#

sub lastmonth {
    my ($year,$month,$day) = Today();



    if ($month == 1) { 
        $month = 12;
        $year = $year - 1;
    }
    else { $month--; };

    my $start = "00:00 " . $month . '/01/'. $year; 

    my $end = "23:59 " . $month . '/'. Days_in_Month($year,$month) . '/'. $year; # this is the data from the last 5 min period, last month

    return($start,$end);
}

######################################################################
#
# yesterday
#

sub yesterday {
    my ($year,$month,$day) = Today();

   my $end = $month . '/' . $day . '/'. $year . " 00:00"; # this is the data from the last 5 min period, yesterday

    $day--;

    if ($day < 1) {
	$month--;

	if ($month < 1) {
	    $month = 12;
	    $year--;
	}

	$day = Days_in_Month($year,$month);
    }


    my $start = $month . '/' . $day . '/'. $year . " 00:05"; # this is the data from the first 5 minute period, yesterday
 
    
    return($start,$end);
}

######################################################################

sub escapecolon {
    my $str = shift;
    
    $str =~ s/:/\\:/;

    return ($str);

}
    
######################################################################

sub makecircgraph {
    my $rrdfile = shift;
    my $outfile = shift;
    my $title = shift;

    my $start = shift;
    my $end = shift;

    &DebugPR(4,"In: makecircgraph\n");

    if (-e $rrdfile) {
	$start = '' if !defined($start);
	$end = '' if !defined($end);

	my @options = ($outfile);
	push(@options,"-s", $start) if ($start ne '');
	push(@options,"-e", $end) if ($end ne '');

	push(@options,"--imgformat", 'PNG');
	push(@options,"--width", '500');
	push(@options,"--height", '200');
	
	push(@options,"--title",$title) if defined($title);

	# Define the data

	push(@options,"DEF:indata=$rrdfile:ds0:AVERAGE");
	push(@options,"DEF:outdata=$rrdfile:ds1:AVERAGE");

	# Convert from octets to bits

	push(@options,"CDEF:in=indata,8,*");
	push(@options,"CDEF:out=outdata,8,*");

	# Define the graphs

	push(@options,"AREA:in#00cc00:Sent to Cogent");
	push(@options,"LINE1:out#0000FF:Received from Cogent");
	push(@options,'COMMENT:\n');
	push(@options,'COMMENT:\n');
	
	if ($end ne '' && $start ne '') {
	    push(@options,"COMMENT:Graph Period " . &escapecolon("$start - $end"));
	    push(@options,'COMMENT:\n');
	}

	push(@options,"COMMENT:Graph Generated ". &escapecolon("$longdate"));

	&DebugPR(2,Dumper(@options)) if $main::debug > 2;
	
	my @arr = RRDs::graph(@options);
	if (@arr) {
		
	    &DebugPR(3,"Gifsize: " . $arr[1] . "x" . $arr[2] . "\n") if $main::debug > 3;
	    &DebugPR(3,"Printf strings: ", (join ", ", @{$arr[0]})) if $main::debug > 3;
	} 
	
	return(@arr);
    } else {
	perr("ERROR: makecircgraph - Can't find data file $rrdfile\n");
	return(undef);
    }

}

######################################################################

sub getrrddata {
    my $rrdfile = shift;
    my $start = shift;
    my $end = shift;

    my %rv = ();

    if (-e $rrdfile) {
	$start = '' if !defined($start);
	$end = '' if !defined($end);

	my @options = ($rrdfile,"AVERAGE");
	push(@options,"-s", $start) if ($start ne '');
	push(@options,"-e", $end) if ($end ne '');
	
	my $names;
	my $step;
	my $data;
	
	($start,$step,$names,$data) = RRDs::fetch(@options);

	$rv{'target'} = $rrdfile;
	$rv{'datafile'} = $rrdfile;

	$rv{'start'} = $start;  
	$rv{'step'} = $step;
	$rv{'names'} = $names;
	$rv{'in'} = [];
	$rv{'inhash'} = {};
	$rv{'out'} = [];
	$rv{'outhash'} = {};
	$rv{'mergemax'} = [];
	$rv{'mergesum'} = [];
	
	if (defined($data)) {

	    my $tstamp = $start;

	    my @in = ();
	    my %inhash = ();
	    my @out = ();
	    my %outhash = ();
	    my @mergemax = ();
	    my @mergesum = ();

	    $rv{'data'} = $data; # raw data return;
	    
	    foreach my $line (@$data) {

		# $line is a pointer to an array
		# 
		# Values for Cricket interface stats:
		# $$line[0] = in Octets per sec
		# $$line[1] = out Octets per sec
		# $$line[2] = in Errors per sec
		# $$line[3] = out Errors per sec
		# $$line[4] = in UcastPackets per sec
		# $$line[5] = out UcastPackets per sec

		my $i = 0;
		my $o = 0;

		if (defined($$line[0])) {
		    $i = &oct2megb($$line[0]);
		    push(@in,$i);
		    $inhash{$tstamp} = $i;
		}
		if (defined($$line[1])) {
		    $o = &oct2megb($$line[1]);
		    push(@out,$o);
		    $outhash{$tstamp} = $o;
		}
		push(@mergemax,&max($i,$o));
		push(@mergesum,($i+$o));

		$tstamp += $step;
	    }

	    $rv{'in'} = \@in;
	    $rv{'inhash'} = \%inhash;
	    $rv{'out'} = \@out;
	    $rv{'outhash'} = \%outhash;
	    $rv{'mergemax'} = \@mergemax;
	    $rv{'mergesum'} = \@mergesum;
	} 
	return(\%rv);
    } else {
	perr("ERROR: getrrdedata - Can't find data file $rrdfile\n");
	return(undef);
    }
}

######################################################################
#
# iskmg - Check to see if we have kmg attached
# 
sub iskmg {
    my $bw = shift;

    return(0) if !defined($bw);

    $bw =~ tr/a-z/A-Z/;

    if ($bw =~ /^\d+(\.\d+)?([KMG])$/) {
	return(1);
    }

    return(0);
}

######################################################################
#
# kmg2m - normalize something ending in kmg to m
# 
sub kmg2m {
    my $bw = shift;

    return(undef) if !defined($bw);

    $bw =~ tr/a-z/A-Z/;

    if ($bw =~ /^\d+(\.\d+)?([KMG])$/) {
	my $scale = '';
	if (defined($2)) {
	    $scale = $2;
	} else {
	    $scale = $1;
	}

	$bw =~ s/[KMG]//;

	if ($scale eq 'M') {
	    # do nothing it's already in meg
	} elsif ($scale eq 'K') {
	    $bw = $bw/1000;
	} elsif ($scale eq 'G') {
	    $bw = $bw * 1000;
	}

    } 
    return($bw);
}

######################################################################
#
# m2kmg - value is in Meg go to Kilo, Mega, or Giga
# 
sub m2kmg {
    my $bw = shift;

    return(undef) if !defined($bw) || !($bw =~ /^\d+(\.\d+)?$/);

    if ($bw < 1) {
	$bw = ($bw * 1000) . "K";
    } elsif ($bw >= 1000) {
	$bw = ($bw/1000) . "G";
    } else {
	$bw = $bw . "M";
    }

    return($bw);
}
######################################################################
#
# Make a checksum on a hash that's likely to end up in a DB.
#
sub h2Checksum {
    my $h = shift;

    if (defined($h)) {
	my $key;
	my $str = '';
	foreach $key (sort(keys(%{$h}))) {
	    if (defined($h->{$key})) {
		next if $key eq 'checksum';  # Don't include checksums in checksums ;)
		next if $key eq 'entrydate'; # or dates
		next if $key eq 'changedate'; # especially ones that change ;)

		$str .= $key . "=" . $h->{$key} . " ";
		&DebugPR(5,"Adding to checksum $key == " . $h->{$key} . "\n");
	    } else {
		&DebugPR(5,"Skipping as undef $key \n");
	    }

	}
	$str =~ s/\s+$//;             # trim right

	&DebugPR(3,"Making checksum on $str\n");

	return(md5_hex($str));
    } else {
	return(undef);
    }
}
######################################################################
#
# arr2str - Take a pointer to an array and generate a string with
#           array data (good for insert into db)
#
sub arr2str {
    my $aptr = shift;

    return(undef) if (ref($aptr) ne 'ARRAY');

    my $rv = '[';
    my $val;
    foreach $val (@{$aptr}) {
	$val =~ s/,/\\,/;  # escape any commas
	$rv .= $val . ',';
    }

    $rv =~ s/,$//; #remove trailing comma
    $rv .= ']';

    return($rv);
}
######################################################################
#
# str2arr - Take a string in the format from arr2str and turn it back
#           into an array
#
sub str2arr {
    my $str = shift;
    
    return(undef) if !defined($str);

    my $rv = [];

    return($rv) if ($str eq '[]');

    # we should now have a comma separated list 
    # with commas in the data escaped by a \

    $str = s/^\[//; # remove leading [
    $str = s/\]$//; # remove trailing ]

    # look for escaped commas and change them to a non-comma

    $str = s/\\,/###MAS-COMMA-MAS###/;

    my @arr = split(/,/,$str);


    my $val;
    foreach $val (@arr) {
	$val =~ s/###MAS-COMMA-MAS###/,/;
	push(@{$rv},$val);
    }
    return($rv);
}
######################################################################
#
# dnsptrlookup - Give an IP address, return first PTR record if found
#
sub dnsptrlookup {
    my $ip = shift;
    my $noisy = shift;

    my $res = Net::DNS::Resolver->new;

    my $query = $res->search("$ip");    

    my $rv = undef;

    if ($query) { 
	foreach my $rr ($query->answer) { 
	    next unless $rr->type eq "PTR"; 
	    $rv = $rr->ptrdname;
	    last if defined($rv);
	} 
    } else { 
	if (defined($noisy)) {
	    print "dnsptrlookup: resolver failed for $ip -- " . 
		$res->errorstring . "\n"; 
	}
    } 
    return($rv);
}

######################################################################
#
# dnsptrlookup - Give an IP address, return first PTR record if found
#
sub dnsalookup {
    my $host = shift;
    my $noisy = shift;

    my $res = Net::DNS::Resolver->new;

    my $query = $res->search("$host");    

    my $rv = undef;

    if ($query) { 
	foreach my $rr ($query->answer) { 
	    next unless $rr->type eq "A"; 
	    $rv = $rr->address;
	    last if defined($rv);
	} 
    } else { 
	if (defined($noisy)) {
	    print "dnsptrlookup: resolver failed for $host -- " . 
		$res->errorstring . "\n"; 
	}
    } 
    return($rv);
}


######################################################################
#
# ccode - Return RGB Color Code for word values
#
sub ccode {
    my $code = shift;

    if (defined($code) && exists($colorcode{$code})) {
	return($colorcode{$code});
    } else {
	return(undef);
    }
}


######################################################################
sub longdatenow {
    return(POSIX::strftime('%b %d, %Y %H:%M %Z',POSIX::localtime(time)));
}
######################################################################
sub datetimenow {
    return(POSIX::strftime('%Y-%m-%d %H:%M:%S',POSIX::localtime(time)));
}

######################################################################
sub sec2dhms {
    my $secs = shift;

    return(undef) if !defined($secs);
    return(Normalize_DHMS(0,0,0,$secs));
}
######################################################################
sub dhms2str {
    my $days = shift // 0;
    my $hrs = shift // 0;
    my $min = shift // 0;
    my $sec = shift // 0;
    my $printsec = shift // 0;

    my $rv = '';

    if ($days) {
	$rv .= "${days}d "; 
    }
    if ($days || $hrs) {
	$rv .= sprintf("%02dh ", $hrs);
    }
    if ($days || $hrs || $min) {
	$rv .= sprintf("%02dm ", $min);
    }

    if ($printsec || !($days || $hrs || $min)) {
	$rv .= sprintf("%02ds ", $sec);
    }

    $rv =~ s/\s+$//;  # remove trailing spaces
    return($rv);
}
######################################################################
# 
# IsPrivateASN true if as being tested is 64512 through 65535
# 
sub IsPrivateASN {
    my $asn = shift // 0;

    if ($asn >= 64512 && $asn <= 65535) { return (1); }
    else { return (0); }

}
######################################################################
# 
# As2NameHash - create a hash containing asn -> name lookup
# 

sub As2NameHash {

    # Create as2name hash for future lookups
    my $asnamefile = "$webrptdir/asnames.txt";

    my %as2name = ();

    my $fh = new IO::File;

    if ($fh->open($asnamefile)) {
	my $ln;
	my $counter;
	while ($ln=$fh->getline) {
	    chomp($ln);
	    if ($ln =~ /AS(\d+)\s+(\S.*)/) {
		$as2name{$1} = &cleanstr($2);
		$counter++;
		next;
	    }
	    if ($ln =~ /AS(\d+)\.(\d+)\s+(\S.*)/) {

		$as2name{($1 * 65536) + $2} = &cleanstr($3);
		$counter++;
		next;
	    }
	}
	&DebugPR(0,"as2name has $counter mappings\n");
	$fh->close;
    } else {
	croak("Can't open $asnamefile\n");
    }

    return(\%as2name);
}

######################################################################
# IPv6 Functions
######################################################################

######################################################################
# 
# isv6 - check if a ipv6 address
#
sub isv6 {
    my $str = shift // '';

    return(defined(&Net::IPv6Addr::is_ipv6($str)));
}

######################################################################
# 
# ipv6short - take an IPv6 address and return short form
#
sub ipv6short {
    my $ip6 = shift // '';

    return(&Net::IPv6Addr::to_string_compressed($ip6));
}

######################################################################
# 
# ipv6ptr - take an IPv6 address and return the ip6.int PTR record
#
sub ipv6ptr {
    my $ip6 = shift // '';

    return(&Net::IPv6Addr::to_string_ip6_int($ip6));
}

######################################################################
# Debugging stuff
######################################################################
sub perr {
    print STDERR @_;
}

######################################################################
# prints the parameters if DEBUG is true
#
sub DebugPR {
    my $dbglvl = shift(@_) // 0;
    my $dbgmsg = shift(@_) // '';
    print STDERR "DBG:$dbglvl> $dbgmsg" if defined($main::debug) && $main::debug > $dbglvl;
}
######################################################################
# Standarized Error messages for devices that should be standard ;)
#
sub ErrorPR {
    my $hostname = shift;
    my $errorclass = shift;
    my $detail = shift;

    my $rv = undef;

    if (&COIstandard($hostname)) {
	$rv = "$hostname: $errorclass: $detail";
	print "$rv\n";
    }
    return($rv);
}
######################################################################
sub error {
#    return $main::$errstr;
}
######################################################################
sub referr {
    my $v = shift;
    my $hostname = shift // '';

    if (ref($v)) {
	&perr(($hostname ne '' ? "$hostname: " : '') . "Unexpected REF ". ref($v) . "\n" . Dumper($v));
	return(1);
    }
    return(0);
}
######################################################################
sub reftest {
    my($name,$nref) = @_;

    if (ref($nref)) {
        print "$name is a ref = ",ref($nref),"\n";
        return (ref($nref));
    }
    else {
        print "$name is NOT a ref = $nref\n";
        return (0);
    }
}
######################################################################
sub dumpstr {
    my $str = shift;
    my $ptr = shift;

    $str = "Dumping " . $str;
    $str .= Data::Dumper->Dump([$ptr],[qw(*ptr)]);
    
    if (@_) { 
	print $str;
    }
    return($str);
}

1;
