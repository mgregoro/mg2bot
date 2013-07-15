#!/usr/bin/perl

# edited by tony

use DB_File;
my %dum_hash;
tie %dum_hash, 'DB_File', 'test.db';
my @array = (1, 2, 3, 4);

@{$dum_hash{pepsi}} = @array;

untie %dum_hash;

tie %dum_hash, 'DB_File', 'test.db';

foreach my $key (keys %dum_hash) {
    foreach my $ele (@{$dum_hash{$key}}) {
        print $ele . "\n";
    }
}
