# Original Script (Diccionario.TCL) by BaRDaHL
#
# by ICU <icu@eggdrop-support.org> (#eggdrop.support @ irc.QuakeNet.org)
#
# Further changes by DopeGhoti <dopeghoti@gmail.com>
#
# Thanks to #eggdrop.support for all the tips and support :)
#
# ChangeLog
#
# 20110227 - More flood controls
#          - Will not repeat the same FAQ with X seconds.
# 
# 20110221 - Incorporated deflood.tcl
#          - Flood controls
# 
# 20030106 - Changed Name to faq.tcl (changed purpose)
#          - Changed some commands
#	   - Updated the language
#	   - Added some commands
#	   - Fixes:)
#
# 20030115 - Changed the ?faq helptext
#	   - Fixed all to key word
#
# 20030122 - Removed some private parts from the script (?send-faq) till 
#	     i found a solution to make it in tcl (not in perl ;-))
#	   - Changed the way ?faq works. it now uses public replys
#	     (requested by #eggdrop.support)
#
# 20030123 - Some cosmetic changes
# 
# 20030219 - Changed matchattr to don't use quotation marks
#
# 20030411 - Fixed handling of some special chars in facts/description. 
#	     Mainly changed listtostring proc.
#	     Thx to |sPhiNX| for reporting ;)
#
# 20030728 - Removed the listtostring proc. 
#            Format updates
#            Spelling
#            Changed matchattr to check for chan M too
#            Switched the Settings handling
#            Added configurable cmdchar, splitchar, glob_flag and chan_flag:
#            cmdchar: char to prefix commands
#            splitchar: seperator between keyword and definition
#            glob_flag: globalflag to be a FAQ Master
#            chan_flag: channelflag to be a FAQ Master
#            Now using keyword instead of key word
#            Switched from using "" to \002
#
# 20030730 - Fixed the "?faq nick key word" bug (wouldn't notice the second
#            part of the word)
#
# 20030731 - Added the ability to limit the chans where the script is active
#          - Bugfixes - thanks to AliTriX on #eggdrop.support
#
# 20030805 - Last bugfixes and public relase v2.07
#
# 20031011 - Honored the latest changes on egghelp.org by slennox
#
# 20040122 - Changed the default faq(splitchar) since it causes some trouble 
#            on TCL 8.4+
#          - Removed egghelp.org stuff for public release.
#
# 20040314 - Using string trim to remove trailing spaces from fact lookups
#            Thanks to bUrN for reporting
#
# 20040629 - Added possibility to use multi-line responses.
#            Thanks to arena7|Blacky for the idea
#
#
# creates a file in your eggdrop-dir to store facts
# if you want to modify the faq-database status you need to have the +M flag
# to set this flag you just need to copy ".chattr <handle> +M" to the partyline
#
# The most current Version is available here: http://no-scrub.de/other/faq.tcl.zip
#
# Depending on your faq(cmdchar) setting prefix something other then a questionmark
# Depending on your faq(splitchar) settings use something other then a paragraph sign
#
# Public commands:
# ?faq-help - usage
# ? keyword - used to look up something from the db
# ?faq nick keyword - used to explain something(keyword) to someone(nick)
#
# Master commands:
# ?addword keyword§definition - used to add something to the db
# ?delword keyword - used to delete something from the db
# ?modify keyword§definition - used to modify a keyword in the db
# ?open-faq - opens the database if closed
# ?close-faq - closes the database if opened
#
# Flood control:
# #if {![checkUser $nick $chan]} {return}

########
# SETS #
########

#	Channel flag that must be st for this script to be active in a channel
set faq(chanflag) "mcfaq"
setudef flag ${faq(chanflag)}

# File will be created in your eggdrop dir unless you specify a path
# Ex. set faq(database) "/path/to/faqdatabase"
set faq(database) "faqdatabase"

# This char will be prefixed to all commands
set faq(cmdchar) "??"

# This char is used to split the keyword from the definition on irc commands and in the database.
# Note: § will not longer work on TCL 8.4+ for some strange reason.
set faq(splitchar) "|"

