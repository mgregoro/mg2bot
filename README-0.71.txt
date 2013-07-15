the mg2bot
v0.71b

(c) 2008 Michael Gregorowicz
         the mg2 organization
         (mike at mg2.org)

Please see the document "LEGAL" for information pertaining to the
distribution of this software.

the mg2bot was written primarily to do channel maintenence for the channel
#mg2 on efnet.  this is the channel that our users come to to ask questions
and hang out.  the user system is currently strongly tied to our sql based
user database.  this is why many of you will find it lacking.

the thing that separates mg2bot from the rest of the perl based irc bots is
that it's based on Net::IRC, not POE.  yes i am aware this is a bad thing, but
Net::IRC is nice and simple, (albeit poorly documented.. just like my bot..)
and works just fine on my favorite irc network (efnet).

i know what the bot is missing.  it's missing plenty.  i've focused on some
areas that some of you might find useful, and i've let areas slip that some of
you might find essential.  if you find the bot to be useful, and have one or
two things you require to use the bot, let me know.  i'll probably add them if
they're not stupid (not that that's stopped me at all).  one of the bot's
strong points is the plugin system, if you are a perl programmer please
utilize them and send me what you've done.  it would be much appreciated.

below you will find release notes.  that's about all the running documentation
i've been keeping.  if you need help setting up the bot, please visit #mg2 on
efnet.  usually there is someone there who will be able to help with your
questions.

Release Notes:

First Release: 0.31pr
The first (private) release of the mg2bot. 

Last Release: 0.41pr
* Added plugin author / help / syntax information subs to the main bot
* Created plugin "plugin" to handle the interface to the new plugin info
* Implemented the first round of account inventory (user tracking) to 
allow for future enhancements that require this information.  A number of 
new handlers were created to take care of this.
* Upgraded plugins to link the IRC nick back to the mg2 username.
* Created the plugin "last" to allow users to check when their friends 
were last seen in the channel.
* Created a debugging mechanism.  (Requires an upgrade to Net::IRC::Entry 
to allow for the dump2string method to work.  Turning debugging on 
without this will CRASH the mg2bot.)
* Cleaned up the mg2bot directory structure and configuration options a bit 
more.  (Note you must set the $mg2bot_dir configuration value for the bot 
to function correctly).

Previous Release: 0.42pr
* Added local user database functionality and library.

Previous Release: 0.42pr-r2
* patched the stupid learn loophole (at the source) - Thanks tony for
fixing that up
* Fixed local user database, added country and sponsor fields

Previous Release: 0.45pr
* ripped out all my user tracking stuff from 0.42.  We now use the
lightweight "who" rather than the bulky "whois".
* got rid of "known_users" as well as join / part timestamps.  that
just seemed excessive.  if you find a use for it i will explain how
you can write a plugin to provide the same functionality
* replaced mg2bot's weather plugin with tony c's weather plugin.
* added the priority based event plugins.  This requires a bit of 
explanation so im going to go on now.  The two new plugin contexts
are "pub_last" and "priv_last".  These plugins sit at the end of the
on_public and on_msg handlers.  They're gathered by the get_plugins
function inside d.pl.  Eventually the code for this and the contexts for
all of this will be in EVERY handler.  But for now.. they're just in the
msg and public handlers.  Anyways the plugins are returned in an array
sorted by their PRIORITY.  (the p: header field).  The HIGHER the
priority number the lower the priority.  1 is the highest priority, and
well there's no limit to the lowest priority.  The plugins should
return either undef or a true value.  if a plugin returns true, it stops
running plugins and continues on.  if a plugin returns undef, it runs
the next plugin.  VERY NEET EH? ok.. thanks.
* added googlism as the first priorty based event plugin.  right now
it's priority 1.
* removed googlism code from the bot proper.
* created the %channels hash for channels and users.
* set up a $auto_reconnect flag enabling the bot to auto reconnect
* set up localize_mg2 function to localize the mg2 user database in the
mg2bot format, eliminating the total dependence on the mg2 user database
for the bots normal activities.  It can/will still op users regardless
of mg2 going down etc.
* updated status plugin
* updated userinfo plugin
* eliminated last plugin
* added the catchall_pub and catchall_priv plugins just to be cool.
* added the last handlers to contexts 'quit', 'join', 'part', and 'nick'
for quits, joins, parts, and nick changes repsectively.
* fixed the stupid channel-polluting bug.

