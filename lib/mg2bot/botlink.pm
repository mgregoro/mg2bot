package mg2bot::botlink;


# $Id: botlink.pm 203 2005-04-09 14:28:50Z corrupt $
# need this one ;)
BEGIN {
    use IO::Select;
    use IO::Socket;

    # try for the native version!
    eval "use Digest::MD5 qw(md5_hex);";
    if ($@) {
        warn "[startup]: No native version of Digest::MD5 found.  Using slower, but included pure perl version.\n";
        use Digest::Perl::MD5 qw(md5_hex);
    }
}

my $version = '0.06';

sub new {
    my ($class, @rels) = @_;
    my $self = {
        _bots_linked        =>      0,
        _connected          =>      0,
        _authenticated      =>      0,
        _should_listen      =>      0,
        _am_listening       =>      0,
        _listen_config      =>      0,
        _server             =>      undef,
        _sel                =>      new IO::Select,
        _clients            =>      [],
        _challanges         =>      {},
        _handlers           =>      {},
        _listen_rels        =>      0,
        _listen_auth        =>      0,
        _num_rels           =>      0};
    foreach my $rel (@rels) {
        next unless $rel->{nick};
        $self->{_should_listen} = 1 unless $rel->{initiate};
        ++$self->{_listen_rels} unless $rel->{initiate};
        $self->{_rel}->{$rel->{nick}}->{mask} = $rel->{mask};
        $self->{_rel}->{$rel->{nick}}->{nick} = $rel->{nick};
        $self->{_rel}->{$rel->{nick}}->{initiate} = $rel->{initiate};
        $self->{_rel}->{$rel->{nick}}->{my_token} = $rel->{my_token};
        $self->{_rel}->{$rel->{nick}}->{their_token} = $rel->{their_token};
        $self->{_rel}->{$rel->{nick}}->{connected} = 0;
        ++$self->{_num_rels};
    }

    return bless $self, $class;
}

# send message to a particular bot
sub send_message {
    my ($self, $target, $message) = @_;
    if (exists($self->{_rel}->{$target})) {
        if ($self->{_rel}->{$target}->{connected}) {
            my $sock = $self->getsock($target);
            if ($message =~ /\n$/) {
                print $sock $message;
            } else {
                print $sock "$message\n";
            }
            return 1;
        }
    }
    return undef;
}

# broadcast message to all bots
sub broadcast {
    my ($self, $message) = @_;
    my $i;
    foreach my $rel (keys %{$self->{_rel}}) {
        if ($self->{_rel}->{$rel}->{connected}) {
            #print "[debug]: broadcasting $message to $rel\n";
            my $sock = $self->getsock($rel);
            if ($message =~ /\n$/) {
                print $sock $message;
            } else {
                print $sock "$message\n";
            }
            ++$i;
        }
    }
    return $i;
}

# gets the socket by nick
sub getsock {
    my ($self, $name) = @_;
    return $self->{_rel}->{$name}->{sock};
}

# gets the relationship by nick
sub rel {
    my ($self, $name) = @_;
    return $self->{_rel}->{$name};
}

# get the relationship by mask
sub mask_to_rel {
    my ($self, $mask) = @_;
    foreach my $rel (keys %{$self->{_rel}}) {
        if (mask_match($mask, $self->{_rel}->{$rel}->{mask})) {
            return $self->{_rel}->{$rel};
        }
    }
    return undef;
}

sub initiate {
    my ($self, $my_nick, $nick, $mask, $host) = @_;
    print "[botlink]: i recognize $nick ($mask)\n";
    my $rel = $self->{_rel}->{$nick};
    if ($rel->{connected}) {
        print "[botlink]: im already connected to $nick ($mask)\n";
        return undef;
    }

    if (my $sock = IO::Socket::INET->new(   PeerAddr        =>      $host,
                                            PeerPort        =>      6446,
                                            Proto           =>      'tcp',
                                            Type            =>      SOCK_STREAM)) {
        # we're connected.
        my $welcome = <$sock>;
        $welcome =~ s/[\r\n]+$//g;
        if ($welcome =~ /^mg2 botlink v(\d+)\.(\d+) \[(.+)\]$/) {
            my $version = "$1.$2";
            my $chal = $3;
            print $sock "$my_nick [" . md5_hex("$rel->{my_token}$chal") . "]\n";
            my $response = <$sock>;
            $response =~ s/[\r\n]+$//g;
            if ($response =~ /^\[info\]:/) {
                # we're logged in!
                $self->{_sel}->add($sock);
                $rel->{sock} = $sock;
                $rel->{connected} = 1;
                ++$self->{_authenticated};
                print "[botlink]: successfully authenticated with $nick.\n";
                return 1;
            } else {
                print "[botlink]: error initiating connection with $nick, authentication error '$response'\n";
                return undef;
            }
        } else {
            print "[botlink]: error initiating connection with $nick, unknown welcome message '$welcome'\n";
            return undef;
        }
    } else {
        print "[botlink]: error initiating connection with $nick $@.\n";
        return undef;
    }
}

