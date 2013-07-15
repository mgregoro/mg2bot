#!/usr/bin/perl

print mask_match('ProFX!pro@desktop.ipv6.ProFX.net', '*!*@desktop.ipv6.ProFX.net') . "\n";

print mask_match('Corrupt_!corrupt@grafight.accs.wayne.edu', '*!corrupt@*.wayne.edu') . "\n";

sub mask_match {
    my $from = shift;
    my $mask = shift;
    my ($name_mask, $host_mask) = split(/\@/, $mask);
    my ($name, $host) = split(/\@/, $from);
                
    $host_mask =~ s/\*/[A-Za-z0-9\-]*/g;
    #$name_mask =~ s/\*/[A-Za-z0-9\-\_\`\[\]\\\'\^]*/g;
            
    if ($name =~ /^$name_mask$/i) {
        if ($host =~ /^$host_mask$/i) {
            return 1;
        } else {
            return 0;
        }
    } else {    
        return 0;
    }
}   
