#!/usr/bin/perl

use DB_File;

my %db;

tie %db, 'DB_File', './d.db';

foreach my $key (keys %db) {
    print "%%$key%% %%$db{$key}%%\n";
}

untie %db;
