#!/usr/bin/perl

# the mg2 bot
# (c) 2008 Michael Gregorowicz
#     The mg2 organization
#     
# $Id: mg2bot.pl 267 2008-08-19 14:49:25Z corrupt $

use lib('lib');
my ($have_lwp, $have_dfmt, $have_jabber, $have_db);

BEGIN { 
    require 5.005;

    # modules, libraries, and strict
    eval "use LWP::UserAgent;";     # optional ( for googlism hook )
    $have_lwp = $@ ? 0 : 1;
    undef $@;
    eval "use Date::Format;";       # optional ( for debugging output )
    $have_dfmt = $@ ? 0 : 1;    
    undef $@;
    eval "use Net::Jabber;";
    $have_jabber = $@ ? 0 : 1;
    undef $@;
    eval "use DB_File;";
    $have_db = $@ ? 0 : 1;
    undef $@;

    use XML::Simple;                # required ( for config file )
    use Net::IRC;                   # required ( for irc connections ) <included>
    use Cwd;                        # required ( to get our bearings )
    use mg2bot::botlink;            # optional ( for botlink )
    use mg2bot::console;            # required ( for console )
    use mg2bot::jabber;             # optional ( for jabber )
    use strict;

    # turn autoflush off!
    $| = 1;

    print "[startup]: mg2bot starting with (ON/off) [ ";

    print $have_lwp ? "WWW " : "www ";
    print $have_dfmt ? "DEBUG " : "debug ";
    print $have_jabber ? "JABBER " : "jabber ";
    print $have_db ? "FACTOIDS " : "factoids ";

    print "]\n";

};

# create Net::IRC object.
my $irc = new Net::IRC;

# declare version!
my $VERSION = '0.71';

# release type
my $RELEASE = '';

# the plugin data structures
my $loaded_plugins = {};
my $about_plugins = {};
my %plugins_data; # declared as a sandbox for the plugins to store data in!

# get the start epoch
my $start_time = time();

# initialize some structures and variables
my $sleeping = 0;
my %time;
my %time_handlers;

# structure for holding users
my $mg2_users;

# hold the stuff i've learned
my %learned;

# create a hash for the channel info
my $channels = {};

# queue the mode changes.
my $mode_changes = {};

# queue some botlink messages.
my $botlink_queue = [];

# queue the who's
my $who_queue = []; # im using references for channels, and modes.. why stop here?

# wait time for auto-reconnect
my $wait_time = 0;

# current server index
my $current_server = 0;

# are we connected?
my $ic_connected = 0;

#
# CONFIGURATION FOLLOWS
#

# declare config variable!
my $c;

if (!-e "conf/mg2bot_config.xml") {
    warn "conf/mg2bot_config.xml does not exist.  ALL default values will be used.  (this is bad)\n";
} else {
    $c = XMLin("conf/mg2bot_config.xml", GroupTags    => {loaded_on_startup => 'plugin'}, ForceArray    =>   [ 'masters', 'channel', 'irc_server', 
                                                                                                                            'botlink_relationship']);
    print "[startup]: Found and parsed config file found mg2bot_config.xml bot version " . $c->{bot_version} . ".\n";
}

# do we IRC at all?
my $no_irc = $c->{global}->{no_irc} ? $c->{global}->{no_irc} : 0;

# for debugging
my $write_to_dbug = $c->{global}->{write_to_debug} ? $c->{global}->{write_to_debug} : 0;

# the mg2bot directory
my $mg2bot_dir = cwd();

# default allowed levels (levels meaning levels who get ops)
my @allowed_levels = $c->{global}->{op_level} ? @{$c->{global}->{op_level}} : (1, 10, 50);

# plugins loaded on startup
my @loaded_on_startup = $c->{global}->{loaded_on_startup} ? @{$c->{global}->{loaded_on_startup}} : qw(googlize pub_catchall priv_catchall);

# mg2 user database info PRIVATE
my $ldap_dn = $c->{global}->{ldap_dn} ? $c->{global}->{ldap_dn} : undef;
my $ldap_pass = $c->{global}->{ldap_pass} ? $c->{global}->{ldap_pass} : undef;

# i did this again.  this is the shorthand character!
my $shorthand_char = $c->{global}->{shorthand_char} ? $c->{global}->{shorthand_char} : "\\+";

# the bot's nick!
my $my_nick = $c->{global}->{my_nick} ? $c->{global}->{my_nick} : "mg2bot";

# irc server(s)
my @irc_server = $c->{global}->{irc_server} ? @{$c->{global}->{irc_server}} : ("irc.some.net"); # default wont work

# irc name
my $irc_name = $c->{global}->{irc_name} ? $c->{global}->{irc_name} : "mg2bot!  the bot for #mg2!";

# Misc configuration stuff, time handlers, and scramble related stuff.
my $scores_lines = $c->{global}->{scores_lines} ? $c->{global}->{scores_lines} : 5;
my $factoids_per_line = $c->{global}->{factoids_per_line} ? $c->{global}->{factoids_per_line} : 20;
my $db_file = $c->{global}->{db_file} ? $mg2bot_dir . $c->{global}->{db_file} : $mg2bot_dir . '/data/d.db';

# reconnect ?
my $auto_reconnect = $c->{global}->{auto_reconnect} ? $c->{global}->{auto_reconnect} : 0;

# BOT MASTERS!!!
my @masters = $c->{global}->{masters} ? @{$c->{global}->{masters}} : ('Corrupt_!corrupt@grafight.accs.wayne.edu');

# the length of the ticks themselves
my $tick_length = $c->{global}->{tick_length} ? $c->{global}->{tick_length} : 5;

# get the relationships for the botlink
my @relationships = $c->{global}->{botlink_relationship} ? @{$c->{global}->{botlink_relationship}} : undef;

# create the botlink object if we have relationships.
my $bl = mg2bot::botlink->new(@relationships) if scalar(@relationships);

# local addr?
my $localaddr = $c->{global}->{localaddr} ? $c->{global}->{localaddr} : undef;

# ping timeout?
my $ping_timeout = $c->{global}->{ping_timeout} ? $c->{global}->{ping_timeout} : undef;

# jabber stuff...
my $jabber_name = $c->{global}->{jabber_name} ? $c->{global}->{jabber_name} : undef;
my $jabber_pass = $c->{global}->{jabber_pass} ? $c->{global}->{jabber_pass} : undef;
my $jabber_server = $c->{global}->{jabber_server} ? $c->{global}->{jabber_server} : undef;

#########
# END CONFIGURATION
#########

my $jabber;
if ($have_jabber && ($jabber_name && $jabber_pass && $jabber_server)) {
    print "[startup]: Initializing jabber connection to $jabber_server....\n";
    $jabber = mg2bot::jabber->new($jabber_name, $jabber_pass, $jabber_server, \&on_jabber);
}

# loading user database!
print "[startup]: Importing local users....\n";
$mg2_users = fetch_local_users();

# console code goes here!
my $console = mg2bot::console->new(\&on_console);

# initialize the IRC connection ($ic = iRC cONNECTION)
my $ic = init_connection() unless $no_irc;

# actually load the plugins
foreach my $plugin (@loaded_on_startup) {
    print "[startup]: " . load_plugin("plugins/$plugin") . "\n";
}

