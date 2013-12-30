#! /usr/bin/env tclsh
#

# For each file found in arguments run extraction of strings
proc processArgs {} {
	foreach File [lsearch -inline -all $::argv *.po] {
		writeMsgFile [parsePo [file normalize $File] ] $File
	}
}
# Parse .po file into a list
proc parsePo { File } {
	set i 0
	set data [open $File r]
	while {-1 != [gets $data line]} {
		if { $line eq {} } {
			incr i
			continue
		}
		dict lappend poparsed $i $line
	}
    close $data
    dict for {key value} $poparsed {
		if { [llength $value] > 6 } {
			set ::header $value
			continue
		}
		set vlist [join $value]
		lappend result $vlist
		incr i
	}
	return $result
}
# Prints list data from parsePo to a .msg format
proc writeMsgFile { data name } {
	set lang [file tail [file root $name]]
	set dirname [file dirname [file normalize [info script]]]
	set filename [file join $dirname ${lang}.msg]

	set File [open $filename w]
	puts $File "# Translation file for $name\n"

	foreach line $::header {
		puts $File [format {# %s} $line]
	}
	puts -nonewline $File "\n"
	puts $File "::msgcat::mcmset $lang \{"
	set format_string {{%1$s} {%2$s}}
	set format_notrans {{%1$s} {%1$s}}
	foreach el $data {
		set orstring [lindex $el end-2]
		set transtring [lindex $el end]
		puts $File [format [expr {($transtring eq {}) ? $format_notrans : $format_string } ] $orstring $transtring]
	}
	puts $File \}

	close $File
}

processArgs