sub have_relationship_with {
    $_[0]->rel(@_) if ref($_[0]);
    undef;
}

sub do_one_loop {
    my ($self, $local_addr) = @_;
    # first off, start up our listener if we should be listening.
    if (($self->{_should_listen}) && (!$self->{_am_listening})) {                    # botlink port
        print "[botlink]: $self->{_authenticated} of $self->{_num_rels} friendlys connected.  Starting bot listener.\n";
        if ($self->{_server} = new IO::Socket::INET(Listen  =>  1,  LocalAddr   =>  $local_addr, LocalPort   =>  6446,
                                                Type    => SOCK_STREAM,
                                                Reuse   => 1)) {
            $self->{_sel}->add($self->{_server});
            $self->{_am_listening} = 1;
        } else {
            print "[botlink]: ERROR couldn't listen on port 6446: $@\n";
        }
    } elsif (($self->{_am_listening}) && (!$self->{_should_listen})) {
        print "[botlink]: $self->{_authenticated} of $self->{_num_rels} friendlys connected.  Stopping bot listener.\n";
        $self->{_sel}->remove($self->{_server});
        $self->{_server}->close;
        $self->{_am_listening} = 0;
    }
    # get data.
    my @ready = $self->{_sel}->can_read(0);
    foreach my $fh (@ready) {
        if ($fh == $self->{_server}) {
            # we have a new connection, let's accept and greet them.
            my $client = $self->{_server}->accept;

            # we made a connection, lets make a record of that
            ++$self->{_connected};

            # lets generate a challenge to send them!
            my $challange = $self->gen_challange;

            # link this socket back to this challange
            $self->{_challanges}->{$client} = $challange;

            # SEND the challange!
            print $client "mg2 botlink v$version [$challange]\n";
            $self->{_sel}->add($client);

            # find out if we should listen anymore... not quite sure why.. but.. i'll leave it.
            if ($self->{_listen_auth} >= $self->{_listen_rels}) {
                $self->{_should_listen} = 0;
            } elsif ($self->{_listen_auth} < $self->{_listen_rels}) {
                $self->{_should_listen} = 1;
            }

            # we're done!
            next;
        } elsif (exists($self->{_challanges}->{$fh})) { 
            # authenticate unauthenticated!
            my $auth_string = <$fh>;
            $auth_string =~ s/[\r\n]+$//g;
            my $rel = $self->auth($auth_string, $self->{_challanges}->{$fh});
            if ($rel) {
                if ($self->{_rel}->{$rel}->{connected} == 1) {
                    print $fh "[err]: $rel already connected.\n";
                    $self->{_sel}->remove($fh);
                    $fh->close;
                    --$self->{_connected};
                } else {
                    $self->{_rel}->{$rel}->{sock} = $fh;
                    $self->{_rel}->{$rel}->{connected} = 1;
                    $self->{_rel}->{$rel}->{ip} = $fh->peerhost;
                    print $fh "[info]: welcome, $rel @ $self->{_rel}->{$rel}->{ip}.\n";
                    print "[botlink]: connection from " . $fh->peerhost . " authenticated as $rel.\n";
                    ++$self->{_authenticated};
                    ++$self->{_listen_auth};
                }
            } else {
                print $fh "[err]: invalid credentials.\n";
                $self->{_sel}->remove($fh);
                $fh->close;
                --$self->{_connected};
            }
            delete $self->{_challanges}->{$fh};

            if ($self->{_listen_auth} >= $self->{_listen_rels}) {
                $self->{_should_listen} = 0;
            } elsif ($self->{_listen_auth} < $self->{_listen_rels}) {
                $self->{_should_listen} = 1;
            }

            # NEEEEXXT!
            next;
        }

        # go through connected!
        foreach my $rel (keys %{$self->{_rel}}) {
            if ($fh == $self->{_rel}->{$rel}->{sock}) {
               my $data = <$fh>;
               if ($data eq '') {
                    $self->{_sel}->remove($fh);
                    $self->{_rel}->{$rel}->{connected} = 0;
                    delete $self->{_rel}->{$rel}->{ip};
                    $fh->close();
                    $data = "$rel closed the connection.";
                    # decrement the total authenticated connections.
                    --$self->{_authenticated};

                    # decrement the authenticated listeners if we put up a listener for this
                    # relationship
                    --$self->{_listen_auth} unless $self->{_rel}->{$rel}->{initiate};
                }
                $data =~ s/[\r\n]+$//g;
                $self->botlink_handler($rel, $data);
            }
        }
        if ($self->{_listen_auth} >= $self->{_listen_rels}) {
            $self->{_should_listen} = 0;
        } elsif ($self->{_listen_auth} < $self->{_listen_rels}) {
            $self->{_should_listen} = 1;
        }

    }
}

