use strict;
use warnings;
use lib '/local/scripts/lib';

use Connection::Starfish;
use Connection::Aarondev;

my $db = Connection::Starfish->new();
my $adb = Connection::Aarondev->new();

my $arecs = $adb->GetIndexRecords('aarondev.bundlecustomer', 'inuse', 1);

for my $arec (@$arecs){
	#print "$arec->{bundleid}\t$arec->{orderid}\t$arec->{user}\n";
	$db->DoSQL("INSERT INTO networkdbor.dbo.bundles VALUES ($arec->{bundleid}, '$arec->{orderid}', '$arec->{user}', 'customer', GETDATE());");
}