# This char is used to split multiple lines in your reply/definition.
# Note: § will not longer work on TCL 8.4+ for some strange reason.
set faq(newline) ";;"

# Global flag needed to use the FAQ Master commands
set faq(glob_flag) "M"

# Channel flag needed to use FAQ Master commands (empty means noone)
set faq(chan_flag) ""

# Channels the FAQ is active on
#set faq(channels) "##VoxelHead #mcbots #MineCraftHelp #Minecraft"
#
# Deprecated, use mcfaq channel flag

# # Flood protection; default three in sixty seconds
set flood 4:180

# Flood protection for individual FAQs:
# Number of seconds withing which to prevent repeat FAQs.
set toofasttime 15

# if ![info exists ::lastFAQ] {set ::lastFAQ 0}

#  set max [lindex [split $flood ":"] 0]; set time [lindex [split $flood ":"] 1]

# if {$::lastFAQ >= $max} {set type notice; set dest $nick} \
# 	else {set type privmsg; set dest $chan}

set toofast(stub) "stub"

#################
# END OF CONFIG #
#################

##############
# STOP HERE! #
##############

# Initial Status of the Database (0 = open 1 = closed)
set faq(status) 0
# Current Version of the Database
set faq(version) "20110227 v2.17"

#########
# BINDS #
#########

bind pub - "[string trim $faq(cmdchar)]" faq:explain_fact
bind pub - "[string trim $faq(cmdchar)]>" faq:tell_fact
bind pub - "[string trim $faq(cmdchar)]<" faq:self_fact
bind pub - "[string trim $faq(cmdchar)]>>" faq:send_fact
bind pub - "[string trim $faq(cmdchar)]+" faq:add_fact
bind pub - "[string trim $faq(cmdchar)]-" faq:delete_fact
bind pub - "[string trim $faq(cmdchar)]~" faq:modify_fact
bind pub - "[string trim $faq(cmdchar)]close-faq" faq:close-faqdb
bind pub - "[string trim $faq(cmdchar)]open-faq" faq:open-faqdb
bind pub - "[string trim $faq(cmdchar)]faq-help" faq:faq_howto
bind pub - "[string trim $faq(cmdchar)]index" faq:faq_index
#bind pub - "see" faq:explain_fact

bind pub M "[string trim $faq(cmdchar)]!" faq:reset_flood

#########
# PROCS #
#########

proc faq:close-faqdb {nick idx handle channel args} {
	global faq chanflag

	if { ! [ channel get $channel ${faq(chanflag)} ] } { 
		return 0 
	}

	if {![matchattr $handle [string trim $faq(glob_flag)]|[string trim $faq(chan_flag)] $channel]} {
		putnotc $nick "You can't change the faq-database status."
		return 0
	}
	if {$faq(status)==0} {
		set faq(status) 1
		putnotc $nick "The faq-database was \002closed\002."
		putnotc $nick "Now nobody can use the command '[string trim $faq(cmdchar)] keyword'."
		putnotc $nick "To open the faq-database again use the command '[string trim $faq(cmdchar)]open-faq'."
		return 0
	}
	if {$faq(status)==1} {
		putnotc $nick "The faq-database is \002already\002 closed."
		return 0
	}
}

proc faq:open-faqdb {nick idx handle channel args} {
	global faq chanflag

	if { ! [ channel get $channel ${faq(chanflag)} ] } { 
		return 0 
	}

	if {![matchattr $handle [string trim $faq(glob_flag)]|[string trim $faq(chan_flag)] $channel]} {
		putnotc $nick "You can't change the faq-database status."
		return 0
	}
	if {$faq(status)==1} {
		set faq(status) 0
		putnotc $nick "The faq-database was \002opened\002."
		putnotc $nick "Now anybody can use the command '[string trim $faq(cmdchar)] \002keyword\002'."
		putnotc $nick "To close the faq-database again just use the command '[string trim $faq(cmdchar)]close-faq'."
		return 0
	}
	if {$faq(status)==0} {
		putnotc $nick "The faq-database is \002already\002 open."
		return 0
	}
}

