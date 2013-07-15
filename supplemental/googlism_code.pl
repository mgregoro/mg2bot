#!/usr/bin/perl

# THIS IS THE CODE I USE TO LEECH FROM GOOGLISM ;)

use LWP::UserAgent;
use strict;

print googlize($ARGV[0], $ARGV[1]) . "\n";

sub googlize {
    my %th = (
            whois   =>      1,
            whatis  =>      2 );
    my $type = shift;
    $type = $th{$type};
    my $ism = shift;
    
    my $ua = LWP::UserAgent->new();
    $ua->agent("Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1; Q312461)");
    my $req = HTTP::Request->new(GET => "http://www.googlism.com/index.htm?ism=$ism&type=$type");
    my $res = $ua->request($req);
    if ($res->content) {
        return fetch_random_gism(parse_content($res->content));
    } else {
        return "nothing!\n";
    }
}

sub fetch_random_gism {
    my @gisms = @_;
    my $number = rand(scalar(@gisms));
    $number =~ s/(\d+)\.*\d*/$1/g;
    return $gisms[$number];
}

sub parse_content {
    my $content = shift;
    my @googlisms;
    my $have_content = 0;
    foreach my $line (split('\n', $content)) {
        if ($line =~ /Googlism for.+\<\/h1\>\<br\>(.+)\<br\>/) {
            my $first_line = $1;
            $have_content = 1;
            push (@googlisms, $first_line);
            next;
        }
        next unless $have_content == 1; 
        if ($line =~ /^(.+)\<br\>/) {
            my $gism = $1;
            push (@googlisms, $gism);
        } elsif (($line eq "\n") || ($line =~ /^\s+$/)) {
            $have_content = 0;
        }
    }
    return @googlisms;
}
