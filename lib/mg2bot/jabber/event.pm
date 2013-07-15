
# $Id: event.pm 218 2006-04-13 14:23:25Z corrupt $

package mg2bot::jabber::event;

sub new {
    my ($class, %attr) = @_;
    return bless({attr  =>  \%attr}, $class);
}

sub to {
    return $_[0]->{attr}->{to} ? $_[0]->{attr}->{to} : ["*jabber"];
}

sub from {
    return $_[0]->{attr}->{from} ? $_[0]->{attr}->{from} : "jabber\@jabber";
}

sub nick {
    return $_[0]->{attr}->{nick} ? $_[0]->{attr}->{nick} : "jabber";
}

sub format {
    return $_[0]->{attr}->{format} ? $_[0]->{attr}->{format} : "jabber";
}

sub type {
    return $_[0]->{attr}->{type} ? $_[0]->{attr}->{type} : "jabber";
}

sub object {
    return $_[0]->{attr}->{object} ? $_[0]->{attr}->{object} : undef;
}

sub id {
    return $_[0]->{attr}->{id} ? $_[0]->{attr}->{id} : undef;
}

sub args {
    return ($_[0]->{attr}->{args});
}

1;