proc faq:reset_flood {nick idx handle channel args } {
	set ::lastFAQ 0
	putnotc $nick "Flood counter for FAQ DB reset."
}

proc faq:explain_fact {nick idx handle channel args} {
	global faq chanflag
	global flood
	global fast
	global toofasttime
	global toofast


	if { ! [ channel get $channel ${faq(chanflag)} ] } { 
		return 0 
	}

	if ![info exists ::lastFAQ] {set ::lastFAQ 0}

	#	Parse flood settings
	set fmax [lindex [split $flood ":"] 0]
	set ftime [lindex [split $flood ":"] 1]

	#	Set output type based on flood control
	if {$::lastFAQ>=$fmax} {
		set otype notice
		set odest $nick
		putnotc $nick "Flood prevention has caused my answer to be in a CTCP NOTICE instead of in-channel."
	} else {
		set otype privmsg
		set odest $channel
	}

	#	Increase the counter now, and after time, decrease to zero
	incr ::lastFAQ
	utimer $ftime [list incr ::lastFAQ -1]

	if {$faq(status) == 1} { 
		putnotc $nick "The faq-database is \002closed\002."
		return 0 
	}
	if {![file exist $faq(database)]} { 
		set database [open $faq(database) w]
		puts -nonewline $database ""
		close $database
	}
	set fact [ string trim [ string tolower [ join $args ] ] ]
	if {$fact == ""} {
		#  putmsg $nick "Syntax: [string trim $faq(cmdchar)] \002keyword\002"
		return 0
	}

	if ![info exists toofast($fact)] {
		set toofast($fact) "yes"
		utimer $toofasttime [list unset toofast($fact)]
		set database [open $faq(database) r]
		set dbline ""
		while {![eof $database]} {
			gets $database dbline
			set dbfact [ string tolower [ lindex [split $dbline [string trim $faq(splitchar)]] 0 ]] 
			set dbdefinition [string range $dbline [expr [string length $fact]+1] end]
			if {$dbfact==$fact} {
				if {[string match -nocase "*$faq(newline)*" $dbdefinition]} {
					set out1 [lindex [split $dbdefinition $faq(newline)] 0]
					set out2 [string range $dbdefinition [expr [string length $out1]+2] end]
	#				putmsg $channel "\002$fact\002: $out1"
	#				putmsg $channel "\002$fact\002: $out2"
					puthelp "$otype $odest :\002$fact\002: $out1"
					puthelp "$otype $odest :\002$fact\002: $out2"
				} else { 
	#				putmsg $channel "\002$fact\002: $dbdefinition"
					puthelp "$otype $odest :\002$fact\002: $dbdefinition"
				}
				close $database
				return 0
			}
		}
		close $database
		putnotc $nick "I don't have an entry in my databse for the keyword, \002$fact\002.  For a link to a list of entries, check the keyword \002index\002."
		if {[matchattr $handle [string trim $faq(glob_flag)]|[string trim $faq(chan_flag)] $channel]} {
			putnotc $nick "You could add \002$fact\002 by using [string trim $faq(cmdchar)]+ \002$fact\002[string trim $faq(splitchar)]Definition goes here."
		} else {
			#  putnotc $nick "If you're looking for a TCL-Script try http://www.egghelp.org/cgi-bin/tcl_archive.tcl?strings=$fact"
		}
	} else {
		putnotc $nick "I just said that less than $toofasttime seconds ago."
		putlog "Suppressing duplication flood of $fact by $nick."
	}
	return 0
}