# pingstamp - the ping timestamp;
my $pingstamp;

# a loop of our own sturdy design?
for (;;) {
    # i hate double negatives, so this excludes re-connecting for people who specify
    # no_irc in their conf files.. for jabber only, etc
    if ($auto_reconnect && !$no_irc) {
        $ic = init_connection() unless $ic_connected;
    }

    # I have no idea wtf i was doing here.
    $bl->do_one_loop($localaddr) if $bl;    # loop for the bots!
    $jabber->do_one_loop if $jabber;        # loop for jabber!
    $console->do_one_loop;                  # loop for the console!
    $irc->do_one_loop unless $no_irc;       # loop for the irc network!

    # one tick!
    refresh_status();
}

# sets the default handlers, and connects to IRC.
sub init_connection {
    until ($ic_connected) {
        print "[startup]: Attempting to connect to $irc_server[$current_server]... ";
        sleep $wait_time;

        # see if we'll break
        eval {
            if ($localaddr) {
                $ic = $irc->newconn(Nick =>  $my_nick,
                                    Ircname => $irc_name,
                                    LocalAddr => $localaddr,
                                    Server  =>  $irc_server[$current_server]);
            } else {
                $ic = $irc->newconn(Nick =>  $my_nick,
                               Ircname => $irc_name,
                               Server  =>  $irc_server[$current_server]);
            }
        };

        warn $@ if $@;

        if (ref($ic)) {
            $ic_connected = 1 if $ic->connected;
        } 
        ++$wait_time;

        print "Failed.\n" unless $ic_connected;

        # go to the next server or back to the beginning, depending on how many
        # servers we have configured and how many we've tried already.
        next if $#irc_server == 0;
        if ($current_server == $#irc_server) {
            $current_server = 0;
        }
        ++$current_server;
    }
    print "Succeeded in $wait_time tries.\n";
    $ic->add_global_handler('376', \&on_connect);
    $ic->add_global_handler('disconnect', \&on_disconnect);
    $ic->add_handler('433', \&nick_in_use_handler);
    $ic->add_handler('nick', \&nick_change);
    $ic->add_handler('352', \&who_handler);
    $ic->add_handler('367', \&bans_handler);
    $ic->add_handler('mode', \&mode_handler);
    $ic->add_handler('msg', \&on_msg);
    $ic->add_handler('join', \&on_join);
    $ic->add_handler('part', \&on_part);
    $ic->add_handler('quit', \&on_quit);
    $ic->add_handler('public', \&on_public);
    $ic->add_handler('kick', \&on_kick);
    $ic->add_handler('topic', \&topic_handler);
    $ic->add_handler('cversion', \&on_version);
    $ic->add_handler('cping', \&on_cping);
    $ic->add_handler('caction', \&action_handler);
    $ic->add_handler('ping', \&on_ping);
    if ($ping_timeout) {
        print "[startup]: bot configured to reconnect if it receives no pings from the irc server in $ping_timeout ticks.\n";
        add_scheduled_event('ping_timeout', $ping_timeout, \&check_ping_timeout);
        $pingstamp = time;
    }
    add_scheduled_event('change_modes', 1, \&perform_mode_changes);
    add_scheduled_event('do_whos', 1, \&do_who_queue);
    add_scheduled_event('send_botlink', 2, \&send_botlink_data);
    return $ic;
}

sub check_ping_timeout {
    # we want it in seconds, so multiply times tick_length to translate 'ticks' to seconds
    if (($pingstamp + ($ping_timeout * $tick_length)) < time) {
        print "[timeout]: Ping timeout past the tick threshold $ping_timeout ticks.\n";
        $ic->disconnect;
    }
}

sub on_ping {
    my ($self, $event) = @_;
    $self->sl("PONG " . join(' ', $event->args));
    if ($write_to_dbug) {
        dbugr($event->dump2string);
    }
    $pingstamp = time;
}

sub send_botlink_data {
    return unless $bl->{_authenticated};
    # go through the queue
    foreach my $act (@$botlink_queue) {
        my $type = shift(@$act);
        if ($type eq "broadcast") {
            $bl->broadcast(@$act);
        } elsif ($type eq "send_message") {
            $bl->send_message(@$act);
        }
    }
    # clear the queue
    $botlink_queue = [];
}

sub do_who_queue {
    # very simple.. just perform the who you were going to perform.
    my @who_users = splice(@$who_queue, 0, 2);
    foreach my $who_user (@who_users) {
        return unless $who_user;
        $ic->who($who_user);
    }
}

sub perform_mode_changes {
    foreach my $chan (keys %$mode_changes) {
        while (scalar(@{$mode_changes->{$chan}})) {
            my @batch = splice(@{$mode_changes->{$chan}}, 0, 4);
            my ($modes, $nicks);
            foreach my $ar (@batch) {
                $modes .= $$ar[0];
                $nicks .= " $$ar[1]";
            }
            $ic->mode($chan, $modes, $nicks);
        }
        delete $mode_changes->{$chan};
    }
}

sub run_scheduled_event {
    my ($name) = @_;
    eval {
        $time_handlers{$name}->($ic);
    };
    if (my $error = $@) {
        warn "Error running scheduled event $name: $error\n";
        remove_scheduled_event($name);
    } else {
        $time{$name} = 0;
    }
}


sub postpone_scheduled_event {
    my ($name, $ticks) = @_;
    $time{"end_$name"} += $ticks;
}

sub expedite_scheduled_event {
    my ($name, $ticks) = @_;
    if (($time{"end_$name"} - $ticks) > 0) {
        $time{"end_$name"} -= $ticks;
    } else {
        $time{"end_$name"} = 1;
    }
}

# adds a scheduled event to the scheduler
# usage: add_scheduled_event('event_name', 1, '\&my_handler');
# where the first arg is the event name, second is the number of 'ticks'
# (tick length is specified in mg2bot_config.xml), and the third arguement
# is a reference to the function that should be executed.
sub add_scheduled_event {
    my $name = shift;
    my $ticks = shift;
    my $handler = shift;
    $time{$name} = 0;
    $time{"end_$name"} = $ticks;
    $time_handlers{$name} = $handler;
}

# removes a scheduled event by ('name')
sub remove_scheduled_event {
    my $name = shift;
    delete $time{$name};
    delete $time_handlers{$name};
}

# updates the number of 'ticks' that have been waited for a certain
# function to be run, and if it's time, runs the function and clears
# the counter.
sub refresh_status {
    foreach my $key (keys %time) {
        next if $key =~ /^end_/;
        ++$time{$key};
        if ($time{$key} >= $time{"end_$key"}) {    
            run_scheduled_event($key);
        }
    }
}

# a piss-poor attempt at handling a nick in use!
sub nick_in_use_handler {
    my $self = shift;
    my $event = shift;
    print "[status]: $my_nick already used ";
    if (length($my_nick) > 9) {
        $my_nick = substr($my_nick, 0, 8) . "-";
    } else {
        $my_nick = $my_nick . "_";
    }
    print "trying $my_nick instead.\n";
    $self->nick($my_nick);
}

# simple ctcp ping reply
sub on_cping {
    my ($self, $event) = @_;
    if ($write_to_dbug) {
        dbugr($event->dump2string);
    }
    print "[notice]: " . $event->nick . " ctcp ping'd me.\n";
    $self->ctcp_reply($event->nick, join(' ', $event->args) . " We're here.");
}

