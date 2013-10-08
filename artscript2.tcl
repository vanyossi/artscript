#!/usr/bin/wish
#
#----------------:::: ArtscriptTk ::::----------------------
# Version: 2.0-alpha
# Author:IvanYossi / http://colorathis.wordpress.com ghevan@gmail.com
# Script inspired by David Revoy artscript / www.davidrevoy.com info@davidrevoy.com
# License: GPLv3 
#-----------------------------------------------------------
# Goal : Batch convert any image file supported by imagemagick, calligra & Inkscape.
# Dependencies: >=imagemagick-6.7.5, tk 8.5 zip
# Optional deps: calligraconverter, inkscape, gimp
#
# __Customize:__
#   You can modify any variable between "#--=====" markers
#   Or (recomended) make a config file (rename presets.config.presets to presets.config)
#   File must be in the same directory as the script.
#
package require Tk
ttk::style theme use clam
namespace eval ::img { }

#--====User variables
#Extension, define what file tipes artscript should read.
set ::ext ".ai .bmp .dng .exr .gif .jpeg .jpg .kra .miff .ora .png .psd .svg .tga .tiff .xcf .xpm"
#set date values
#Get a different number each run
set ::raninter [clock seconds]
set ::now [split [clock format $raninter -format %Y/%m/%d/%u] "/"]
set ::year [lindex $now 0]
set ::month [lindex $now 1]
set ::day [lindex $now 2]
set ::date [join [list $year $month $day] "-"]
#set autor name
set ::autor "Autor"
#Initialize variables for presets

#Watermark options
set ::wmtxt {}
set ::watermarks [list \
	"Copyright (c) $autor" \
	"Copyright (c) $autor / $date" \
	"http://www.yourwebsite.com" \
	"Artwork: $autor" \
	"$date" \
]
set ::wmsize 10
set ::wmcol "#000000"
set ::wmcolswatch {} ; # [list "red" "#f00" "blue" "#00f" "green" "#0f0" "black" "#000" "white" "#fff" ]
set ::wmop 80
set ::wmpos "BottomRight"
set ::wmpositions [list "TopLeft" "Top" "TopRight" "Left" "Center" "Right" "BottomLeft" "Bottom" "BottomRight"]
#Place image watermark URL. /home/user/image
set ::wmimsrc ""
# Set name path of your watermark images. Path must be absolute
set ::iwatermarks [dict create \
	"Logo" "/Path/to/logo" \
	"Client Watermark" "/path/to/watermarkimg" \
]
set ::wmimpos "Center"
set ::wmimsize "0"
set ::wmimcomp "Over"
set ::wmimop 100

#Sizes
set ::sizes [list \
	"1920x1920" \
	"1650x1650" \
	"1280x1280" \
	"1024x1024" \
	"720x720" \
	"50%" \
]
#Suffix and prefix ops
set ::ouprefix {}
set ::ousuffix {}
#General checkboxes
set ::watsel 0
set ::watseltxt 0
set ::watselimg 0
set ::sizesel 0
set ::prefixsel 0
set ::overwrite 0
#Extension & output
set ::outext "png"
set ::iquality 92
#--=====
#Don't modify below this line

set ::version "v2.0-alpha"
set ::lstmsg ""
# TODO remove this list of global tcl vars. set all user vars in a pair list value, or array.
set ::gvars {tcl_rcFileName|tcl_version|argv0|argv|tcl_interactive|tk_library|tk_version|auto_path|errorCode|tk_strictMotif|errorInfo|auto_index|env|tcl_pkgPath|tcl_patchLevel|argc|tk_patchLevel|tcl_library|tcl_platform}
#Function to send message boxes
proc alert {type icon title msg} {
		tk_messageBox -type $type -icon $icon -title $title \
		-message $msg
}
# TODO: look for binary paths using global $env variable
proc validate {program} {
	expr { ![catch {exec which $program}] ? [return 1] : [return 0] }
}
#Gimp path
set hasgimp [validate "gimp"]
#Inkscape path, if true converts using inkscape to /tmp/*.png
set hasinkscape [validate "inkscape"]
#calligraconvert path, if true converts using calligra to /tmp/*.png
set hascalligra [validate "calligraconverter"]

#Prepares output name adding Suffix or Prefix
#Checks if destination file exists and adds a standard suffix
proc getOutputName { iname outext { prefix "" } { suffix {} } {sizesufix {}} {orloc 0} } {
	
	if {!$::prefixsel} {
		set prefix {}
		set suffix {}
	}
	# if {$tmprun} { set suffix "" } else { set tmpsuffix $::suffix }
	
	if {$orloc != 0 } {
		set iname $orloc
	}
	set dir [file normalize [file dirname $iname]]
	set name [file rootname [file tail $iname]]
	set lname [concat $prefix [list $name] $suffix $sizesufix ] ; # Name in brackets to protect white space
	append outname [join $lname "_"] "." $outext
	
	#Add a counter if filename exists
	if {!$::overwrite} {
		set tmpname $outname
		while { [file exists [file join $dir "$outname"] ] } {
			set outname $tmpname
			incr s
			set outname [join [list [string trimright $outname ".$outext"] "_$s" ".$outext"] {} ]
		}
		unset tmpname
	}
	set olist [list]
	return [lappend olist $outname $dir]
}