proc faq:tell_fact {nick idx handle channel args} {
	global faq chanflag
	global flood
	global fast
	global toofasttime
	global toofast
	

	if { ! [ channel get $channel ${faq(chanflag)} ] } { 
		return 0 
	}

	#	Flood control
	if {![checkUser $nick $channel]} {return}

	if {$faq(status)==1} { 
		putnotc $nick "The faq-database is \002closed\002."
		return 0 
	}
	if {![file exist $faq(database)]} { 
		set database [open $faq(database) w]
		puts -nonewline $database ""
		close $database
	}
	set tellnick [ lindex [split [join $args]] 0 ] 
	set fact [ string trim [ string tolower [ join [ lrange [split [join $args]] 1 end ] ] ] ]
	if {$tellnick == ""} { 
		putnotc $nick "Syntax: [string trim $faq(cmdchar)]faq \002nick\002 keyword"
		return 0 
	}
	if {$fact == ""} { 
		putnotc $nick "Syntax: [string trim $faq(cmdchar)]faq nick \002keyword\002"
		return 0
	}
	if ![info exists toofast($fact)] {
		set toofast($fact) "yes"
		utimer $toofasttime [list unset toofast($fact)]
		set database [open $faq(database) r]
		set dbline ""
		while {![eof $database]} {
			gets $database dbline
			set dbfact [ string tolower [ lindex [split $dbline [string trim $faq(splitchar)]] 0 ] ]
			set dbdefinition [string range $dbline [expr [string length $fact]+1] end]
			if {$dbfact==$fact} {
				if {[string match -nocase "*$faq(newline)*" $dbdefinition]} {
					set out1 [lindex [split $dbdefinition "$faq(newline)"] 0]
					set out2 [string range $dbdefinition [expr [string length $out1]+2] end]
					putmsg $channel "\002$tellnick\002: ($dbfact) $out1"
					putmsg $channel "\002$tellnick\002: ($dbfact) $out2"
				} else {
					putmsg $channel "\002$tellnick\002: ($dbfact) $dbdefinition"
				}
				putlog "FAQ: Send keyword \"\002$fact\002\" to $tellnick by $nick ($idx)"
				close $database
				return 0
			}
		}
		close $database
		putnotc $nick "I don't have the keyword \002$fact\002 in my database.  For a list of entries, consult the \002index\002."
		if {[matchattr $handle [string trim $faq(glob_flag)]|[string trim $faq(chan_flag)] $channel]} {
			putnotc $nick "You could add \002$fact\002 by using [string trim $faq(cmdchar)]+ \002$fact\002[string trim $faq(splitchar)]Definition goes here."
		} else {
			#  putnotc $nick "If you're looking for a TCL-Script try http://www.egghelp.org/cgi-bin/tcl_archive.tcl?strings=$fact"
		}
	} else {
		putnotc $nick "I just said that less than $toofasttime seconds ago."
		putlog "Suppressing duplication flood of $fact by $nick."
	}
	return 0
}

proc faq:add_fact {nick idx handle channel args} {
	global faq chanflag

	if { ! [ channel get $channel ${faq(chanflag)} ] } { 
		return 0 
	}

	if {$faq(status)==1} {
		putnotc $nick "The faq-database is \002closed\002."
		return 0
	}
	if {![matchattr $handle [string trim $faq(glob_flag)]|[string trim $faq(chan_flag)] $channel]} {
		putnotc $nick "You can't add keywords into my dababase."
		return 0
	}
	if {![file exist $faq(database)]} {
		set database [open $faq(database) w]
		puts -nonewline $database ""
		close $database
	}
	set fact [ string tolower [ lindex [split [join $args] [string trim $faq(splitchar)]] 0 ] ]
	set definition [string range [join $args] [expr [string length $fact]+1] end]  
	set database [open $faq(database) r]
	if {($fact=="")} {
		putnotc $nick "Left parameters."
		putnotc $nick "use: [string trim $faq(cmdchar)]+ \002keyword\002[string trim $faq(splitchar)]definition"
		return 0
	} elseif {($definition=="")} {
		putnotc $nick "Left parameters."
		putnotc $nick "use: [string trim $faq(cmdchar)]+ keyword[string trim $faq(splitchar)]\002definition\002"
		return 0
	}
	while {![eof $database]} {
		gets $database dbline
		set add_fact [ string tolower [ lindex [split $dbline [string trim $faq(splitchar)]] 0 ] ]
		if {$add_fact==$fact} {
			putnotc $nick "This keyword is already in my database:"
			putnotc $nick "Is: \002$fact\002 - $definition"
			putnotc $nick "If you want to modify it just use '[string trim $faq(cmdchar)]~ $fact[string trim $faq(splitchar)]\002definition\002'"
			close $database
			return 0
		}
	}
	close $database
	set database [open $faq(database) a]
	puts $database "$fact[string trim $faq(splitchar)]$definition"
	close $database
	putnotc $nick "The keyword \002$fact\002 was added correctly to my database."
	putnotc $nick "Now: \002$fact\002 - $definition"
}

