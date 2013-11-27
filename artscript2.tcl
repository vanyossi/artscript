#! /usr/bin/env wish
#
# ---------------:::: ArtscriptTk ::::-----------------------
#  Version: 2.1.2
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
set ::version "v2.1.2"

# Do not show .dot files by default. !fails in OSX
catch {tk_getOpenFile foo bar}
set ::tk::dialog::file::showHiddenVar 0
set ::tk::dialog::file::showHiddenBtn 1

#Set default theme to clam if supported
catch {ttk::style theme use clam}
namespace eval img { }

# Loads default values for setting vars
# Returns dict with all vars.
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
		sizes_set(wallpaper) [list "2560x1440" "1920x1080" "1680x1050" "1366x768" "1280x1024" "1280x720" "1024x768"] \
		sizes_set(percentage) "90% 80% 50% 25%" \
		sizes_set(icon) "128x128 96x96 48x48 36x36" \
		sizes_set(texture) "256x256 512x512" \
		sizes_set(default) "" \
	]
	#sizes       [list "2560x1440"  "1920x1080" "1680x1050" "1366x768" "1280x1024" "1280x720" "1024x768" "720x1050" "50%"] \

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
		artscript(alfa_color)	"white" \
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
    # TODO array set ::settings $::artscript::usett
	# puts "array $::settings(ext)"
}
#--=====
# Don't modify below this line

# Implement alert type call for tk_messageBox
# type,icon,title,msg => string
proc alert { title msg type icon } {
		tk_messageBox -type $type -icon $icon -title $title -message $msg
}
# Find program in path
# Return bool
proc validate {program} {
	foreach place [split $::env(PATH) {:}] {
		expr { [file exists [file join $place $program]] == 1 ? [return 1] : [continue] }
	}
	return 0
}

# Modifies iname adding suffix, prefix, size and ext.
# If destination name file exists adds a standard suffix
# iname => file string, preffix suffix sizesuffix => string to append,
# orloc => filepath: Used to return destination to orignal loc in case of tmp files (KRA,ORA)
# returns filename.ext
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

# Parses the list $argv for (:key value) elements. breaks if strin is file
# returns list
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

#-==== Global variable declaration
array set ::settings [artscriptSettings]
array set ::widget_name {}
#puts $settings(sizes)
#-==== Global dictionaries, files values, files who process
set ::inputfiles [dict create]
set ::handlers [dict create]
set ::ops [getUserOps $argv]
#-==== Find Optional dependencies (as global to search file only once)
set ::hasgimp [validate "gimp"]
set ::hasinkscape [validate "inkscape"]
set ::hascalligra [validate "calligraconverter"]
#-====# Global file counter TODO: separate delete to a list
set ::fc 1

# Get image properties Size, format and path of Image
# Receives an absolute (f)ile path
# Returns dict or error if file is not supported
proc identifyFile { f } {
	set identify [list identify -quiet -format "%wx%h:%m:%M "]
	if { [catch {set finfo [exec {*}$identify $f] } msg ] } {
		return -code break "$msg"
	} else {
		foreach {size ext path} [split [lindex $finfo 0] ":"] {
			set valist "size $size ext [string tolower $ext] path $path"
		}
		return [dict merge $valist]
	}
}

# Get SVG file to get Width and Height.
# Works with plain and normal svg saved from inkscape. TODO: testing
# returns string {widtxheight} or 0 if nothing found
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

# Computes values to insert in global inputfiles dictionary
# id => uniq integer, fpath filepath, size WxH, ext .string, h string(inkscape,calligra,gimp...)
proc setDictEntries { id fpath size ext h {add 1}} {
	global inputfiles handlers

	set input_values [dict create \
		name      [file tail $fpath] \
		output    [getOutputName $fpath $::outext $::ouprefix $::ousuffix] \
		size      $size \
		osize     [getOutputSizesForTree $size 1] \
		ext       [string trim $ext {.}] \
		path      [file normalize $fpath] \
		deleted   0 \
	]
	dict set handlers $id $h
	dict for {key value} $input_values {
		dict set inputfiles $id $key $value
	}
	if {$add} {
		addTreevalues $::widget_name(flist) $id ; # TODO set widget name as global
	}
}
	
# Get contents from file and parse them into Size values.
proc getOraKraSize { image_file filext } {
	set size {}

	switch -- $filext {
	".ora" { set unzip_file {stack.xml} }
	".kra" { set unzip_file {maindoc.xml} }
	}
	if { [catch { set zipcon [exec unzip -p $image_file $unzip_file]} msg] } {
		return -code break "$image_file is not a valid ORA/KRA"
	}

	set zipkey [lsearch -inline -regexp -all $zipcon {^(w|h|width|height)} ]

	foreach size_val $zipkey {
		lassign [scan $size_val {%[hwiegdth]="%d"%s}] val1 val2
		lappend size_list [list $val1 $val2]
	}
	set width_height [lsort -decreasing -index 0 $size_list]
	lassign $width_height width height
	set size [join [list [lindex $width 1] [lindex $height 1]] {x}]

	return $size
}

# Validates the files supplied to be Filetypes supported by script
# Search order: gimp(xcf,psd) > inkscape(svg,ai) > calligra(kra,ora,xcf,psd) > allelse
# ltoval list
proc listValidate { ltoval } {
	# global fc

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

			runCommand [list identify -format "%wx%h " $i] [list set ::validate_wait 1] ::artscript(tmp_size)
			vwait ::validate_wait
			set size [lindex $::artscript(tmp_size) 0]

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
				 # TODO get rid of head cmd
				if { [catch { set svgcon [exec inkscape -S $i | head -n 1] } msg] } {
					puts $msg
					continue
				}
				set svgvals [lrange [split $svgcon {,}] end-1 end] ; # Get the last elements of first line == w x h
				set size [expr {round([lindex $svgvals 0])}] ; # Make float to int. TODO check if format "%.0f" works best here
				append size "x" [expr {round([lindex $svgvals 1])}]
			}
			setDictEntries $::fc $i $size $filext "i"
			incr ::fc
			continue

		} elseif { [regexp {^(.kra|.ora|.xcf|.psd)$} $filext ] && $::hascalligra } {

			if { [catch {set size [getOraKraSize $i $filext]} msg ] } {
				puts $msg
				continue
			}

			setDictEntries $::fc $i $size $filext "k"
			incr ::fc
			continue

		# Catch magick errors. Some files have the extension but are not valid types
		# And check for files with no extension with IM identify
		} elseif { [lsearch $::ext $filext ] >= 0 || [string equal $filext {}] } {
			if { [catch {set finfo [identifyFile $i ] } msg ] } {
				puts $msg
				continue
			}
			set size [dict get $finfo size]
			set ext [dict get $finfo ext]
			setDictEntries $::fc $i $size $ext "m"
			incr ::fc
		}
	}
}

