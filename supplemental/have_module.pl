#!/usr/bin/perl

my $module = $ARGV[0];

eval "use $module;";

if ($@) {
    print "ERROR: $module not found.\n";
}