Previous Release: 0.51pr
* added support for plugins belonging to multiple contexts.
* added configuration file (XML::Simple required)
* added channel info, bans, ops, etc.  (made the info more robust)
* added get_channel_data function to the main bot.
* chui101 moved scramble into a plugin
* updated lots of plugins to allow for private / public contexts
* worked out more data corruption bugs.
* more, but i'm too lazy to type right now.  i think these are the big
ones.

Previous Release: 0.52pr
* fixed the scramble plugin
* fixed the nick_change handler.. my dumb ass was changing all the
channels the bot was in to reflect the change.. thus anyone who changed
their nick in any of the channels suddenly showed up with their new nick
in all the channels.... this is all fixed ;)

Previous Release: 0.53b 
* implemented start and stopable plugins.  any plugin with a true value
in their t: header line will have their plugin run with "start" or
"stop" as their first argument during startup or shutdown respectively.
This can be used going forward for dependency self-checking.  Keep in
mind you should handle at least the "start" command and return a true
value or you will get a warning printed out on the console.
* wrote a plugin "log" that does what the name implies..  it logs
channel activity excluding bot-interactive commands and the bot's own
yacking.  It logs for every channel that it's in, this could still be
buggy, in fact i'm willing to wager it is.  Please let me know if you
encounter any bugs with the log plugin.
* Altered listplugins to list the plugins and the contexts they're in in
[]'s afterwards.  This is ugly and will be changed again.  The other way
was just too much spam.
* Altered plugininfo to list all contexts that a plugin is loaded into.
a rule going forward: NO PLUGIN MAY HAVE THE SAME NAME AS ANOTHER PLUGIN
NO MATTER WHAT CLASS IT GOES IN.  That's not a hard one to live by.  I
mean how long did we get by with 8x3 filenames (YAY DOS).
* Now, all output output by a plugin needs to have [pluginname]:
prefixed by the plugin.  This isn't via privmsg but printed to the bot's
console.  Debating writing a plugprint() function or ppr() which will
take care of this task for you.
* Worked really really really really really really hard to get the
channel inventory debugged and working properly.  It should be sane 99%
of the time now.  Please let me know the bot's output if the bot crashes
using the log plugin or any other plugin that uses the %channels hash.
* this is the first beta release.  please distribute discretely.

Previous Release: 0.57b
* lots of new features!!!

Previous Release: 0.60b
* Figured there have been so many releases since 0.53, I owe you guys a
bit of documentation as to what we modified.  I'll start with the most
recent additions since thats what i remember.
* Integrated Net::IRC into the bot, as well as Digest::Perl::MD5
Got rid of DBI and most traces of *SQL stuff.  the mg2 userbase
recently switched to LDAP, so I interface with my mg2 API.  So you
will notice an "mg2" dependency check at startup.
* Implemented preliminary botlink code.  We can handshake now, as well
as transfer messages across the botnet.  A few plugins were created to
serve these purposes, need_ops, op_bots.  They implement a botlink
handler that knows how to handle a request for ops.
* Fixed all sorts of network bugs by getting rid of the SIGALRM's in
lieu of creating our own primary bot loop and checking it on a basis
determined by the tick_length.
* Implemented ping_timeout config option which disconnects the bot and
reconnects if specified number of ticks passes between pings.
* Implemented per plugin config files using cf: header and XML::Simple
* Implemented mode change coordination into the mode_handler.  Bot now
dequeues queued operation that it witnesses happen.  For instance, a bot
which queued an op of another bot due to a relationship, dequeues it
when it sees it opped in the channel.  Tweak tick_length to taste.
* So so many other things.  I can't remember anymore.  If your code
broke or something tell me and I'll figure it out.  I'll be better at
documenting the next release.