# Searchs for presets.config in script directory, parses and set values from file to global
# TODO return dict, use dict values to set master settings array
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
# Change settings values from $::presets dict "s"
# s string, setting preset name
proc setUserPresets { s } {
	global presets
	if {![info exists presets]} {
		return 0
	}

    # TODO remove this list of global tcl vars. set all user vars in a pair list value, or array.
    set gvars {tcl_rcFileName|tcl_version|argv0|argv|tcl_interactive|tk_library|
    tk_version|auto_path|errorCode|tk_strictMotif|errorInfo|auto_index|env|tcl_p
    kgPath|tcl_patchLevel|argc|tk_patchLevel|tcl_library|tcl_platform}
	
	#set values according to preset
	dict for {key value} [dict get $presets $s] {
		if { ![regexp $gvars $key ] } {
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
# get_del bool, true = get all files loaded
# returns integer
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

# Returns a list of ids of all elements that have args string in value
# args string list (gimp inkscape, magick, calligra)
proc putsHandlers {args} {
	global handlers
	foreach c $args {
		lappend images {*}[dict filter $handlers script {k v} {expr {$v eq $c}}]
		# lappend images {*}[dict keys [set ${c}fdict]]
	}
	return [dict keys $images]
}
# Shows open dialog for supported types
# Validates the input and updates the window title
proc openFiles [list [list path $::env(HOME)]] {
	if {[info exists ::artscript(openpath)]} {
		set path $::artscript(openpath)
	}
	set exts [list $::ext]
	set types " \
	 	\"{Suported Images}  $exts \"
	{{KRA, ORA}      {.ora .kra}  } \
	{{SVG, AI}       {.svg .ai}   } \
	{{XCF, PSD}      {.xcf .psd}  } \
	{{PNG}           {.png}       } \
	{{JPG, JPEG}     {.jpg .jpeg} } \
	"
	set files [tk_getOpenFile -filetypes $types -initialdir $path -multiple 1]
	# Set initialdir global from files
	set ::artscript(openpath) [file dirname [lindex $files 0]]

	listValidate $files
	updateWinTitle
}

# ----=== Gui proc events ===----
# Sort arguments and send first 4 to global mod procs
proc bindsetAction { args } {
	foreach i $args {
		incr n
		set $n $i
	}
	setGValue $1 $2
	optionOn $3 $4
}
# Sets global value with value
# gvar: global variable name
# TODO, review for removal
proc setGValue {gvar value} {
	if {$gvar != 0} {
		upvar #0 $gvar var
		set var $value
		puts $var
	}
}
# Toggles on state of checkbox using gvar
# only if args elements are different.
# args = widget checkbox path
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
# Parent checkbox only off if all args are off
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
	update idletasks
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
# Sorts tree values by column
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
# Sorts tree column by pair tags On/off
# tree widgetname, col, column, tag/antitag
proc treeSortTagPair {tree col tag antitag} {
	# Build something we can sort
	set data {}
    foreach row [$tree tag has $tag] {
        lappend data $row
    }
    
    set r -1
    foreach info [lsort $data] {
        $tree move $info {} [incr r]
    }
    # reverse sort order
    set cmd [list treeSortTagPair $tree $col $antitag $tag]
    $tree heading $col -command $cmd
}

# Updates global variable
# var = global variable name, value = new value
# TODO: check if necessary
proc updateTextLabel { var value } {
	upvar #0 $var ltext
	set ltext $value
	return
}
# Transform a read with the supplied script and writes it to dict and treeview
# Script: script to run, w = widget, write/read = dict key or tree column
proc treeAlterVal { {script {set $value}} w read write  } {
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
# Updates checkbox state and output name values on tree (w)
proc printOutname { w } {
	if {$::prefixsel || $w != 0} {
		bindsetAction 0 0 prefixsel $::widget_name(cb-prefix)
	}
	treeAlterVal {getOutputName $value $::outext $::ouprefix $::ousuffix} $::widget_name(flist) path output
}

# Check id of thumbnail shown sends it to convert to preview.
# TODO add size preview selection
proc showPreview {} {
	if {[info exists ::artscript(preview_id)]} {
		prepConvert Convert $::artscript(preview_id) 1
	}
	return
}

# Creates a thumbnail and places it in user thumbnail folders
# It uses md5 string to store the file name in thumbs dir
proc makeThumb { path filext tsize } {
	set cmd [dict create]
	dict set cmd .ora {Thumbnails/thumbnail.png}
	dict set cmd .kra {preview.png}

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

proc setThumbGif { path } {
	global img oldimg thumb_proc

	set prevgif {/tmp/atkpreview.gif}
	
	catch {close $thumb_proc}
	set thumb_proc [runCommand [concat convert -quiet $path GIF:$prevgif] [list set ::thumb_wait 1]]
	vwait ::thumb_wait
	# catch { exec convert -quiet $lthumb GIF:$prevgif }
	catch {set oldimg $img}
	catch {puts $img}
	set img [image create photo -file $prevgif ]

	$::widget_name(thumb-im) configure -compound image -image $img
	catch {image delete $oldimg}
	# catch {file delete $prevgif}
}

# Attempts to load a thumbnail from thumbnails folder if exists.
# Creates a thumbnail for files missing Large thumbnail
proc showThumb { w f {tryprev 1}} {
	global inputfiles env

	# Do not process if selection is multiple
	if {[llength $f] > 1} {
		return -code break
	}
	# TODO, get value with no lindex: .t set $f id
	set ::artscript(preview_id) [lindex [$::widget_name(flist) item $f -values] 0]
	
	set path [dict get $inputfiles $::artscript(preview_id) path]
	set filext [string tolower [file extension $path] ]
	# Creates md5 checksum from text string: TODO avoid using echo
	# exec md5sum << "string" and string trim $hash {- }
	set thumbname [lindex [exec echo -n "file://$path" \| md5sum] 0]
	set thumbdir "$env(HOME)/.thumbnails"
	set lthumb "${thumbdir}/large/$thumbname.png"
	set nthumb "${thumbdir}/normal/$thumbname.png"

	# Displays preview in widget, Make proc of this.
	if { [file exists $lthumb ] } {
		setThumbGif $lthumb
		return 

	} elseif { [file exists $nthumb] } {
		puts "$path has normal thumb"
		if {[regexp {.xcf|.psd} $filext ]} {
			setThumbGif $nthumb
			return
		}
		makeThumb $path $filext [list 256 $lthumb]
	} else {
		puts "$path has no thumb"
		makeThumb $path $filext [list 128 $nthumb 256 $lthumb]
	}

	if {$tryprev} {
		showThumb w $f 0
	}
}

# Scroll trough tabs on a notebook. (dir = direction)
proc scrollTabs { w i {dir 1} } {
		set tlist [llength [$w tabs]]
		# Defines if we add or res
		expr { $dir ? [set op "-"] : [set op ""] }
		incr i ${op}1
		if { $i < 0 } {
			$w select [expr {$tlist-1}]
		} elseif { $i == $tlist } {
			$w select 0
		} else {
			$w select $i
		}
}

# Defines combobox editable events.
proc comboBoxEditEvents { w {script {optionOn watsel} }} {
	bind $w <<ComboboxSelected>> $script
	bind $w <Button-3> { %W configure -state normal }
	bind $w <Control-Button-1> { %W configure -state normal }
	bind $w <space> { %W configure -state normal }
	bind $w <KeyRelease> $script
	bind $w <FocusOut> { %W configure -state readonly }
}

# Convert RGB to HSV, to calculate contrast colors
# Returns float list => hue, saturation, value, lightness, luma 
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

# Calls tk colorchooser and sets color on canvas element widget.
# return hex color string
# TODO, remove hardcoded names to allow use on other canvas widgets
proc setColor { w item col {chooser 1} } {
	set identify_tag [lindex [$w itemcget $item -tags] 0]
	switch -- $identify_tag {
		"bg"          { set title "Collage Background Color"}
		"border"      { set title "Collage Border Color"}
		"label"       { set title "Collage Label Color"}
		"watermark"   { set title "Watermark Text Color"}
		"default"     { set title "Choose color"}
	}
	set col [lindex $col end]

	#Call color chooser and store value to set canvas color and get rgb values
	if { $chooser } {
		set col [tk_chooseColor -title $title -initialcolor $col -parent .]
	}
	# User selected a color and not cancel then
	if { $col ne "" } {
		$w itemconfigure $item -fill $col
	} else {
		return -code break "No color selected"
	}
	return $col
}
# Calls color chooser and set contrast color for watermark text
# w widget to modify, args pass to setColor
proc setColorAndContrast { w args } {
	# set col [setColor $w {*}$args]
	if { [catch {set col [setColor $w {*}$args]} msg] } {
		return
	}
	$w itemconfigure $::canvasWatermark(main) -outline [getContrastColor $col]
	set ::wmcol $col
}

# Returns the most contrasting color, black or white, based on luma values
proc getContrastColor { color } {
	set rgbs [winfo rgb . $color]
	set luma [lindex [rgbtohsv {*}$rgbs ] 4]
	return [expr { $luma >= 105 ? "black" : "white" }]
}

# Draws watermark color swatches
# (w)idgetname, args = color list
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
		$w bind $::canvasWatermark($i) <Button-1> [list setColorAndContrast $w $::canvasWatermark(main) $col 0 ]
		if { $i == $chal } {
			incr y $ch
			set x [expr {$x-($cw*$i)}]
		}
		incr x 13
	}
}

# from http://wiki.tcl.tk/534
# Convert rgb to hex values
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

# Returns sorted dict of colors
# Colors can be sorted, or grouped by luma, saturation, hsv...
# colist list, sortby integer (index of rgbtohsv return vals)
proc getswatches { {colist 0} {sortby 1}} {
	# Set a default palette, colors have to be in rgb

	set swcol { Black {0 0 0} English-red {208 0 0} {Dark crimson} {120 4 34} Orange {254 139 0} Sand {193 177 127}
	Sienna {183 65 0} {Yellow ochre} {215 152 11} {Cobalt blue} {0 70 170} Blue {30 116 253} {Bright steel blue} {170
	199 254} Mint {118 197 120} Aquamarine {192 254 233} {Forest green} {0 67 32} {Sea green} {64 155 104} Green-yellow
	{188 245 28} Purple {137 22 136} Violet {77 38 137} {Rose pink} {254 101 203} Pink {254 202 218} {CMYK Cyan} {0 254
	254} {CMYK Yellow} {254 254 0} White {255 255 255} }
	
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
				Button.padding -sticky nswe -children {Button.label -expand 0 -side left -sticky nswe}
				}
			}
		}
	ttk::style configure small.TButton -padding {6 0} -width 0
	ttk::style layout no_indicator.TCheckbutton { 
		Checkbutton.padding -sticky nswe -children { 
			Checkbutton.focus -side left -sticky w -children {
				Checkbutton.label -sticky nswe}
			}
		}
	ttk::style configure no_indicator.TCheckbutton -font "-weight bold"
}

