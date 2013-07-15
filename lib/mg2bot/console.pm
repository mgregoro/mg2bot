# $Id: console.pm 218 2006-04-13 14:23:25Z corrupt $

package mg2bot::console;

use IO::Select;
use mg2bot::console::event;

sub new {
    my ($class, $handler) = @_;
    my $s = IO::Select->new();
    $s->add(\*STDIN);
    return bless({  s       =>      $s, 
                    h       =>      $handler}, $class);
}

sub do_one_loop {
    my ($self) = @_;
    if (my @ready = $self->{s}->can_read(0)) {
        foreach my $socket (@ready) {
            # get the line from the socket..
            my $line = <$socket>;

            # create an event from the line..
            my $event = mg2bot::console::event->new(args    =>  $line);
            $self->{h}->($self, $event);
        }
    }
}

# gotta implement this for feedback.. probably others.
sub privmsg {
    my ($self, @parts) = @_;
    my $msg = join(" ", @parts);
    if ($msg =~ /[\r\n]+$/o) {
        print "[bot response]: $msg";
    } else {
        print "[bot response]: $msg\n";
    }
}

1;

