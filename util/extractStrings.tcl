#! /usr/bin/env tclsh
#
# Call clock before rewritting msgcat creator to avoid having it set
# extra strings
set now [split [clock format [clock seconds] -format %Y/%m/%d/%u] "/"]
package require msgcat
namespace eval ::msgcat {

	variable msgdata

	proc mc {src args} {
	    # Check for the src in each namespace starting from the local and
	    # ending in the global.

		variable msgdata
	    variable Msgs
	    variable Loclist
	    variable Locale

	    set ns [uplevel 1 [list ::namespace current]]

	    while {$ns != ""} {
	        foreach loc $Loclist {
	            lappend msgdata $src
	            if {[dict exists $Msgs $loc $ns $src]} {
	                if {[llength $args] == 0} {
	                    return [dict get $Msgs $loc $ns $src]
	                } else {
	                    return [format [dict get $Msgs $loc $ns $src] {*}$args]
	                }
	            }
	        }
	        set ns [namespace parent $ns]
	    }
	    # we have not found the translation
	    return [uplevel 1 [list [namespace origin mcunknown] \
	            $Locale $src {*}$args]]
	}
}

# For each file found in arguments run extraction of strings
proc processArgs {} {
	foreach File [lsearch -inline -all $::argv *.tcl] {
		loadMagCatStrings [file normalize $File]
		getMsgCatStrings [file normalize $File]
		writeMsgCatTCL [lsort -uniq $::msgcat::msgdata] $File
		#loadMagCatStrings [file normalize $File]
	}
}
# Find all msgcat strings in tcl file
# Return list
proc getMsgCatStrings { File } {
	set data [open $File r]
	while {-1 != [gets $data line]} {
		set result [regexp -inline -all -- {\[(?:::msgcat::)??mc (?:.*?)\]} $line]
		if {$result ne {}} {
			foreach match $result {
				set parsed [lindex [string trim $match {\[\{\}\]}] 1]
				if {[string index $parsed 0] ne {$}} {
					lappend ::msgcat::msgdata $parsed
				}
			}
		}
		incr i
	}
    close $data
}

# Get all mc runtime strings on tcl script and append them to list
proc loadMagCatStrings { File } {
	source $File 
}
# Write Tcl file with only the strings for msgcat
proc writeMsgCatTCL { strings name } {
	set dirname [file dirname [file normalize [info script]]]
	set filename [file join $dirname "msgcatSTR_[file tail $name]"]
	set File [open $filename w]
	puts $File "# Translation strings for $name"
	foreach find $strings {
		# set string [lindex $find 1]
		puts $File [format {::msgcat::mc "%s"} [string map {$ \\$} $find]]
	}
	close $File
}
processArgs

#writeMsgCatTCL [getMsgCatStrings $string]
# <TAG\b[^>]*>(.*?)</TAG>
# workflow
# Script takes all trans strings from file to a "dict for making po"
# dict used as source for gettext
# po edited file (LANG.po) to new parser for .msg formatting

set postring {
msgid ""
msgstr ""
"Project-Id-Version: \n"
"Report-Msgid-Bugs-To: \n"
"POT-Creation-Date: 2013-12-20 18:56-0600\n"
"PO-Revision-Date: 2013-12-20 18:56-0600\n"
"Last-Translator: IvanYossi <ghevan@gmail.com>\n"
"Language-Team: \n"
"Language: \n"
"MIME-Version: 1.0\n"
"Content-Type: text/plain; charset=UTF-8\n"
"Content-Transfer-Encoding: 8bit\n"
"X-Poedit-KeywordsList: ::mc\n"
"X-Poedit-Basepath: ../\n"
"X-Poedit-SourceCharset: utf-8\n"
"X-Poedit-SearchPath-0: .\n"
"X-Poedit-SearchPath-1: ..\n"

#: artscript2.tcl:48
#: ../artscriptk/artscript2.tcl:48
msgid "Tk drag and drop enabled"
msgstr "Tk, arrastrar y soltar, habilitado"

#: artscript2.tcl:157
#: ../artscriptk/artscript2.tcl:157
#, tcl-format
msgid "%1$s not found"
msgstr "%1$s no encontrado"

#: artscript2.tcl:290
#: ../artscriptk/artscript2.tcl:290
#, tcl-format
msgid "%s is not a valid ORA/KRA"
msgstr ""

}
# puts $postring

# Converts .po file into .msg format
# returns list
proc parsePo { postring {fileName 0} } {
	set i 0
	foreach line [split $postring \n] {
		if { $line eq {} } {
			incr i
			continue
		}
		dict lappend poparsed $i $line
	}
	dict for {key value} $poparsed {
		if { [llength $value] > 6 } {
			continue
		}
		set vlist [join $value]
		lappend result $vlist
		incr i
	}
	return $result
}
proc writeMsgFile { data } {
	foreach el $data {
		# set line [join [lrange $el 0 1]]
		set orstring [lindex $el end-2]
		set transtring [lindex $el end]
		puts [format {msgcat::mcset %s {%s} {%s}} $::LANG $orstring $transtring]
	}
}
# writeMsgFile [parsePo $postring]