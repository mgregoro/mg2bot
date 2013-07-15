#!/usr/bin/perl

use XML::Simple;
use Data::Dumper;

my $cf = "mg2bot_config.xml";
my $xp = XML::Simple->new();
my $c = $xp->XMLin($cf, GroupTags    => {loaded_on_startup => plugin});

print Dumper($c);

