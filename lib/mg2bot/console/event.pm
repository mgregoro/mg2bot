
# $Id: event.pm 218 2006-04-13 14:23:25Z corrupt $

package mg2bot::console::event;

sub new {
    my ($class, %attr) = @_;
    return bless({attr  =>  \%attr}, $class);
}

sub to {
    return $_[0]->{attr}->{to} ? $_[0]->{attr}->{to} : ("*console");
}

sub from {
    return $_[0]->{attr}->{from} ? $_[0]->{attr}->{from} : "*master@console";
}

sub nick {
    return $_[0]->{attr}->{nick} ? $_[0]->{attr}->{nick} : "*master";
}

sub format {
    return $_[0]->{attr}->{format} ? $_[0]->{attr}->{format} : "console";
}

sub type {
    return $_[0]->{attr}->{type} ? $_[0]->{attr}->{type} : "console";
}

sub args {
    return ($_[0]->{attr}->{args});
}

1;