proc faq:delete_fact {nick idx handle channel args} {
	global faq chanflag

	if { ! [ channel get $channel ${faq(chanflag)} ] } { 
		return 0 
	}

	if {$faq(status)==1} {
		putnotc $nick "The faq-database is \002closed\002."
		return 0
	}
	if {![matchattr $handle [string trim $faq(glob_flag)]|[string trim $faq(chan_flag)] $channel]} {
		putnotc $nick "You can't delete keywords from my database."
		return 0
	}
	if {![file exist $faq(database)]} { 
		set database [open $faq(database) w]
		puts -nonewline $database ""
		close $database
	}
	set fact [string tolower [join $args]]
	if {($fact=="")} {
		putnotc $nick "Left parameters."
		putnotc $nick "use: [string trim $faq(cmdchar)]delword \002keyword\002"
		return 0
	}
	set database [open $faq(database) r]
	set dbline ""
	set found 0
	while {![eof $database]} {
		gets $database dbline
		set dbfact [ string tolower [ lindex [split $dbline [string trim $faq(splitchar)]] 0 ] ]
		set dbdefinition [string range $dbline [expr [string length $fact]+1] end]
		if {$dbfact!=$fact} {
			lappend datalist $dbline
		} else {
			putnotc $nick "The keyword \002$fact\002 was deleted correctly from my database."
			putnotc $nick "Was: \002$dbfact\002 - $dbdefinition"
			set found 1
		}
	}
	close $database
	set databaseout [open $faq(database) w]
	foreach line $datalist {
		if {$line!=""} {puts $databaseout $line}
	}
	close $databaseout
	if {$found != 1} {putnotc $nick "\002$fact\002 not found in my database."}
}

proc faq:modify_fact {nick idx handle channel args} {
	global faq chanflag

	if { ! [ channel get $channel ${faq(chanflag)} ] } { 
		return 0 
	}

	if {$faq(status)==1} {
		putnotc $nick "The faq-database is \002closed\002."
		return 0
	}
	if {![matchattr $handle [string trim $faq(glob_flag)]|[string trim $faq(chan_flag)] $channel]} {
		putnotc $nick "You can't modify keywords in my database."
		return 0
	}
	if {![file exist $faq(database)]} { 
		set database [open $faq(database) w]
		puts -nonewline $database ""
		close $database
	}
	set fact [ string tolower [ lindex [split [join $args] [string trim $faq(splitchar)]] 0 ] ]
	set definition [string range [join $args] [expr [string length $fact]+1] end]
	set database [open $faq(database) r]
	if {($fact=="")} {
		putnotc $nick "Left parameters."
		putnotc $nick "use: [string trim $faq(cmdchar)]modify \002keyword\002[string trim $faq(splitchar)]definition"
		return 0
	}
	if {($definition=="")} {
		putnotc $nick "Left parameters."
		putnotc $nick "use: [string trim $faq(cmdchar)]modify keyword[string trim $faq(splitchar)]\002definition\002"
		return 0
	}
	set database [open $faq(database) r]
	set dbline ""
	set found 0
	while {![eof $database]} {
		gets $database dbline
		set dbfact [ string tolower [ lindex [split $dbline [string trim $faq(splitchar)]] 0 ] ]
		set dbdefinition [string range $dbline [expr [string length $fact]+1] end]
		if {$dbfact!=$fact} {
			lappend datalist $dbline
		} else {
			if {$dbdefinition!=$definition} {
				lappend datalist "$fact[string trim $faq(splitchar)]$definition"
				putnotc $nick "The keyword \002$fact\002 was modified correctly in my database."
				putnotc $nick "Is now: \002$fact\002 - $definition"
				putnotc $nick "Was: $dbfact - $dbdefinition"
				set found 1
			} else {
				lappend datalist $dbline
				putnotc $nick "I already had it that way. \002$fact\002 was not modified."
				putnotc $nick "Is: \002$fact\002 - $definition"
				set found 1
			}
		}
	}
	close $database
	set databaseout [open $faq(database) w]
	foreach line $datalist {
		if {$line!=""} {puts $databaseout $line}
	}
	close $databaseout
	if {$found != 1} {
		putnotc $nick "\002$fact\002 not found in my database"
		putnotc $nick "If you want to add the fact to the database use: [string trim $faq(cmdchar)]+ $fact[string trim $faq(splitchar)]\002description\002"
	}
}

