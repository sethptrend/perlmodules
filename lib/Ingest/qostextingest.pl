#!/usr/bin/perl

use strict;
use warnings;
fork and exit;
use lib '/local/scripts/lib/';
use Connection::Netinv;
my $dir = '/local/neteng/data/qos/';
my $trecs = 0;
my $fnum = 0;
my $netdb = Connection::Netinv->new();
opendir my $listing, $dir or die $!;

while(my $filename = readdir($listing)){

print "Process (".++$fnum."/~22899): $filename\n";
if(open my $fh, '<', $dir.$filename){
	my $recs = 0;
	
	while(<$fh>){
	chomp;
	my @vals = split /\t/;
	
	if ( (scalar @vals) == 36){
		$netdb->InsertValuesNoKeys('qos.qos_data', @vals);
		++$recs;
		next;
	}
	
	print "Bad Record: " . scalar @vals . " values: $_\n" and last;	

	}

	print "Records: $recs\n";
	$trecs += $recs;
	close $fh;
}

}

closedir($listing);
print "Total Recs: $trecs\n";