# ----=== Gui Construct ===----
# TODO Make every frame a procedure to ease movement of the parts
# Adds the widgets given top to bottom
proc addFrameTop { args } {
	foreach widget [list {*}$args] {
		pack $widget -side top -fill x
	}
}
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
# Add children to panedwindows or notebooks
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

	set ::option_tab [guiOptionTabs $paned_botom.n]
	set gui_out [guiOutput $paned_botom.onam]
	
	guiAddChildren $paned_botom $::option_tab $gui_out
	$paned_botom pane $::option_tab -weight 6
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
	set ::cl [tabCollage $w.cl]
	
	$w add $::wt -text "Watermark" -underline 0
	$w add $::st -text "Resize" -underline 0 -sticky nsew -image $::img_off -compound right
	$w add $::cl -text "Collage" -underline 0 -sticky nsew -image $::img_off -compound right

	return $w
}

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
	bind $wt.fontsize <ButtonRelease> { bindsetAction wmsize [%W get] watsel "$::widget_name(check-wm) $wt.cbtx"}
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
	
	set ::canvasWatermark(main) [$wt.st.chos create rectangle 2 2 26 26 -fill $::wmcol -width 2 -outline [getContrastColor $::wmcol] -tags {watermark main}]
	$wt.st.chos bind main <Button-1> { setColorAndContrast %W $::canvasWatermark(main) [%W itemconfigure $::canvasWatermark(main) -fill] }

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
proc getArrayNamesIfValue { aname } {
	foreach key [array name $aname] {
		if {[llength $[set aname]($key)] > 0 } {
			lappend presets $key
		}
	}
	return $presets
}

# Create checkbox images
proc createImageVars {} { 
	set ::img_off [image create photo]
	$::img_off put {
        R0lGODlhCgAKAPQQACUlJSYmJicnJygoKCkpKTQ0NOjo6Orq6u3t7fDw8PPz8/T09Pb29vf39/n5
+f39/f///wAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACH5BAAA
AAAAIf8LSW1hZ2VNYWdpY2sOZ2FtbWE9MC40NTQ1NDUALAAAAAAKAAoAAAUuYDEAZDmIUKqmI8S8
MERCSm3LAI0oO4JDiKAQ5zAYjw5S8WhMDlywF+Q0KpFOIQA7
    }
    set ::img_on [image create photo]
    $::img_on put {
        R0lGODlhCgAKAPQAAColMSolMiolMysnMislNCslNSslNiwlNi0nNjQ0Nrr/NLP/PL7/PMP/NLb/
RLn/TLn/Tb3/VcH/RcT/TsT/T8D/Xcn/WMP/Zcz/YM//adP/dN3/eAAAAAAAAAAAAAAAACH5BAAA
AAAAIf8LSW1hZ2VNYWdpY2sOZ2FtbWE9MC40NTQ1NDUALAAAAAAKAAoAAAU3YIIghkGaYqOsbEMy
SywzpeTcuFROT+9PBoElQixaBAJMZcnEIDOXqDSD3Giu2I0gIQAgv4NECAA7
    }
}

# Hides or shows height combobox depending if value is wxh or w%
# size => stringxstring or string%x
# returns pair list
proc sizeToggleWidgetWxH { size {name "resize"} } {
	set w $::widget_name(tab_${name}_size)

	scan $size "%d%s" width height
	set sep [string index $height 0]
	set height [string range $height 1 end]

	if { ($sep eq "x") && $height ne {} } {
		pack $w.hei -side left -after $w.xmu
		$w.hei state !disabled
		$w.xmu configure -text "x" -anchor center
		bind $w.xmu <Button> [list sizeAlterRatio $name]
		set size [list wid $width hei $height]

	} elseif { $sep eq "%"} {
		$w.wid set $width
		if { $name ne "collage" } {
			pack forget $w.hei

			$w.xmu configure -text "%" -anchor w
			bind $w.xmu <Button> {}
			bind $w.wid <KeyRelease> [list setBind $w $name]

			set size [list wid $width hei $width]
		}
	}
	return $size
}
# Convert aspect ratio pairs to float
# Widget name
# returns float. Or returns 0 if no ratio
proc sizeRatioToFloat { w } {
	
	set ratio [string trim [$w get] {:}]
	if {$ratio eq {} } {
		return 0
	}
	set sratio [split $ratio {:}]
	
	if { [llength $sratio] > 1 } {
		set sratio [lreplace $sratio end end [format "%.2f" [lindex $sratio end]] ]
		catch { set ratio [expr [join $sratio /]] }
	}
	return $ratio
}
# Flips width and heigth field values and sets a new ratio if it's set
proc sizeAlterRatio { name } {
	# Get w and h values
	set wid [$::widget_name(tab_${name}_wid) get]
	set hei [$::widget_name(tab_${name}_hei) get]
	
	if { ($wid eq {}) || ($hei eq {}) } {
		return 0
	}
	# reverse width and height values
	$::widget_name(tab_${name}_wid) set $hei
	$::widget_name(tab_${name}_hei) set $wid
	
	# Get current ratio, calculate new ratio, else format 2:3, reverse
	set rawratio [$::widget_name(tab_${name}_ratio) get]
	if { ($rawratio ne {}) && ([string is double $rawratio]) } {
		set ratio [expr {[format "%.1f" $hei] / $wid}]
		$::widget_name(tab_${name}_ratio) set $ratio
	} else {
		$::widget_name(tab_${name}_ratio) set [join [lreverse [split $rawratio {:}]] {:}]
		# $::widget_name(resize_ratio) set [ sizeRatioToFloat $::widget_name(resize_ratio) 1 ]
	}
}
# Changes dimension, width or height in respect to Aspect ratio
# Alter == wid or hei   w, widget father.
proc sizeAlter { w alter name } {
	set ratio [sizeRatioToFloat $w.rat]
	set wid [$::widget_name(tab_${name}_wid) get]
	set hei [$::widget_name(tab_${name}_hei) get]

	if {($ratio != 0) && ($hei eq {})} {
		set hei $wid
	}

	if { [catch {set val [dict get [sizeToggleWidgetWxH ${wid}x${hei} $name] $alter]} ]} {
		return
	}
	setDimentionRatio $ratio $val $name $alter
}
# Set size wid Bind, back to default value
proc setBind { w name } {
	bind $w.wid <KeyRelease> [list sizeAlter $w wid $name]
}

# Calculates counterpart dimension depending on ratio
# sets value to target widget from ( mod ) values
# returns ratio
proc setDimentionRatio { r val {name "resize"} {mod "wid"} } {
	if { ($val eq {}) || ($r == 0) } {
		return
	}
	switch -- $mod {
		"hei" { 
			set val [expr round( $val * $r )] 
			set target "wid"
		}
		"wid" { 
			set val [expr round( $val / $r )] 
			set target "hei"
		}
	}
	$::widget_name(tab_${name}_${target}) set $val
	return $r
}
# Add selected W and H from fields, selected and groupd "custom"
proc sizeTreeAddWxH { operator width height } {
	set op [$operator cget -text]
	set wid [$width get]
	set hei [$height get]
	if { $op eq {%}} {
		set hei {}
	}
	set size [append wid "x" $hei]
	if { $size eq "x"} {
		return
	}
	# set size [join [list $wid $hei] "x" ]
	sizeTreeAdd $size
	return
}
# Add all preset values to sizeTree
proc sizeTreeAddPreset { w } {
	set preset [$w get]
	if { $preset eq {} } {
		return
	}
	foreach size $::sizes_set($preset) {
		sizeTreeAdd $size nonselected off
	}
}
# Add selected value from preset childs.
proc sizeTreeAddPresetChild { w } {
	set size [$w get]
	sizeTreeAdd $size
}

# Adds size to sizetree with default value on
proc sizeTreeAdd { size {sel "selected"} {state "on"} } {
	if { $size eq {} } {
		return
	}
	if { [scan $size "%dx%d" percentage heim] == 1} {
		set size [append percentage "%"]
	}
	if { [lsearch -exact [array names ::sdict] $size] == -1 } {
		set ::sdict_$size [$::widget_name(resize_tree) insert {} end -tag $sel -values "$size custom" ]
		set ::sdict($size) $state
	} else {
		$::widget_name(resize_tree) item [set ::sdict_$size] -tag selected
		set ::sdict($size) {on}
	}
	# Check if sizes set
	eventSize
	#puts [set $val]
	return
}

