#!/usr/bin/perl

use warnings;
use strict;

use lib '/local/scripts/lib/';

use Connection::Netinv;
my $netdb = Connection::Netinv->new();


use JSON;


my $targets = $netdb->GetCustomRecords("SELECT * FROM netinv.devices WHERE status='Active' and chassis_type like 'ASR%'");
my @output;
my %smus;

for my $target (@$targets){
	print STDERR "Curent router: $target->{hostname}\n";
	open my $fh, "<", "/opt/rancid/var/$target->{rancidgrp}/configs/$target->{hostname}";
	while(<$fh>){
		if(/!ImageCommit:\s+disk0:(.*CSC.*)-1.0.0/){
			my $smu = $1;
			unless($smus{$smu}){
			$smu =~ /(.*)-(\d\.\d\.\d)\./;
			my $platform = $1;
			my $release = $2;
			$platform =~ s/\-/_/;
			my $cmd =  "curl -u root:root http://hhcv-ncsdev.sys.cogentco.com:5000/api/get_smu_details/platform/$platform/release/$release/smu_name/$smu";
			print "$cmd\n";
			my $result = `$cmd`;
			print "result: $result\n";
			$result =~ s/\n/ /g;
			$smus{$smu}->{router} = ["$target->{hostname}"] and next if $result =~ /Page does not exist/;
			print "$result\n";
			my $api = decode_json($result);
			$smus{$smu} = $api->{data}->[0];
			$smus{$smu}->{router} = ["$target->{hostname}"];
			}
			else{
			push @{$smus{$smu}->{router}}, $target->{hostname};
			}
		}


	}
	close $fh;
}

open my $ofh, ">", "test.output";
print $ofh encode_json(\%smus);
close $ofh;