proc faq:faq_howto {nick idx handle channel args} {
	global faq chanflag

	if { ! [ channel get $channel ${faq(chanflag)} ] } { 
		return 0 
	}

	putnotc $nick "Help commands for FAQ Database $faq(version)"
	if {[matchattr $handle [string trim $faq(glob_flag)]|[string trim $faq(chan_flag)] $channel]} {
		if {$faq(status)==0} {
			putnotc $nick " - [string trim $faq(cmdchar)]close-faq"
			putnotc $nick " - [string trim $faq(cmdchar)]+ : [string trim $faq(cmdchar)]+ \002keyword\002[string trim $faq(splitchar)]your description goes here..."
			putnotc $nick " - [string trim $faq(cmdchar)]- : [string trim $faq(cmdchar)]- \002keyword\002"
			putnotc $nick " - [string trim $faq(cmdchar)]~ : [string trim $faq(cmdchar)]~ \002keyword\002[string trim $faq(splitchar)]your new description goes here..."
		}
		if {$faq(status)==1} {
			putnotc $nick " - [string trim $faq(cmdchar)]open-faq"
		}
	}
	if {$faq(status)==0} {
		putnotc $nick " - [string trim $faq(cmdchar)] \002keyword\002 : looks up keyword in the database"
		putnotc $nick " - To let the bot tell someone about something use [string trim $faq(cmdchar)]> nick \002keyword\002"
	}
	if {$faq(status)==1} {
		putnotc $nick "The faq-database is \002closed\002."
	}
}

proc faq:faq_index {nick idx handle channel args} {
	global faq chanflag

	if { ! [ channel get $channel ${faq(chanflag)} ] } { 
		return 0 
	}

	if {![checkUser $nick $chan]} {return}
	putnotc $nick "A list of FAQ keywords can be seen at http://mchelp.darksigns.net/faqindex"
	if {$faq(status)==1} {
		putnotc $nick "The faq-database is \002closed\002."
	}
}

proc faq:self_fact {nick idx handle channel args} {
	global faq chanflag
	set otype notice
	set odest $nick


	if { ! [ channel get $channel ${faq(chanflag)} ] } { 
		return 0 
	}

	if {$faq(status) == 1} { 
		putnotc $nick "The faq-database is \002closed\002."
		return 0 
	}
	if {![file exist $faq(database)]} { 
		set database [open $faq(database) w]
		puts -nonewline $database ""
		close $database
	}
	set fact [ string trim [ string tolower [ join $args ] ] ]
	if {$fact == ""} {
		#  putmsg $nick "Syntax: [string trim $faq(cmdchar)] \002keyword\002"
		return 0
	}
	set database [open $faq(database) r]
	set dbline ""
	while {![eof $database]} {
		gets $database dbline
		set dbfact [ string tolower [ lindex [split $dbline [string trim $faq(splitchar)]] 0 ]] 
		set dbdefinition [string range $dbline [expr [string length $fact]+1] end]
		if {$dbfact==$fact} {
			if {[string match -nocase "*$faq(newline)*" $dbdefinition]} {
				set out1 [lindex [split $dbdefinition $faq(newline)] 0]
				set out2 [string range $dbdefinition [expr [string length $out1]+2] end]
#				putmsg $channel "\002$fact\002: $out1"
#				putmsg $channel "\002$fact\002: $out2"
				puthelp "$otype $odest :\002$fact\002: $out1"
				puthelp "$otype $odest :\002$fact\002: $out2"
			} else { 
#				putmsg $channel "\002$fact\002: $dbdefinition"
				puthelp "$otype $odest :\002$fact\002: $dbdefinition"
			}
			close $database
			return 0
		}
	}
	close $database
	putnotc $nick "I don't have an entry in my databse for the keyword, \002$fact\002.  For a list of entries, consult keyword \002index\002."
	if {[matchattr $handle [string trim $faq(glob_flag)]|[string trim $faq(chan_flag)] $channel]} {
		putnotc $nick "You could add \002$fact\002 by using [string trim $faq(cmdchar)]+ \002$fact\002[string trim $faq(splitchar)]Definition goes here."
	} else {
		#  putnotc $nick "If you're looking for a TCL-Script try http://www.egghelp.org/cgi-bin/tcl_archive.tcl?strings=$fact"
	}
	putlog "$nick asked for information on $fact for emself."
	return 0
}