# Constructs size box (Probably this has to be cut into pieces)
proc addSizeBox { w name } {
	ttk::frame $w
	
	set ratiovals {1:1 1.4142 2:1 3:2 4:3 5:4 5:7 8:5 1.618 16:9 16:10 14:11 12:6 2.35 2.40}
	set ::widget_name(tab_${name}_ratio) [ttk::combobox $w.rat -width 6 -state readonly -values $ratiovals -validate key -validatecommand { regexp {^(()|[0-9])+(()|(\.)|(:))?(([0-9])+|())$} %P } ]
	comboBoxEditEvents $w.rat [list sizeAlter $w wid $name]
	#bind $w.rat <KeyRelease> [list sizeRatioToFloat $w.rat]
	
	ttk::label $w.lwxh -text ":" -font "-size 18" -anchor center
	# set walppvals {2560 1920 1800 1680 1600 1440 1366 1280 1200 1080 1024 960 864 800 768 600}
	set ::widget_name(tab_${name}_wid) [ ttk::spinbox $w.wid -width 5 -increment 10 -from 1 -to 5000 \
	  -validate key -validatecommand { regexp {^(()|[0-9])+(()|%%)$} %P } ]
	bind $::widget_name(tab_${name}_wid) <ButtonRelease> [list sizeAlter $w wid $name]
	bind $::widget_name(tab_${name}_wid) <KeyRelease> [list sizeAlter $w wid $name]

	# comboBoxEditEvents $w.wid "sizeAlter $w wid $name"
	# bind $w.wid <KeyRelease> [list sizeAlter $w "wid $name"]
	# bind $w.wid <Shift-Button><Shift-Motion> { puts "[winfo pointerx .] %w"}

	set ::widget_name(tab_${name}_hei) [ ttk::spinbox $w.hei -width 5 -increment 10 -from 1 -to 5000 \
		-validate key -validatecommand { string is integer %P } ]
	bind $::widget_name(tab_${name}_hei) <ButtonRelease> [list sizeAlter $w hei $name]
	bind $::widget_name(tab_${name}_hei) <KeyRelease> [list sizeAlter $w hei $name]
	# comboBoxEditEvents $w.hei "sizeAlter $w hei $name"
	# bind $w.hei <KeyRelease> [list sizeAlter $w "hei $name"]
	
	# comboBoxEditEvents $w.wid$id "eventSize $w $id"
	ttk::label $w.xmu -text "x" -font "-size 18" -anchor center
	ttk::label $w.empty
	bind $w.xmu <Button> [list sizeAlterRatio $name]

	pack $w.rat $w.lwxh $w.wid $w.xmu $w.hei $w.empty -side left -fill x
	pack configure $w.empty -expand 1

	return $w
}
# TODO organize and comment
proc sizeSetPreset { w tw } {
	set preset [$w get]
	$tw configure -values $::sizes_set($preset)
	$tw set [lindex $::sizes_set($preset) 0]
	sizeEdit $tw
}
# TODO organize and comment
proc sizeEdit { w } {
	set size [$w get]
	set sizes [sizeToggleWidgetWxH $size]

	set w $::widget_name(tab_resize_size)
	
	dict with sizes {
		$w.wid set $wid
		$w.hei set $hei
		#set ratio
		$::widget_name(tab_resize_ratio) set [expr {[format "%.2f" $wid] / $hei}]
	}
	return 0
}

proc addPresetBrowser { w } {
	ttk::frame $w
	
	ttk::frame $w.preset
	ttk::frame $w.set_sizes
	
	ttk::label $w.preset.browser -text "Browse presets"

	set presets [lsort [getArrayNamesIfValue ::sizes_set]]

	ttk::combobox $w.preset.sets -state readonly -values $presets
	bind $w.preset.sets <<ComboboxSelected>> [list sizeSetPreset %W $w.set_sizes.size]
	$w.preset.sets set [lindex $presets 0]

	ttk::button $w.preset.add -text "+" -padding {2 0} -style small.TButton -command [list sizeTreeAddPreset $w.preset.sets]
	
	ttk::combobox $w.set_sizes.size -state readonly
	bind $w.set_sizes.size <<ComboboxSelected>> [list sizeEdit %W]
	# ttk::button $w.set_sizes.edit -text "Edit" -width 6 -style small.TButton -command [list sizeEdit $w.set_sizes.size]
	ttk::button $w.set_sizes.add -text "+" -padding {2 0} -style small.TButton -command [list sizeTreeAddPresetChild $w.set_sizes.size]
	
	pack $w.preset $w.set_sizes -side top -expand 1 -fill x
	pack $w.set_sizes -pady 6
	
	pack $w.preset.browser $w.preset.sets $w.preset.add -side left -fill x
	pack $w.set_sizes.size $w.set_sizes.add -side left -fill x
	pack configure $w.preset.browser $w.set_sizes.size -expand 1	

	return $w
}

# Creates sizes list GUI
# w = own widget name
# returns frame name
proc sizeTreeList { w } {
	ttk::frame $w
	set size_tree_colname {size}
	set ::widget_name(resize_tree) [ttk::treeview $w.sizetree -columns $size_tree_colname -height 5 -yscrollcommand "$w.sscrl set"]
	foreach tag {selected nonselected} {
		$w.sizetree tag bind $tag <Button-1> { sizeTreeToggle %W [%W selection] %x %y }
	}
	foreach key {<KP_Add> <plus> <a>} {
		bind $w.sizetree $key { sizeTreeSetTag %W [%W selection] selected }
	}
	foreach key {<KP_Subtract> <minus> <d>} {
		bind $w.sizetree $key { sizeTreeSetTag %W [%W selection] nonselected }
	}
	bind $w.sizetree <Control-a> { %W selection add [%W children {}] }
	bind $w.sizetree <Control-d> { %W selection remove [%W children {}] }
	bind $w.sizetree <Control-i> { %W selection toggle [%W children {}] }
	bind $w.sizetree <Key-Delete> { sizeTreeDelete [%W selection] }
	bind $w.sizetree <KeyRelease> { eventSize }

	# bind $w.sizetree <<TreeviewSelect>> eventSize

	ttk::scrollbar $w.sscrl -orient vertical -command [list $w.sizetree yview ]
	
	pack $w.sizetree $w.sscrl -side left -fill both
	pack configure $w.sizetree -expand 1
	
	$w.sizetree heading #0 -text {} -image $::img_off -command [list treeSortTagPair $w.sizetree #0 selected nonselected ]
	$w.sizetree column #0 -width 34 -stretch 0
	$w.sizetree column size -width 50 -stretch 1
	foreach col $size_tree_colname {
		set name [string totitle $col]
		$w.sizetree heading $col -text $name -command [list treeSort $w.sizetree $col 0 ]
	}
	
    # Set images to tags
    $w.sizetree tag configure selected -image $::img_on
    $w.sizetree tag configure nonselected -image $::img_off
    
    # Add values for each array key
    # puts [array names ::sizes]
	foreach size $::sizes_set(default) {
		set ::sdict_$size [$w.sizetree insert {} end -tag nonselected -values "$size $name"]
		# default selecte state, off.
		set ::sdict($size) {off}
		#puts [set [subst ::sdict$size]]
	}
	return $w
}
# Selects size for processing, setting tag as selected
# w = widget name, sel = item ids, x = pointer x coordinate, y = yposition
proc sizeTreeToggle { w sel {x 0} {y 0} } {
	if {$x == 0} {
		set id $sel
	} else {
		set element [$w identify element $x $y]
		#Only change image if we press over it (check box)
		if { $element ne "image" } {
			return
		}
		set id [$w identify item $x $y]
	}
	foreach el $id {
		set val [$w set $el size]
		if { $::sdict($val) eq "on" } {
			set ::sdict($val) {off}
			set tag nonselected
		} else {
			set ::sdict($val) {on}
			set tag selected
		}
		$w item [set ::sdict_$val] -tag $tag
	}
	#recalculate sizes
	eventSize
}
# Sets selected tag to given treeview ids
# w = target widget, id = list of ids, tag = tag to place
# returns widget name
proc sizeTreeSetTag { w id tag } {
	foreach el $id {
		set val [$w set $el size]
		$w item [set ::sdict_$val] -tag $tag
	}
}
# Deletes sizes from sizeTree and unsets from array
proc sizeTreeDelete { sizes } {
	set slist {}
	foreach size $sizes {
		if {[scan $size "I%d" tmp] > 0} {
			set size [$::widget_name(resize_tree) set $size size]
		}
		array unset ::sdict $size
		lappend slist [set ::sdict_$size]
	}
	$::widget_name(resize_tree) detach $slist
	eventSize
}

proc sizeTreeOps { w } {
	ttk::frame $w
	
	ttk::button $w.clear -text "clear" -style small.TButton -command {sizeTreeDelete [array names ::sdict]}
	ttk::separator $w.separator -orient horizontal
	ttk::label $w.selectl -text "Select:"
	ttk::button $w.all -text "all" -style small.TButton -command {$::widget_name(resize_tree) selection add [$::widget_name(resize_tree) children {}] }
	ttk::button $w.inv -text "inv." -style small.TButton -command {$::widget_name(resize_tree) selection toggle [$::widget_name(resize_tree) children {}] }
	ttk::button $w.sels -text "sels" -image $::img_on -style small.TButton -padding {2} -command {$::widget_name(resize_tree) selection set [$::widget_name(resize_tree) tag has selected]}

	#Set focus on tree after pressing the buttons
	foreach widget [list $w.all $w.inv $w.sels] {
		bind $widget <ButtonRelease> { focus $::widget_name(resize_tree) }
	}

	pack $w.clear $w.separator $w.selectl $w.all $w.inv $w.sels -side left
	pack $w.separator -expand 1 -padx 12
	return $w
}
# Returns list of sizes with selected tag
proc getSizesSel { {sizes {} } } {
	set selected [$::widget_name(resize_tree) tag has selected]
	foreach item $selected {
		lappend sizes [$::widget_name(resize_tree) set $item size]
	}
	return $sizes
}