# Global dictionaries, files values, files who process
set inputfiles [dict create]
set handlers [dict create]
# Checks the files listed in args to be valid files supported	
proc listValidate { ltoval {counter 1}} {
	global ext hasinkscape hascalligra hasgimp
	global identify ops
	
	proc setDictEntries { id fpath size ext h} {
		global inputfiles handlers

		set iname [file tail $fpath]
		set apath [file normalize $fpath]
		set ext [string trim $ext {.}]
		
		dict set inputfiles $id name $iname
		dict set inputfiles $id oname [lindex [getOutputName $fpath $::outext $::ouprefix $::ousuffix] 0]
		dict set inputfiles $id size $size
		dict set inputfiles $id ext $ext
		dict set inputfiles $id path $apath
		dict set inputfiles $id deleted 0
		dict set handlers $id $h
	}
	# Keep $fc adding up if proc is called a second time. TODO (perhaps make global)
	set fc $counter
	
	# TODO make functions work with a single identify format { identify -quiet -format "%wx%h:%m:%M " }
	# Last returns a list of (n) nunber of layers the image has
	set identify "identify -quiet -format %wx%h\|%m\|%M\|"
	# Variable to store option arguments:ex :p xx.preset
	set ops [dict create]
	set options true
	set lops 1
	#We validate sort arguments into options and filelists
	foreach i $ltoval {
		# TODO inset while to avoid evaluating this when options is set to false
		incr c
		if { [string index $i 0] == ":" && $options} {
			dict set ops $i [lindex $argv $c]
			set lops [expr {[llength $ops]+1}]
			continue
		} elseif { $options && $lops == $c } {
			set options false
		}
		# from here vars are not options but files
		# Call itself with directory contents if arg is dir
		if {[file isdirectory $i]} {
			listValidate [glob -nocomplain -directory $i -type f *] $fc
			continue
		}
		set filext [string tolower [file extension $i] ]
		set iname [file tail $i]

		if {[lsearch $ext $filext ] >= 0 } {
			if { [regexp {.xcf|.psd} $filext ] && $hasgimp } {

				set size [lindex [exec identify -format "%wx%h " $i ] 0]

				setDictEntries $fc $i $size $filext "g"
				incr fc
				continue

			} elseif { [regexp {.svg|.ai} $filext ] && $hasinkscape } {

				if { [catch { exec inkscape -S $i | head -n 1 } msg] } {
					append lstmsg "EE: $i discarted\n"
					puts $msg
					continue
				}
				
				# TODO get rid of head cmd
				set svgcon [exec inkscape -S $i | head -n 1]
				# Get the last elements of first line == w x h
				set svgvals [lrange [split $svgcon {,}] end-1 end]
				# Make float to int. TODO check if format "%.0f" works best here
				set size [expr {round([lindex $svgvals 0])}]
				append size "x" [expr {round([lindex $svgvals 1])}]

				setDictEntries $fc $i $size $filext "i"
				incr fc
				continue

			} elseif { [regexp {.kra|.ora|.xcf|.psd} $filext ] && $hascalligra } {
				set size "N/A"
				# TODO Simplify
				# Get contents from file and parse them into Size values.
				if { $filext == ".ora" } {
					if { [catch { set zipcon [exec unzip -p $i stack.xml | grep image | head -n 1] } msg] } {
						continue
					}
					set zipcon [exec unzip -p $i stack.xml | grep image | head -n 1]
					set zipkey [lreverse [ string trim $zipcon "image<> " ] ]
					set size [string trim [lindex [split [lindex $zipkey 0] {=}] 1] "\""]x[string trim [lindex [split [lindex $zipkey 1] "="] 1] {"\""}]
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

				setDictEntries $fc $i $size $filext "k"
				incr fc
				continue

			# Catch magick errors. Some files have the extension but are not valid types
			} else {
				if { [catch {set finfo [exec {*}[split $identify " "] $i ] } msg ] } {
					puts $msg
					append ::lstmsg "EE: $i discarted\n"
					continue
				} else {
					set size [lindex [split [string trim $finfo "|"] "|"] 0]
				}

				setDictEntries $fc $i $size $filext "m"
				incr fc
			}
		
		# When no extension we still check if file is valid image file, this can't tell
		# if image type is openraster, krita or gimp valid. Need to work with mimes.
		} elseif { [string is boolean [file extension $i]] && !$options } {
			if { [catch { set f [exec {*}[split $identify " "] $i ] } msg ] } {
				puts $msg
			} else {
				if { [catch {set finfo [exec {*}[split $identify " "] $i ] } msg ] } {
					puts $msg
					append ::lstmsg "EE: $i discarted\n"
					continue
				}

				set iminfo [split [string trim $finfo "|"] "|"]
				set size [lindex $iminfo 0]
				set filext [string tolower [lindex $iminfo 1]]

				setDictEntries $fc $i $size $filext "m"
				incr fc
			}
		}
	}
}
# Validate input filetypes
listValidate $argv

#configuration an presets
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
	#set values according to preset
	foreach i $preset {
		if {[dict exists $presets $i]} {
			dict for {key value} [dict get $presets $i] {
				if {[info exists $key] != [regexp $gvars $key ] } {
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
		}
	}
}
# Returns total of files in dict except for flagged as deleted.
# TODO all boolean is reversed.
proc getFilesTotal { { all 0} } {
	global inputfiles
	
	set count {}
	if { $all == 1 } {
		dict for {id datas} $inputfiles {
 	 		dict with datas {
				if { $deleted == 0 } {
					lappend count $id
				}
 	 		}
		}
	} else {
		set count [dict keys $inputfiles]
	}
	return [llength $count]
}

proc updateWinTitle {} {
	wm title . "Artscript $::version -- [getFilesTotal 1] Files selected"
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
puts [putsHandlers "g"]
puts [putsHandlers "i"]
puts [putsHandlers "k"]
puts [putsHandlers "m"]

#--- Window options
wm title . "Artscript $version -- [getFilesTotal] Files selected"

# We test if icon exist before addin it to the wm
set wmiconpath [file join [file dirname [info script]] "atk-logo.gif"]
if {![catch {set wmicon [image create photo -file $wmiconpath  ]} msg ]} {
	wm iconphoto . -default $wmicon
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
	
	listValidate $files [expr {[getFilesTotal]+1}] ; # Add 1 to keep global counter id in sync
	# TODO Instead of using global inputfiles we could create a trasition dict and append to it.
	addTreevalues .f2.fb.flist $inputfiles 
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

# Sets a custom value to any key of all members o the dict
# TODO complete the function. recieves widget, inputdict, key to alter, script
proc changeval {} {
	global inputfiles
	foreach arg [dict keys $inputfiles] {
		global imgid$arg
		set setval [.m2.ac.conv.size.sizes item [.m2.ac.conv.size.sizes selection] -text]
		set oname "[dict get $inputfiles $arg name]_$setval"
		dict set inputfiles $arg oname $oname
		.m1.flist set [set imgid$arg] output $oname
	}
}
# Get nested dict values and place them in the tree $w
proc addTreevalues { w fdict } {
	# .f2.fb.flist
	#puts [dict keys [set ${c}fdict]]
	#or puts [dict keys [subst $${c}fdict]]
	dict for {id datas} $fdict {
		#check to see if id exists to avoid duplication
		if { [info exists ::img::imgid$id] || [dict get $fdict $id deleted] } {
			continue
		}
 	  dict with datas {
				set values [list $id $name $ext $size $oname]
				set ::img::imgid$id [$w insert {} end -values $values]
 	  }
	}
}

# Deletes the keys from tree(w), and sets deletes value to 1
# TODO Remove all entries of file type. (filtering)
proc removeTreeItem { w i } {
	global inputfiles

	foreach item $i {
		set id [$w set $item id]
		# TODO undo last delete
		dict set inputfiles $id deleted 1
		unset ::img::imgid$id
	}
	# remove keys from tree
	$w delete $i
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
proc updateTextLabel { w gval args } {
	upvar #0 $gval tvar
	set opt [dict create {*}$args]
	
	if {[dict exists $opt suffix]} {
		set suffix [dict get $opt suffix]
	} else {
		set suffix {}
	}
	if {[dict exists $opt text]} {
		$w configure -text [concat $suffix [dict get $opt text] ]
	}
	if {[dict exists $opt textv]} {
		set tvar [concat $suffix [dict get $opt textv] ]
	}
	update
}
# Sets a custom value to any key of all members o the dict
# TODO complete the function. recieves widget, inputdict, key to alter, script
proc treeAlterVal { w column {script {puts $value}} } {
	global inputfiles
	
	foreach id [dict keys $inputfiles] {

		set value [dict get $inputfiles $id $column]
		set fpath [dict get $inputfiles $id path]
		set newvalue [uplevel 0 $script]
		
		$w set [set ::img::imgid$id] $column $newvalue
		dict set inputfiles $id $column $newvalue
	}
}

proc printOutname { w } {
	if {$::prefixsel || $w != 0} {
		bindsetAction 0 0 prefixsel .f2.ac.onam.cbpre
	}
	treeAlterVal .f2.fb.flist oname {lindex [getOutputName $fpath $::outext $::ouprefix $::ousuffix] 0}
}
# Attempts to load a thumbnail from thumbnails folder if exists.
# Creates a thumbnail for files missing Large thumbnail
proc showPreview { w f {tryprev 1}} {

	# First define subprocesses
	# TODO, set a rename proc "" to delete process and make it trully local (or lambas?)
	# makeThumb creates a thumbnail based on path (file type) makes requested sizes.
	proc makeThumb { path tsize } {
		set cmd [dict create]
		dict set cmd .ora {Thumbnails/thumbnail.png}
		dict set cmd .kra {preview.png}

		set filext [string tolower [file extension $path] ]

		if { [regexp {.ora|.kra} $filext ] } {
			set container [dict get $cmd $filext]
			#unzip to location tmp$container
			catch {exec unzip $path $container -d /tmp/}
			set tmpfile "/tmp/$container"
			set path $tmpfile

		# Remove gimp and psd thumnail if we cannot figure it out how to keep GUI responsive
		# Or: force use of tmp file from convert (faster) instead of savind a preview.
		} elseif {[regexp {.xcf|.psd} $filext ]} {
			# TODO: Break appart preview function to allow loading thumbs from tmp folder
			.f2.fb.lprev.im configure -compound text -text "No preview"
			return 0
		}
		foreach {size dest} $tsize {
			catch {exec convert $path -thumbnail [append size x $size] -flatten PNG32:$dest} msg
		}
		catch {file delete $tmpfile}
	}

	global inputfiles env

	# Do not process if selection is multiple
	if {[llength $f] > 1} {
		return -code 3
	}
	# TODO, get value with no lindex: .t set $f id
	set id [lindex [.f2.fb.flist item $f -values] 0]
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
		
		exec convert $lthumb GIF:$prevgif
		catch {set oldimg $img}
		set img [image create photo -file /tmp/atkpreview.gif ]

		.f2.fb.lprev.im configure -compound image -image $img
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
		showPreview w $f 0
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
		$w itemconfigure $::c(main) -outline [getContrastColor $col]
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
	set chal [expr {([llength $args]/2)+1}] ; # Half swatch list

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
		set ::c($i) [$w create rectangle $x $y [expr {$x+$cw}] [expr {$y+$ch-1}] -fill $swatch -width 1 -outline {gray26} -tags {swatch}]
		set col [lindex [$w itemconfigure $::c($i) -fill] end]
		$w bind $::c($i) <Button-1> [list setColor $w wmcol $::c(main) $col 0 ]
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

# ----=== Gui Construct ===----
# TODO Make every frame a procedure to ease movement of the parts
# Top menu panel
pack [ttk::frame .f1] -side top -expand 0 -fill x
ttk::label .f1.title -text "Artscript 2.0alpha"
ttk::button .f1.add -text "Add files" -command { puts [openFiles] }
pack .f1.title .f1.add -side left


# Paned views, File manager and options
ttk::panedwindow .f2 -orient vertical
ttk::frame .f2.fb
ttk::panedwindow .f2.ac -orient horizontal
.f2 add .f2.fb
.f2 add .f2.ac

# --== File manager treeview start ==
set fileheaders { id input ext size oname }
ttk::treeview .f2.fb.flist -columns $fileheaders -show headings -yscrollcommand ".f2.fb.sscrl set"
foreach col $fileheaders {
	set name [string totitle $col]
	.f2.fb.flist heading $col -text $name -command [list treeSort .f2.fb.flist $col 0 ]
}
.f2.fb.flist column id -width 48 -stretch 0
.f2.fb.flist column ext -width 48 -stretch 0
.f2.fb.flist column size -width 86 -stretch 0

#Populate tree
addTreevalues .f2.fb.flist $inputfiles

bind .f2.fb.flist <<TreeviewSelect>> { showPreview .m2.lprev.im [%W selection] }
bind .f2.fb.flist <Key-Delete> { removeTreeItem %W [%W selection] }
ttk::scrollbar .f2.fb.sscrl -orient vertical -command { .f2.fb.flist yview }

# --== Thumbnail
ttk::labelframe .f2.fb.lprev -width 276 -height 292 -padding 6 -labelanchor n -text "Thumbnail"
# -labelwidget .f2.ac.checkwm
ttk::label .f2.fb.lprev.im -anchor center -text "No preview"


pack .f2.fb.flist -side left -expand 1 -fill both
pack .f2.fb.sscrl .f2.fb.lprev -side left -expand 0 -fill both
pack propagate .f2.fb.lprev 0
pack .f2.fb.lprev.im -expand 1 -fill both

# --== Option tabs
ttk::notebook .f2.ac.n
ttk::notebook::enableTraversal .f2.ac.n
bind .f2.ac.n <ButtonPress-4> { scrollTabs %W [%W index current] 1 }
bind .f2.ac.n <ButtonPress-5> { scrollTabs %W [%W index current] 0 }

# Set a var to ease modularization. TODO: procs
set wt {.f2.ac.n.wm}
ttk::frame $wt -padding 6

ttk::label $wt.lsel -text "Selection*"
ttk::label $wt.lsize -text "Size" -width 4
ttk::label $wt.lpos -text "Position" -width 10
ttk::label $wt.lop -text "Opacity" -width 10


# Text watermark ops
ttk::checkbutton $wt.cbtx -onvalue 1 -offvalue 0 -variable watseltxt -command { turnOffParentCB .f3.rev.checkwm $wt.cbtx $wt.cbim}
ttk::label $wt.ltext -text "Text"
ttk::combobox $wt.watermarks -state readonly -textvariable wmtxt -values $watermarks -width 28
$wt.watermarks set [lindex $watermarks 0]
comboBoxEditEvents $wt.watermarks {bindsetAction 0 0 watsel ".f3.rev.checkwm $wt.cbtx"}

# font size spinbox
set fontsizes [list 8 10 11 12 13 14 16 18 20 22 24 28 32 36 40 48 56 64 72 144]
ttk::spinbox $wt.fontsize -width 4 -values $fontsizes -validate key \
	-validatecommand { string is integer %P }
$wt.fontsize set $wmsize
bind $wt.fontsize <ButtonRelease> {bindsetAction wmsize [%W get] watsel ".f3.rev.checkwm $wt.cbtx"}
bind $wt.fontsize <KeyRelease> { bindsetAction wmsize [%W get] watsel ".f3.rev.checkwm $wt.cbtx" }

# Text position box
ttk::combobox $wt.position -state readonly -textvariable wmpos -values $::wmpositions -width 10
$wt.position set $wmpos
bind $wt.position <<ComboboxSelected>> { bindsetAction 0 0 watsel ".f3.rev.checkwm $wt.cbtx" }

# Image watermark ops
ttk::checkbutton $wt.cbim -onvalue 1 -offvalue 0 -variable watselimg -command {turnOffParentCB .f3.rev.checkwm $wt.cbtx $wt.cbim}
ttk::label $wt.limg -text "Image"
# dict get $dic key
# Get only the name for image list.
set iwatermarksk [dict keys $::iwatermarks]
ttk::combobox $wt.iwatermarks -state readonly -values $::iwatermarksk
$wt.iwatermarks set [lindex $iwatermarksk 0]
set ::wmimsrc [dict get $::iwatermarks [lindex $iwatermarksk 0]]
bind $wt.iwatermarks <<ComboboxSelected>> { bindsetAction wmimsrc [dict get $::iwatermarks [%W get]] watsel ".f3.rev.checkwm $wt.cbim" }

# Image size box \%
ttk::spinbox $wt.imgsize -width 4 -from 0 -to 100 -increment 10 -validate key \
	-validatecommand { string is integer %P }
$wt.imgsize set $wmimsize
bind $wt.imgsize <ButtonRelease> { bindsetAction wmimsize [%W get] watsel .f3.rev.checkwm }
bind $wt.imgsize <KeyRelease> { bindsetAction wmimsize [%W get] watsel ".f3.rev.checkwm $wt.cbim"] }

# Image position
ttk::combobox $wt.iposition -state readonly -textvariable wmimpos -values $wmpositions -width 10
$wt.iposition set $wmimpos
bind $wt.iposition <<ComboboxSelected>> { bindsetAction 0 0 watsel ".f3.rev.checkwm $wt.cbim" }

# Opacity scales
# Set a given float as integer, TODO uplevel to set local context variable an not global namespace
proc progressBarSet { gvar cvar wt cb ft fl } {
	bindsetAction $gvar [format $ft $fl] $cvar ".f3.rev.checkwm $wt.$cb"
}

ttk::scale $wt.txop -from 10 -to 100 -variable wmop -value $wmop -orient horizontal -command { progressBarSet wmop watsel $wt cbtx "%.0f" }
ttk::label $wt.tolab -width 3 -textvariable wmop

ttk::scale $wt.imop -from 10 -to 100 -variable wmimop -value $wmimop -orient horizontal -command { progressBarSet wmimop watsel $wt cbim "%.0f" }
ttk::label $wt.iolab -width 3 -textvariable wmimop

# Style options
ttk::frame $wt.st
ttk::label $wt.st.txcol -text "Text Color"
ttk::label $wt.st.imstyle -text "Image Blending"
ttk::separator $wt.st.sep -orient vertical

canvas $wt.st.chos  -width 62 -height 26
set c(main) [$wt.st.chos create rectangle 2 2 26 26 -fill $::wmcol -width 2 -outline [getContrastColor $::wmcol] -tags {main}]
$wt.st.chos bind main <Button-1> { setColor %W wmcol $c(main) [%W itemconfigure $c(main) -fill] }

set wmswatch [getswatches $::wmcolswatch]
drawSwatch $wt.st.chos $wmswatch

set iblendmodes [list Bumpmap ColorBurn ColorDodge Darken Exclusion HardLight Hue Lighten LinearBurn LinearDodge LinearLight Multiply Overlay Over Plus Saturate Screen SoftLight VividLight]
ttk::combobox $wt.st.iblend -state readonly -textvariable wmimcomp -values $iblendmodes -width 12
$wt.st.iblend set $wmimcomp
bind $wt.st.iblend <<ComboboxSelected>> { bindsetAction wmimcomp [%W get] watsel ".f3.rev.checkwm $wt.cbim" }

set wtp 2 ; # Padding value

grid $wt.lsize $wt.lpos $wt.lop -row 1 -sticky ws
grid $wt.cbtx $wt.ltext $wt.watermarks $wt.fontsize $wt.position $wt.txop $wt.tolab -row 2 -sticky we -padx $wtp -pady $wtp
grid $wt.cbim $wt.limg $wt.iwatermarks $wt.imgsize $wt.iposition $wt.imop $wt.iolab -row 3 -sticky we -padx $wtp -pady $wtp
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

# --== Size options
proc tabResize {st} {
	global wList hList
	foreach size $::sizes {
		if { [string index $size end] == {%} } {
			lappend pList $size
		} else {
			set size [split $size {x}]
			lappend wList [lindex $size 0]
			lappend hList [lindex $size 0]
		}
	}
	lappend wList $pList 
	
	ttk::frame $st -padding 6
	
	ttk::frame $st.lef
	ttk::labelframe $st.rgt -text "Options"
	
	grid $st.lef -column 1 -row 1 -sticky nesw
	grid $st.rgt -column 2 -row 1 -sticky nesw
	grid columnconfigure $st 1 -weight 1 -minsize 250
	grid columnconfigure $st 2 -weight 2 -minsize 250
	grid rowconfigure $st 1 -weight 1 
	
	ttk::label $st.rgt.ins -text ""
	pack $st.rgt.ins -side left
	
	ttk::style layout small.TButton {
		Button.border -sticky nswe -border 1 -children {
			Button.focus -sticky nswe -children {
				Button.spacing -sticky nswe -children {Button.label -sticky nswe}
				}
			}
		}
	# ttk::style configure small.TButton -background color
	
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
	
	proc eventSize { w wc } {
		set sizesels [getSizesSel $w]
		#Set the interface according to the size type px or %
		if {![string is boolean $wc]} {
			set sel [$wc get]
			set id [string range $wc end end]
			set pref [string range $wc 0 end-4]
			append hei $pref "hei" $id
			$hei set $sel
			if { [string range $sel end end] == {%} } {
				$hei set {} ; # set to not to avoid sizes like 50%x50% no supported
				grid forget $hei
				${pref}xmu$id configure -text "%"
			} elseif { [lindex [${pref}xmu$id configure -text] end] == "%" } {
				array set info [grid info $wc]
				grid $hei -column 4 -row $info(-row) -sticky we
				${pref}xmu$id configure -text "x"
			}
		}

		if { [llength $sizesels] > 1 } {
			# treeAlterVal .f2.fb.flist oname {lindex [getOutputName $value $::outext $::oupreffix $::ousuffix] 0}
		} elseif { [llength $sizesels] == 1 } {
			bindsetAction 0 0 sizesel .f3.rev.checksz
		} elseif { [llength $sizesels] == 0 } {
			.f3.rev.checksz invoke
		}
		
		# set fname [getOutputName $f $::outext $::ouprefix $::ousuffix]
		# puts $fname
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
		comboBoxEditEvents $st.wid$id "eventSize $st %W"
		comboBoxEditEvents $st.hei$id "eventSize $st %W"
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
}

tabResize .f2.ac.n.sz

# Add frames to tabs in notebook
.f2.ac.n add $wt -text "Watermark" -underline 0
.f2.ac.n add .f2.ac.n.sz -text "Resize" -underline 0

# --== Suffix and prefix ops
set ou .f2.ac.onam
ttk::frame $ou
ttk::checkbutton $ou.cbpre -onvalue 1 -offvalue 0 -variable prefixsel -text "Suffix and Prefix" -command {printOutname 0 }
ttk::labelframe $ou.efix -text "Suffix and Prefix" -labelwidget $ou.cbpre -padding 6

ttk::label $ou.lpre -text "Prefix"
ttk::label $ou.lsuf -text "Suffix"

set ::suffixes [list \
	"net" \
	"archive" \
	"by-[string map -nocase {{ } -} $autor]" \
	"$date" \
]
lappend ::suffixes {} ; # Appends an empty value to allow easy deselect
foreach suf $::suffixes {
	lappend suflw [string length $suf]
}
set suflw [lindex [lsort -integer -decreasing $suflw] 0]
set suflw [expr {int($suflw+($suflw*.2))}]
expr { $suflw > 16 ? [set suflw 16] : [set suflw] }

ttk::combobox $ou.efix.pre -width $suflw -state readonly -textvariable ::ouprefix -values $suffixes
$ou.efix.pre set [lindex $suffixes 0]
comboBoxEditEvents $ou.efix.pre {printOutname %W }
ttk::combobox $ou.efix.suf -width $suflw -state readonly -textvariable ::ousuffix -values $suffixes
$ou.efix.suf set [lindex $suffixes end-1]
comboBoxEditEvents $ou.efix.suf {printOutname %W }

# --== Output frame

ttk::labelframe $ou.f -text "Output & Quality" -padding 8

set formats [list png jpg gif] ; # TODO ora and keep
ttk::label $ou.f.lbl -text "Format:"
ttk::combobox $ou.f.fmt -state readonly -width 6 -textvariable outext -values $formats
$ou.f.fmt set [lindex $formats 0]
bind $ou.f.fmt <<ComboboxSelected>> { treeAlterVal .f2.fb.flist oname {lindex [getOutputName $fpath $::outext $::ouprefix $::ousuffix] 0} }

ttk::label $ou.f.qtb -text "Quality:"
ttk::scale $ou.f.qal -from 10 -to 100 -variable iquality -value $::iquality -orient horizontal -command { progressBarSet iquality 0 0 0 "%.0f" }
ttk::label $ou.f.qlb -width 4 -textvariable iquality
ttk::separator $ou.sep -orient horizontal
ttk::checkbutton $ou.f.ove -text "Allow Overwrite" -onvalue 1 -offvalue 0 -variable overwrite -command { treeAlterVal .f2.fb.flist oname {lindex [getOutputName $fpath $::outext $::ouprefix $::ousuffix] 0} }

pack $ou.efix $ou.sep $ou.f -side top -fill both -expand 1 -padx $wtp
pack configure $ou.sep -padx 24 -pady 6 -expand 0
pack configure $ou.efix -fill x -expand 0

pack $ou.efix.pre $ou.efix.suf -padx $wtp -side left -fill x -expand 1

ttk::separator $ou.f.sep -orient vertical

grid $ou.f.qtb $ou.f.qlb $ou.f.qal -row 1
grid configure $ou.f.qtb -column 1
grid configure $ou.f.qal -column 2 -columnspan 2 -sticky we
grid configure $ou.f.qlb -column 4 -sticky w
grid $ou.f.lbl $ou.f.fmt -row 2
grid configure $ou.f.lbl -column 2
grid configure $ou.f.fmt -column 3	
grid $ou.f.ove -row 3 -column 2
grid configure $ou.f.fmt $ou.f.qlb -sticky we
grid configure $ou.f.qtb $ou.f.lbl -sticky e

grid columnconfigure $ou.f {2} -weight 12 -pad 4 
grid columnconfigure $ou.f {1} -weight 2 -pad 4
grid rowconfigure $ou.f {0 1 2 3} -weight 1 -pad 4


# Add frame notebook to pane left.
.f2.ac add .f2.ac.n
.f2.ac add .f2.ac.onam
.f2.ac pane .f2.ac.n -weight 6
.f2.ac pane .f2.ac.onam -weight 2

#pack panned window
pack .f2 -side top -expand 1 -fill both

# ----==== Status bar
pack [ttk::frame .f3] -side top -expand 0 -fill x
ttk::frame .f3.rev
ttk::frame .f3.do


ttk::checkbutton .f3.rev.checkwm -text "Watermark" -onvalue 1 -offvalue 0 -variable watsel -command { turnOffChildCB watsel "$wt.cbim" watselimg "$wt.cbtx" watseltxt }
ttk::checkbutton .f3.rev.checksz -text "Resize" -onvalue 1 -offvalue 0 -variable sizesel

ttk::progressbar .f3.do.pbar -maximum [getFilesTotal 1] -variable ::cur -length "300"
ttk::label .f3.do.plabel -text "Converting: " -textvariable pbtext
ttk::button .f3.do.bconvert -text "Convert" -command {convert}

pack .f3.rev.checkwm .f3.rev.checksz -side left
pack .f3.rev -side left
pack .f3.do -side right
pack .f3.do.bconvert -side right -fill x -padx 6 -pady 8

proc pBarUpdate { w gvar args } {
	upvar #0 $gvar cur
	set opt [dict create]
	set opt [dict create {*}$args]
	
	if {[dict exists $opt max]} {
		$w configure -maximum [dict get $opt max]
		update
	}
	if {[dict exists $opt current]} {
		set cur [dict get $opt current]
	}
	incr cur
	update
}

#Resize: returns the validated entry as wxh or N%
proc getFinalSizelist {} {
	set sizeprelist [getSizesSel .f2.ac.n.sz.lef]
	if {$sizeprelist != 0 } {
		foreach {size} $sizeprelist {
			lappend sizelist [join $size {x}]
		}
	} else {
		set sizelist 0
	}
	return $sizelist
}
#Give original size and destination square.
proc getOutputSize { w h dw dh } {
		if { $w > $h } {
			set dh [ expr {$h*$dw/$w} ]
		} else {
			set dw [ expr {$w*$dh/$h} ]
		}
		return "${dw}x${dh}"
	}
#Preproces functions
#watermark
proc watermark {} {
	global deleteFileList
	set wmcmd {}
	
	# Positions list correspond to $::watemarkpos, but names as imagemagick needs
	set magickpos [list "NorthWest" "North" "NorthEast" "West" "Center" "East" "SouthWest" "South" "SouthEast"]
	set wmpossel   [lindex $magickpos [.f2.ac.n.wm.position current] ]
	set wmimpossel [lindex $magickpos [.f2.ac.n.wm.iposition current] ]
	# wmtxt watermarks wmsize wmcol wmcolswatch wmop wmpositions wmimsrc iwatermarks wmimpos wmimsize wmimcomp wmimop watsel watseltxt watselimg
	#Watermarks, check if checkboxes selected
	if { $::watseltxt } {
		set wmtmptx [file join "/tmp" "artk-tmp-wtmk.png" ]
		set width [expr {[string length $::wmtxt] * 3 * ceil($::wmsize/4.0)}]
		set height [expr {[llength [split $::wmtxt {\n}]] * 30 * ceil($::wmsize/8.0)}]
		set wmcolinv [getContrastColor $::wmcol ]
		
		set wmtcmd [list convert -size ${width}x${height} xc:transparent -pointsize $::wmsize -gravity Center -fill $::wmcol -annotate 0 "$::wmtxt" -trim \( +clone -background $wmcolinv  -shadow 80x2+0+0 -channel A -level 0,60% +channel \) +swap +repage -gravity center -composite $wmtmptx]
		exec {*}$wmtcmd
		
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
			set wmicmd [ list convert -size $size xc:transparent -gravity Center $::wmimsrc -compose dissolve -define compose:args=$::wmimop -composite $wmtmpim]
			exec {*}$wmicmd
			
			# set watval [concat -gravity $::wmimpos -draw "\"image $::wmimcomp 10,10 0,0 '$::wmimsrc'\""]
			lappend deleteFileList $wmtmpim ; # add wmtmp to delete list
			append wmcmd " " [list -gravity $wmimpossel $wmtmpim -compose $::wmimcomp -define compose:args=$::wmimop -geometry +10+10 -composite ]
			# puts $watval
			
		}
	}
	return $wmcmd
}

#Calligra, gimp and inkscape converter
proc processHandlerFiles { {outdir "/tmp"} } {
	global inputfiles handlers deleteFileList
	
	# Files to convert
	set ids [putsHandlers g i k]
	array set handler $handlers
	
	pBarUpdate .f3.do.pbar cur max [llength $ids] current 0
	set msg {}
	foreach imgv $ids {
		array set id [dict get $inputfiles $imgv]
		updateTextLabel .f3.do.plabel pbtext textv "Extracting... $id(name)"
		set outname [file join ${outdir} [file root $id(name)]]
		append outname ".png"
		
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
		
		#Error reporting, if code NONE then png conversion success.
		if { ![file exists $outname ]} {
			set errc $::errorCode;
			set erri $::errorInfo
			puts "errc: $errc \n\n"
			if {$errc != "NONE"} {
				append ::lstmsg "EE: $$id(name) discarted\n"
				puts $msg
			}
			error "something went wrong, Tmp png wasn't created"
			continue
		}
		dict set inputfiles $imgv tmp $outname
		lappend deleteFileList $outname
		# puts [dict get $inputfiles $imgv]
		
	pBarUpdate .f3.do.pbar cur
	}	
	return 0
}

proc convert {} {
	global inputfiles deleteFileList
	
	#Create progressbar
	pack .f3.do.plabel .f3.do.pbar -side left -fill x -padx 2 -pady 0
	
	#get watermark value
	set wmark [watermark]
	#get make resize string
	set sizes [getFinalSizelist]
	
	#process Gimp Calligra and inkscape to Tmp files
	processHandlerFiles
	
	pBarUpdate .f3.do.pbar cur max [expr {[getFilesTotal 1]*[llength $sizes]}] current 0

	dict for {id datas} $::inputfiles {
		dict with datas {
			if {!$deleted} {
				set opath $path

				if {[dict exists $datas tmp]} {
					set opath $tmp
				}
				set filter "-interpolate bicubic -filter Lagrange"
				set unsharp [string repeat "-unsharp 0.4x0.4+0.4+0.008 " 3]
				
				foreach dimension $sizes {
					updateTextLabel .f3.do.plabel pbtext textv "Converting... $name"
					set resize {}
					if {$dimension == 0} {
						set convertCmd [concat $opath $resize $wmark $unsharp $oname]
						exec convert {*}$convertCmd
						pBarUpdate .f3.do.pbar cur
						continue
					}
					incr i
					set cur_w [lindex [split $size {x} ] 0]
					set dest_w [lindex [split $dimension {x} ] 0]
					
					if {[string range $dimension end end] == "%"} {
						set dest_w [string trim 50% {%}]
						set dest_w [expr {round($cur_w * ($dest_w / 100.0))} ]
						set operator {}
					} else {
						set operator "\\>"
					}
					# We have to get the final size ourselves or else imagick could miss by 1 px
					set finalscale [getOutputSize {*}[concat [split $size {x} ] [split $dimension {x}]] ]
					#Add resize filter (better quality)
					set resize "-colorspace RGB"
					set resize [concat $resize $filter]
					while { [expr {[format %.1f $cur_w] / $dest_w}] > 1.5 } {
						set cur_w [expr {round($cur_w * 0.80)}]
						set resize [concat $resize -resize 80% +repage $unsharp]
					}
					# Final resize output
					set resize [concat $resize -resize ${finalscale}${operator} +repage -colorspace sRGB]
					
					updateTextLabel .f3.do.plabel pbtext textv "Converting... ${name} to $dimension"
					if {$i == 1} {
						set dimension {}
					}
					set soname [lindex [getOutputName $opath $::outext $::ouprefix $::ousuffix $dimension] 0]
					
					set convertCmd [concat -quiet "$opath" $resize $wmark $unsharp -quality $::iquality "$soname"]
					exec convert {*}$convertCmd

					pBarUpdate .f3.do.pbar cur
				}
				#convert for each size
				#depend on size do quality unsharp
				#general unsharp value
				# -unsharp 0x6+0.5+0
				#extra quality x3 smashing
			}
		}
	}
	updateTextLabel .f3.do.plabel pbtext textv "Deleting Temporary Files..."
	catch {file delete [list $deleteFileList]}
	pack forget .f3.do.pbar .f3.do.plabel
	updateTextLabel .f3.do.plabel pbtext textv ""
}

