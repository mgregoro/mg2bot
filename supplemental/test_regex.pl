#!/usr/bin/perl

my $command = "- ";

#print "$command\n";

if ($command =~ /^[A-Za-z0-9\.\-\!\s]+$/) {
    print "$command\n";
}
