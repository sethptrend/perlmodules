#!/usr/local/bin/perl

use warnings;
use strict;


use lib '/local/scripts/lib';
use Connection::Starfish;
my $dca = Connection::Starfish->new();

open my $fh, "<", "/local/home/rancid/var/corporate/configs/blackhole.sys.cogentco.com" or die "meh";

my @lines = <$fh>;
close $fh;

foreach my $line (@lines){
next unless $line =~ /neighbor.*description.*ID:(\d-\d+)/;
my $orderid = $1;
my $record = $dca->GetCustomRecord("SELECT Order_Prov_Details.[OrderId],[CancellationDate],[TLG].[mjain].[OPM_Order_Details].OrderId as MACID" .
"  FROM [TLG].[mjain].[Order_Prov_Details]  left join [TLG].[mjain].[OPM_Order_Details] on Order_Prov_Details.OrderId=MacOrderList where Order_Prov_Details.[OrderId]='$orderid'");
$record->{MACID} = 'None' unless $record->{MACID};
$record->{CancellationDate} = '' unless $record->{CancellationDate};
$record->{OrderId} = 'Order Not Found' unless $record->{OrderId};
if($record){
print "$orderid,$record->{OrderId},$record->{CancellationDate},$record->{MACID}\n";
}


}
