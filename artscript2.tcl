#!/usr/bin/wish
#
# ---------------:::: ArtscriptTk ::::-----------------------
#  Version: 2.0.1
#  Author:IvanYossi / http://colorathis.wordpress.com ghevan@gmail.com
#  Script inspired by David Revoy artscript / www.davidrevoy.com info@davidrevoy.com
#  License: GPLv3 
# -----------------------------------------------------------
#  Goal : Aid in the deploy of digital artwork for media with the best possible quality
#   Dependencies: >=imagemagick-6.7.5, tk 8.5 zip md5
#   Optional deps: calligraconverter, inkscape, gimp
#
#  Customize:__
#   Make a config file (rename presets.config.example to presets.config)
#   File must be in the same directory as the script.
#
# ---------------------::::::::::::::------------------------
package require Tk
set ::version "v2.0.1"

# Do not show .dot files by default
catch {tk_getOpenFile foo bar}
set ::tk::dialog::file::showHiddenVar 0
set ::tk::dialog::file::showHiddenBtn 1

#Set default theme to clam if supported
catch {ttk::style theme use clam}
namespace eval img { }

# array set ::settings $::artscript::usett
# puts "array $::settings(ext)"
proc artscriptSettings {} {
	# Date values
	set seconds [clock seconds]
	set now [split [clock format $seconds -format %Y/%m/%d/%u] "/"]
	lassign $now ::year ::month ::day
	set ::date [join [list $::year $::month $::day] "-"]
	
	#--==== Artscript Default Settings
	set mis_settings [dict create \
		ext ".ai .bmp .dng .exr .gif .jpeg .jpg .kra .miff .ora .png .psd .svg .tga .tif .xcf .xpm .webp" \
		autor "Autor" \
	]
	# Watermark options
	set wat_settings [dict create \
		wmtxt           { }                 \
		watermarks      [list {Copyright (c) $::autor} {http://www.yourwebsite.com} {Artwork: $::autor} {$::date}] \
		wmsize          10                  \
		wmcol           "#000000"           \
		wmcolswatch     { }                 \
		wmop            80                  \
		wmpos           "BottomRight"       \
		wmimsrc         { }                 \
		iwatermarks     [dict create        \
			"Logo" "/Path/to/logo"          \
			"Client Watermark" "/path/to/watermarkimg" \
		] \
		wmimpos         "Center"            \
		wmimsize        "0"                 \
		wmimcomp        "Over"              \
		wmimop          100                 \
		]
	#Sizes
	set siz_settings [dict create \
		sizes       [list "2560x1440"  "1920x1080" "1680x1050" "1366x768" "1280x1024" "1280x720" "1024x768" "720x1050" "50%"] \
	]
	#Suffix and prefix ops
	set suf_settings [dict create   \
		suffixes    [list "net" "archive" {by-[string map -nocase {{ } -} $::autor]}] \
		ouprefix    {}              \
		ousuffix    {}              \
	]
			#General checkboxes
	set bool_settings [dict create  \
		watsel      0               \
		watseltxt   0               \
		watselimg   0               \
		sizesel     0               \
		prefixsel   0               \
		overwrite   0               \
		alfaoff		{}				\
	]
	#Extension & output
	set out_settings [dict create \
		outext      "png"   \
		iquality    92      \
	]
	#--==== END of Artscript Default Settings
	set settings [dict merge $mis_settings $wat_settings $siz_settings $suf_settings $bool_settings $out_settings]
	dict for {key value} $settings {
		set ::$key [subst $value]
	}
    return $settings
}
#--=====
#Don't modify below this line

# Quick hack to keep GUI responsive, without using update extensively
proc updateGUI {} {
	# set after inside to 1 to avoid weird behaviour progressbar
	after idle [list after 1 set x 0]
	vwait x
}
#Function to send message boxes
proc alert {type icon title msg} {
		tk_messageBox -type $type -icon $icon -title $title \
		-message $msg
}
# TODO: look for binary paths using global $env variable
proc validate {program} {
	expr { ![catch { exec which $program }] ? [return 1] : [return 0] }
}

#Prepares output name adding Suffix or Prefix
#Checks if destination file exists and adds a standard suffix
proc getOutputName { iname outext { prefix "" } { suffix {} } {sizesufix {}} {orloc 0} } {
	
	if {!$::prefixsel} {
		set prefix {}
		set suffix {}
	}
	if {$orloc != 0 } {
		set iname $orloc
	}
	set dir [file normalize [file dirname $iname]]
	set name [file rootname [file tail $iname]]
	set lname [concat $prefix [list $name] $suffix $sizesufix ] ; # Name in brackets to protect white space
	append outname [join $lname "_"] "." [lindex $outext 0]
	
	#Add a counter if filename exists
	if {!$::overwrite} {
		set tmpname $outname
		while { [file exists [file join $dir "$outname"] ] } {
			set outname $tmpname
			incr s
			set outname [join [list [string trimright $outname ".$outext"] "_$s" ".[lindex $outext 0]"] {} ]
		}
		unset tmpname
	}
	return $outname
}

# Parses the list $argv for :key value elements. returns list
proc getUserOps { l } {
	foreach f $l {
		if { [file exists $f] } {
			break
		}
		lappend el $f
	}
	if { [info exists el] } {
		return $el
	}
}

# Global variable declaration
array set ::settings [artscriptSettings]
array set ::widget_name {}
#puts $settings(sizes)
# Global dictionaries, files values, files who process
set ::inputfiles [dict create]
set ::handlers [dict create]
set ::ops [getUserOps $argv]
# Find Optional dependencies (as global to search file only once)
set ::hasgimp [validate "gimp"]
set ::hasinkscape [validate "inkscape"]
set ::hascalligra [validate "calligraconverter"]

# Get image properties Size, format and path from identify IM
# Receives an absolute file path
proc identifyFile { f } {
	set identify [list identify -quiet -format "%wx%h:%m:%M "]
	if { [catch {set finfo [exec {*}$identify $f] } msg ] } {
		return -code error "$msg"
	} else {
		foreach {size ext path} [split [lindex $finfo 0] ":"] {
			set valist "size $size ext [string tolower $ext] path $path"
		}
		return [dict merge $valist]
	}
}

# Parse SVG directly as Inkscape gives drawing not page wxh data
# Works with plain and normal svg saved from inkscape. TODO: testing
proc getWidthHeightSVG { f } {
	set fl [open $f]
	set data [read $fl]
	close $fl
	set lines [lrange [split $data \n] 1 30]
	foreach l $lines {
		set l [lsearch -inline -regexp -all $l {^(width|height)} ]
		if {[string length $l] > 0} {
			set start [string last "=" $l]
			lappend size [expr {round([string range [subst $l] $start+2 end-1]) }]
		}
	}
	if {[info exists size]} {
		return [join $size {x}]
	} else {
		return 0
	}
}

proc setDictEntries { id fpath size ext h} {
	global inputfiles handlers

	set iname [file tail $fpath]
	set apath [file normalize $fpath]
	set ext [string trim $ext {.}]
	
	dict set inputfiles $id name $iname
	dict set inputfiles $id output [getOutputName $fpath $::outext $::ouprefix $::ousuffix]
	dict set inputfiles $id size $size
	dict set inputfiles $id osize [getOutputSizesForTree $size 1]
	dict set inputfiles $id ext $ext
	dict set inputfiles $id path $apath
	dict set inputfiles $id deleted 0
	dict set handlers $id $h
	
	addTreevalues $::widget_name(flist) $id ; # TODO set widget name as global
}

# Checks the files listed in args to be Filetypes supported from a path list
set ::fc 1 ; # Global counter TODO: separate delete to a list
proc listValidate { ltoval } {
	global fc

	foreach i $ltoval {
		# Call itself with directory contents if arg is dir
		if {[file isdirectory $i]} {
			listValidate [glob -nocomplain -directory $i -type f *]
			incr ::fc
			continue
		}
		set filext [string tolower [file extension $i] ]
		set iname [file tail $i]

		if { [regexp {^(.xcf|.psd)$} $filext ] && $::hasgimp } {

			set size [lindex [exec identify -format "%wx%h " $i ] 0]

			setDictEntries $::fc $i $size $filext "g"
			incr ::fc
			continue

		} elseif { [regexp {^(.svg|.ai)$} $filext ] && $::hasinkscape } {
			
			if { $filext == ".svg" } {
				set size [getWidthHeightSVG $i]
				if { $size == 0 } {
					continue
				}
			} else {
				if { [catch { exec inkscape -S $i | head -n 1 } msg] } {
					append ::lstmsg "EE: $i discarted\n"
					puts $msg
					continue
				}
				set svgcon [exec inkscape -S $i | head -n 1] ; # TODO get rid of head cmd
				set svgvals [lrange [split $svgcon {,}] end-1 end] ; # Get the last elements of first line == w x h
				set size [expr {round([lindex $svgvals 0])}] ; # Make float to int. TODO check if format "%.0f" works best here
				append size "x" [expr {round([lindex $svgvals 1])}]
			}
			setDictEntries $::fc $i $size $filext "i"
			incr ::fc
			continue

		} elseif { [regexp {^(.kra|.ora|.xcf|.psd)$} $filext ] && $::hascalligra } {
			set size "N/A"
			# TODO Simplify
			# Get contents from file and parse them into Size values.
			if { $filext == ".ora" } {
				if { [catch { set zipcon [exec unzip -p $i stack.xml | grep image | head -n 1] } msg] } {
					continue
				}
				set zipcon [exec unzip -p $i stack.xml | grep image | head -n 1]
				set zipkey [lreverse [ string trim $zipcon "image<> " ] ]
				set size [string trim [lindex [split [lindex $zipkey 1] {=}] 1] "\""]x[string trim [lindex [split [lindex $zipkey 0] "="] 1] {"\""}]
				unset zipcon zipkey

			} elseif { $filext == ".kra" } {
				if { [catch { set zipcon [exec unzip -p $i maindoc.xml | grep -i IMAGE | head -n1] } msg] } {
					continue
				}
					set zipcon [exec unzip -p $i maindoc.xml | grep -i IMAGE | head -n1]
					set zipkey [lsearch -inline -regexp -all $zipcon {^(width|height)} ]
					set size [string trim [lindex [split [lindex $zipkey 0] {=}] 1] "\""]x[string trim [lindex [split [lindex $zipkey 1] "="] 1] {"\""}]
					unset zipcon zipkey
			}
			setDictEntries $::fc $i $size $filext "k"
			incr ::fc
			continue

		# Catch magick errors. Some files have the extension but are not valid types
		# And check for files with no extension with IM identify
		} elseif { [lsearch $::ext $filext ] >= 0 || [string equal $filext {}] } {
			if { [catch {set finfo [identifyFile $i ] } msg ] } {
				puts $msg
				append ::lstmsg "EE: $i discarted\n"
				continue
			}
			set size [dict get $finfo size]
			set ext [dict get $finfo ext]
			setDictEntries $::fc $i $size $ext "m"
			incr ::fc
		}
	}
}

#configuration an presets
proc getUserPresets {} {
	global ops presets
	
	set configfile "presets.config"
	set configfile [file join [file dirname [info script]] $configfile]

	if { [file exists $configfile] } {
		puts "config file found in: $configfile"

		set File [open $configfile]
		#read each line of File and store "key=value"
		foreach {i} [split [read $File] \n] {
				set firstc [string index $i 0]
				if { $firstc != "#" && ![string is space $firstc] } {
					lappend lista [split $i "="]
					#lappend ListofResult [lindex [split $i ,] 1]
				}
			}
			close $File
		if {![info exists lista]} {
			return 0
		}
		#declare default dictionary to add defaut config values
		 set ::preset "default"
		 if {[dict exists $ops ":preset"]} {
			lappend ::preset [dict get $ops ":preset"]
		 }
		#iterate list and populate dictionary with values
		set default true
		foreach i $lista {
			if { [lindex $i 0] == "preset" } {
				set condict [lindex $i 1]
				dict set presets $condict [dict create]
				set datos false
				continue
			}
			if {![info exists condict]} {
				set condict "default"
			}
			dict set presets $condict [lindex $i 0] [lindex $i 1]
		}
	}
}
proc setUserPresets { s } {
	global presets
	if {![info exists presets]} {
		return 0
	}

	# TODO remove this list of global tcl vars. set all user vars in a pair list value, or array.
	set gvars {tcl_rcFileName|tcl_version|argv0|argv|tcl_interactive|tk_library|tk_version|auto_path|errorCode|tk_strictMotif|errorInfo|auto_index|env|tcl_pkgPath|tcl_patchLevel|argc|tk_patchLevel|tcl_library|tcl_platform}
	
	#set values according to preset
	dict for {key value} [dict get $presets $s] {
		if {[info exists ::$key] != [regexp $gvars $key ] } {
			# Dirty fix: TODO we should set preset on an array
			set value [string map {{$} {$::}} $value]
			if { [catch {set keyval [eval list [string trim $value]] } msg] } {
				puts $msg
			} else {
				if {[llength $keyval] > 1} { 
					set ::$key $keyval
				} else {
					set ::$key [string trim $keyval "{}"]
				}
			}
		#puts [eval list [set $key] ]
		#set ::$key [eval concat $tmpkey]
		}
	}
	return
}

# ---=== Get user presets from file
getUserPresets
setUserPresets "default"
	
# Returns total of files in dict except for flagged as deleted.
# TODO all boolean is reversed. use incr to count
proc getFilesTotal { { get_del 0} } {
	global inputfiles
	
	set count 0
	set deleted 0
	dict for {id datas} $inputfiles {
		incr count
		if {[dict get $inputfiles $id deleted]} {
			incr deleted
		}
	}
	if { $get_del == 1 } {
		return $count
	}
	return [expr {$count - $deleted}]
}

proc updateWinTitle { } {
	wm title . "Artscript $::version -- [getFilesTotal] Files selected"
}

# Returns a list with all keys that match value == c
proc putsHandlers {args} {
	global handlers
	foreach c $args {
		set ${c}fdict [dict filter $handlers script {k v} {expr {$v eq $c}}]
		lappend images {*}[dict keys [set ${c}fdict]]
	}
	return $images
	#or puts [dict keys [subst $${c}fdict]]
}

proc openFiles {} {
	global inputfiles
	set exts [list $::ext]
	set types " \
	 	\"{Suported Images}  $exts \"
	{{KRA, ORA}      {.ora .kra}  } \
	{{SVG, AI}       {.svg .ai}   } \
	{{XCF, PSD}      {.xcf .psd}  } \
	{{PNG}           {.png}       } \
	{{JPG, JPEG}     {.jpg .jpeg} } \
	"
	set files [tk_getOpenFile -filetypes $types -initialdir $::env(HOME) -multiple 1]
	listValidate $files
	
	updateWinTitle
}

# ----=== Gui proc events ===----

# Checks checkbox state, turns on if off and returns value.
# TODO Make versatile to any checkbox
proc bindsetAction { args } {
	foreach i $args {
		incr n
		set $n $i
	}
	setGValue $1 $2
	optionOn $3 $4
}
proc setGValue {gvar value} {
	if {$gvar != 0} {
		upvar #0 $gvar var
		set var $value
		puts $var
	}
}
proc optionOn {gvar args} {
	if {$gvar != 0} {
		upvar #0 $gvar var
		foreach check {*}$args {
			set vari [$check cget -variable]
			upvar #0 $vari wmcbst
			if { !$var || !$wmcbst} {
				$check invoke
			}
		}
	}
}
# Parent cb only off if all args are off
# proc master child1? child2?...
proc  turnOffParentCB { parent args } {
	set varpar [$parent cget -variable]
	upvar #0 $varpar pbvar
	foreach cb $args {
		set varcb [$cb cget -variable]
		upvar #0 $varcb cbvar
		lappend total $cbvar
	}
	set total [expr [join $total +]]
	if { ($total > 0 && !$pbvar) || ($total == 0 && $pbvar) } {
		$parent invoke
	}
}

# A master checkbox unset all of the submitted childs
# All variables must be declared for it to work.
# proc master child1 var1 ?child2 ?var2 ...
proc turnOffChildCB { w args } {
	upvar #0 $w father
	set checkbs [list {*}$args]

	if {!$father} {
		dict for {c var} $checkbs {
			upvar #0 $var mn
			if {$mn} {
				$c invoke
			}
		}
	}
}

# Add key values into new treeview item id
# Receives w=widget name and id= key name of global dict
proc addTreevalues { w id } {
	global inputfiles
	
	dict with ::inputfiles $id {
		set values [list $id $ext $name $size $output $osize]
		set ::img::imgid$id [$w insert {} end -values $values]
	}
	#Keep Gui with fresh news
	updateWinTitle
	updateGUI
}

# Deletes the keys from tree(w), and sets deletes value to 1
# TODO Remove all entries of file type. (filtering)
proc removeTreeItem { w i } {
	global inputfiles

	foreach item $i {
		set id [$w set $item id]
		# TODO undo last delete
		dict set inputfiles $id deleted 1
		# unset ::img::imgid$id
	}
	# remove keys from tree
	$w detach $i
	updateWinTitle
}

# from http://wiki.tcl.tk/20930
proc treeSort {tree col direction} {
	# Build something we can sort
    set data {}
    foreach row [$tree children {}] {
        lappend data [list [$tree set $row $col] $row]
    }

    set dir [expr {$direction ? "-decreasing" : "-increasing"}]
    set r -1

    # Now reshuffle the rows into the sorted order
    foreach info [lsort -dictionary -index 0 $dir $data] {
        $tree move [lindex $info 1] {} [incr r]
    }

    # Switch the heading so that it will sort in the opposite direction
    set cmd [list treeSort $tree $col [expr {!$direction}]]
    $tree heading $col -command $cmd
}

# Updates global variable
# var = global variable name, value = new value
proc updateTextLabel { var value } {
	upvar #0 $var ltext
	set ltext $value
	return
}
# Transform a value with the supplied script and writes it to dict and treeview
# Script: script to run, w = widget read = dict readkey, write = key to write
proc treeAlterVal { {script {puts $value}} w read write  } {
	global inputfiles
	
	foreach id [dict keys $inputfiles] {

		set value [dict get $inputfiles $id $read]
		set newvalue [uplevel 0 $script]
		
		$w set [set ::img::imgid$id] $write $newvalue
		dict set inputfiles $id $write $newvalue
		
		if { $read == "path" } {
			set path [file dirname $value]
			if {[file exists [file join $path "$newvalue"] ]} {
				$w item [set ::img::imgid$id] -tags {exists}
			} else {
				$w item [set ::img::imgid$id] -tags {}
			}
		}
	}
}

proc printOutname { w } {
	if {$::prefixsel || $w != 0} {
		bindsetAction 0 0 prefixsel $::widget_name(cb-prefix)
	}
	treeAlterVal {getOutputName $value $::outext $::ouprefix $::ousuffix} $::widget_name(flist) path output
	
}

# Check id of file selected and sends it to convert to process as preview.
proc showPreview {} {
	set id [lindex [$::widget_name(flist) item [$::widget_name(flist) selection] -values] 0]
	if { $id >= 0 } {
		convert $id
	}
	return
}
# First define subprocesses
# makeThumb creates a thumbnail based on path (file type) makes requested sizes.
proc makeThumb { path tsize } {
	set cmd [dict create]
	dict set cmd .ora {Thumbnails/thumbnail.png}
	dict set cmd .kra {preview.png}

	set filext [string tolower [file extension $path] ]

	if { [regexp {.ora|.kra} $filext ] } {
		set container [dict get $cmd $filext]
		#unzip to location tmp$container
		catch { exec unzip $path $container -d /tmp/ }
		set tmpfile "/tmp/$container"
		set path $tmpfile

	} elseif {[regexp {.xcf|.psd} $filext ]} {
		# TODO: Break appart preview function to allow loading thumbs from tmp folder
		$::widget_name(thumb-im) configure -compound text -text "No Thumbnail"
		return 0
	}
	foreach {size dest} $tsize {
		catch { exec convert -quiet $path -thumbnail [append size x $size] -flatten PNG32:$dest } msg
	}
	catch {file delete $tmpfile}
}
	
# Attempts to load a thumbnail from thumbnails folder if exists.
# Creates a thumbnail for files missing Large thumbnail
proc showThumb { w f {tryprev 1}} {
	global inputfiles env

	# Do not process if selection is multiple
	if {[llength $f] > 1} {
		return -code 3
	}
	# TODO, get value with no lindex: .t set $f id
	set id [lindex [$::widget_name(flist) item $f -values] 0]
	
	set path [dict get $inputfiles $id path]
	# Creates md5 checksum from text string: TODO avoid using echo
	# exec md5sum << "string" and string trim $hash {- }
	set thumbname [lindex [exec echo -n "file://$path" \| md5sum] 0]
	set thumbdir "$env(HOME)/.thumbnails"
	set lthumb "${thumbdir}/large/$thumbname.png"
	set nthumb "${thumbdir}/normal/$thumbname.png"

	# Displays preview in widget, Make proc of this.
	if { [file exists $lthumb ] } {
		global img oldimg
		set prevgif {/tmp/atkpreview.gif}
		
		catch { exec convert -quiet $lthumb GIF:$prevgif }
		catch {set oldimg $img}
		set img [image create photo -file /tmp/atkpreview.gif ]

		$::widget_name(thumb-im) configure -compound image -image $img
		catch {image delete $oldimg}

		catch {file delete $prevgif}
		return ; # Exits parent proc
		# As a proc it has to return true false

	} elseif { [file exists $nthumb] } {
		puts "$path has normal thumb"
		makeThumb $path [list 256 $lthumb]
	} else {
		puts "$path has no thumb"
		makeThumb $path [list 128 $nthumb 256 $lthumb]
	}

	if {$tryprev} {
		showThumb w $f 0
	}
}

# Scroll trough tabs on a notebook. (dir = direction)
proc scrollTabs { w i {dir 1} } {
		set tlist [llength [$w tabs]]
		# Defines if we add or res
		expr { $dir ? [set op ""] : [set op "-"] }
		incr i [append ${op} 1]
		if { $i < 0 } {
			$w select [expr {$tlist-1}]
		} elseif { $i == $tlist } {
			$w select 0
		} else {
			$w select $i
		}
}

# Defines a combobox editable with right click
proc comboBoxEditEvents { w {script {optionOn watsel} }} {
	bind $w <<ComboboxSelected>> $script
	bind $w <Button-3> { %W configure -state normal }
	bind $w <Control-Button-1> { %W configure -state normal }
	bind $w <KeyRelease> $script
	bind $w <FocusOut> { %W configure -state readonly }
}
#Convert RGB to HSV, to calculate contrast colors
proc rgbtohsv { r g b } {
	set r1 [expr {$r/255.0}]
	set g1 [expr {$g/255.0}]
	set b1 [expr {$b/255.0}]
	set max [expr {max($r1,$g1,$b1)}]
	set min [expr {min($r1,$g1,$b1)}]
	set delta [expr {$max-$min}]
	set h -1
	set s {}
	set v $max
	set l $v
	set luma $l

	if {$delta != 0} {
		set l [expr { ($max + $min) / 2 } ]
		set s [expr { $delta/$v }]
		set luma [expr { (0.2126 * $r1) + (0.7152 * $g1) + (0.0722 * $b1) }]
		if { $max == $r1 } {
			set h [expr { ($g1-$b1) / $delta }]
		} elseif { $max == $g1 } {
			set h [expr { 2 + ($b1-$r1) / $delta }]
		} else {
			set h [expr { 4 + ($r1-$g1) / $delta }]
		}
		set h [expr {round(60 * $h)}]
		if { $h < 0 } { incr h 360 }
	} else {
		set s 0
	}
	return [list $h [format "%0.2f" $s] [format "%0.2f" $v] [format "%0.2f" $l] [format "%0.2f" $luma]]
}

proc setColor { w var item col {direct 1} { title "Choose color"} } {
	upvar 1 $var txtcol ; # review if txtcol can be deleted
	set col [lindex $col end]

	#Call color chooser and store value to set canvas color and get rgb values
	if { $direct } {
		set col [tk_chooseColor -title $title -initialcolor $col -parent .]
	}
	# User selected a color and not cancel then
	if { [expr {$col ne "" ? 1 : 0}] } {
		$w itemconfigure $item -fill $col
		$w itemconfigure $::canvasWatermark(main) -outline [getContrastColor $col]
		set txtcol $col
	}
	return $col
}

proc getContrastColor { color } {
	set rgbs [winfo rgb . $color]
	set luma [lindex [rgbtohsv {*}$rgbs ] 4]
	return [expr { $luma >= 105 ? "black" : "white" }]
}

proc drawSwatch { w args } {
	set args {*}$args
	set chal [expr {ceil([llength $args]/2.0)}] ; # Half swatch list

	set gap 10
	set height 26
	set width [expr {$height+($chal*13)+$gap}]
	set cw 13
	set ch 13
	set x [expr {26+$gap}]
	set y 1
	
	$w configure -width $width

	foreach swatch $args {
		incr i
		set ::canvasWatermark($i) [$w create rectangle $x $y [expr {$x+$cw}] [expr {$y+$ch-1}] -fill $swatch -width 1 -outline {gray26} -tags {swatch}]
		set col [lindex [$w itemconfigure $::canvasWatermark($i) -fill] end]
		$w bind $::canvasWatermark($i) <Button-1> [list setColor $w ::wmcol $::canvasWatermark(main) $col 0 ]
		if { $i == $chal } {
			incr y $ch
			set x [expr {$x-($cw*$i)}]
		}
		incr x 13
	}
}

# from http://wiki.tcl.tk/534
proc dec2rgb {r {g 0} {b UNSET} {clip 0}} {
	if {![string compare $b "UNSET"]} {
		set clip $g
		if {[regexp {^-?(0-9)+$} $r]} {
			foreach {r g b} $r {break}
		} else {
			foreach {r g b} [winfo rgb . $r] {break}
		}
	}
	set max 255
	set len 2
	if {($r > 255) || ($g > 255) || ($b > 255)} {
		if {$clip} {
		set r [expr {$r>>8}]; set g [expr {$g>>8}]; set b [expr {$b>>8}]
		} else {
			set max 65535
			set len 4
		}
	}
	return [format "#%.${len}X%.${len}X%.${len}X" \
	  [expr {($r>$max)?$max:(($r<0)?0:$r)}] \
	  [expr {($g>$max)?$max:(($g<0)?0:$g)}] \
	  [expr {($b>$max)?$max:(($b<0)?0:$b)}]]
}

proc getswatches { {colist 0} {sortby 1}} {
	# Set a default palette, colors have to be in rgb
	set swcol { Black {0 0 0} English-red {208 0 0} {Dark crimson} {120 4 34} Orange {254 139 0} Sand {193 177 127} Sienna {183 65 0} {Yellow ochre} {215 152 11} {Cobalt blue} {0 70 170} Blue {30 116 253} {Bright steel blue} {170 199 254} Mint {118 197 120} Aquamarine {192 254 233} {Forest green} {0 67 32} {Sea green} {64 155 104} Green-yellow {188 245 28} Purple {137 22 136} Violet {77 38 137} {Rose pink} {254 101 203} Pink {254 202 218} {CMYK Cyan} {0 254 254} {CMYK Yellow} {254 254 0} White {255 255 255} }
	
	if { [llength $colist] > 1 } {
		set swcol [list]
		# Convert hex list from user to rgb 257 vals
		foreach {ncol el} $colist {
			set rgb6 [winfo rgb . $el]
			set rgb6 [list [expr {[lindex $rgb6 0]/257}] [expr {[lindex $rgb6 1]/257}] [expr {[lindex $rgb6 2]/257}] ]
			lappend swcol $ncol $rgb6
		}
	}

	set swdict [dict create {*}$swcol]
	set swhex [dict create]
	set swfinal [dict create]

	dict for {key value} $swdict {
		lappend swluma [list $key [lindex [rgbtohsv {*}$value] $sortby]]
		dict set swhex $key [dec2rgb {*}$value]
	}

	foreach pair [lsort -index 1 $swluma] {
		set swname [lindex $pair 0]
		dict set swfinal $swname [dict get $swhex $swname]
	}
	return [dict values $swfinal]
}
# Ttk style modifiers
proc artscriptStyles {} {
	ttk::style layout small.TButton {
		Button.border -sticky nswe -border 1 -children {
			Button.focus -sticky nswe -children {
				Button.spacing -sticky nswe -children {Button.label -sticky nswe}
				}
			}
		}
	# ttk::style configure small.TButton -background color
}
# ----=== Gui Construct ===----
# TODO Make every frame a procedure to ease movement of the parts
# Horizontal panel for placing operations that affect Artscript behaviour
proc guiTopBar { w } {
	pack [ttk::frame $w] -side top -expand 0 -fill x
	# ttk::label $w.title -text "Artscript 2.0.0"
	ttk::separator $w.sep -orient vertical
	ttk::button $w.add -text "Add files" -command { openFiles }
	pack $w.add $w.sep -side left -fill x
	pack configure $w.sep -expand 1


	if {[info exists presets]} {
		ttk::combobox $w.preset -state readonly -values [dict keys $presets]
		$w.preset set "default"
		bind $w.preset <<ComboboxSelected>> { setUserPresets [%W get] }
		pack $w.preset -after $w.add -side left
	}
	return $w
}

proc guiMakePaned { w orientation } {
	ttk::panedwindow $w -orient $orientation
	return $w
	}
proc guiAddChildren { w args } {
	foreach widget $args {
		$w add $widget	
	}
}

proc guiMiddle { w } {
	
	set paned_big [guiMakePaned $w vertical]
	pack $paned_big -side top -expand 1 -fill both

	set file_pane $paned_big.fb
	ttk::frame $file_pane
	set paned_botom [guiMakePaned $paned_big.ac horizontal]
	guiAddChildren $paned_big $file_pane $paned_botom

	guiFileList $file_pane
	guiThumbnail $file_pane
	
	# Add frame notebook to pane left.

	set option_tab [guiOptionTabs $paned_botom.n]
	set gui_out [guiOutput $paned_botom.onam]
	
	guiAddChildren $paned_botom $option_tab $gui_out
	$paned_botom pane $option_tab -weight 6
	$paned_botom pane $gui_out -weight 2
	
	pack $file_pane.flist -side left -expand 1 -fill both
	pack $file_pane.sscrl $file_pane.thumb -side left -expand 0 -fill both
	pack propagate $file_pane.thumb 0
	pack $file_pane.thumb.im -expand 1 -fill both
	
	return $w
}

proc guiFileList { w } {
	set fileheaders { id ext input size output osize }
	set ::widget_name(flist) [ttk::treeview $w.flist -columns $fileheaders -show headings -yscrollcommand "$w.sscrl set"]
	foreach col $fileheaders {
		set name [string totitle $col]
		$w.flist heading $col -text $name -command [list treeSort $w.flist $col 0 ]
	}
	$w.flist column id -width 32 -stretch 0
	$w.flist column ext -width 48 -stretch 0
	$w.flist column size -width 86 -stretch 0
	$w.flist column osize -width 86
	bind $w.flist <<TreeviewSelect>> { showThumb $::widget_name(thumb-im) [%W selection] }
	bind $w.flist <Key-Delete> { removeTreeItem %W [%W selection] }
	ttk::scrollbar $w.sscrl -orient vertical -command [list $w.flist yview ]
	$::widget_name(flist) tag configure exists -foreground #f00
	return $w
}

proc guiThumbnail { w } {
	ttk::labelframe $w.thumb -width 276 -height 316 -padding 6 -labelanchor n -text "Thumbnail"
	set ::widget_name(thumb-im) [ttk::label $w.thumb.im -anchor center -text "No Thumbnail"]
	set ::widget_name(thumb-prev) [ttk::button $w.thumb.prev -text "Preview" -style small.TButton -command { showPreview }]
	pack $w.thumb.prev -side bottom
}

# --== Option tabs
proc guiOptionTabs { w } {
	ttk::notebook $w
	ttk::notebook::enableTraversal $w
	
	bind $w <ButtonPress-4> { scrollTabs %W [%W index current] 1 }
	bind $w <ButtonPress-5> { scrollTabs %W [%W index current] 0 }
	
	set ::wt [tabWatermark $w.wm]
	set ::st [tabResize $w.sz]
	
	$w add $::wt -text "Watermark" -underline 0
	$w add $::st -text "Resize" -underline 0
	
	return $w
}
# Set a var to ease modularization. TODO: procs
proc tabWatermark { wt } {

	ttk::frame $wt -padding 6

	ttk::label $wt.lsel -text "Selection*"
	ttk::label $wt.lsize -text "Size" -width 4
	ttk::label $wt.lpos -text "Position" -width 10
	ttk::label $wt.lop -text "Opacity" -width 10

	# Text watermark ops
	ttk::checkbutton $wt.cbtx -onvalue 1 -offvalue 0 -variable ::watseltxt -command { turnOffParentCB $::widget_name(check-wm) $wt.cbtx $wt.cbim}
	ttk::label $wt.ltext -text "Text"
	ttk::combobox $wt.watermarks -state readonly -textvariable ::wmtxt -values $::watermarks -width 28
	$wt.watermarks set [lindex $::watermarks 0]
	
	comboBoxEditEvents $wt.watermarks {bindsetAction 0 0 watsel "$::widget_name(check-wm) $wt.cbtx"}

	# font size spinbox
	set fontsizes [list 8 10 11 12 13 14 16 18 20 22 24 28 32 36 40 48 56 64 72 144]
	ttk::spinbox $wt.fontsize -width 4 -values $fontsizes -validate key \
		-validatecommand { string is integer %P }
	$wt.fontsize set $::wmsize
	bind $wt.fontsize <ButtonRelease> {bindsetAction wmsize [%W get] watsel "$::widget_name(check-wm) $wt.cbtx"}
	bind $wt.fontsize <KeyRelease> { bindsetAction wmsize [%W get] watsel "$::widget_name(check-wm) $wt.cbtx" }

	set wmpositions	[list "TopLeft" "Top" "TopRight" "Left" "Center" "Right" "BottomLeft" "Bottom"  "BottomRight"]
	# Text position box 
	set ::widget_name(wmpos) [ttk::combobox $wt.position -state readonly -textvariable ::wmpos -values $wmpositions -width 10]
	$wt.position set $::wmpos
	bind $wt.position <<ComboboxSelected>> { bindsetAction 0 0 watsel "$::widget_name(check-wm) $wt.cbtx" }

	# Image watermark ops
	ttk::checkbutton $wt.cbim -onvalue 1 -offvalue 0 -variable ::watselimg -command {turnOffParentCB $::widget_name(check-wm) $wt.cbtx $wt.cbim}
	ttk::label $wt.limg -text "Image"
	# dict get $dic key
	# Get only the name for image list.
	set iwatermarksk [dict keys $::iwatermarks]
	ttk::combobox $wt.iwatermarks -state readonly -values $iwatermarksk
	$wt.iwatermarks set [lindex $iwatermarksk 0]
	set ::wmimsrc [dict get $::iwatermarks [lindex $iwatermarksk 0]]
	bind $wt.iwatermarks <<ComboboxSelected>> { bindsetAction wmimsrc [dict get $::iwatermarks [%W get]] watsel "$::widget_name(check-wm) $wt.cbim" }

	# Image size box \%
	ttk::spinbox $wt.imgsize -width 4 -from 0 -to 100 -increment 10 -validate key \
		-validatecommand { string is integer %P }
	$wt.imgsize set $::wmimsize
	bind $wt.imgsize <ButtonRelease> { bindsetAction wmimsize [%W get] watsel $::widget_name(check-wm) }
	bind $wt.imgsize <KeyRelease> { bindsetAction wmimsize [%W get] watsel "$::widget_name(check-wm) $wt.cbim"] }

	# Image position
	set ::widget_name(wmipos) [ttk::combobox $wt.iposition -state readonly -textvariable ::wmimpos -values $wmpositions -width 10]
	$wt.iposition set $::wmimpos
	bind $wt.iposition <<ComboboxSelected>> { bindsetAction 0 0 watsel "$::widget_name(check-wm) $wt.cbim" }

	# Opacity scales
	# Set a given float as integer, TODO uplevel to set local context variable an not global namespace
	proc progressBarSet { gvar cvar wt cb ft fl } {
		bindsetAction $gvar [format $ft $fl] $cvar "$::widget_name(check-wm) $wt.$cb"
	}

	ttk::scale $wt.txop -from 10 -to 100 -variable ::wmop -value $::wmop -orient horizontal -command { progressBarSet ::wmop ::watsel $wt cbtx "%.0f" }
	ttk::label $wt.tolab -width 3 -textvariable ::wmop

	ttk::scale $wt.imop -from 10 -to 100 -variable ::wmimop -value $::wmimop -orient horizontal -command { progressBarSet ::wmimop ::watsel $wt cbim "%.0f" }
	ttk::label $wt.iolab -width 3 -textvariable ::wmimop

	# Style options
	ttk::frame $wt.st
	ttk::label $wt.st.txcol -text "Text Color"
	ttk::label $wt.st.imstyle -text "Image Blending"
	ttk::separator $wt.st.sep -orient vertical

	canvas $wt.st.chos  -width 62 -height 26
	
	set ::canvasWatermark(main) [$wt.st.chos create rectangle 2 2 26 26 -fill $::wmcol -width 2 -outline [getContrastColor $::wmcol] -tags {main}]
	$wt.st.chos bind main <Button-1> { setColor %W wmcol $::canvasWatermark(main) [%W itemconfigure $::canvasWatermark(main) -fill] }

	set wmswatch [getswatches $::wmcolswatch]
	drawSwatch $wt.st.chos $wmswatch

	set iblendmodes [list Bumpmap ColorBurn ColorDodge Darken Exclusion HardLight Hue Lighten LinearBurn LinearDodge LinearLight Multiply Overlay Over Plus Saturate Screen SoftLight VividLight]
	ttk::combobox $wt.st.iblend -state readonly -textvariable ::wmimcomp -values $iblendmodes -width 12
	$wt.st.iblend set $::wmimcomp
	bind $wt.st.iblend <<ComboboxSelected>> { bindsetAction wmimcomp [%W get] watsel "$::widget_name(check-wm) $wt.cbim" }

	set wtpadding 2
	grid $wt.lsize $wt.lpos $wt.lop -row 1 -sticky ws
	grid $wt.cbtx $wt.ltext $wt.watermarks $wt.fontsize $wt.position $wt.txop $wt.tolab -row 2 -sticky we -padx $wtpadding -pady $wtpadding
	grid $wt.cbim $wt.limg $wt.iwatermarks $wt.imgsize $wt.iposition $wt.imop $wt.iolab -row 3 -sticky we -padx $wtpadding -pady $wtpadding
	grid $wt.cbtx $wt.cbim -column 1 -padx 0 -ipadx 0
	grid $wt.ltext $wt.limg -column 2
	grid $wt.watermarks $wt.iwatermarks -column 3
	grid $wt.lsize $wt.fontsize $wt.imgsize -column 4
	grid $wt.lpos $wt.position $wt.iposition -column 5
	grid $wt.lop $wt.txop $wt.imop -column 6
	grid $wt.tolab $wt.iolab -column 7
	grid $wt.st -row 4 -column 3 -columnspan 4 -sticky we -pady 4
	grid columnconfigure $wt {3} -weight 1

	pack $wt.st.txcol $wt.st.chos $wt.st.sep $wt.st.imstyle $wt.st.iblend -expand 1 -side left -fill x
	pack configure $wt.st.txcol $wt.st.chos $wt.st.imstyle -expand 0
	
	return $wt
}

# --== Size options
proc tabResize {st} {
	global wList hList
	foreach size $::sizes {
		if { [string index $size end] == {%} } {
			lappend pList $size
		} else {
			set size [split $size {x}]
			lappend wList [lindex $size 0]
			lappend hList [lindex $size 1]
		}
	}
	lappend wList {*}$pList
	
	ttk::frame $st -padding 6
	
	set ::widget_name(tabsize-left) [ttk::frame $st.lef]
	set ::widget_name(tabsize-right) [ttk::frame $st.rgt ]
	
	grid $st.lef -column 1 -row 1 -sticky nesw
	grid $st.rgt -column 2 -row 1 -sticky nesw
	grid columnconfigure $st 1 -weight 1 -minsize 250
	grid columnconfigure $st 2 -weight 2 -minsize 250
	grid rowconfigure $st 1 -weight 1 
	
	set ::widget_name(st-right-ins) [ttk::label $st.rgt.ins -text ""]
	pack $st.rgt.ins -side top -expand 0 -fill x
	
	# grid $st.ins -column 0 -row 1 -columnspan 5 -sticky we
	ttk::label $st.lef.ann -text "   No Selection" -font "-size 14"
	ttk::button $st.lef.add -text "+" -width 2 -style small.TButton -command [list addSizecol $st.lef 1 1]
	grid $st.lef.ann -column 1 -row 1 -columnspan 4 -sticky nwse
	grid $st.lef.add -column 0 -row 1 -sticky w
	grid rowconfigure $st.lef 1 -minsize 28

	proc getSizesSel { w } {
		set cols [grid slaves $w -column 2]
		if { $cols == "$w.ann" } {
			return 0
		}
		set gsels {}
		set widx [expr {[string length $w]+4}]
		foreach el $cols {
			set idl [string range $el $widx end]
			set wid [$w.wid$idl get]
			set hei [$w.hei$idl get]
			lappend gsels "$wid $hei"
		}
		return $gsels
	}
	
	proc eventSize { w id } {
		set sizesels [getSizesSel $w]
		#Set the interface according to the size type px or %
		if {$id > 0} {
			set wc $w.wid$id
			set sel [$wc get]
			set pref "$w."
			append hei $pref "hei" $id
			
			# String is emptu if they are editing, do nothing in that case
			if { $sel eq "" } {
				return
			}
			# Select height original pair for width
			if { [catch {$hei current [$wc current]} ]} {
				 $hei set $sel
			}
			# If size is percentage, remove height. 50%x50% values not supported
			if { [string range $sel end end] == {%} } {
				$hei set {} 
				grid forget $hei
				${pref}xmu$id configure -text "%"
			# If size does not end like that bue text of label is %, pack height
			} elseif { [lindex [${pref}xmu$id configure -text] end] == "%" } {
				array set info [grid info $wc]
				grid $hei -column 4 -row $info(-row) -sticky we
				${pref}xmu$id configure -text "x"
			}
		}

		if { [llength $sizesels] > 1 } {
			treeAlterVal {getOutputSizesForTree $value 1} $::widget_name(flist) size osize
			$::widget_name(st-right-ins) configure -text "[llength $sizesels] Sizes set"
		} elseif { ([llength $sizesels] == 1) && ($sizesels != 0) } {
			treeAlterVal {getOutputSizesForTree $value} $::widget_name(flist) size osize
			$::widget_name(st-right-ins) configure -text "[llength $sizesels] Size set"
			bindsetAction 0 0 sizesel $::widget_name(check-sz)
		} elseif { [llength $sizesels] == 0 } {
			$::widget_name(check-sz) invoke
			$::widget_name(st-right-ins) configure -text ""
		}
	}
	
	proc addSizecol {st id row {state normal}} {
		global wList hList
		
		grid forget $st.ann
		ttk::combobox $st.wid$id -state readonly -width 8 -justify right -values $wList -validate key \
	-validatecommand { regexp {^(()|[0-9])+(()|%%)$} %P }
		$st.wid$id set [lindex $wList 0]
		ttk::combobox $st.hei$id -state readonly -width 8 -values $hList -validate key \
	-validatecommand { string is integer %P }
		$st.hei$id set [lindex $hList 0]
		comboBoxEditEvents $st.wid$id "eventSize $st $id"
		comboBoxEditEvents $st.hei$id ""
		# ttk::separator $st.sep -orient vertical -padding
		ttk::label $st.xmu$id -text "x" -font "-size 18"	
		ttk::button $st.del$id -text "-" -width 2 -style small.TButton -command [list delSizecol $st $id]
		
		grid $st.del$id $st.wid$id $st.xmu$id $st.hei$id -row $row
		grid $st.del$id -column 1
		grid $st.wid$id -column 2 -sticky we
		grid $st.xmu$id -column 3 
		grid $st.hei$id -column 4 -sticky we
		grid columnconfigure $st {3} -pad 18
		
		incr id
		incr row
		$st.add configure -command [list addSizecol $st $id $row]
		
		eventSize $st 0
	}

	proc delSizecol { st id } {
		# grid forget $st.del$id $st.wid$id $st.xmul$id $st.hei$id
		destroy $st.del$id $st.wid$id $st.xmu$id $st.hei$id
		set szgrid [llength [getSizesSel $st]]
		
		eventSize $st 0
		if {[llength [grid slaves $st -row 1]] <= 1 } {
			set i 1
			set sboxl [lsort [grid slaves $st -column 2]]
			set widx [expr {[string length $st]+4}]
			foreach el $sboxl {
				set idl [string range $el $widx end]
				grid $st.del$idl $st.wid$idl $st.xmu$idl $st.hei$idl -row $i
				incr i
			}
		}
		if { [llength [grid slaves $st -column 2]] == 0 } {
			$st.add configure -command [list addSizecol $st $id 1]
			grid $st.ann -column 1 -row 1 -columnspan 4 -sticky nwse
		}
		return $szgrid
	}
	return $st
}

# --== Suffix and prefix ops
proc guiOutput { w } {

	ttk::frame $w
	set ::widget_name(cb-prefix) [ttk::checkbutton $w.cbpre -onvalue 1 -offvalue 0 -variable ::prefixsel -text "Suffix and Prefix" -command {printOutname 0 } ]
	ttk::labelframe $w.efix -text "Suffix and Prefix" -labelwidget $w.cbpre -padding 6

	frameSuffix $w.efix
	# ttk::label $w.lpre -text "Prefix"
	# ttk::label $w.lsuf -text "Suffix"
	
	ttk::separator $w.sep -orient horizontal
	set ::widget_name(frame-output) [frameOutput $w.f]
	
	pack $w.efix $w.sep -side top -fill both -expand 1 -padx 2
	pack $w.f -side top -fill both -expand 1 -padx 2
	pack configure $w.sep -padx 24 -pady 6 -expand 0
	pack configure $w.efix -fill x -expand 0
	
	return $w
}

proc frameSuffix { w } {
	lappend ::suffixes "$::date" {} ; # Appends an empty value to allow easy deselect
	set ::suffixes [lsort $::suffixes]
	foreach suf $::suffixes {
		lappend suflw [string length $suf]
	}
	set suflw [lindex [lsort -integer -decreasing $suflw] 0]
	set suflw [expr {int($suflw+($suflw*.2))}]
	expr { $suflw > 16 ? [set suflw 16] : [set suflw] }

	ttk::combobox $w.pre -width $suflw -state readonly -textvariable ::ouprefix -values $::suffixes
	$w.pre set [lindex $::suffixes 0]
	comboBoxEditEvents $w.pre {printOutname %W }
	ttk::combobox $w.suf -width $suflw -state readonly -textvariable ::ousuffix -values $::suffixes
	$w.suf set [lindex $::suffixes 0]
	comboBoxEditEvents $w.suf {printOutname %W }

	pack $w.pre $w.suf -padx 2 -side left -fill x -expand 1

	return $w
}

proc frameOutput { w } {
	ttk::labelframe $w -text "Output & Quality" -padding 6

	set formats [list png jpg gif webp {webp lossy} ora] ; # TODO ora and keep
	ttk::label $w.lbl -text "Format:"
	ttk::combobox $w.fmt -state readonly -width 9 -textvariable ::outext -values $formats
	$w.fmt set [lindex $formats 0]
	bind $w.fmt <<ComboboxSelected>> [list setFormatOptions $w ]

	ttk::label $w.qtb -text "Quality:"
	ttk::scale $w.qal -from 10 -to 100 -variable ::iquality -value $::iquality -orient horizontal -command { progressBarSet ::iquality 0 0 0 "%.0f" }
	ttk::label $w.qlb -width 4 -textvariable ::iquality

	ttk::checkbutton $w.ove -text "Allow Overwrite" -onvalue 1 -offvalue 0 -variable ::overwrite -command { treeAlterVal {getOutputName $value $::outext $::ouprefix $::ousuffix} $::widget_name(flist) path output }
	ttk::checkbutton $w.alf -text "Remove Alfa" -onvalue "-background white -alpha remove" -offvalue "" -variable ::alfaoff

	ttk::separator $w.sep -orient vertical

	grid $w.qtb $w.qlb $w.qal -row 1
	grid configure $w.qtb -column 1
	grid configure $w.qal -column 2 -columnspan 2 -sticky we
	grid configure $w.qlb -column 4 -sticky w
	grid $w.lbl $w.fmt -row 2
	grid configure $w.lbl -column 2
	grid configure $w.fmt -column 3	
	grid $w.ove $w.alf -row 3 -columnspan 3 -sticky we
	grid configure $w.fmt $w.qlb -sticky we
	grid configure $w.qtb $w.lbl -sticky e

	grid columnconfigure $w {2} -weight 12 -pad 4 
	grid columnconfigure $w {1} -weight 2 -pad 4
	grid rowconfigure $w {0 1 2 3} -weight 1 -pad 4
	return $w
}

# Alters ouput widgets to show format output options
# w = widget name
proc setFormatOptions { w } {
	# update listname
	treeAlterVal {getOutputName $value $::outext $::ouprefix $::ousuffix} $::widget_name(flist) path output
	$::widget_name(convert-but) configure -text "Convert" -command {convert}
	$::widget_name(thumb-prev) state !disabled
	switch -glob -- $::outext {
		jpg	{
			set ::iquality 92 
			$w.qtb configure -text "Quality:"
			$w.qal configure -from 10 -to 100
		}
		png	{
			set ::iquality 9
			$w.qtb configure -text "Compress:"
			$w.qal configure -from 0 -to 9
		}
		gif	{
			set ::iquality 256
			$w.qtb configure -text "Colors:"
			$w.qal configure -from 1 -to 256
		}
		ora	{
			set ::iquality 0
			$w.qtb configure -text "Quality:"
			$w.qal configure -from 0 -to 0
			$::widget_name(convert-but) configure -text "Make ORA" -command {prepOra}
			$::widget_name(thumb-prev) state disabled
		}
		webp { 
			set ::iquality 100 
			$w.qtb configure -text "Quality:"
			$w.qal configure -from 10 -to 100
		}
		webp* { 
			set ::iquality 60
			$w.qtb configure -text "Quality:"
			$w.qal configure -from 10 -to 100
		}
	}
}

# ----==== Status bar
proc guiStatusBar { w } {
	pack [ttk::frame $w] -side top -expand 0 -fill x
	
	ttk::frame $w.rev
	ttk::frame $w.do
	
	set ::widget_name(check-wm) [ttk::checkbutton $w.rev.checkwm -text "Watermark" -onvalue 1 -offvalue 0 -variable ::watsel -command { turnOffChildCB watsel "$wt.cbim" watselimg "$wt.cbtx" watseltxt }]
	set ::widget_name(check-sz) [ttk::checkbutton $w.rev.checksz -text "Resize" -onvalue 1 -offvalue 0 -variable ::sizesel]

	set ::widget_name(pbar-main) [ttk::progressbar $w.do.pbar -maximum [getFilesTotal] -variable ::cur -length "260"]
	set ::widget_name(pbar-label) [ttk::label $w.do.plabel -textvariable pbtext -anchor e]
	set ::widget_name(convert-but) [ttk::button $w.do.bconvert -text "Convert" -command {convert}]
	setFormatOptions $::widget_name(frame-output)

	pack $w.rev.checkwm $w.rev.checksz -side left
	pack $w.rev -side left
	pack $w.do -side right -expand 1 -fill x
	pack $w.do.bconvert -side right -fill x -padx 6 -pady 8

	return $w
}

# Sets values for progress bar.
# w = widget, gvar = global variable name
# args ( max = max value, current, current value)
proc pBarUpdate { w gvar args } {
	upvar #0 $gvar cur
	# set opt [dict create]
	set opt [dict create {*}$args]
	
	if {[dict exists $opt max]} {
		$w configure -maximum [dict get $opt max]
	}
	if {[dict exists $opt current]} {
		set cur [dict get $opt current]
	}
	incr cur
}

# Controls the basic operation of create update and forget from main progressbar
proc pBarControl { itext {action none} { delay 0 } {max 0} } {
	updateTextLabel pbtext $itext
	# event generate $::widget_name(pbar-label) <Expose> -when now
	update idletasks
	after $delay
	switch -- $action {
		"create" { 
			pack $::widget_name(pbar-label) $::widget_name(pbar-main) -side left -expand 1 -fill x -padx 2 -pady 0
			pack configure $::widget_name(pbar-main) -expand 0
			pBarUpdate $::widget_name(pbar-main) cur max $max current -1
			# update idletasks
		}
		"forget" { 
			pack forget $::widget_name(pbar-main) $::widget_name(pbar-label)
			updateTextLabel pbtext ""
		 }
		"update"  { pBarUpdate $::widget_name(pbar-main) cur }
	}
}

#Resize: returns the validated entry as wxh or N%
proc getFinalSizelist {} {
	set sizeprelist [getSizesSel $::widget_name(tabsize-left)]
	if {$sizeprelist != 0 } {
		foreach {size} $sizeprelist {
			lappend sizelist [join $size {x}]
		}
	} else {
		set sizelist 0
	}
	return [lreverse $sizelist]
}
# Returns scaled size fitting in destination measures
# w xh = original dimension dw x dh = Destination size
proc getOutputSize { w h dw dh } {
	set ratio [expr { $h / [format "%0.2f" $w]} ]
	set dratio [expr { $dh / [format "%0.2f" $dw]} ]
	if { $dratio > $ratio } {
		set dh [ expr {round($h * $dw / [format "%0.2f" $w])} ]
	} else {
		set dw [ expr {round($w * $dh / [format "%0.2f" $h])} ]
	}
	# Do not allow to grow, at the moment is not supported
	if { $dw > $w } {
		return "${w}x${h}"
	}
	return "${dw}x${dh}"
}

# Calculates scaling destination for size in respect of chosen sizes
# size, string WidthxHeight, the original file size,
# Returns a list of wxh elements, Bool returns formated list
proc getOutputSizesForTree { size {formated 0}} {
	set cur_w [lindex [split $size {x} ] 0]
	set cur_h [lindex [split $size {x} ] 1]
	
	set sizelist [getFinalSizelist]
	foreach dimension $sizelist {
		if {[string range $dimension end end] == "%"} {
			set ratio [string trim $dimension {%}]
			set dest_w [expr {round($cur_w * ($ratio / 100.0))} ]
			set dest_h [expr {round($cur_h * ($ratio / 100.0))} ]
		} elseif {$dimension == 0} {	
			set dest_w $cur_w	
			set dest_h $cur_h
		} else {
			set dest_w [lindex [split $dimension {x} ] 0]
			set dest_h [lindex [split $dimension {x} ] 1]
		}
		# get final size
		#set finalscale [getOutputSize {*}[concat [split $size {x} ] [split $dimension {x}]] ]
		set finalscale [getOutputSize $cur_w $cur_h $dest_w $dest_h]
		#Add resize filter (better quality)
		lappend fsizes $finalscale
	}
	if {$formated} {
		return [join $fsizes {, }]
	}
	return $fsizes
}
#Preproces functions
# Renders watermark images based on parameters to tmp folder
# global watseltxt wmtxt wmsize wmcol, watselimg wmimsrc wmimop wmimcomp
# returns string
proc watermark {} {
	global deleteFileList
	set wmcmd {}
	
	# Positions list correspond to $::watemarkpos, but names as imagemagick needs
	set magickpos [list "NorthWest" "North" "NorthEast" "West" "Center" "East" "SouthWest" "South" "SouthEast"]
	set wmpossel   [lindex $magickpos [$::widget_name(wmpos) current] ]
	set wmimpossel [lindex $magickpos [$::widget_name(wmipos) current] ]
	# wmtxt watermarks wmsize wmcol wmcolswatch wmop wmpositions wmimsrc iwatermarks wmimpos wmimsize wmimcomp wmimop watsel watseltxt watselimg
	#Watermarks, check if checkboxes selected
	if { $::watseltxt } {
		set wmtmptx [file join "/tmp" "artk-tmp-wtmk.png" ]
		set width [expr {[string length $::wmtxt] * 3 * ceil($::wmsize/4.0)}]
		set height [expr {[llength [split $::wmtxt {\n}]] * 30 * ceil($::wmsize/8.0)}]
		set wmcolinv [getContrastColor $::wmcol ]
		
		set wmtcmd [list convert -quiet -size ${width}x${height} xc:transparent -pointsize $::wmsize -gravity Center -fill $::wmcol -annotate 0 "$::wmtxt" -trim \( +clone -background $wmcolinv  -shadow 80x2+0+0 -channel A -level 0,60% +channel \) +swap +repage -gravity center -composite $wmtmptx]
		catch { exec {*}$wmtcmd }
		
		lappend deleteFileList $wmtmptx ; # add wmtmp to delete list
		append wmcmd [list -gravity $wmpossel $wmtmptx -compose dissolve -define compose:args=$::wmop -geometry +5+5 -composite ]
		# puts [subst $wmcmd] ; # unfold if string in {}
	}
	if { $::watselimg && [file exists $::wmimsrc] } {
		set identify {identify -quiet -format "%wx%h:%m:%M "}
		if { [catch {set finfo [exec {*}$identify $::wmimsrc ] } msg ] } {
			puts $msg	
		} else {
			set imfl [split $finfo { }]
			set iminfo [lindex [split $imfl ":"] 0]
			set size [lindex $iminfo 0]
			set wmtmpim [file join "/tmp" "artk-tmp-wtmkim.png" ]
			set wmicmd [ list convert -quiet -size $size xc:transparent -gravity Center $::wmimsrc -compose dissolve -define compose:args=$::wmimop -composite $wmtmpim]
			catch { exec {*}$wmicmd }
			
			# set watval [concat -gravity $::wmimpos -draw "\"image $::wmimcomp 10,10 0,0 '$::wmimsrc'\""]
			lappend deleteFileList $wmtmpim ; # add wmtmp to delete list
			append wmcmd " " [list -gravity $wmimpossel $wmtmpim -compose $::wmimcomp -define compose:args=$::wmimop -geometry +10+10 -composite ]
			# puts $watval
		}
	}
	return $wmcmd
}

# Makes resize command, takes a size and calculates intermediate resize steps
# size = image size, dsize = destination size, filter = resize filter
# unsharp = unsharp string options
# return string
proc getResize { size dsize filter unsharp} {
	# Use processed scale from getOuputSizeForTree
	set finalscale $dsize
	# Operator is force size (!)
	set operator "\\!"
	set cur_w [lindex [split $size {x} ] 0]
	set dest_w [lindex [split $dsize {x} ] 0]
	
	# Create string Colospace, filter, resize x N, original Colorspace
	set resize "-colorspace RGB"
	set resize [concat $resize $filter]
	while { [expr {[format %.1f $cur_w] / $dest_w}] > 1.5 } {
		set cur_w [expr {round($cur_w * 0.8)}]
		set resize [concat $resize -resize 80% +repage $unsharp]
	}
	# Final resize output
	set resize [concat $resize -resize ${finalscale}${operator} +repage "-colorspace sRGB"]
	
	return $resize
}

# set quality options depending on extension
# returns string
proc getQuality { ext } {
	switch -glob -- $ext {
		jpg	{ set quality "-sampling-factor 1x1,1x,1x1 -quality $::iquality" }
		png	{ set quality "-type TrueColorMatte -define png:format=png32 -define png:compression-level=$::iquality -define png:compresion-filter=4" }
		gif	{ set quality "-channel RGBA -separate \( +clone -dither FloydSteinberg -remap pattern:gray50 \) +swap +delete -combine -channel RGB -dither FloydSteinberg -colors $::iquality" }
		webp { set quality "-quality $::iquality -define webp:auto-filter=true -define webp:lossless=true -define webp:method=5" }
		webp* { set quality "-quality $::iquality -define webp:auto-filter=true -define webp:lossless=false -define webp:alpha-quality=100"}
	}
	return $quality
}

# Gets all inputfiles, filter files on extension, sends resulting list to makeORA
# returns nothing
proc prepOra {} {
	
	set idlist [dict keys $::inputfiles]
	
	set filtered_list {}
	foreach id $idlist {
		if { [regexp {^(webp|svg)$} [dict get $::inputfiles $id ext]] } {
			continue
		}
		lappend filtered_list $id
	}
	pBarControl {} create 0 [llength $filtered_list]
	makeOra 0 $filtered_list
	
	return
}

# Converts files recursively to ORA format
# index = current file, ilist = list to walk with index
# returns nothing
proc makeOra { index ilist } {

	set idnumber [lindex $ilist $index]
	incr index
	
	if { $idnumber eq {} } {
		pBarControl "All operations Done" forget 600
		return
	}
	
	set datas [dict get $::inputfiles $idnumber]
	dict with datas {
		if {!$deleted} {
			pBarControl "Oraizing... $name" update

			set outname [file join [file dirname $path] $output]
			catch { exec calligraconverter --batch -- $path $outname } msg
		}
	}
	after idle [list after 0 [list makeOra $index $ilist]]
	return
}

# Gets files to be rendered by gimp, calligra or inkscape
# ids = files to convert (default all)
# returns integer, total files to process
proc prepHandlerFiles { {ids ""} } {
	if { $ids eq ""} {
		set ids [putsHandlers g i k]
	}
	set id_length [llength $ids]
	pBarUpdate $::widget_name(pbar-main) cur max $id_length current -1
	
	processHandlerFiles 0 $ids
	return $id_length
}

# Calligra, gimp and inkscape converter
# Creates a png file in tmp and adds file path to dict id
# index = current process position, ilist = list to walk, outfdir = output directory
# returns nothing
proc processHandlerFiles { index ilist {outdir "/tmp"} } {
	global inputfiles handlers deleteFileList
	
	set imgv [lindex $ilist $index]
	incr index
	
	if { $imgv eq {} } {
		return
	}
	set msg {}
	array set handler $handlers
	array set id [dict get $inputfiles $imgv]

	set outname [file join ${outdir} [file root $id(name)]]
	append outname ".png"
	
	puts "extract $id(name)"
	pBarControl "Extracting... $id(name)" update
	
	if { ![file exists $outname ]} {
		if { $handler($imgv) == {g} } {
			set i $id(path)
			set cmd "(let* ( (image (car (gimp-file-load 1 \"$i\" \"$i\"))) (drawable (car (gimp-image-merge-visible-layers image CLIP-TO-IMAGE))) ) (gimp-file-save 1 image drawable \"$outname\" \"$outname\") )(gimp-quit 0)"
			#run gimp command, it depends on file extension to do transforms.
			catch { exec gimp -i -b $cmd } msg
		}
		if { $handler($imgv) == {i} } {
			# output 100%, resize imagick
			catch { exec inkscape $id(path) -z -C -d 90 -e $outname } msg
		}
		if { $handler($imgv) == {k} } {
			catch { exec calligraconverter --batch -- $id(path) $outname } msg
		}
		if { $handler($imgv) == {m} } {
			continue
		}
	}
	#Error reporting, if code NONE then png conversion success.
	if { ![file exists $outname ]} {
		set errc $::errorCode;
		set erri $::errorInfo
		puts "errc: $errc \n\n"
		if {$errc != "NONE"} {
			append ::lstmsg "EE: $$id(name) discarted\n"
			puts $msg
		}
		error "something went wrong, tmp png wasn't created"
	} else {
		dict set inputfiles $imgv tmp $outname
		lappend deleteFileList $outname
	}
	array unset handler
	after idle [list after 0 [list processHandlerFiles $index $ilist]]
	return
}

# Get ids of files to process
# id = file to process
# return list
proc processIds { {id ""} } {
	if { $id ne "" } {
		return $id
	} else {
		return [dict keys $::inputfiles]
	}
}

# Convert: Construct and run convert tailored to each file
# id = files to process, none given: process all
# return nothing
proc doConvert { {id ""} } {
	
	set idnumber [lindex $::artscript_convert(files) $::artscript_convert(count)]
	incr ::artscript_convert(count)
	
	if { $idnumber eq {} } {
		if { $id eq ""} {
			catch {file delete [list $::deleteFileList]}
		}
		pBarControl "Operations Done..." forget 600
		return
	}
	
	set datas [dict get $::inputfiles $idnumber]
	dict with datas {
		if {$deleted} {
			continue
		}
		set opath $path
		set outpath [file dirname $path]

		if {[dict exists $datas tmp]} {
			set opath $tmp
		}
		# - Lagrange Lanczos2 Catrom Lanczos Parzen Cosine + (sharp)
		# use "-interpolate bicubic -filter Lanczos -define filter:blur=.9891028367558475" SLOW but best
		# with -distort Resize instead of -resize "or LanczosRadius"
		set filter "-interpolate bicubic -filter Parzen"
		set unsharp [string repeat "-unsharp 0.48x0.48+0.60+0.012 " 1]
		set i 0
		# get make resize string
		set sizes [getOutputSizesForTree $size]
		set nsizes [llength $sizes]
		
		foreach dimension $sizes {
			incr i
			set resize {}
			if { $size != $osize } {
				set resize [getResize $size $dimension $filter $unsharp]
			}
			pBarControl "Converting... ${name} to $dimension" update
			
			if {$i == 1} {
				set dimension {}
			}
			
			if { $id eq ""} {
			set soname \"[file join $outpath [getOutputName $opath $::outext $::ouprefix $::ousuffix $dimension] ]\"
			} else {
				set soname "show:"
			}
			set convertCmd [concat -quiet \"$opath\" $resize $::artscript_convert(wmark) $unsharp $::alfaoff $::artscript_convert(quality) $soname]
			catch { exec convert {*}$convertCmd }
			
			# pBarControl "Converting... ${name} to $dimension" update 1000
		}
	}
	after idle [list after 0 doConvert]
	
	return
}

# Set convert global values and total files to process
# id = files to convert, if none given, all will be processed
proc convert { {id ""} } {
	
	set ::artscript_convert(count) 0
	
	#get watermark value
	set ::artscript_convert(wmark) [watermark]
	set ::artscript_convert(quality) [getQuality $::outext]
	
	#Create progressbar
	pBarControl {} create 0 1
	
	#process Gimp Calligra and inkscape to Tmp files
	set total_renders [prepHandlerFiles $id]
	puts "end handler"
	set ::artscript_convert(files) [processIds $id]
	
	pBarUpdate $::widget_name(pbar-main) cur max [expr {([getFilesTotal] + $total_renders) * [llength [getFinalSizelist]]}] current 0

	doConvert $id
	puts "end convert"
}

# ---=== Window options
wm title . "Artscript $::version -- [getFilesTotal] Files selected"
# Set close actions
bind . <Destroy> [list catch {file delete [list $::deleteFileList] } ]

# We test if icon exist before addin it to the wm
set wmiconpath [file join [file dirname [info script]] "atk-logo.gif"]
if {![catch {set wmicon [image create photo -file $wmiconpath  ]} msg ]} {
	wm iconphoto . -default $wmicon
}

# ---=== Construct GUI
artscriptStyles
# Pack Top: menubar. Middle: File, thumbnail, options, suffix output.
# Bottom: status bar
guiTopBar .f1
guiMiddle .f2
guiStatusBar .f3

# ---=== Validate input filetypes
set argvnops [lrange $argv [llength $::ops] end]
listValidate $argvnops

