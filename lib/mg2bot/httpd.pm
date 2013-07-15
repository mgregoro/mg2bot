package mg2bot::httpd;

# $Id: httpd.pm 212 2005-08-05 02:46:27Z corrupt $

BEGIN {
    use IO::Select;
    use HTTP::Daemon;
    use HTTP::Response;

    $SIG{PIPE} = sub { print "[error]: client aborted abnormally.\n"; };
};

my $version = '0.01';

sub new {
    my ($class, %attribs) = @_;
    my $httpd = HTTP::Daemon->new(
       LocalAddr       =>          $attribs{localaddr},
       LocalPort       =>          $attribs{httpd_port}
    );

    if ($httpd) {
        my $self = {
            _sel        =>      IO::Select->new([$httpd]),
            _handlers   =>      {},
            _httpd      =>      $httpd
        };
        return bless($self, $class);
    } else {
        return undef;
    }
}

sub do_one_loop {
    my ($self) = @_;
    my ($httpd) = $self->{_sel}->can_read(0);
    if ($httpd) {
        # we had something!
        my $httpc = $self->httpd->accept;
        my $req = $httpc->get_request;
        unless ($req) {
            $httpc->close;
            undef($httpc);
            return;
        }
        print "[httpd]: request for " . $req->url . " made from " . $httpc->peerhost . "\n";
        $self->httpd_handler($httpc, $req);
        $httpc->close;
        undef($httpc);
    }
}

sub httpd_handler {
    my ($self, $client, $req) = @_;
    if (exists($self->{_handlers}->{$req->url})) {
        my $res = HTTP::Response->new;
        $res->code(200);
        $res->header('Content-Type'     =>      'text/html');
        $res->content($self->{_handlers}->{$req->url}->($req, $res));
        if ($client->connected) {
            $client->send_response($res);
        }
    } else {
        my $res = HTTP::Response->new;
        $res->code(200);
        $res->header('Content-Type'     =>      'text/html');
        $res->content("Sorry, no handler available for " . $req->url . "\n");
        if ($client->connected) {
            $client->send_response($res);
        }
    }
}

# adds an httpd handler
sub add_handler {
    # add the handler to the list of handlers.
    my ($self, $message_type, $coderef) = @_;
    $self->{_handlers}->{$message_type} = $coderef;
}

# wipes out all the handlers for a specific message type
sub del_handler {
    my ($self, $message_type) = @_;
    delete $self->{_handlers}->{$message_type} if exists $self->{_handlers}->{$message_type};
}

sub httpd {
    my ($self) = @_;
    return $self->{_httpd};
}

1;