Previous Release: 0.61b
* enhanced plugin system to allow for header information to be passed to
the plugin when it's called. %{$_[$#_]}
* enhanced plugin system to allow for context to be passed to the 
plugin when it's called.  (which event) $_[$#_]->{_cc_}
* enhanced plugin system, added new contexts: add_mode, remove_mode
* enhanced mode event system, added function queue_mode_change(), and
shorthand qmc().
* rewrote mask_match routine to more accurately say wether a from
(corrupt!corrupt@rem.mg2.org) matches a mask (*!*@*.mg2.org)
* wrote user_protect plugin to protect known users from being deopped,
devoiced, kicked, or banned.
* separated privilege distribution into a single function called
grant_mode.  this function handles ops, voices, greets, etc.
* added is_present() function to see wether or not a user... well..
is_present.

Previous Release: 0.62b
* fixed a bug in the scope of have_db
* XML::Simple now included with the bot
* updated user system to use new xml format
* added plugin jeekfortune (based on jeek.net/jeekfortune)
* added plugin rydia based on the bot "Rydia" from efnet #teen
* misc. bug fixes
* finalized botlink initiation implementation.  It now works with masks
instead of nicks.

Skipped (and subsequently canned) Release: 0.63b
* Added httpd functionality which destabalized the bot.. it was good in
theory but never really proved itself to be really useful without being
a huge security problem.  Not that mg2bot is fort knox, but deviating
from watching IRC as the bot's primary responsibility could harm the
usefulness of the bot.
* Added tinyurl plugin
* Added karma plugin
* Tweaked rydia plugin
* Worked out kinks in 0.62b

Previous Release: 0.64
* 0.63b (non-httpd) took the uptime record from 0.46pr (Which actually 
wasn't ever released to anyone).  The bot's been running for over 75 
days with no problems or glitches.  I figure it's worth a non-beta 
release now.  Thanks to everyone who worked on either coding or testing
this project with me.  thx to tony, que, jeek, chui, nomad, kriss, and
toby.  you have all taught me how to develop an irc bot without annoying
the hell out of everyone.  I hope it's been useful to everyone.
* All unreleased features of 0.63b

Private Release: 0.65pr
* Improved plugin loading mechanism to refer to one compilation of the 
plugin per context.. vs one compilation for every context.. this should cut 
down on plugin load time and memory usage.
* Added the _internal_ context which allows plugins to be called
internally..  from other plugins and from within the bot itself (though
I highly advise against hardcoding plugin calls into the bot proper). 
* Added the run_plugin() function which allows you to run a plugin from
somewhere else in the bot.  run_plugin($plugin_name, @arguments) is the
way to run it.
* Added a test plugin run_plugin
* Added plugin spy which can be used to direct traffic from one channel
to another.  Usage: botname, spy #src_chan #dst_chan .. 

Previous Release: 0.70b
* Changed terminology "plugin classes" to "plugin contexts" in all code 
and documentation.
* Added Jabber support by creating the proxy class mg2bot::jabber and
mg2bot:jabber::event .. existing plugins work with minimal massaging, 
a few plugins were ported simply by adding "jabber" to the c: line in 
the plugin header.
* Fixed the on_console event handler, it was running all plugins for any
command typed on the command line regardless of weither or not it could
actually find a plugin for that command name.
* Net::Jabber required for Jabber support.
* Added virtuescore and virtuemonitor plugins for monitoring peoples' 
virtuemeter.com accounts.  (Shameless plug)
* Added learn, unlearn, and relearn plugins re-instituting legacy mg2bot
factoid support (abandoning the mission to plugin-ify infobot).

Current Release: 0.71
* Fixed a scheduled event bug that caused the bot to freeze up in
certain situations.
* Added wowitem plugin for looking up World of Warcraft items on wowhead
* Added random_quote, areacode, and emeter general bot plugins
* Major overhaul of the calc plugin, allows for the use of math
functions like abs(), sqrt(), etc