# simple ctcp version reply
sub on_version {
    my $self = shift;
    my $event = shift;
    if ($write_to_dbug) {
        dbugr($event->dump2string);
    }
    print "[notice]: " . $event->nick . " ctcp verison'd me.\n";
    $self->ctcp_reply($event->nick, "VERSION mg2bot v$VERSION$RELEASE by Mikey G, http://mike.mg2.org/article/software/mg2bot/");
}

sub topic_handler {
    my $self = shift;
    my $event = shift;
    my @args = $event->args;
    my $channel;

    if ($write_to_dbug) {
        dbugr($event->dump2string);
    }

    # format check -- avoid bogus data
    if ($event->format eq "server") {
        $channel = lc($args[1]);
    } elsif ($event->format eq "topic") {
        $channel = lc($event->to->[0]);
        print "[notice]: " . $event->nick . " changed topic in " . $event->to->[0] . " to " . $args[0] . "\n";
    } else {
        return;
    }
    my $topic = $args[2];
    $channels->{$channel}->{'*topic'} = $topic;
    
    # any plugins for the topic.. run them now
    my @plugins = get_plugins('topic');
    foreach my $plugin (@plugins) {
        last if $plugin->[0]->($self, $event, $plugin->[1]);
    }
}

sub action_handler {
    my ($self, $event) = @_;
    if ($write_to_dbug) {
        dbugr($event->dump2string);
    }
    my @plugins = get_plugins('caction');
    foreach my $plugin (@plugins) {
        last if $plugin->[0]->($self, $event, ($event->args)[0], $plugin->[1]);
    }
}

# run when a nick event comes down the line.  copies user
# info in the channels hash over to the new name.
sub nick_change {
    my $self = shift;
    my $event = shift;
    if ($write_to_dbug) {
        dbugr($event->dump2string);
    }
    my $old_nick = lc($event->nick);
    my @args = $event->args;
    my $new_nick = lc($args[0]);
    print "[notice]: " . $event->nick . " changed nick to $new_nick\n";

    # run plugins before changing data!
    my @plugins = get_plugins('nick');
    foreach my $plugin (@plugins) {
        last if $plugin->[0]->($self, $event, $plugin->[1]);
    }

    foreach my $channel (keys %$channels) {
        if (exists($channels->{$channel}->{$old_nick})) {
            # don't be deleting anything if it's just a case change
            unless ($old_nick eq $new_nick) {
                $channels->{$channel}->{$new_nick} = $channels->{$channel}->{$old_nick};
                delete $channels->{$channel}->{$old_nick};
            }
            # always update the nick's case.. obviously there's something different
            $channels->{$channel}->{$new_nick}->{nick} = $args[0];
        }
    }
}

