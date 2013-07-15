#!/usr/bin/perl

# plugins.pl
# (c)2003 Michael Gregorowicz
# the mg2 organization
#
# plugins engine for the mg2bot

my $loaded_plugins = {};
my $about_plugins = {};

our $VERSION = "0.40";

my $scoped_variable = "Can you see me?";

print load_plugin($ARGV[0]) . "\n";
print load_plugin("googlize.plugin") . "\n";

$class = find_class("roger");

# call the googlize plugin.
print $loaded_plugins->{$class}->{roger}->("your hard cock") . "\n" if plugin_loaded("roger");

sub plugin_loaded {
    my $plugin_name = shift;
    foreach my $key (keys %$about_plugins) {
        foreach my $key (keys %{%$about_plugins->{$key}}) {
            return 1 if $key eq $plugin_name;
        }
    }
    return 0;
}

sub find_class {
    my $plugin_name = shift;
    foreach my $key (keys %$about_plugins) {
        foreach my $key2 (keys %{%$about_plugins->{$key}}) {
            return $key if $key2 eq $plugin_name;
        }
    }
    return 0;
}

sub plugin_version {
    my $plugin_name = shift;
    my $class = find_class($plugin_name);
    return $about_plugins->{$class}->{$plugin_name}->{v} if $about_plugins->{$class}->{$plugin_name};
    return undef;
}

sub load_plugin {
    my ($plugin_file) = @_;
    my $plugin_info = {};
    my $code;
    open(PF, '<' . $plugin_file) or return "Plugin File not found!";
    while(<PF>) {
        if (($. == 1) && ($_ ne ";;mg2bot plugin file;;\n")) {
            return "Bad plugin file format!";
            last;
        } elsif (($. == 1) && ($_ eq ";;mg2bot plugin file;;\n")) {
            next; # next line ;)
        }
        if ($_ =~ /^(\w{1,2})\:([\w\d\.\_]+)\n$/) { # extract the header info
            $plugin_info->{$1} = $2; # put it into the plugin_info hashref!
            next;
        }
        $code .= $_; # the rest is code!
    }
    close(PF);
    if (!$plugin_info->{c}) {
        return "No class specified in plugin file!";
    }
    if (!$plugin_info->{n}) {
        return "No name specified in plugin file!";
    }
    $code = '$loaded_plugins->{$plugin_info->{c}}->{$plugin_info->{n}} = sub ' . $code ;
    return "Can't Load Plugin: running version $VERSION. $plugin_info->{dv} required." if $VERSION < $plugin_info->{dv};
    $about_plugins->{$plugin_info->{c}}->{$plugin_info->{n}} = $plugin_info;
    eval $code;
    if ($@) {
        return "Error loading plugin: $@";
    } else {
        return "Plugin $plugin_info->{n} loaded successfully.";
    }
}