#set to <<TreeviewSelect>>
# and add to '+' action buttons
proc eventSize { } {
	set sizes [getSizesSel]

	treeAlterVal {getOutputSizesForTree $value 1} $::widget_name(flist) size osize

	if { [llength $sizes] > 0 } {
		#$::widget_name(st-right-ins) configure -text "[llength $sizes] Sizes set"
		$::option_tab tab $::st -image $::img_on
		# bindsetAction 0 0 sizesel $::widget_name(check-sz)
	} else {
		# $::widget_name(check-sz) invoke
		# $::widget_name(st-right-ins) configure -text ""
		$::option_tab tab $::st -image $::img_off
	}
}

# -	proc delSizecol { st id } { }

proc tabResize { st } {
	ttk::frame $st -padding 6
	
	ttk::frame $st.lef
	ttk::frame $st.rgt
	
	pack $st.lef -side left -fill y -padx {6 12}
	pack $st.rgt -expand 1 -fill both

	set preset_browse [addPresetBrowser $st.lef.broswer]
	set ::widget_name(tab_resize_size) [addSizeBox $st.lef.size "resize"]
	# pack widgets around addSizeBox
	set w $::widget_name(tab_resize_size)
	ttk::label $w.title -text "Add custom size. ratio : wxh" -font "-size 12" 
	ttk::button $w.add -text "+" -padding {2 0} -style small.TButton -command [list sizeTreeAddWxH $w.xmu $w.wid $w.hei]
	
	pack $w.title -before $w.rat -side top -fill x
	pack $w.add -after $w.empty -side left
	
	addFrameTop $preset_browse $::widget_name(tab_resize_size)
	pack [sizeTreeOps $st.rgt.size_ops ] -fill x
	pack [sizeTreeList $st.rgt.size_tree] -expand 1 -fill both

	return $st
}

# --== Collage options
proc colBorderPreview { pixel } {
	if { $pixel eq {} } {
		set pixel 0
	}
	lassign [$::widget_name(col_canvas) coords $::canvas_Collage(img_color)] ox oy fx fy
	$::widget_name(col_canvas) coords $::canvas_Collage(border_color) [expr {$ox-$pixel}] [expr { $oy-$pixel }] [expr { $fx+$pixel }] [expr { $fy+$pixel }]
}
proc colPaddingPreview { } {
	lassign {2 2 79 55} ox oy fx fy
	foreach var {padding border} {
		set value [$::widget_name(tab_collage_${var}) get]
		set $var [expr { $value eq {} ? 0 : $value }]
	}

	$::widget_name(col_canvas) coords $::canvas_Collage(img_color) [expr {$ox+$padding+$border}] [expr { $oy+$padding+$border }] [expr { $fx-$padding-$border }] [expr { $fy-$padding-$border }]
	colBorderPreview $border
}
proc setColageStyle { style {erase true}} {
	# if {!$::collage_sel} {
	# 	$::widget_name(col_select) invoke
	# }
	dict for {prop value} $style {
		set type [split $prop {_}]
		if { [lindex $type end] eq "color"} {
			$::widget_name(col_canvas) itemconfigure $::canvas_Collage($prop) -fill $value
		} else {
			# if {$erase} {
			# 	setColageStyle [list $prop ""] false
			# }
			switch -- $prop {
				"label" {
					$::widget_name(tab_collage_${prop}) delete 0 end
					$::widget_name(tab_collage_${prop}) insert 0 $value
				}
				"default" {
					$::widget_name(tab_collage_${prop}) set $value
				}
			}
		}
	}
	colPaddingPreview
	return
}

# constructs the border and spacing GUI
proc colSpacing { w } {
	ttk::frame $w
	set width 4

	ttk::label $w.label_border -text "Border"
	set ::widget_name(tab_collage_border) [ttk::spinbox $w.value_border -from 0 -to 10 -width $width \
		-validate key -validatecommand { string is integer %P }]
	$::widget_name(tab_collage_border) set 1
	bind $::widget_name(tab_collage_border) <ButtonRelease> { colPaddingPreview }
	bind $::widget_name(tab_collage_border) <KeyRelease> { colPaddingPreview }

	ttk::label $w.label_pad -text "Padding"
	set ::widget_name(tab_collage_padding) [ttk::spinbox $w.value_pad -from 0 -to 20 -width $width \
		-validate key -validatecommand { string is integer %P }]
	$::widget_name(tab_collage_padding) set 6
	bind $::widget_name(tab_collage_padding) <ButtonRelease> { colPaddingPreview }
	bind $::widget_name(tab_collage_padding) <KeyRelease> { colPaddingPreview }

	grid $w.label_border $w.label_pad -sticky w
	grid $w.value_border $w.value_pad -sticky w
	grid columnconfigure $w {0} -pad 6

	return $w
}
proc colGetRange {} {
	lassign [list [$::widget_name(tab_collage_col) get] [$::widget_name(tab_collage_row) get]] col row
	# If value empty, we convert to 0.
	foreach el {col row} {
		set val [set $el]
		set $el [expr { $val eq {} ? 0 : $val }]
	}
	set range [expr {($col * $row)}]
	return $range
}
proc colSetRange {} {
	set range [colGetRange]
	if { ($range != 0 ) } {
		$::widget_name(tab_collage_range) set [format %.f $range]
	}
	return
}

proc colLayout { w } {
	ttk::frame $w ; #-padding {0 4 0 0}
	set width 4

	# ttk::label $w.title -text "Layout:"

	ttk::label $w.label_col -text "Columns:"
	set ::widget_name(tab_collage_col) [ttk::spinbox $w.col -width $width -to 20 -command colSetRange \
		-validate key -validatecommand { string is integer %P }]
	ttk::label $w.label_row -text "Rows:" -padding {6 0 0}
	set ::widget_name(tab_collage_row) [ttk::spinbox $w.row -width $width -to 20 -command colSetRange \
		-validate key -validatecommand { string is integer %P }]
	ttk::label $w.label_ran -text "Range:"
	set ::widget_name(tab_collage_range) [ttk::spinbox $w.ran -width $width -from 1 -to 56 \
		-validate key -validatecommand { string is integer %P }]

	grid $w.label_col $w.label_row $w.label_ran -sticky w
	grid $w.col $w.row $w.ran -sticky w
	grid columnconfigure $w {0 1} -pad 6

	return $w

}

proc colFilterLabel { id } {
	#global inputfiles
	set input [$::widget_name(tab_collage_label) get]
	set text [split $input]
	set ftext {}

	foreach word $text {
		switch -glob -- $word {
			"*%%*" { }
			"*%f*" { set word [string map -nocase "%f [list [dict get $::inputfiles $id name] ]" $word ] }
			"*%e*" { set word [string map -nocase "%e [list [dict get $::inputfiles $id ext] ]" $word ] }
			"*%G*" { set word [string map -nocase "%G [list [dict get $::inputfiles $id size] ]" $word ] }
		}
		lappend ftext $word
	}
	set string [join $ftext]
	return $string
}

proc colLabel { w } {
	ttk::frame $w -padding {0 12 0 0}

	ttk::label $w.label_title -text "Label:"
	set ::widget_name(tab_collage_label) [ ttk::entry $w.label_text \
		-validate key -validatecommand { string is print %P } ]
	ttk::label $w.subst -text "%f => file.ext, %e => ext, %G => WxH"

	ttk::checkbutton $w.col_mode -text "Concatenate" -variable ::concatenate
	ttk::label $w.col_label_mode -text "(Images ignore tile size)"

	set col_ops [ttk::frame $w.options -padding {12 0 0 0} ]
	ttk::label $col_ops.prev -width 9 -text "" -anchor e
	ttk::button $col_ops.show_prev -text "Estimate size" -style small.TButton -command [list colEstimateSize $col_ops.prev]
	ttk::label $col_ops.label_mode -text "Mode:" -anchor e
	set ::widget_name(tab_collage_mode) [ttk::combobox $col_ops.mode -width 12 -state readonly -values {{} Concatenation {Zero geometry}} ]

	grid $col_ops.prev $col_ops.show_prev -sticky e
	grid $col_ops.label_mode $col_ops.mode -sticky e
	grid configure $col_ops.prev $col_ops.label_mode -padx {0 6}
	grid columnconfigure $col_ops {0} -weight 1
	grid rowconfigure $col_ops "all" -pad 4

	# grid $w.col_mode $w.col_label_mode -sticky we
	grid $w.label_title $w.label_text $col_ops -sticky we
	grid $w.subst - -sticky we
	grid configure $col_ops -columnspan 1
	grid columnconfigure $w {1} -weight 1
	grid columnconfigure $w {2} -weight 2
	grid rowconfigure $w {0 1} -pad 6


	return $w
}

