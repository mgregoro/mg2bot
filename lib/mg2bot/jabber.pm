# $Id: jabber.pm 218 2006-04-13 14:23:25Z corrupt $

package mg2bot::jabber;

use IO::Select;
use mg2bot::jabber::event;

our @event_queue;

sub new {
    my ($class, $name, $pass, $server, $handler) = @_;
    my $self = bless({ name => $name, pass => $pass, server => $server, h => $handler });
    $self->init_connection;
    return $self;
}

sub jc {
    my ($self) = @_;
    return $self->{jc};
}

sub queue_event {
    my ($id, $event) = @_;
    return unless $id && $event;
    my $type = $event->GetType if ref($event);

    push(@event_queue, {    id => $id, 
                            event => $event, 
                            type => $type,
                       });
}

sub do_one_loop {
    my ($self) = @_;
    if (defined($self->{jc}->Process(0.01))) {
        foreach my $e (@event_queue) {
            my $event = mg2bot::jabber::event->new(
                type        =>      $e->{type},
                to          =>      [$e->{event}->GetFrom],
                from        =>      $e->{event}->GetFrom,
                nick        =>      $e->{event}->GetFrom,
                object      =>      $e->{event},
                format      =>      'jabber',
                id          =>      $e->{id},
            );
            if (ref($event->object) =~ /message/i) {
                my $args = $event->object->GetBody();
                next unless $args; # skip the "bobby is typing" bs.
                $event->{attr}->{args} = $args;
            }
            $self->{h}->($self, $event);
            $self->{event_count}++;
            $self->{user_count}->{$event->from}++;
        }
        @event_queue = ();
    } else {
        $self->init_connection;
    }
}

sub init_connection {
    my ($self) = @_;
    my $jc = Net::Jabber::Client->new();
    if ($jc->Connect(hostname   =>      $self->{server})) {
        my @r = $jc->AuthSend(   username    =>      $self->{name},
                                 password    =>      $self->{pass},
                                 resource    =>      'mg2bot',
                             );
        if ($r[0] eq "ok") {
            $jc->RosterGet();
            $jc->PresenceSend();
            $jc->SetCallBacks(map { $_ => \&queue_event } qw/message presence iq/);
            $self->{jc} = $jc;
        } else {
            warn "Error authorizing jabber user $self->{name}: $r[0] - $r[1]\n";
            return undef;
        }
    } else {
        warn "Error connecting to Jabber server $self->{server}: $!\n";
        return undef;
    }
}

# gotta implement this for feedback.. probably others.
sub privmsg {
    my ($self, $to, @parts) = @_;
    my $msg = Net::Jabber::Message->new();
    $msg->SetMessage(   to        =>      $to,
                        type      =>      "chat",
                        body      =>      join(" ", @parts),
                    );
    $self->jc->Send($msg);
}

1;