proc faq:send_fact {nick idx handle channel args} {
	global faq chanflag
	

	if { ! [ channel get $channel ${faq(chanflag)} ] } { 
		return 0 
	}

	#	Flood control
	if {![checkUser $nick $channel]} {return}

	if {$faq(status)==1} { 
		putnotc $nick "The faq-database is \002closed\002."
		return 0 
	}
	if {![file exist $faq(database)]} { 
		set database [open $faq(database) w]
		puts -nonewline $database ""
		close $database
	}
	set tellnick [ lindex [split [join $args]] 0 ] 
	set fact [ string trim [ string tolower [ join [ lrange [split [join $args]] 1 end ] ] ] ]
	if {$tellnick == ""} { 
		putnotc $nick "Syntax: [string trim $faq(cmdchar)]faq \002nick\002 keyword"
		return 0 
	}
	if {$fact == ""} { 
		putnotc $nick "Syntax: [string trim $faq(cmdchar)]faq nick \002keyword\002"
		return 0
	}
	set database [open $faq(database) r]
	set dbline ""
	while {![eof $database]} {
		gets $database dbline
		set dbfact [ string tolower [ lindex [split $dbline [string trim $faq(splitchar)]] 0 ] ]
		set dbdefinition [string range $dbline [expr [string length $fact]+1] end]
		if {$dbfact==$fact} {
			if {[string match -nocase "*$faq(newline)*" $dbdefinition]} {
				set out1 [lindex [split $dbdefinition "$faq(newline)"] 0]
				set out2 [string range $dbdefinition [expr [string length $out1]+2] end]
#				putmsg $channel "\002$tellnick\002: ($dbfact) $out1"
#				putmsg $channel "\002$tellnick\002: ($dbfact) $out2"
				putnotc $tellnick "$nick wanted you to know about \002$dbfact\002:"
				putnotc $tellnick "$out1"
				putnotc $tellnick "$out2"
				putnotc $nick "I told $tellnick about \002$dbfact\002."
			} else {
				putnotc $tellnick "$nick wanted you to know about \002$dbfact\002:"
#				putmsg $channel "\002$tellnick\002: ($dbfact) $dbdefinition"
				putnotc $tellnick "$dbdefinition"
				putnotc $nick "I told $tellnick about \002$dbfact\002."
			}
			putlog "FAQ: Privately send keyword \"\002$fact\002\" to $tellnick by $nick ($idx)"
			close $database
			return 0
		}
	}
	close $database
	putnotc $nick "I don't have the keyword \002$fact\002 in my database.  For a list of entries, consult the keyword \002index\002."
	if {[matchattr $handle [string trim $faq(glob_flag)]|[string trim $faq(chan_flag)] $channel]} {
		putnotc $nick "You could add \002$fact\002 by using [string trim $faq(cmdchar)]+ \002$fact\002[string trim $faq(splitchar)]Definition goes here."
	} else {
		#  putnotc $nick "If you're looking for a TCL-Script try http://www.egghelp.org/cgi-bin/tcl_archive.tcl?strings=$fact"
	}
	putlog "$nick sent info on $fact to $tellnick."
	return 0
}

#######
# LOG #
#######

putlog "FAQ-Database $faq(version) loaded."

#################
# END OF SCRIPT #
#################