proc colStyle { w } {
	ttk::frame $w -padding {4 0}

	ttk::label $w.label_head -text "Style:" -width 12 -anchor w -padding {0 0 0 6}

	set ::widget_name(col_canvas) [canvas $w.preview -width 80 -height 78]
	set ::canvas_Collage(bg_color) [$w.preview create rectangle 1 1 79 77 -fill "grey10" -width 1 -outline "grey20" -tags {bg click}]
	set ::canvas_Collage(border_color) [$w.preview create rectangle 5 5 75 51 -fill "grey27" -width 0 -tags {border click}]
	set ::canvas_Collage(img_color) [$w.preview create rectangle 5 5 75 51 -fill "grey5" -width 0 -tags {img}]
	set ::canvas_Collage(label_color) [$w.preview create text 40 56 -text "label" -font "-size 14 -weight bold" -anchor n -fill "grey80" -tags {label click}]
	$w.preview bind click <Button-1> { setColor %W [%W find closest %x %y] [%W itemconfigure [%W find closest %x %y] -fill] }
	$w.preview bind img <Button-1> { setColor %W 2 [%W itemconfigure 2 -fill] }

	ttk::label $w.label_styles
	set ::collage_styles(neutral) "bg_color grey50 border_color grey40 label_color grey30 img_color grey50"
	set ::collage_styles(bright) "bg_color grey88 border_color grey66 label_color grey30 img_color grey99"
	set ::collage_styles(dark) "bg_color grey10 border_color grey20 label_color grey50 img_color grey5"
	set ::collage_styles(darker) "bg_color grey5 border_color grey10 label_color grey45 img_color black"

	set swatches [lsort [getArrayNamesIfValue ::collage_styles]]

	ttk::combobox $w.styles -width 0 -state readonly -values $swatches
	bind $w.styles <<ComboboxSelected>> { setColageStyle $::collage_styles([%W get])}

	pack $w.label_head [colSpacing $w.space] -side top -expand 1 -fill x -ipady 2
	pack $w.preview -after $w.label_head -side top
	place $w.styles -in $w.label_head -relwidth .6 -x 40 ; #-expand 1 -fill x -ipady 2
	
	# Update style preview with border padding values.
	after idle colPaddingPreview
	#$w.preview coords $::canvas_Collage(border) 15 15 65 51

	return $w
}
proc colSelect {} {
	switch -- $::collage_sel {
		0 {set ops {off ? "Convert" {prepConvert} } }
		1 {set ops {on ! "Make Collage" {prepConvert "Collage"} } }
	}
	lassign $ops state mode convert_string convert_cmd
	set image [append ::img_$state]
	$::widget_name(col_select) configure -image $image -text "Make Collage$mode"
	$::option_tab tab $::cl -image $image
	set ::artscript(bconvert_string) $convert_string
	set ::artscript(bconvert_cmd) $convert_cmd
	$::widget_name(convert-but) configure -text $convert_string -command $convert_cmd
}

proc colLayoutsSelect { w } {
	ttk::frame $w -padding {0 0 0 6}
	set ::collage_sel 0
	set ::widget_name(col_select) [ttk::checkbutton $w.sel_collage -text "Make Collage?" -variable ::collage_sel -command colSelect \
		-style no_indicator.TCheckbutton -image $::img_off -compound left]

	ttk::label $w.label_layouts -text "Layouts:"

	set {::collage_layouts(Photo sheet)} "ratio 3:2 wid 275 hei 183 col 6 row 5 range 30 border 1 padding 4 label {%f: (%G)}"
	set {::collage_layouts(Storyboard)} "ratio 16:9 wid 500 hei 281 col 3 row 3 range 9 border 1 padding 8 label {%f}"
	set {::collage_layouts(Image Strip v)} "ratio 4:3 wid 300 hei 225 col 1 row 8 range {} border 0 padding 2 label {}"
	set {::collage_layouts(Image Strip h)} "ratio 4:3 wid 300 hei 225 col 8 row 1 range {} border 0 padding 2 label {}"
	set {::collage_layouts(Square 3x3)} "ratio 1:1 wid 350 hei 350 col 3 row 3 range {} border 0 padding 2 label {}"
	
	set swatches [lsort [getArrayNamesIfValue ::collage_layouts]]
	ttk::combobox $w.layouts -width 16 -state readonly -values $swatches
	bind $w.layouts <<ComboboxSelected>> { setColageStyle $::collage_layouts([%W get])}

	ttk::label $w.separator

	pack $::widget_name(col_select) $w.separator $w.label_layouts $w.layouts -side left -fill x
	pack configure $w.separator -expand 1
	# place  -in $w.label_layouts -relwidth .3 -x 60

	return $w
}
proc tabCollage { w } {
	ttk::frame $w -padding 6
	# main divisions
	ttk::frame $w.lef
	ttk::frame $w.rgt

	pack $w.lef -side left -expand 1 -fill both -padx {6 12}
	pack $w.rgt -expand 1 -fill both

	set col_title [colLayoutsSelect $w.lef.title]
	
	ttk::frame $w.lef.tilesize
	ttk::label $w.lef.tilesize.separate

	set ::widget_name(tab_collage_size) [addSizeBox $w.lef.tilesize.size "collage"]
	pack $::widget_name(tab_collage_size) $w.lef.tilesize.separate [colLayout $w.lef.tilesize.layout] -side left
	pack configure $w.lef.tilesize.separate -expand 1

	set size_frame $::widget_name(tab_collage_size)
	ttk::label $size_frame.title -text "Tile size. ratio : w x h" 
	pack $size_frame.title -before $size_frame.rat -side top -fill x

	addFrameTop $col_title $w.lef.tilesize [colLabel $w.lef.label]

	# bind $w.lef.title.layouts <Tab> [list focus $::widget_name(tab_collage_size).rat ]

	pack [colStyle $w.rgt.col_style ] -fill x
	# pack [sizeTreeList $w.rgt.size_tree] -expand 1 -fill both
	# pack [ttk::button $w.ac -text "run" -command getSizesSel ] -side bottom

	return $w
}
# Estimate ouptput size. TODO make the code less repetitive with prepCollage 
proc colEstimateSize { w } {
	foreach {value} {border padding col row } {
		set $value [$::widget_name(tab_collage_${value}) get]
	}
	# Calculate space needed for padding and border
	set pixel_space [expr {($border + $padding)*2} ]

	foreach var {width height} value [colGetTileSize] {
		set $var [expr {$value - $pixel_space}]
	}
	if { [catch {set fsize "[expr {$col * ($width + $pixel_space)}]x[expr {$row * ($height + $pixel_space)}]"}] } {
		$w configure -text "Need more data"
	} else {
		$w configure -text $fsize
	}
}

proc colGetTileSize {} {
	set width [$::widget_name(tab_collage_wid) get]
	set height [$::widget_name(tab_collage_hei) get]

	if {($width eq {}) && ($height eq {}) } {
		return [list 1500 1500]
	} elseif {$width eq {}} {
		set width 1500
	} elseif {$height eq {}} {
		set height 1500
	}
	return [list $width $height]
}

# Cut the a list in N sizes
# ilist list, range integer
proc colRange { ilist range } {
	set listsize [llength $ilist]
	set times [expr {($listsize/$range)+(bool($listsize % $range))} ]

	for {set i 0} { $i < $times } { incr i } {
		set val1 [expr {$range * $i}]
		set val2 [expr {$range + $val1 - 1} ]
		lappend rangelists [lrange $ilist $val1 $val2]
	}
	return $rangelists
}