sub botlink_handler {
    my ($self, $rel, $data) = @_;
    my ($message_type, $data) = $data =~ /^(\w+)\s(.+)$/;
    if (exists($self->{_handlers}->{$message_type})) {
        foreach my $handler (@{$self->{_handlers}->{$message_type}}) {
            $handler->($rel, $message_type, $data);
        }
    } else {
        unless (_default_handler($rel, $message_type, $data)) {
            print "[botlink]: no handler for message of type $message_type from $rel '$data'\n";
        }
    }
}

sub _default_handler {
    my ($frombot, $type, $args) = @_;
    if ($args eq "closed the connection.") {
        print "[botlink]: lost connection from $frombot.\n";
        return 1;
    }
    return undef;
}

sub auth {
    my ($self, $auth_string, $challange) = @_;
    my ($botname, $md5_hash);

    # check for proper formatting
    if ($auth_string =~ /^(.+)\s\[([0-9a-f]{32})\]$/) {
        $botname = $1;
        $md5_hash = $2;
    } else {
        return undef;
    }

    # make sure we have a relationship with this bot.
    if (exists $self->{_rel}->{$botname}) {
        my $should_be = md5_hex($self->{_rel}->{$botname}->{their_token} . $challange);

        # check the token!
        if ($should_be eq $md5_hash) {
            # success!
            return $botname;
        } else {
            print "Should be $should_be, got $md5_hash\n";
            return undef;
        } 
    } else {
        return undef;
    }
}

sub gen_challange {
    my ($self) = @_;
    my $chal;
    my @chars = (A...Z, a...z, 0...9);
    for (my $i = rand(20) + 20; $i > 0; --$i) {
        $chal .= $chars[sprintf('%d', rand(scalar(@chars)))];
    }
    return $chal;
}

sub add_handler {
    # add the handler to the list of handlers.
    my ($self, $message_type, $coderef) = @_;
    push(@{$self->{_handlers}->{$message_type}}, $coderef);
}

# wipes out handler by index
sub del_handler {
    # since we don't know which one we're going to delete...
    my ($self, $type, $index) = @_;
    $index = $index ? $index : 0;
    @{$self->{_handlers}->{$message_type}} = remove_index($index, @{$self->{_handlers}->{$message_type}});
    return scalar(@{$self->{_handlers}->{$message_type}});
}

# wipes out all the handlers for a specific message type
sub del_handlers {
    delete $self->{_handlers}->{$message_type} if exists $self->{_handlers}->{$message_type};
}

# returns an array except for the one index that you specify as the first arg.
sub remove_index {
    my ($index, @array) = @_;
    @array = (@array[0..($index - 1)], @array[($index + 1)..$#array]);
}

# does the from (arg1) match the mask (arg2)?
sub mask_match {
    my ($from, @masks) = @_;

    if (ref($from) eq "mg2bot::botlink") {
        $from = shift(@masks);
    }
    
    foreach my $mask (@masks) {
        if ($from =~ /^([A-Za-z0-9\-\_\`\[\]\'\^]+)!([A-Za-z0-9\-\_\`\[\]\'\^\~]+)\@([A-Za-z0-9\-\.]+)$/) {
            my ($from_nick, $from_ident, $from_host) = ($1, $2, $3);
            if ($mask =~ /^([A-Za-z0-9\-\_\`\[\]\'\^\*]+)!([A-Za-z0-9\-\_\`\[\]\'\^\*\~]+)\@([A-Za-z0-9\-\.\*]+)$/) {
                my ($mask_nick, $mask_ident, $mask_host) = ("^$1\$", "^$2\$", "^$3\$");
                $mask_nick =~ s/\*/[A-Za-z0-9\\\-\\\_\\\`\\\[\\\]\'\\\^\\\*]*/g;
                $mask_ident =~ s/\*/[A-Za-z0-9\\\~\\\-\\\_\\\`\\\[\\\]\'\\\^\\\*]*/g;
                $mask_host =~ s/\*/[A-Za-z0-9\\\-\\\.\\\*]*/g;
                if ($from_nick =~ /$mask_nick/) {
                    if ($from_ident =~ /$mask_ident/) {
                        if ($from_host =~ /$mask_host/) {
                            return 1;
                        }
                    }
                }
            } 
        }       
    }
    # return undef after you leave the loop
    return undef;
}

1;
