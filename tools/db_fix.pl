#!/usr/bin/perl

use DB_File;

my $to_delete = "+bitch";

my %db;

tie %db, 'DB_File', './d.db';

#delete($db{$to_delete});

foreach my $key (keys %db) {
    print "$key: $db{$key}\n";
}

untie %db;