proc prepCollage { input_files } {

	set ::artscript_convert(collage_vars) [dict create]

	# get Border padding range col row
	foreach {value} {border padding col row range mode} {
		set $value [$::widget_name(tab_collage_${value}) get]
	}

	# Calculate space needed for padding and border
	set pixel_space [expr {($border + $padding)*2} ]

	#Add Conditional settings
	lassign [list {} 0 {}] concatenate zero_geometry trim
	if {$mode eq "Concatenation"} {
		set concatenate {-mode Concatenate}
	} elseif {$mode eq "Zero geometry"} {
		set zero_geometry 1
	}

	# Set width height minus spacing from border padding.
	foreach var {width height} value [colGetTileSize] {
		set $var [expr {$value - $pixel_space}]
	}
	if {($zero_geometry == 0) && ($concatenate eq {})} {
		set width [expr {$width == (1500 - $pixel_space) ? $height : $width}]
		set height [expr {$height == (1500 - $pixel_space) ? $width : $height}]
	} else {
		set trim {-trim}
	}

	# Calculate range validity (less than col * row)
	set auto_range [colGetRange]

	if { $auto_range != 0 && $range ne {} } {
		set range [expr {min($range,$auto_range)}]
	}
	if { $range eq {} || $range == 0 } {
		set range_lists [list $input_files]
		set range 1
	} else {
		set range_lists [colRange $input_files $range]
	}

	pBarUpdate $::widget_name(pbar-main) cur max [expr { ceil([llength $input_files] / [format %.2f $range]) * 2 + $::artscript_convert(total_renders) * [llength [getFinalSizelist]] }] current [expr {$::cur -2}]
	

	# Place color values
	foreach {color} {bg_color border_color img_color label_color} {
		dict set ::artscript_convert(collage_vars) $color [$::widget_name(col_canvas) itemcget $::canvas_Collage($color) -fill]
	}
	# Add row col size label range border padding to dict
	foreach {value} {width height col row range border padding pixel_space concatenate zero_geometry trim} {
		dict set ::artscript_convert(collage_vars) $value [set $value]
	}
	puts $::artscript_convert(collage_vars)
	return $range_lists
}
proc doCollage { files {step 1} args } {
	# global inputfiles
	switch $step {
	0 {
		if {$::artscript_convert(extract)} {
			# wait until extraction ends to begin converting
			vwait ::artscript_convert(extract)
		}
		puts "Powering up Collage Assembly line"
		set ::artscript_convert(count) 0
		set range_files [prepCollage $files]
		after idle [list after 0 [list doCollage $range_files]]

	} 1 {

		set range_pack [lindex $files $::artscript_convert(count)]
		incr ::artscript_convert(count)

		pBarControl [format {%s %d/%d} "Assembling..." ${::artscript_convert(count)} [llength $files]] update

		# Stop process if no more collages in cue
		if { ($range_pack eq {}) } {
			# set ::artscript_convert(extract) false
			puts "All collages assembled"
			doConvert $::artscript_convert(collage_ids) 0
			return
		}
		dict with ::artscript_convert(collage_vars) {

			foreach id $range_pack {
				set opath [dict get $::inputfiles $id path]
				catch {set opath [dict get $::inputfiles $id tmp]}

				#get label
				set clabel [colFilterLabel $id]

				lassign [scan [dict get $::inputfiles $id size] "%dx%d"] wid hei
				set rsize [getOutputSize $wid $hei $width $height]
				if {$clabel ne {}} {
					lappend collage_names -label $clabel
				}
				lappend collage_names [format {%s[%s]} $opath $rsize]
			}

			foreach {var} {col row} {
				set value [set $var]
				set x$var [expr {($value eq {} || $value == 0) ? 1 : $value}]
			}
			# finalsize convert 50% > wid = row x destw
			set fsize "[expr {$xcol * ($width + $pixel_space)}]x[expr {$xrow * ($height + $pixel_space)}]"

			#Add filename to dict
			set output_path [format {%s_%d.%s} "/tmp/collage-${::day}" $::artscript_convert(count) "png"]
			set geometry [expr { $zero_geometry ? "1x1+${padding}+${padding}\\<" : "${width}x${height}+${padding}+${padding}" }]
			# puts $geometry

			set Cmd [concat montage -quiet $collage_names \
				-geometry [list $geometry] $concatenate -tile ${col}x${row} \
				-border $border -background $bg_color -bordercolor $border_color -fill $label_color \
				$trim "png:$output_path" ]
			# puts $Cmd
		}
		runCommand $Cmd [list relaunchCollage $output_path $opath $fsize $files]
	}}
}
proc relaunchCollage { file_generated destination size files } {
	# global fc deleteFileList
	if {[file exists $file_generated]} {
		set output_dir [file dirname $destination]
		set name [file join $output_dir [file tail $file_generated]]

		lappend ::artscript_convert(collage_ids) $::fc
		setDictEntries $::fc $name $size {.png} {m} 0
		dict set ::inputfiles $::fc tmp $file_generated
		lappend ::deleteFileList $file_generated
		incr ::fc
	}
	after idle [list after 0 [list doCollage $files]]
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
	ttk::labelframe $w -text "Output & Quality" -padding {6 6 12}

	set formats [list png jpg gif webp {webp lossy} ora] ; # TODO ora and keep
	ttk::label $w.label_format -text "Format:"
	ttk::combobox $w.format -state readonly -width 9 -textvariable ::outext -values $formats
	$w.format set [lindex $formats 0]
	bind $w.format <<ComboboxSelected>> [list setFormatOptions $w ]

	ttk::label $w.label_quality -text "Quality:"
	ttk::scale $w.slider_qual -from 10 -to 100 -variable ::iquality -value $::iquality -orient horizontal -command { progressBarSet ::iquality 0 0 0 "%.0f" }
	ttk::label $w.slider_qual_val -width 4 -textvariable ::iquality

	ttk::checkbutton $w.overwrite -text "Allow Overwrite" -onvalue 1 -offvalue 0 -variable ::overwrite -command { treeAlterVal {getOutputName $value $::outext $::ouprefix $::ousuffix} $::widget_name(flist) path output }
	ttk::checkbutton $w.alfa_off -text "Remove Alfa" -onvalue "-background %s -alpha remove" -offvalue "" -variable ::alfaoff
	canvas $w.alpha_color -width 16 -height 16
	set ::artscript(alfa_color) [$w.alpha_color create rectangle 1 1 15 15 -fill $::artscript(alfa_color) -width 1 -outline "grey20" -tags {alfa}]
	$w.alpha_color bind alfa <Button-1> { set ::artscript(alfa_color) [setColor %W $::artscript(alfa_color) [%W itemconfigure $::artscript(alfa_color) -fill]] }
	
	ttk::separator $w.sep -orient vertical

	grid $w.label_quality $w.slider_qual_val $w.slider_qual - -row 1 -sticky we
	#grid configure $w.label_quality -column 1
	#grid configure $w.slider_qual -column 2 -columnspan 2 -sticky we
	grid configure $w.slider_qual_val -column 4 -sticky w
	grid x x $w.label_format $w.format x -row 2 -sticky we
	# grid configure $w.label_format -column 2
	# grid configure $w.format -column 3
	grid $w.overwrite - - $w.alfa_off - - -row 3 -sticky we
	# grid configure $w.format $w.slider_qual_val -sticky we
	grid configure $w.label_quality $w.label_format -sticky e
	place $w.alpha_color -in $w.alfa_off -relx .92 -y 1 -anchor ne

	grid columnconfigure $w {1} -weight 12 -pad 4 
	grid columnconfigure $w {0} -weight 2 -pad 4
	grid rowconfigure $w "all" -pad {6}
	grid configure $w.overwrite $w.alfa_off -pady {12 1}
	return $w
}

# Alters ouput widgets to show format output options
# w = widget name
proc setFormatOptions { w } {
	# update listname
	treeAlterVal {getOutputName $value $::outext $::ouprefix $::ousuffix} $::widget_name(flist) path output
	$::widget_name(convert-but) configure -text $::artscript(bconvert_string) -command $::artscript(bconvert_cmd)
	$::widget_name(thumb-prev) state !disabled
	switch -glob -- $::outext {
		jpg	{
			set ::iquality 92 
			$w.label_quality configure -text "Quality:"
			$w.slider_qual configure -from 10 -to 100
		}
		png	{
			set ::iquality 9
			$w.label_quality configure -text "Compress:"
			$w.slider_qual configure -from 0 -to 9
		}
		gif	{
			set ::iquality 256
			$w.label_quality configure -text "Colors:"
			$w.slider_qual configure -from 1 -to 256
		}
		ora	{
			set ::iquality 0
			$w.label_quality configure -text "Quality:"
			$w.slider_qual configure -from 0 -to 0
			$::widget_name(convert-but) configure -text "Make ORA" -command {prepOra}
			$::widget_name(thumb-prev) state disabled
		}
		webp { 
			set ::iquality 100 
			$w.label_quality configure -text "Quality:"
			$w.slider_qual configure -from 10 -to 100
		}
		webp* { 
			set ::iquality 60
			$w.label_quality configure -text "Quality:"
			$w.slider_qual configure -from 10 -to 100
		}
	}
}

