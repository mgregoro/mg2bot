#!/usr/bin/perl

use DB_File;

$| = 1;

my ($dump_file, $db_file) = @ARGV;

open(DUMP, $dump_file) or die "Can't open $dump_file: $!\n";

my %db;

tie %db, 'DB_File', $db_file;

while (<DUMP>) {
    if ($_ =~ /^(.+)\s\=\>\s(.+)\n$/) {
        print ".";
        $db{$1} = $2;
    }
}

print "\n" . scalar(keys(%db)) . " factoids loaded into $db_file.\n";
print "\n\n";

untie %db;

close(DUMP);