# what gets run if a mode change is witnessed.  not sure
# if it's bulletproof yet.  think it's not.
sub mode_handler {
    my ($self, $event) = @_;
    if ($write_to_dbug) {
        dbugr($event->dump2string);
    }
    my @args = $event->args;
    my $chan = lc($event->to->[0]);
    unless ($chan) {
        print "[error]: no channel in mode handler.\n";
        return;
    }
    my ($type, $pos);
    foreach my $char (split(//, $args[0])) {
        if ($char eq "-") {
            $type = "remove";
            ++$pos unless $pos; # fixes null user bug on mode change
                                # only increment the position if it's the first
                                # if you don't you'll get a null user in the channel's hash
            next;
        } elsif ($char eq "+") {
            $type = "add";
            ++$pos unless $pos; # fixes null user bug on mode change
            next;
        }
        if ($type eq "add") {
            # dequeue first, for quick response time
            dequeue_mode_change($chan, "+$char", $args[$pos]);

            # do plugins right away!
            my @plugins = get_plugins('add_mode');
            foreach my $plugin (@plugins) {
                last if $plugin->[0]->($self, $event, $chan, $args[$pos], $char, $plugin->[1]);
            }
            $channels->{$chan}->{lc($args[$pos])}->{opped} = 1 if $char =~ /o/i;
            $channels->{$chan}->{lc($args[$pos])}->{voiced} = 1 if $char =~ /v/i;
            if ($char =~ /b/i) {
                my $ban_exists;
                foreach my $ban (@{$channels->{$chan}->{'*bans'}}) {
                    $ban_exists = 1 if $ban eq $args[$pos];
                }
                push(@{$channels->{$chan}->{'*bans'}}, $args[$pos]) unless $ban_exists;
            }
            if ($args[$pos]) {
                print "[mode]: +$char $args[$pos] in $chan by " .  $event->nick . "\n";
            } else {
                print "[mode]: +$char $chan by " .  $event->nick . "\n";
            }
        } elsif ($type eq "remove") {
            # dequeue first, for quick response time
            dequeue_mode_change($chan, "-$char", $args[$pos]);

            # do plugins soon after!
            my @plugins = get_plugins('remove_mode');
            foreach my $plugin (@plugins) {
                last if $plugin->[0]->($self, $event, $chan, $args[$pos], $char, $plugin->[1]);
            }

            delete $channels->{$chan}->{lc($args[$pos])}->{opped} if $char =~ /o/i;
            delete $channels->{$chan}->{lc($args[$pos])}->{voiced} if $char =~ /v/i;
            if ($char =~ /b/i) {
                my @newbans;
                foreach my $ban (@{$channels->{$chan}->{'*bans'}}) {
                    next if $ban eq $args[$pos]; # exclude the one to delete.
                    push (@newbans, $ban);
                }
                $channels->{$chan}->{'*bans'} = \@newbans;
            }
            if ($args[$pos]) {
                print "[mode]: -$char $args[$pos] in $chan by " .  $event->nick . "\n";
            } else {
                print "[mode]: -$char $chan by " .  $event->nick . "\n";
            }
        }
        ++$pos;
    }
    my @plugins = get_plugins('mode');
    foreach my $plugin (@plugins) {
        last if $plugin->[0]->($self, $event, $plugin->[1]);
    }
}

sub dequeue_mode_change {
    my ($chan, $mode, $target) = @_;
    my @new_modes;
    foreach my $moderef (@{$mode_changes->{$chan}}) {
        # check lowercase too.. i donno why
        unless (($mode eq $moderef->[0]) && (($target eq $moderef->[1]) || ($target eq lc($moderef->[1])))) {
            push (@new_modes, $moderef);
        } 
    }
    $mode_changes->{$chan} = \@new_modes;
    return;
}

sub qmc {
    return queue_mode_change(@_);
}

sub queue_mode_change {
    my ($chan, $mode, $target) = @_;
    return undef if mode_is_queued($chan, $mode, $target);
    push (@{$mode_changes->{$chan}}, [$mode, $target]);
    return 1;
}

sub botlink_is_queued {
    my ($func, $args) = @_;
    foreach my $line (@$botlink_queue) {
        if (($line->[0] eq $func) && ($line->[1] eq $args)) {
            return 1;
        }
    }
    return undef;
}

sub mode_is_queued {
    my ($chan, $mode, $target) = @_;
    foreach my $moderef (@{$mode_changes->{$chan}}) {
        my $user = $moderef->[1];
        if (($mode eq $moderef->[0]) && (($target eq $moderef->[1]) || ($target eq lc($moderef->[1])))) {
            return 1;
        }
    }
    return undef;
}

# what gets called when a who reply is sent to us
# this is pretty much the authority on user tracking.
sub who_handler {
    my ($self, $event) = @_;
    if ($write_to_dbug) {
        dbugr($event->dump2string);
    }
    my $user = {};
    my @args = $event->args;
    $user->{nick} = $args[5];
    $user->{mask} = "$args[5]!$args[2]\@$args[3]";
    $user->{ircname} = substr($args[7], 2, length($args[7]));
    $user->{username} = mask_to_user($user->{mask});
    if ($user->{username}) {
        my %uD = get_all_user_data($user->{username}, $mg2bot_dir);
        $user->{firstname} = $uD{firstname};
        $user->{country} = $uD{country};
        $user->{level} = $uD{level};
    }
    if ($args[6] =~ /\@$/) {
        $user->{opped} = 1;
    } elsif ($args[6] =~ /\+$/) {
        $user->{voiced} = 1;
    }
    if (im_in_channel(lc($args[1]))) {
        $channels->{lc($args[1])}->{lc($args[5])} = $user;
    }
    my @plugins = get_plugins('whoreply');
    foreach my $plugin (@plugins) {
        last if $plugin->[0]->($self, $event, $plugin->[1]);
    }
}

# a bans list?  we'll get it here.
sub bans_handler {
    my ($self, $event) = @_;
    if ($write_to_dbug) {
        dbugr($event->dump2string);
    }
    my @args = $event->args;
    push(@{$channels->{lc($args[1])}->{'*bans'}}, $args[2]);
}

# someone got kicked?  okay.
sub on_kick {
    my $self = shift;
    my $event = shift;
    if ($write_to_dbug) {
        dbugr($event->dump2string);
    }
    my @args = $event->args;
    my $channel = lc($args[0]);
    my $nick = lc($event->to->[0]);
    if ($nick eq $my_nick) {
        print "[kick]: " . $event->from . " kicked me from $channel.\n";
        delete $channels->{$channel};
        return;
    }

    # plugin first!
    my @plugins = get_plugins('kick');
    foreach my $plugin (@plugins) {
        last if $plugin->[0]->($self, $event, $plugin->[1]);
    }

    delete $channels->{$channel}->{$nick} if $channels->{$channel}->{$nick};
    print "[notice]: $nick kicked from $channel: $args[1]\n";

}

# the on_jabber handler.. pretty much a copy of the on_public handler
sub on_jabber {
    my ($self, $event) = @_;
    if ($write_to_dbug) {
        dbugr($event->dump2string);
    }
    my @args = $event->args;
    my $msg = $args[0];

    # handle subscription stuff...
    if ($event->type eq "subscribe") {
        $self->jc->Send($event->object->Reply(type  =>  'subscribed'));
        $self->jc->Send($event->object->Reply(type  =>  'subscribe'));
    } elsif ($event->type eq "unsubscribe") {
        $self->jc->Send($event->object->Reply(type  =>  'unsubscribed'));
        $self->jc->Send($event->object->Reply(type  =>  'unsubscribe'));
    } elsif ($msg =~ /^([0-9a-zA-Z\<\>\-\=\_\#\'\?\!\.]+)\s*(.*)$/) {
        my $command = $1;
        my $args = $2;
        if ($command eq "version") {
            $self->privmsg($event->to->[0], "mg2bot v$VERSION$RELEASE by Mikey G, http://mike.mg2.org/article/software/mg2bot/");
        } else {
            # this is where i set up shop for the plugins
            my $plugin = get_plugin("jabber", $command); # look for things in the "public" context, since we're the
                                                         # "public" handler ;)
            if ($plugin) {
                #$self->privmsg("#mg2", $plugin->($args)); # perhaps we'll give $self to the plugins in the future
                # the future is now!
                eval { $plugin->[0]->($self, $event, $args, $plugin->[1]); };
                if ($@) {
                    $self->privmsg($event->to->[0], "Barf: $@");
                }
                return;
            }
        }
    }
    my @plugins = get_plugins('jabber_last');
    foreach my $plugin (@plugins) {
        last if $plugin->[0]->($self, $event, $msg, $plugin->[1]);
    }
}

# the on_console handler.. pretty much a copy of the on_public handler
sub on_console {
    my $self = shift;
    my $event = shift;
    if ($write_to_dbug) {
        dbugr($event->dump2string);
    }
    my @args = $event->args;
    my $msg = $args[0];
    my $was_a_learned;
    if (($msg =~ /^$my_nick,\s*([0-9a-zA-Z\<\>\-\=\_\#\'\?\!\.]+)\s*(.*)$/) || 
            ($msg =~ /^$my_nick,\s*\"([0-9a-zA-Z\<\>\-\=\s\_\#\'\?\!\.]+)\"\s*(.*)$/) ||
            ($msg =~ /^$shorthand_char\"([0-9a-zA-Z\<\>\-\=\s\_\#\'\?\!\.]+)\"\s*(.*)$/) || 
            ($msg =~ /^$shorthand_char([0-9a-zA-Z\<\>\-\=\_\#\'\?\!\.]+)\s*(.*)$/) ) {
        my $command = $1;
        my $args = $2;
        if ($command eq "version") {
            $self->privmsg($event->to->[0], "mg2bot v$VERSION$RELEASE by Mikey G, http://mike.mg2.org/article/software/mg2bot/");
        } elsif ($command =~ /^loadplugin[s]*$/) {
            # used to be if is_master($event->from) ..
            if (1) {
                if (!$args) {
                    $self->privmsg($event->to->[0], "Loaded: Nothing.  Errors: No plugin specified.");
                    print "[loadplugin]: Loaded: Nothing.  Errors: No plugin specified.\n";
                    return;
                }
                my %lp = load_plugins(split(/ /, $args));
                my (@plugins_loaded, @load_err);
                foreach my $key (keys %lp) {
                    if ($lp{$key} =~ /uccessfully/) {
                        push(@plugins_loaded, $key);
                    } else {
                        push(@load_err, "(ERROR loading $key: $lp{$key})");
                    }
                }
                $load_err[0] = "No errors." unless scalar(@load_err);
                if (scalar(@plugins_loaded)) {
                    $self->privmsg($event->to->[0], "Loaded: " . join(', ', (@plugins_loaded)) . ".  Errors: " . join(', ', (@load_err)));
                    print "[loadplugin]: Loaded: " . join(', ', (@plugins_loaded)) . ".  Errors: " . join(', ', (@load_err)) . "\n";
                } else {
                    $self->privmsg($event->to->[0], "Loaded: Nothing.  Errors: " . join(', ', (@load_err)));
                    print "[loadplugin]: Loaded: Nothing.  Errors: " . join(', ', (@load_err)) . "\n";
                }
            } else {
                $self->privmsg($event->to->[0], "DENIED!");
            }
        } elsif ($command =~ /^unloadplugin[s]*$/) {
            # used to be if is_master($event->from) ..
            if (1) {
                my $plugins_unloaded = unload_plugins(split(/ /, $args));
                if ($plugins_unloaded) {
                    $self->privmsg($event->to->[0], "Plugins: " . $plugins_unloaded . "unloaded.");
                    print "[unloadplugin]: Plugins: $plugins_unloaded unloaded.\n";
                } else {
                    $self->privmsg($event->to->[0], "Plugins: " . $args . " were not loaded.");
                }
            } else {
                $self->privmsg($event->to->[0], "No you aren't my master");
            }
        } else {
            # this is where i set up shop for the plugins
            my $plugin = get_plugin("console", $command); # look for things in the "public" context, since we're the
                                                         # "public" handler ;)

            if ($plugin) {
                #$self->privmsg("#mg2", $plugin->($args)); # perhaps we'll give $self to the plugins in the future
                # the future is now!
                eval { $plugin->[0]->($self, $event, $args, $plugin->[1]); };
                if ($@) {
                    $self->privmsg($event->to->[0], "Barf: $@");
                }
                return;
            }
            # get rid of shitty characters!
            $command =~ s/\?/\\\?/g;
            $command =~ s/\(/\\\(/g;
            $command =~ s/\)/\\\)/g;
            $args =~ s/\?/\\\?/g;
    	    $args =~ s/\(/\\\(/g;
	        $args =~ s/\)/\\\)/g;
        }
    }
    my @plugins = get_plugins('console_last');
    foreach my $plugin (@plugins) {
        last if $plugin->[0]->($self, $event, $msg, $plugin->[1]);
    }
}

# ahh the on_public handler.. what fields most of the bot's queries.
sub on_public {
    my $self = shift;
    my $event = shift;
    if ($write_to_dbug) {
        dbugr($event->dump2string);
    }
    my @args = $event->args;
    my $msg = $args[0];
    my $was_a_learned;
    if (($msg =~ /^$my_nick,\s*([0-9a-zA-Z\<\>\-\=\_\#\'\?\!\.]+)\s*(.*)$/) || 
            ($msg =~ /^$my_nick,\s*\"([0-9a-zA-Z\<\>\-\=\s\_\#\'\?\!\.]+)\"\s*(.*)$/) ||
            ($msg =~ /^$shorthand_char\"([0-9a-zA-Z\<\>\-\=\s\_\#\'\?\!\.]+)\"\s*(.*)$/) || 
            ($msg =~ /^$shorthand_char([0-9a-zA-Z\<\>\-\=\_\#\'\?\!\.]+)\s*(.*)$/) ) {
        my $command = $1;
        my $args = $2;
        if ($command eq "version") {
            $self->privmsg($event->to->[0], "mg2bot v$VERSION$RELEASE by Mikey G, http://mike.mg2.org/article/software/mg2bot/");
        } elsif ($command =~ /^loadplugin[s]*$/) {
            if (is_master($event->from)) {
                if (!$args) {
                    $self->privmsg($event->to->[0], "Loaded: Nothing.  Errors: No plugin specified.");
                    print "[loadplugin]: Loaded: Nothing.  Errors: No plugin specified.\n";
                    return;
                }
                my %lp = load_plugins(split(/ /, $args));
                my (@plugins_loaded, @load_err);
                foreach my $key (keys %lp) {
                    if ($lp{$key} =~ /uccessfully/) {
                        push(@plugins_loaded, $key);
                    } else {
                        push(@load_err, "(ERROR loading $key: $lp{$key})");
                    }
                }
                $load_err[0] = "No errors." unless scalar(@load_err);
                if (scalar(@plugins_loaded)) {
                    $self->privmsg($event->to->[0], "Loaded: " . join(', ', (@plugins_loaded)) . ".  Errors: " . join(', ', (@load_err)));
                    print "[loadplugin]: Loaded: " . join(', ', (@plugins_loaded)) . ".  Errors: " . join(', ', (@load_err)) . "\n";
                } else {
                    $self->privmsg($event->to->[0], "Loaded: Nothing.  Errors: " . join(', ', (@load_err)));
                    print "[loadplugin]: Loaded: Nothing.  Errors: " . join(', ', (@load_err)) . "\n";
                }
            } else {
                $self->privmsg($event->to->[0], "DENIED!");
            }
        } elsif ($command =~ /^unloadplugin[s]*$/) {
            if (is_master($event->from)) {
                my $plugins_unloaded = unload_plugins(split(/ /, $args));
                if ($plugins_unloaded) {
                    $self->privmsg($event->to->[0], "Plugins: " . $plugins_unloaded . "unloaded.");
                    print "[unloadplugin]: Plugins: $plugins_unloaded unloaded.\n";
                } else {
                    $self->privmsg($event->to->[0], "Plugins: " . $args . " were not loaded.");
                }
            } else {
                $self->privmsg($event->to->[0], "No you aren't my master");
            }
        } else {
            # this is where i set up shop for the plugins
            my $plugin = get_plugin("public", $command); # look for things in the "public" context, since we're the
                                                         # "public" handler ;)

            if ($plugin) {
                #$self->privmsg("#mg2", $plugin->($args)); # perhaps we'll give $self to the plugins in the future
                # the future is now!
                eval { $plugin->[0]->($self, $event, $args, $plugin->[1]); };
                if ($@) {
                    $self->privmsg($event->to->[0], "Barf: $@");
                }
                return;
            }
            # get rid of shitty characters!
            $command =~ s/\?/\\\?/g;
            $command =~ s/\(/\\\(/g;
            $command =~ s/\)/\\\)/g;
            $args =~ s/\?/\\\?/g;
    	    $args =~ s/\(/\\\(/g;
	        $args =~ s/\)/\\\)/g;
            if ($have_db) {
                foreach my $key (keys %learned) {
                    if ($key =~ /^[\_]*$command[\+]*$/i) {
                        $was_a_learned = 1;
                        my $phrase = $learned{$key};
                        my $from_nick = $event->nick;
                        $phrase =~ s/\$who/$from_nick/g;
                        if ($key =~ /^\_(.+?)\+$/) {
                            if ($phrase =~ /\<args\>/) {
                                $phrase =~ s/\<args\>/$args/;
                            } else {
                                $phrase = "$phrase $args";
                            }
                            $self->me($event->to->[0], "$phrase");
                            return;
                        } elsif ($key =~ /^\_/)  {
                            $self->me($event->to->[0], "$phrase");
                            return;
                        } elsif ($key =~ /\+$/) {
                            if ($phrase =~ /\<args\>/) {
                                $phrase =~ s/\<args\>/$args/;
                            } else {
                                $phrase = "$phrase $args";
                            }
                            $self->privmsg($event->to->[0], "$phrase");
                            return;
                        } else {
                            $self->privmsg($event->to->[0], "$phrase");
                            return;
                        }
                    } elsif ($args !~ /[\*\+\/\\\^\$]+/) {
                        if ($key =~ /^([\_]*)$command $args([\+]*)$/i) {
                            $was_a_learned = 1;
                            my $phrase = $learned{$key};
                            my $from_nick = $event->nick;
                            $phrase =~ s/\$who/$from_nick/g;
                            if ($1) {
                                $self->me($event->to->[0], "$phrase");
                            } else {
                                $self->privmsg($event->to->[0], "$phrase");
                            }
                        }
                    }
                }   
            }
            unless ($was_a_learned) {
                my @plugins = get_plugins('pub_command');
                foreach my $plugin (@plugins) {
                    last if $plugin->[0]->($self, $event, $msg, $plugin->[1]);
                }
            return;
            }
        }
    }
    my @plugins = get_plugins('pub_last');
    foreach my $plugin (@plugins) {
        last if $plugin->[0]->($self, $event, $msg, $plugin->[1]);
    }
}

# someone quit?  this will remove their info.
sub on_quit {
    my ($self, $event) = @_;
    my $nick = lc($event->nick);
    my @args = $event->args;
    if ($write_to_dbug) {
        dbugr($event->dump2string);
    }

    # run the plugins first, while the data is still around
    my @plugins = get_plugins('quit');
    foreach my $plugin (@plugins) {
        last if $plugin->[0]->($self, $event, $plugin->[1]);
    }

    print "[notice]: " . $event->nick . " quit IRC: $args[0]\n";
    foreach my $channel (keys %$channels) {
        delete $channels->{$channel}->{$nick};
    }
}

# people leave.. so we have to make sure we take care of their data..
# hell even the bot leaves sometimes :)
sub on_part {
    my ($self, $event) = @_;
    my $nick = lc($event->nick);
    if ($write_to_dbug) {
        dbugr($event->dump2string);
    }
    my $chan = lc($event->to->[0]);
    if ($nick eq $my_nick) {
        print "[part]: I left channel " . $event->to->[0] . ".  Clearing user list.\n";
        delete $channels->{$chan};
        return;
    }
    # breakdown channel name       known users    nick     present
    print "[notice]: " . $event->nick . " left channel " . $chan . "\n";
    delete $channels->{$chan}->{$nick} if $channels->{$chan}->{$nick};
    my @plugins = get_plugins('part');
    foreach my $plugin (@plugins) {
        last if $plugin->[0]->($self, $event, $plugin->[1]);
    }
}

# handler run when someone joins
sub on_join {
    my $self = shift;
    my $event = shift;
    if ($write_to_dbug) {
        dbugr($event->dump2string);
    }
    my $chan = lc($event->to->[0]);
    if ($event->nick ne $my_nick) {
        print "[notice]: " . $event->nick . " joined " . $chan . "\n";
        unless (im_in_channel($chan)) {
            print "[error]: i don't think im in channel " . $chan . "\n";
            return;
        }
        my $from = $event->from;
        if ($channels->{$chan}->{'*greet'}) {
            $self->privmsg($chan, grant_mode($event->nick, $from, $chan));
        } else {
            grant_mode($event->nick, $from, $chan);
        }
    } else {
        $channels->{$chan};
        $self->who($chan);
        $self->mode($chan, "+b");
        $self->topic($chan);
    }
    push(@$who_queue, $event->nick);
    my @plugins = get_plugins('join');
    foreach my $plugin (@plugins) {
        last if $plugin->[0]->($self, $event, $plugin->[1]);
    }
}

sub grant_mode {
    my ($nick, $target, $chan) = @_;
    foreach my $key (keys %$mg2_users) {
        if (mask_match($target, @{$mg2_users->{$key}->{hostmask}})) {
            my $op = 0;
            my %uD = get_all_user_data($key, $mg2bot_dir);
            foreach my $ele (@allowed_levels) {
                if ($ele == $uD{level}) {
                    $op = 1;
                }
            }
            my $type;
            if ($uD{level} == 50) {
                $type = "Administrator";
            } elsif ($uD{level} == 10) {
                $type = "Emperor";
            } elsif ($uD{level} == 7) {
                $type = "Guest";
            } elsif ($uD{level} == 40) {
                $type = "Friend";
            } else {
                $type = "User";
            }
            if ($op) {
                if ($channels->{$chan}->{'*op_users'}) {
                    if (is_opped($chan, $my_nick)) {
                        push(@{$mode_changes->{$chan}}, ['+o', $nick]);
                        print "[notice]: Gave ops to " . $nick . "[$key].\n";
                    } else {
                        print "[notice]: Wanted to give ops to " . $nick . ", in $chan but couldnt.. since im not opped in $chan.\n";
                    }
                }
            } else {
                if ($channels->{$chan}->{'*op_users'}) {
                    if (is_opped($chan, $my_nick)) {
                        push(@{$mode_changes->{$chan}}, ['+v', $nick]);
                        print "[notice]: Gave voice to " . $nick . "[$key].\n";
                    } else {
                        print "[notice]: Wanted to give voice to " . $nick . ", in $chan but couldnt.. since im not opped in $chan.\n";
                    }
                }
            }
            return "Welcome to " . $chan . ", $uD{firstname} [Level: $uD{level} ($type)]";
        }
    }
}

# when we get a msg, this is the handler that takes care of it
sub on_msg {
    my $self = shift;
    my $event = shift;
    if ($write_to_dbug) {
        dbugr($event->dump2string);
    }
    my @args = $event->args;
    my $msg = $args[0];

    my @plugins = get_plugins('priv_last');
    foreach my $plugin (@plugins) {
        last if $plugin->[0]->($self, $event, $msg, $plugin->[1]);
    }
}

# when we first connect, lets join the channels we're supposed to.
sub on_connect {
    my $self = shift;
    my $event = shift;

    # clear channel information
    undef %$channels;

    # clear wait time for auto reconnect
    $wait_time = 0;

    if ($write_to_dbug) {
        dbugr($event->dump2string);
    }
    print "[startup]: We're connected.. let's do something..\n";
    foreach my $channel (keys %{$c->{channel}}) { 
        $channel = lc($channel);
        if ($c->{channel}->{$channel}->{autojoin}) {
            $channels->{$channel}->{'*autojoin'} = $c->{channel}->{$channel}->{autojoin} ? $c->{channel}->{$channel}->{autojoin} : 0;
            $channels->{$channel}->{'*greet'} = $c->{channel}->{$channel}->{greet} ? $c->{channel}->{$channel}->{greet} : 0;
            $channels->{$channel}->{'*op_users'} = $c->{channel}->{$channel}->{op_users} ? $c->{channel}->{$channel}->{op_users} : 0;
            $channels->{$channel}->{'*autokick'} = $c->{channel}->{$channel}->{autokick} ? $c->{channel}->{$channel}->{autokick} : 0;
            $channels->{$channel}->{'*masters'} = $c->{channel}->{$channel}->{masters} ? $c->{channel}->{$channel}->{masters} : [ undef ];
            print "[startup]: Joining $channel.\n";
            $self->join($channel);
        }
    }
}

# xmlified version
# users are now an arrayref containing a buncha hashrefs.
sub fetch_local_users {
    my $u = XMLin("$mg2bot_dir/data/users.xml", ForceArray    =>      [qw(hostmask givenname level country sponsorname access)]);
    print "\t[info]: Loaded " . scalar(keys %{$u->{user}}) . " users from $mg2bot_dir/data/users.xml\n";
    return $u->{user};
}

sub store_local_users {
    my $u = {};
    ($u->{user}) = @_;
    my $xml = XMLout($u);
    open(USERS, '>', "$mg2bot_dir/data/users.xml");
    print USERS $xml;
    close(USERS);
}

sub localize_mg2 {
    localize_mg2_ldap();
}

sub localize_mg2_ldap {
    open(FILE, ">$mg2bot_dir/data/users.xml") or warn "Can't localize users into $mg2bot_dir/data/users.xml: $!\n";
    my $filter = "(ircHostmask=*)";
    my $u;
    my $mg2 = new mg2;
    my $ldap = $mg2->ldap;
    my $result = $ldap->search(
                base        =>      $mg2->c->BASE_DN,
                scope       =>      $mg2->c->SEARCH_SCOPE,
                filter      =>      $filter,
                attrs       =>      [qw(uid ircHostmask userProfile sponsorName c userLevel givenName)]);

    foreach my $e ($result->entries) {
        my $uid = $e->get_value('uid');
        $u->{user}->{$uid}->{hostmask} = [$e->get_value('ircHostmask')];
        $u->{user}->{$uid}->{givenname} = [$e->get_value('givenName')];
        $u->{user}->{$uid}->{level} = [$e->get_value('userLevel')];
        $u->{user}->{$uid}->{country} = [$e->get_value('c')];
        $u->{user}->{$uid}->{sponsorname} = [$e->get_value('sponsorName')];
        $u->{user}->{$uid}->{user_profile} = [$e->get_value('userProfile')];
    }

    print FILE XMLout($u);
    close(FILE);
    print "\t[info]: " . scalar(keys %{$u->{user}}) . " user imported from mg2 database into $mg2bot_dir/data/users.xml.\n";
}

# does the from (arg1) match the mask (arg2)?
sub mask_match {
    my ($from, @masks) = @_;

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

# resolves a user's from to a known username
sub mask_to_user {
    my $user_mask = shift;
    foreach my $key (keys %$mg2_users) {
        if (mask_match($user_mask, @{$mg2_users->{$key}->{hostmask}})) {
            return $key;
        }
    }
    return undef;
}

# Code Beautiful!
sub getHMS {
    my ($secs) = @_;
    
    return undef unless $secs =~ /^[\d\.]+$/;

    my ($sec, $min, $hrs, $day) = (0, 0, 0, 0);
    my ($minword, $secword);

    $min = $secs / 60;
    $sec = $secs % 60;
    if ($min >= 60) {
        $hrs = $min / 60;
        $min = $min % 60;
        if ($hrs >= 24) {
            $day = $hrs / 24;
            $hrs = $hrs % 24;
        }
    }

    # make sure i got my jawb strait.
    $minword = $min == 1 ? "minute" : "minutes";
    $secword = $sec == 1 ? "second" : "seconds";

    if ($day > 1) {
        return sprintf('%d:%02d:%02d:%02d', $day, $hrs, $min, $sec);
    } elsif ($hrs > 1) {
        return sprintf('%02d:%02d:%02d', $hrs, $min, $sec);
    } elsif ($min > 1) {
        return sprintf("%02d $minword, %02d $secword", $min, $sec);
    } else {
        return sprintf("%02s $secword", $sec);
    }
}

# i donno...
sub leadingZero {
    return sprintf('%02d', shift);
}

# is the user a master. 
sub is_master {
    my $check = shift;
    foreach my $ele (@masters) {
        if (mask_match($check, $ele)) {
            return 1;
        }
    }
    return undef;
}

# the plugin... is it loaded?
sub plugin_loaded {
    my $plugin_name = shift;
    foreach my $key (keys %$about_plugins) {
        foreach my $key (keys %{%$about_plugins->{$key}}) {
            return 1 if $key eq $plugin_name;
        }
    }
    return 0;
}

# what is the context of this plugin name?
sub find_context {
    my $plugin_name = shift;
    my @keys;
    foreach my $key (keys %$about_plugins) {
        next if $key eq "_internal_";
        foreach my $key2 (keys %{%$about_plugins->{$key}}) {
            return $key if $key2 eq $plugin_name;
        }
    }
    return 0;
}

sub find_contexts {
    my $plugin_name = shift;
    my @keys;
    foreach my $key (keys %$about_plugins) {
        next if $key eq "_internal_";
        foreach my $key2 (keys %{%$about_plugins->{$key}}) {
            push(@keys, $key) if $key2 eq $plugin_name; # support for same-named plugins in different contexts 
        }
    }
    return @keys;
}

# what plugins are in what contexts?
sub list_plugins {
    my %plugins;
    foreach my $key (keys %$about_plugins) {
        foreach my $key2 (keys %{%$about_plugins->{$key}}) {
	    push (@{$plugins{$key2}}, $key);
            #push (@{$plugins{$key}}, $key2);
        }
    }
    return %plugins;
}

sub run_plugin {
    my ($plugin_name, @args) = @_;
    my $plugin = get_plugin('_internal_', $plugin_name);
    if ($plugin) {
        return $plugin->[0]->(@args, $plugin->[1]);
    }
    return undef;
}

# get me the code for the plugin in this context by this name
sub get_plugin {
    my ($context_name, $plugin_name) = @_;
    foreach my $key (keys %{%$loaded_plugins->{$context_name}}) {
        next unless $key;
        # let the plugin know the calling context
        $about_plugins->{$context_name}->{$key}->{_cc_} = $context_name;
        return [$loaded_plugins->{$context_name}->{$plugin_name}, $about_plugins->{$context_name}->{$key}] if $key eq $plugin_name;
    }
    return 0;
}

# fetch me all the plugins in this context
sub get_plugins {
    my ($context_name, $plugin_name) = @_;
    my %pre_plug;
    my @plugins;

    # pass back the plugins sorted by priority!
    foreach my $key (keys %{%$loaded_plugins->{$context_name}}) {
        next unless $key;
        # let the plugin know the calling context
        $about_plugins->{$context_name}->{$key}->{_cc_} = $context_name;
        $pre_plug{$about_plugins->{$context_name}->{$key}->{p}} = [$loaded_plugins->{$context_name}->{$key}, $about_plugins->{$context_name}->{$key}];
    }
    foreach my $key (sort { $a <=> $b } keys %pre_plug) {
        push (@plugins, $pre_plug{$key});
    }
    return @plugins;
}

# get version info
sub plugin_version {
    my $plugin_name = shift;
    my $context = find_context($plugin_name);
    return $about_plugins->{$context}->{$plugin_name}->{v} if exists $about_plugins->{$context}->{$plugin_name};
    return undef;
}

# get author info
sub plugin_author {
    my $plugin_name = shift;
    my $context = find_context($plugin_name);
    return $about_plugins->{$context}->{$plugin_name}->{a} if exists $about_plugins->{$context}->{$plugin_name};
    return undef;
}

# get syntax info
sub plugin_syntax {
    my $plugin_name = shift;
    my $context = find_context($plugin_name);
    return $about_plugins->{$context}->{$plugin_name}->{s} if exists $about_plugins->{$context}->{$plugin_name};
    return undef;
}

# get help info
sub plugin_help {
    my $plugin_name = shift;
    my $context = find_context($plugin_name);
    return $about_plugins->{$context}->{$plugin_name}->{h} if exists $about_plugins->{$context}->{$plugin_name};
    return undef;
}

# get aliases
sub plugin_aliases {
    my $plugin_name = shift;
    my $context = find_context($plugin_name);
    return (split(/,/, $about_plugins->{$context}->{$plugin_name}->{al})) if exists $about_plugins->{$context}->{$plugin_name};
    return undef;
}

# loads more than one, returns a hash with errors.
sub load_plugins {
    my @plugins = @_;
    my %returns;
    foreach my $plugin (@plugins) {
        $returns{$plugin} = load_plugin("plugins/$plugin");
    }
    return %returns;
}

# load the plugin.  the heart of the mg2bot plugin system.
sub load_plugin {
    my ($plugin_file) = @_;
    my $plugin_info = {};
    my ($code, $cls);
    open(PF, '<' . $plugin_file) or return "Plugin File not found!";
    while(<PF>) {
        if (($. == 1) && ($_ ne ";;mg2bot plugin file;;\n")) {
            return "Bad plugin file format!";
            last;
        } elsif (($. == 1) && ($_ eq ";;mg2bot plugin file;;\n")) {
            next; # next line ;)
        }

        # no comments on the first line, but why not everywhere else
        next if $_ =~ /^#/;

        if ($_ =~ /^(\w{1,2})\:(.+)\n$/) { # extract the header info
            $plugin_info->{$1} = $2; # put it into the plugin_info hashref!
            next;
        }
        $code .= $_; # the rest is code!
    }
    close(PF);

    # do the config thing.
    if ($plugin_info->{cf}) {
        print "\t[info]: attempting to load config for $plugin_info->{n} from $plugin_info->{cf}... ";
        eval {
            $plugin_info->{cf} = XMLin($plugin_info->{cf});
        };
        if ($@) {
            print "Failed.\n";
        } else {
            print "Success.\n";
        }
    }

    # cleaning up a bit ;) (sorry tony)
    if ($plugin_info->{r}){
        my $errMod;
        foreach my $module (split(/,/, $plugin_info->{r})) {
            eval "use $module;";
            if ($errMod) {
                if ($@) {
                    $errMod .= ", $module";
                }
            } else {
                if ($@) {
                    $errMod = "$module";
                }
            }
         }
         return "Cannot find required modules(s): $errMod" if $errMod;
    }

    if (!$plugin_info->{c}) {
        print "[loadplugin]: No context specified in plugin file!";
    }

    if (!$plugin_info->{n}) {
        return "No name specified in plugin file!";
    }

    unless ($VERSION >= $plugin_info->{dv}) {
        return "Can't Load Plugin: running version $VERSION$RELEASE. $plugin_info->{dv} required.";
    }
    my $sub_ref;
    my $eval_code = '$sub_ref = sub ' . $code;
    eval $eval_code;

    foreach my $context (split(/,/, $plugin_info->{c}), '_internal_') {
        $loaded_plugins->{$context}->{$plugin_info->{n}} = $sub_ref;
        $about_plugins->{$context}->{$plugin_info->{n}} = $plugin_info;
        $cls = $context;
        # now with aliases...
        foreach my $alias (split(/,/, $plugin_info->{al})) {
            $loaded_plugins->{$context}->{$alias} = $sub_ref;
            $about_plugins->{$context}->{$alias} = $plugin_info;
        }
    }

    if ($@) {
        return "Error loading plugin $plugin_file: $@";
    } else {
        if ($plugin_info->{t}) {
            unless ($loaded_plugins->{$cls}->{$plugin_info->{n}}->("start")) {
                print "[t:" . $plugin_info->{t} . "]: Problem running start routine for " . $plugin_info->{n} . "\n";
            }
        }
        return "Plugin $plugin_info->{n} loaded successfully.";
    }

}

sub unload_plugins {
    my @plugins = (@_);
    my $plugins_unloaded;
    foreach my $plug (@plugins) {
        my @contexts = find_contexts($plug);
        foreach my $context (@contexts) {
            next if !exists($loaded_plugins->{$context}->{$plug});
            if ($about_plugins->{$context}->{$plug}->{t}) {
                $loaded_plugins->{$context}->{$plug}->("stop");
            }
            delete $loaded_plugins->{$context}->{$plug};
            delete $about_plugins->{$context}->{$plug};
            foreach my $alias (plugin_aliases($plug)) {
                delete $loaded_plugins->{$context}->{$alias};
                delete $about_plugins->{$context}->{$alias};
                $plugins_unloaded .= "($context/$plug as '$alias') ";
            }
            $plugins_unloaded .= "($context/$plug) ";
        }
    }
    return $plugins_unloaded;
}

# if auto_reconnect is set, lets auto reconnect with this nice handler
sub on_disconnect {
    my ($self, $event) = @_;
    print "We disconnected.  Cleaning up.\n";
    $irc->removeconn($ic);
    $ic_connected = 0;
    if ($auto_reconnect) {
        print "Auto reconnect on, attempting reconnect.\n";
        my $self = init_connection(); 
    } else {
        print "Auto reconnect off, exiting.\n";
        exit();
    }
}

# prints data to a log file!
sub dbugr {
    my ($data) = @_;
    open(DBUG, '>>' . "debug/dbug.$$") or warn "Can't open debug/dbug.$$: $!\n";
    print DBUG "[" . time2str('%C', time) . "]\n";
    print DBUG $data;
    print DBUG "\n";
    close(DBUG);
}

# for compatability
sub get_all_user_data {
    my ($user) = @_;
    if (my $u = user_lookup($user)) {
        my %ud;
        $ud{firstname} = $u->{givenname}->[0];
        $ud{sponsorname} = $u->{sponsorname}->[0];
        $ud{country} = $u->{country}->[0];
        $ud{level} = $u->{level}->[0];
        $ud{user_profile} = $u->{user_profile}->[0];
        return %ud;
    } else {
        return undef;
    }
}

sub get_channel_data {
    my ($channel, $data) = @_;
    $channel = lc($channel);
    if (exists($channels->{$channel})) {
        if (exists($channels->{$channel}->{'*' . $data})) {
            return @{$channels->{$channel}->{'*' . $data}};
        } else {
            return undef;
        }
    } else {
        return undef;
    }
}

sub is_opped {
    my ($channel, $user) = @_;
    $user = lc($user);
    $channel = lc($channel);
    return undef unless im_in_channel($channel);
    if (exists($channels->{$channel}->{$user})) {
        return $channels->{$channel}->{$user}->{opped};
    }
    return undef;
}

sub is_voiced {
    my ($channel, $user) = @_;
    $user = lc($user);
    $channel = lc($channel);
    return undef unless im_in_channel($channel);
    if (exists($channels->{$channel}->{$user})) {
        return $channels->{$channel}->{$user}->{voiced};
    }
    return undef;
}

sub is_present {
    return undef unless im_in_channel(lc($_[0]));
    return exists($channels->{lc($_[0])}->{lc($_[1])});
}

sub is_uic {
    my ($channel, $user) = @_;
    $user = lc($user);
    $channel = lc($channel);
    if ($user) {
        if (exists($channels->{$channel}->{$user})) {
            return 1;
        }
    }
    return undef;
}

# a nice case insensitive user lookup
sub user_lookup {
    my ($user) = @_;
    foreach my $u (keys %$mg2_users) {
        if ($user =~ /$u/i) {
            return $mg2_users->{$u};
        }
    }
    return undef;
}

sub im_in_channel {
    return exists($channels->{lc($_[0])});
}

# returns an array except for the one index that you specify as the first arg.
sub remove_index {
    my ($index, @array) = @_;
    @array = (@array[0..($index - 1)], @array[($index + 1)..$#array]);
}