# ----==== Status bar
proc guiStatusBar { w } {
	# set default button Convert string
	set ::artscript(bconvert_string) "Convert"
	set ::artscript(bconvert_cmd) {prepConvert}
	pack [ttk::frame $w] -side top -expand 0 -fill x
	
	ttk::frame $w.rev
	ttk::frame $w.do
	
	set ::widget_name(check-wm) [ttk::checkbutton $w.rev.checkwm -text "Watermark" -onvalue 1 -offvalue 0 -variable ::watsel -command { turnOffChildCB watsel "$wt.cbim" watselimg "$wt.cbtx" watseltxt }]
	set ::widget_name(check-sz) [ttk::checkbutton $w.rev.checksz -text "Resize" -onvalue 1 -offvalue 0 -variable ::sizesel]

	set ::widget_name(pbar-main) [ttk::progressbar $w.do.pbar -maximum [getFilesTotal] -variable ::cur -length "260"]
	set ::widget_name(pbar-label) [ttk::label $w.do.plabel -textvariable pbtext -anchor e]
	set ::widget_name(convert-but) [ttk::button $w.do.bconvert -text $::artscript(bconvert_string) -command {prepConvert}]
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

#Resize: returns 0 if no size selected: #TODO remove the need of this func
proc getFinalSizelist {} {
	set sizeslist [getSizesSel]
	if {[llength $sizeslist] == 0 } {
		return 0
	}
	return $sizeslist
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
	#Do not return repeated sizes
	set fsizes [lsort -unique $fsizes]
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
	set resize [concat $resize -resize ${finalscale}${operator} +repage "-colorspace sRGB" $unsharp]
	
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
# Adds command to fileevent handler
# cmd exec command, script last cmd executed
proc runCommand {cmd script {var ""}} {
    # output command $cmd
    set f [open "| $cmd 2>@1" r]
    fconfigure $f -blocking false
    fileevent $f readable  [list handleFileEvent $f $script $var]

    return $f
}

# Closes f event if error or end of executing
# Add scritp to event cue when finishing
# That allows for control in comand order 
proc closePipe {f script} {
    # turn blocking on so we can catch any errors
    fconfigure $f -blocking true
    if {[catch {close $f} err]} {
        #output error $err
        puts "some error: $err"
    }
    after idle [list after 0 $script]
}
# Do something depending on what the fileevent returns
# f fileevent, script, pass to closePipe
proc handleFileEvent {f script {var ""}} {
    set status [catch { gets $f line } result]
    if { $status != 0 } {
        # unexpected error
        # puts "error $result"
        closePipe $f $script

    } elseif { $result >= 0 } {
    	catch {set $var $line}
        # we got some output
		puts "$line"

    } elseif { [eof $f] } {
        # End of file
        closePipe $f $script

    } elseif { [fblocked $f] } {
        # Read blocked, so do nothing
    }
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
proc prepHandlerFiles { {files ""} } {
	set ids {}
	if { $files ne ""} {
		array set handler $::handlers
		foreach item $files {
			if {$handler($item) ne {m} } {
				lappend ids $item
			}
		}
	} else {
		set ids [putsHandlers g i k]
	}
	set id_length [llength $ids]
	pBarUpdate $::widget_name(pbar-main) cur max $id_length current -1
	
	processHandlerFiles 0 $ids 0
	return $id_length
}

# Calligra, gimp and inkscape converter
# Creates a png file in tmp and adds file path to dict id
# index = current process position, ilist = list to walk, outfdir = output directory
# returns nothing
proc processHandlerFiles { index ilist {step 1}} {
	global inputfiles handlers deleteFileList

	set imgv [lindex $ilist $index]
	array set handler $handlers
	
	switch $step {
	0 {
		puts "Starting File extractions..."
		after idle [list after 0 [list processHandlerFiles $index $ilist]]
	} 1 {
		
		incr index
		
		# Stop process if no more files to convert
		if { ($imgv eq {}) || ($handler($imgv) eq {m})} {
			set ::artscript_convert(extract) false
			puts "File extractions finished"
			return
		}
		set msg {}
		
		array set id [dict get $inputfiles $imgv]
		
		set outdir "/tmp"
		set outname [file join ${outdir} [file root $id(name)]]
		append outname ".png"
		
		set ::artscript_convert(outname) $outname
		set ::artscript_convert(imgv) $imgv
		
		puts "Extract $id(name)"
		pBarControl "Extracting... $id(name)" update
		
		if { ![file exists $outname ] } {
			if { $handler($imgv) == {g} } {
				puts "Rendering Gimps"
				set i $id(path)
				set cmd "(let* ( (image (car (gimp-file-load 1 \"$i\" \"$i\"))) (drawable (car (gimp-image-merge-visible-layers image CLIP-TO-IMAGE))) ) (gimp-file-save 1 image drawable \"$outname\" \"$outname\") )(gimp-quit 0)"
				#run gimp command, it depends on file extension to do transforms.
				# catch { exec gimp -i -b $cmd } msg
				set extractCmd [list gimp -i -b $cmd]
			}
			if { $handler($imgv) == {i} } {
				puts "Rendering Ink Scapes"
				# output 100%, resize imagick
				# catch { exec inkscape $id(path) -z -C -d 90 -e $outname } msg
				set extractCmd [list inkscape $id(path) -z -C -d 90 -e $outname]
			}
			if { $handler($imgv) == {k} } {
				puts "Rendering Kriters: Calligraconvert always return errors!"
				# catch { exec calligraconverter --batch -- $id(path) $outname } msg
				set extractCmd [list calligraconverter --batch -- $id(path) $outname]
			}
			runCommand $extractCmd [list relauchHandler $index $ilist]
		} else {
			relauchHandler $index $ilist
		}
	} }
	return
}

# After running processHandlerFiles check if file created
# append to global dir if success call for next process.
proc relauchHandler {index ilist} {
	
	set outname $::artscript_convert(outname)
	set imgv $::artscript_convert(imgv)

	#Error reporting, if code NONE then png conversion success.
	if { ![file exists $outname ]} {
		set errc $::errorCode;
		set erri $::errorInfo
		puts "error: $errc \n\n"
		if {$errc != "NONE"} {
			# puts $msg
		}
		error "something went wrong, tmp png wasn't created"
	} else {
		puts "file $outname found!"
		dict set ::inputfiles $imgv tmp $outname
		lappend ::deleteFileList $outname
	}
	# array unset handler
	after idle [list after 0 [list processHandlerFiles $index $ilist]]
	return
}

# Get ids of files to process
# id = file to process
# return list
proc processIds { {ids ""} } {
	if { $ids ne "" } {
		return $ids
	} else {
		lappend images {*}[dict filter $::inputfiles script {k v} {expr {[dict get $v deleted] eq 0}}]
		return [dict keys $images]
	}
}

# Convert: Construct and run convert tailored to each file
# id = files to process, none given: process all
# return nothing
proc doConvert { files {step 1} {preview 0} } {
	
	switch $step {
	0 {
		puts "Starting Convert..."
		set ::artscript_convert(count) 0
		after idle [list after 0 [list doConvert $files 1 $preview]]
	} 1 {
		if {$::artscript_convert(extract)} {
			# wait until extraction ends to begin converting
			vwait ::artscript_convert(extract)
		}
		set idnumber [lindex $files $::artscript_convert(count)]
		incr ::artscript_convert(count)
		
		if { $idnumber eq {} } {
			pBarControl "Operations Done..." forget 600
			puts "Convert done."
			# erase all collage from lists
			if {[llength $::artscript_convert(collage_ids)] > 0} {
				foreach i $::artscript_convert(collage_ids) {
					dict unset ::inputfiles $i
				}
				set ::artscript_convert(collage_ids) {}
			}	
			return
		}
		
		set datas [dict get $::inputfiles $idnumber]
		dict with datas {
			if {!$deleted} {
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
				
				foreach dimension $sizes {
					incr i
					set resize {}
					if { $size != $osize } {
						set resize [getResize $size $dimension $filter $unsharp]
					}
					puts "converting... $name"
					pBarControl "Converting... ${name} to $dimension" update
					
					if {$i == 1} {
						set dimension {}
					}
					
					if {!$preview} {
						set soname \"[file join $outpath [getOutputName $opath $::outext $::ouprefix $::ousuffix $dimension] ]\"
					} else {
						puts "Generating preview"
						set soname "show:"
					}
					set convertCmd [concat convert -quiet \"$opath\" $resize $::artscript_convert(wmark) [format $::alfaoff $::artscript(alfa_color)] $::artscript_convert(quality) $soname]
					#catch { exec {*}$convertCmd }
					runCommand $convertCmd [list doConvert $files]
				}
			}
		}
	}}
	return 0
}

# Set convert global and values total files to process
# id = files to convert, if none given, all will be processed
proc prepConvert { {type "Convert"} {ids ""} {preview 0} } {

	pBarControl {} create 0 1

	set ::artscript_convert(files) [processIds $ids]
	set ::artscript_convert(collage_ids) [list]
	if {[llength $::artscript_convert(files)] == 0} {
		pBarControl "No files loaded!" forget 600
		return -code break
	}
	#get watermark value
	set ::artscript_convert(wmark) [watermark]
	set ::artscript_convert(quality) [getQuality $::outext]

	set ::artscript_convert(extract) true ; #controls all extracts are done before convert
	
	#process Gimp Calligra and inkscape to Tmp files
	set ::artscript_convert(files) [processIds $ids]
	set ::artscript_convert(total_renders) [prepHandlerFiles $::artscript_convert(files)]

	if {$type eq "Collage"} {
		# set total_renders [expr ($total_renders/]
	}

	#Create progressbar
	
	pBarUpdate $::widget_name(pbar-main) cur max [expr {([llength $::artscript_convert(files)] + $::artscript_convert(total_renders)) * [llength [getFinalSizelist]]}] current -1
	
	do$type $::artscript_convert(files) 0 $preview
}

# ---=== Window options
wm title . "Artscript $::version -- [getFilesTotal] Files selected"
# Set close actions
bind . <Destroy> [list catch {file delete {*}$::deleteFileList } ]

# We test if icon exist before addin it to the wm
set wmiconpath [file join [file dirname [info script]] "atk-logo.gif"]
if {![catch {set wmicon [image create photo -file $wmiconpath  ]} msg ]} {
	wm iconphoto . -default $wmicon
}

# ---=== Construct GUI
artscriptStyles
createImageVars
# Pack Top: menubar. Middle: File, thumbnail, options, suffix output.
# Bottom: status bar
guiTopBar .f1
guiMiddle .f2
guiStatusBar .f3

# ---=== Validate input filetypes
set argvnops [lrange $argv [llength $::ops] end]
listValidate $argvnops
