#!/usr/bin/wish
#
#----------------:::: ArtscriptTk ::::----------------------
# Version: 1.8.4
# Author:IvanYossi / http://colorathis.wordpress.com ghevan@gmail.com
# Script inspired by David Revoy artscript / www.davidrevoy.com info@davidrevoy.com
# License: GPLv3 
#-----------------------------------------------------------
# Goal : Batch convert any image file supported by imagemagick, calligra & Inkscape.
# Dependencies: >=imagemagick-6.7.5, tk 8.5
# Optional deps: calligraconverter, inkscape, gimp
#
# __Customize:__
#   You can modify any variable between "#--=====" markers
#   Or (recomended) make a config file (rename presets.config.presets to presets.config)
#   File must be in the same directory as the script.
#
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
set ::autor "Your Name Here"
#Initialize variables for presets
#Watermark options
set ::watxt {}
set ::watermarks [list \
	"Copyright (c) $autor" \
	"Copyright (c) $autor / $date" \
	"http://www.yourwebsite.com" \
	"Artwork: $autor" \
	"$date" \
]
set ::wmsize 10
set ::wmpos "SouthEast"
#Place image watermark URL. /home/user/image
set ::wmimsrc ""
set ::wmimpos "Center"
set ::wmimsize "90%"
set ::wmimcomp "Over"
#Color options:
set ::rgb "#ffffff"
set ::opacity 0.8
set ::wmswatch "black gray white"
set ::bgcolor "#ffffff"
set ::bgop 1
set ::bgswatch "grey10 grey grey96"
set ::bordercol "grey94"
set ::brop .8
set ::brswatch "grey27 grey66 white"
set ::tfill "#ffffff"
set ::tfop .8
set ::tswatch "grey16 gray88 white"
#Size and Montage:
set ::sizes [list \
	"1920x1920" \
	"1650x1650" \
	"1280x1280" \
	"1024x1024" \
	"800x800" \
	"150x150" \
	"100x100" \
	"50%" \
]
set ::sizext "200x200"
# mborder Adds a grey border around each image. set 0 disable
# mspace Adds space between images. set 0 no gap
set ::mborder 5
set ::mspace 3
set ::tileval {}
set ::mrange {}
set ::mlabel {}
# moutput Montage filename output
set ::mname "collage-$raninter"
#Extension & output
set ::outextension "jpg"
#Image quality
set ::iquality 92
#suffix options
set ::suffixes [list \
	"net" \
	"archive" \
	"by-[string map -nocase {{ } -} $autor]" \
	"my-cool-suffix" \
]
set ::suffix ""
#Selected operations, default none.
set ::watsel false
set ::tilesel false
set ::sizesel false
set ::prefixsel false

#--=====
#Don't modify below this line
set ::version "v1.8.4"
set ::lstmsg ""
set ::gvars {tcl_rcFileName|tcl_version|argv0|argv|tcl_interactive|tk_library|tk_version|auto_path|errorCode|tk_strictMotif|errorInfo|auto_index|env|tcl_pkgPath|tcl_patchLevel|argc|tk_patchLevel|tcl_library|tcl_platform}
#Function to send message boxes
proc alert {type icon title msg} {
		tk_messageBox -type $type -icon $icon -title $title \
		-message $msg
}
#Validation Functions
#Finds program trying to get program version, return 0 if program missing
proc validate {program} {
	catch {set fail [exec -ignorestderr $program --version]} msg
	if { [catch {set fail}] eq "1"} {
		puts "$msg"
		return 0
	}
  puts "$program found"
	return 1
}
#Gimp path
set hasgimp [validate "gimp"]
#Inkscape path, if true converts using inkscape to /tmp/*.png
set hasinkscape [validate "inkscape"]
#calligraconvert path, if true converts using calligra to /tmp/*.png
set hascalligra [validate "calligraconverter"]

#Check if we have files to work on, if not, finish program.
if {[catch $argv] == 0 } { 
	alert ok info "Operation Done" "No files selected Exiting"
	exit
}
# listValidate:
# Validates arguments input mimetypes, keeps images strip the rest
# Creates a separate list for .kra, .xcf, .psd, .svg and .ora to process separatedly
proc listValidate {} {
	global argv ext hasinkscape hascalligra hasgimp
	global gimplist calligralist inkscapelist identify lfiles ops fc
	
	set lfiles "Files to be processed\n"
	set gimplist {}
	set calligralist {}
	set inkscapelist {}
	set imlist {}
	
	set identify "identify -quiet -format %wx%h\|%m\|%M\|"
	set ops [dict create]
	set options true
	set lops 1
	#We validate sort arguments into options and filelists
	foreach i $argv {
		incr c
		if { [string index $i 0] == ":" && $options} {
			dict set ops $i [lindex $argv $c]
			set lops [expr {[llength $ops]+1}]
			continue
		} elseif { $options && $lops == $c } {
			set options false
		}
		set filext [string tolower [file extension $i] ]
		if {[lsearch $ext $filext ] >= 0 } {
			incr fc
			if { [regexp {.xcf|.psd} $filext ] && $hasgimp } {
				lappend gimplist $i
				append lfiles "$fc Gimp: $i\n"
				continue
			} elseif { [regexp {.svg|.ai} $filext ] && $hasinkscape } {
				lappend inkscapelist $i
				append lfiles "$fc Ink: $i\n"
				continue
			} elseif { [regexp {.kra|.ora|.xcf|.psd} $filext ] && $hascalligra } {
				lappend calligralist $i
				append lfiles "$fc Cal: $i\n"
				continue
			} else {
				lappend imlist $i
				append lfiles "$fc Mag: $i\n"
			}
		} elseif { [string is boolean [file extension $i]] && !$options } {
			if { [catch { set f [exec {*}[split $identify " "] $i ] } msg ] } {
				puts $msg
			} else {
				incr fc
				lappend imlist $i
				append lfiles "$fc Mag: $i\n"
			}
		}
	}
	set argv $imlist
	#Check if resulting lists have elements
	if {[llength $argv] + [llength $gimplist] + [llength $calligralist] + [llength $inkscapelist] == 0} {
		alert ok info "Operation Done" "No image files selected Exiting"
		exit
	}
}
#We run function to validate input mimetypes
listValidate

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
	if {![info exists lista]} {
		lappend lista {}
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

#For future theming
#tk_setPalette background black foreground white highlightbackground blue activebackground gray70 activeforeground black

#Gui construct. This needs to be improved a lot
#--- watermark options
labelframe .wm -bd 2 -padx 2m -pady 2m -font {-size 12 -weight bold} -text "Watermark options"  -relief ridge
pack .wm -side top -fill x

label .wm.txtlabel -text "Watermark presets"
label .wm.poslabel -text "Position"
listbox .wm.listbox -selectmode single -height 5
foreach i $watermarks { .wm.listbox insert end $i }
bind .wm.listbox <<ListboxSelect>> { setSelectOnEntry [%W curselection] "wm" "watxt"}
entry .wm.entry -text "Custom" -textvariable watxt
bind .wm.entry <KeyRelease> { setSelectOnEntry false "wm" "watxt" }
label .wm.label -text "Selected:"

label .wm.lwmsize -text "Size:"
entry .wm.wmsizentry -textvariable wmsize -width 3 -validate key \
	-vcmd { regexp {^(\s?|[1-9]|[1-4][0-8])$} %P }
scale .wm.wmsize -orient vertical -from 48 -to 1 \
	-variable wmsize -showvalue 0

set wmpos_index {"NorthWest" "North" "NorthEast" "West" "Center" "East" "SouthWest" "South" "SouthEast"}
foreach i $wmpos_index {
	radiobutton .wm.pos$i -value $i -variable wmpos -command { writeVal .wm.posresult "" $wmpos }
}
label .wm.posresult

grid .wm.txtlabel -row 1 -column 1 -sticky w
grid .wm.listbox -row 2 -rowspan 5 -column 1 -sticky nesw
grid .wm.entry -row 7 -column 1 -sticky we
grid .wm.label -row 8 -column 1 -sticky w
grid .wm.lwmsize -row 1 -column 2 -sticky nw
grid .wm.wmsize -row 2 -rowspan 6 -column 2 -sticky ns
grid .wm.wmsizentry -row 8 -column 2 -sticky w 
grid .wm.poslabel -row 1 -column 3 -columnspan 2 -sticky w

#Make position grid
set m 0
for {set i 2} { $i < 7 } { incr i 2 } {
	for {set j 3} { $j < 6 } { incr j } {
		grid .wm.pos[lindex $wmpos_index $m] -row $i -column $j -columnspan 1 -sticky w
		incr m
	}
}
grid .wm.posresult -row 8 -column 3 -columnspan 3 -sticky sw
grid rowconfigure .wm 2 -weight 0
grid rowconfigure .wm {1 3 4 5 6 7 8} -weight 1
grid columnconfigure .wm {1} -weight 16
grid columnconfigure .wm {2} -weight 0
grid columnconfigure .wm {3 4 5} -weight 1

#--- Color options
proc colorSelector { frame suffix colorvar op title colors {row 0} } {
	global $colorvar

	label $frame.${suffix}title -font {size 12} -text $title

	canvas $frame.${suffix}viewcol -bg [set $colorvar] -width 60 -height 30
	$frame.${suffix}viewcol create text 30 16 -text "click me"
	canvas $frame.${suffix}margin -height 2m -width 60

	label $frame.${suffix}lopacity -text "Opacity:"
	scale $frame.${suffix}opacity -orient horizontal -from .1 -to 1.0 -resolution 0.1 -relief flat -bd 0  \
	-variable $op -showvalue 0 -width 8 -command [list writeVal $frame.${suffix}lopacity {Opacity:}]

	bind $frame.${suffix}viewcol <Button> [ list colorBind $frame.${suffix}viewcol $colorvar 0 $title ]
	#Make color swatches depending on number of colors selected.
	foreach i $colors {
		canvas $frame.${suffix}$i -bg $i -width [expr {60/[llength $colors]}] -height 16
		bind $frame.${suffix}$i <Button> [ list colorBind $frame.${suffix}viewcol $colorvar $i $title ]
	}
	#Add widgets to GUI, row increments to prevent overlaps
	grid $frame.${suffix}title -row $row -column 1 -sticky nw
	incr row
	grid $frame.${suffix}viewcol -row $row -column 1 -sticky nesw
	incr row
	set cn 0
	foreach i $colors {
		grid $frame.${suffix}$i -row $row -column [incr cn] -sticky nsew
	}
	incr row
	grid $frame.${suffix}lopacity -row $row -column 1 -sticky wns
	incr row
	grid $frame.${suffix}opacity -row $row -column 1 -sticky ew
	grid $frame.${suffix}title $frame.${suffix}viewcol $frame.${suffix}lopacity $frame.${suffix}opacity $frame.${suffix}margin -columnspan [llength $colors]
	incr row
	grid $frame.${suffix}margin -row $row -column 1
}

#Construct color settings label frame
labelframe .color -bd 0 -padx 2m -pady 2m -font {-size 12 -weight bold} -text "Color settings"  -relief solid
pack .color -side left -fill y
#Construct color dialogs
colorSelector ".color" "wm" "rgb" "opacity" "Watermark" $wmswatch 0
colorSelector ".color" "bg" "bgcolor" "bgop" "Background Col" $bgswatch 6
colorSelector ".color" "br" "bordercol" "brop" "Border Col" $brswatch 12
colorSelector ".color" "fil" "tfill" "tfop" "Label Col" $tswatch 18

#--- Size options
labelframe .size -bd 2 -padx 2m -pady 2m -font {-size 12 -weight bold} -text "Size & Collage settings"  -relief ridge
pack .size -side top -fill x
#scrollbar binding function
proc showargs {args} {
	eval $args
}
#Size menu options
listbox .size.listbox -selectmode extended -relief flat -height 2
foreach i $sizes { .size.listbox insert end $i }
bind .size.listbox <<ListboxSelect>> { setSelectOnEntry [%W curselection] "size" "sizext" 1}
scrollbar .size.scroll -command {showargs .size.listbox yview} -orient vert
.size.listbox conf -yscrollcommand {showargs .size.scroll set}
message .size.exp -width 210 -justify center -text "\
 Size: W x H, 40% \n\
 In Collage size is tile size\n\
 Size 20x20 + Layout 2x2 = w40xh40"

#size and tile entry boxes and validation
entry .size.entry -textvariable sizext -validate key \
	-vcmd { regexp {^(\s*|[0-9])+(\s?|x|%%)(\s?|[0-9])+$} %P }
bind .size.entry <KeyRelease> { setSelectOnEntry false "size" "sizext" }
entry .size.tile -textvariable tileval -width 6  -validate key \
	-vcmd { regexp {^(\s*|[0-9])+(\s?|x|%%)(\s?|[0-9])+$} %P }
bind .size.tile <KeyRelease> { checkstate $tileval .opt.tile }
entry .size.range -textvariable mrange -width 4 -validate key \
	-vcmd { regexp {^(\s*|[0-9])+$} %P }
bind .size.range <KeyRelease> { checkstate $mrange .opt.tile }
entry .size.entrylabel -textvariable mlabel -validate key \
	-vcmd { string is ascii %P }

label .size.label -text "Size:"
label .size.txtile -text "Layout:"
label .size.lblrange -text "Range:"
label .size.lbllabel -text "Label:"

grid .size.listbox -row 1 -column 1 -sticky nwse
grid .size.scroll -row 1 -column 1 -sticky ens
grid .size.entry -row 2 -column 1 -sticky ews
grid .size.label -row 3 -column 1 -sticky wns
grid .size.exp -row 1 -column 2 -columnspan 4 -sticky nsew
grid .size.txtile -row 2 -column 2 -sticky e
grid .size.tile -row 2 -column 3  -sticky ws
grid .size.range -row 2 -column 5 -sticky wse
grid .size.lblrange -row 2 -column 4 -sticky e
grid .size.lbllabel -row 3 -column 2 -sticky e
grid .size.entrylabel -row 3 -column 3 -columnspan 3 -sticky we
grid rowconfigure .size 1 -weight 3
grid rowconfigure .size 2 -weight 1
grid columnconfigure .size 1 -weight 1
grid columnconfigure .size {2 3 4} -weight 0

#--- Format options
labelframe .ex -bd 2 -padx 2m -pady 2m -font {-size 12 -weight bold} -text "Output Format"  -relief ridge
pack .ex -side top -fill x
radiobutton .ex.jpg -value "jpg" -text "JPG" -variable outextension
radiobutton .ex.png -value "png" -text "PNG" -variable outextension
radiobutton .ex.gif -value "gif" -text "GIF" -variable outextension
radiobutton .ex.ora -value "ora" -text "ORA(No post)" -variable outextension
#.ex.jpg select
label .ex.lbl -text "Other"
entry .ex.sel -text "custom" -textvariable outextension -width 4
text .ex.txt -height 3 -width 4
.ex.txt insert end $lfiles

#-- Select only rename no output transform
checkbutton .ex.rname -text "Rename Only" \
		-onvalue true -offvalue false -variable renamesel
#-- Ignore output, use input extension as output.
checkbutton .ex.keep -text "Keep format" \
		-onvalue true -offvalue false -variable keep
#--- Image quality options

scale .ex.scl -orient horizontal -from 10 -to 100 -tickinterval 25 -width 12 \
		-label "" -length 110 -variable iquality -showvalue 1
#    -highlightbackground "#666" -highlightcolor "#333" -troughcolor "#888" -fg "#aaa" -bg "#333" -relief flat
label .ex.qlbl -text "Quality:"
button .ex.good -pady 1 -padx 8 -text "Good" -command resetSlider; #-relief flat -bg "#888"
button .ex.poor -pady 1 -padx 8 -text "Poor" -command {set iquality 30}

grid .ex.jpg .ex.png .ex.gif .ex.ora .ex.rname .ex.keep -column 1 -columnspan 2 -sticky w
grid .ex.jpg -row 1
grid .ex.png -row 2
grid .ex.gif -row 3
grid .ex.ora -row 4
grid .ex.sel -row 5 -column 2
grid .ex.lbl -row 5 -column 1
grid .ex.keep -row 6
grid .ex.rname -row 7	
grid .ex.txt -column 3 -row 1 -columnspan 4 -rowspan 5 -sticky nesw
grid .ex.qlbl .ex.poor .ex.good .ex.scl -row 6 -rowspan 2 -sticky we
grid .ex.qlbl -column 3
grid .ex.poor -column 4
grid .ex.good -column 6
grid .ex.scl  -column 5
grid columnconfigure .ex {1} -weight 0
grid columnconfigure .ex {5} -weight 1

#--- Suffix options
labelframe .suffix -padx 2m -pady 2m -font {-size 12 -weight bold} -text "Suffix"  -relief ridge
pack .suffix -side top -fill x

listbox .suffix.listbox -selectmode single -height 4
foreach i $suffixes { .suffix.listbox insert end $i }
bind .suffix.listbox <<ListboxSelect>> { setSelectOnEntry [%W curselection] "suffix" "suffix"}
label .suffix.label -text "->:"

entry .suffix.entry -textvariable suffix -validate key \
	-vcmd { string is graph %P }
bind .suffix.entry <KeyRelease> { setSelectOnEntry false "suffix" "suffix" }
checkbutton .suffix.date -text "Add Date" \
		-onvalue true -offvalue false -variable datesel -command setdateCmd
checkbutton .suffix.prefix -text "Prefix" \
		-onvalue true -offvalue false -variable prefixsel -command { setSelectOnEntry false "suffix" "suffix" }

grid .suffix.listbox -column 1 -rowspan 4 -sticky nsew
grid .suffix.label -row 1 -column 2 -columnspan 3 -sticky nsw
grid .suffix.entry -row 2 -column 2 -columnspan 3 -sticky ew
grid .suffix.date -row 3 -column 2 -sticky w
grid .suffix.prefix -row 3 -column 4 -sticky w
grid columnconfigure .suffix {1} -weight 0
grid columnconfigure .suffix {2} -weight 1

#--- On off values for watermark, size, date suffix and tiling options
frame .opt -borderwidth 2
pack .opt
checkbutton .opt.watxt -text "Watermark" \
		-onvalue true -offvalue false -variable watsel
checkbutton .opt.waimg -text "Img Watermark" \
		-onvalue true -offvalue false -variable wmimsel
checkbutton .opt.sizext -text "Resize" \
		-onvalue true -offvalue false -variable sizesel
checkbutton .opt.tile -text "Make Collage" \
		-onvalue true -offvalue false -variable tilesel

#Pack command, we insert image watemark check if the variable is set
set packcb [list pack .opt.watxt .opt.sizext .opt.tile -side left]

if { ![string is boolean $::wmimsrc] } {
	set packcb [linsert $packcb 2 .opt.waimg]
}

{*}$packcb

#--- Submit button
frame .act -borderwidth 6
pack .act -side right
button .act.submit -text "Convert" -font {-weight bold} -command convert
pack .act.submit -side right -padx 0 -pady 0

#--- Window options
wm title . "Artscript $version -- $fc Files selected"

#--- General Functions
proc checkstate { val cb } {
	if {$val != {} } {
		$cb select
	} else {
		$cb deselect
	}
}

#Converts hex color value and returns rgb value with opacity setting to alpha channel
proc setRGBColor { rgb {opacity 1.0} } {
	#Transform hex value to rgb 16bit
	set rgbval [ winfo rgb . $rgb ]
	set rgbn "rgba("
	foreach i $rgbval {
		#For each value we divide by 256 to get 8big rgb value (0 to 255)
		#I set it to 257 to get integer values, need to check this further.
		append rgbn "[expr {$i / 257}],"
	}
	append rgbn "$opacity)"
	return $rgbn
}

#Sets text label of "l" to $val
proc writeVal { l text val } {
	$l configure -text "$text $val"
}

#Launchs Color chooser and set color to window: Returns hex color
proc setWmColor { rgb window { title "Choose color"} } {
	#Call color chooser and store value to set canvas color and get rgb values
	set choosercolor [tk_chooseColor -title $title -initialcolor $rgb -parent .]
	if { [expr {$choosercolor ne "" ? 1 : 0}] } {
		set rgb $choosercolor
		$window configure -bg $rgb
	}
	return $rgb
}
#Updates color value of w widget with color val
proc colorBind { w var {color false} title } {
	global $var
	if {![string is boolean $color]} {
		set $var $color
		$w configure -bg $color
	} else {
		set $var [setWmColor [set $var] $w $title]
	}
}

#Receives an index value a rootname and a global variable to call
#Syncs listbox values with other label values and entry values
proc setSelectOnEntry { indx r g {listbox 0}} {
	global $g
	#Check if variable comes from list, if not then get value from entry text
	if { [string is integer $indx] } { 
		set val [.$r.listbox get $indx]
	} elseif { [string is list $indx] && $listbox} {
		foreach sel $indx {
			lappend val [.$r.listbox get $sel]
		}
	} else {
		set val [.$r.entry get]
	}
	set $g $val
	#Dirty hack to add suffix listbox but no select option
	if {$g != "suffix"} {
		.$r.label configure -text "Selected: $val"
	#If anything is selected we set Size option on automatically
		.opt.$g select
	#Else $g is "suffix" 
	} else {
		.$r.label configure -text "->: [getOutputName]"
	}
}

#Set slider value to 92
# BUG: needs to reset to current preset value
proc resetSlider {} {
	global iquality
	set iquality 92
}

#Function that controls suffix date construction
proc setdateCmd {} {
	global datesel date suffix
	#We add the date string if checkbox On
	if {$datesel} {
		uplevel append suffix $date
		.suffix.label configure -text "Output: [getOutputName]"
	} else {
	#If user checkbox to off
	#We erase it when suffix is same as date
		if { $suffix == "$date" } {
			uplevel set suffix "{}"
		} else {
	#Search date string to erase from suffix
			uplevel set suffix [string map -nocase "$date { }" $suffix ]
		}
	}
}
proc keepExtension { i } {
	global outextension
	uplevel set outextension [ string trimleft [file extension $i] "."]
}
#Main Progressbar update control
proc progressUpdate { { current false } { max false } { create false } } {
	if {[string is integer $current]} {
		set ::cur $current
	}
	if {$max} {
		.act.pbar configure -maximum $max
		update
		return
	}
	if {$create} {
		#Draw progressbar next to convert button.
		pack [ ttk::progressbar .act.pbar -maximum [llength [concat $::gimplist $::calligralist $::inkscapelist ] ] -variable ::cur -length "300" ] -side left -fill x -padx 2 -pady 0
		update
		return
	}
	incr ::cur
	update
}

#Preproces functions
#watermark
proc watermark {} {
	global watxt watsel wmsize wmpos rgb opacity wmimsel

	set rgbout [setRGBColor $rgb $opacity]
	set watval ""
	#Watermarks, we check if checkbox selected to add characters to string
	if {$watsel} {
		set watval "-pointsize $wmsize -fill $rgbout -draw \"gravity $wmpos text 10,10 \'$watxt\'\""
	}
	#we check image watermark checkbox to add image wm
	if { $wmimsel } {
			if { [file exists $::wmimsrc] } {
				set watval [concat $watval "-gravity $::wmimpos -draw \"image $::wmimcomp 10,10 0,0 '$::wmimsrc' \""]
			}
		}
	return $watval
}
#Rename files only
proc renameFile { olist {odir false} } {
	global prefixsel
	set fdir $odir
	if [llength $olist] {
		foreach i $olist {
			if {![catch {dict get $odir $i} ] } {
				set fdir [dict get $odir $i]
			}
			keepExtension $i
			set oname [setOutputName $i $outextension $prefixsel 0 $fdir]
			set io [file join [lindex $oname 1] [lindex $oname 0] ]
			file rename $i $io
		}
	}
}
#Resize: returns the validated entry as wxh or ready true as "-resize wxh\>"
proc getSizeSel { {collage false} {ready false}} {
	if { [string is list $::sizext] } {
		set sizeval [lindex $::sizext 0]
	} else {
		set sizeval [string trim $::sizext]
	}
	#We check if user wants resize and $sizeval not empty
	if {$collage} {
		#We have to substract the margin from the tile value, in this way the user gets
		# the results is expecting (200px tile 2x2 = 400px)
		if { $sizeval == "x" } {
			#turns concat mode on
			return "{} 0 0"
		} elseif {![string match -nocase {*[0-9]\%} $sizeval] && ![string is boolean $sizeval] } {
			set mgap [expr {($::mborder + $::mspace)*2} ]
			set xpos [string last "x" $sizeval]
			set sizelast [expr {[string range $sizeval $xpos+1 end]-$mgap}]
			set sizefirst [expr {[string range $sizeval 0 $xpos-1]-$mgap}]
			set sizeval "$sizefirst\x$sizelast\\>"
			return [lappend sizeval $sizefirst $sizelast]
		} else {
			set tmpl ""
			return [lappend tmpl [string trim $sizeval "\%"] "0" "0"]
		}
	} else {
		if {!$::sizesel || [string is boolean $sizeval] || $sizeval == "x" } {
			set sizeval ""
		}
		if {$ready && ![string is boolean $sizeval] } {
			set sizeval "-resize $sizeval\\>"
		}
	}
		return $sizeval
}
#Image magick processes
#Collage mode
proc collage { olist path imcat} {
	global tileval mborder mspace mname mrange mlabel sizext
	#colors
	global bgcolor bgop bordercol brop tfill tfop
	set sizevals [getSizeSel 1]
	set sizeval [lindex $sizevals 0]
	#TODO size in collage does not accept % values
	set sizefirst [lindex $sizevals 1]
	set sizelast [lindex $sizevals 2]

	set clist ""
	#returns multiple lists depending on range value
	proc range { ilist range } {
		set rangelists ""
		set listsize [llength $ilist]
		set times [expr {($listsize/$range)+(bool($listsize % $range))} ]

		for {set i 0} { $i < $times } { incr i } {
			set val1 [expr {$range * $i}]
			set val2 [expr {$range * ($i+1) - 1} ]
			lappend rangelists [lrange $ilist $val1 $val2]
		}
		return $rangelists
	}
	proc getRange { tile } {
		set col_row [split $tile {x}]
		if { [catch { set range [expr [join $col_row *]] }] } {
			return
		}
		return $range
	}
	#Check if range is selected to produce a list of lists
	set frange [expr {[string equal $mrange {}] ? 0 : $mrange}]
	set tilerange [getRange $tileval]
	
	if {($frange == 0) && ([llength $olist] > $tilerange) } {
		set frange $tilerange
	}
	if { $frange > 1 } {
		set clist [range $olist $frange]
	} else {
		lappend clist $olist
	}

	#Check if user set something in tile entry field
	if {![string is boolean $tileval]} {
		set tileval "-tile $tileval"
	}
	#check if user set something to label collage
	set label ""
	if {![string is boolean $mlabel]} {
		set label {-label "$mlabel"}
		#puts $label; exit
	}
	#Returns "width x height" as a list
	proc getWidthHeight { geometry } {
		set xpos [string last "x" $geometry]
		set width [string range $geometry 0 $xpos-1]
		set height [string range $geometry $xpos+1 end]
		return [lappend width $height]
	}
	#Returns size wxh fitted inside destination tile.
	proc getReadSize { w h dw dh } {
		if { $w > $h } {
			set dh [ expr {$h*$dw/$w} ]
		} else {
			set dw [ expr {$w*$dh/$h} ]
		}
		return "\[$dw\x$dh\]"
	}
	#color transforms
	set rgbout [setRGBColor $bgcolor $bgop]
	lappend rgbout [setRGBColor $bordercol $brop]
	lappend rgbout [setRGBColor $tfill $tfop]
	#Run montage
	set count 0
	#Set new maximum length to progress bar to total of collage * 2
	progressUpdate false [expr {[llength $clist] * 2}]

	#Iterate all collage lists
	foreach i $clist {
		set index 0
		foreach j $i {
			set imagesize [getWidthHeight [dict get $imcat $j geometry] ]
			#Set target size equal to image size to avoid resize on read
			if { $sizeval == ""} {
				set sizefirst [lindex $imagesize 0]
				set sizelast [lindex $imagesize 1]
			}
      puts "$sizefirst $sizelast $imagesize"
			set inputsize [getReadSize [lindex $imagesize 0] [lindex $imagesize 1] $sizefirst $sizelast]
			#Add size input string to each read in file: image.jpg[200x200]
			lset i $index [concat $j$inputsize]
			incr index
		}
		set tmpvar ""
		set name [ append tmpvar $mname "_" $count ]
		set tmpname [file join "/tmp" $name]
		eval exec montage -quiet $label $i -geometry "$sizeval+$mspace+$mspace" -border $mborder -background [lindex $rgbout 0] -bordercolor [lindex $rgbout 1] $tileval -fill [lindex $rgbout 2]  "png:$tmpname"
		dict set paths $tmpname [file join $path $name]
		incr count
		#udpate progressbar
		progressUpdate
	}
	lappend rlist [dict keys $paths] $paths
	return $rlist
}
#Run Converters
#gimp process
proc processGimp [list [list olist $gimplist] [list outext $outextension] ] {
	set ifiles ""
	if [llength $olist] {
		foreach i $olist {
			#Sends file input for processing, stripping input directory
			set io [setOutputName $i "png" 0 0 0 1]
			set outname [lindex $io 0]
			set origin [lindex $io 1]
			#Make png to feed convert
			#We set the command outside for later unfolding or it won't work.
			set cmd "(let* ( (image (car (gimp-file-load 1 \"$i\" \"$i\"))) (drawable (car (gimp-image-merge-visible-layers image CLIP-TO-IMAGE))) ) (gimp-file-save 1 image drawable \"/tmp/$outname\" \"/tmp/$outname\") )(gimp-quit 0)"
			#run gimp command, it depends on file extension to do transforms.
			catch { exec gimp -i -b $cmd } msg
			#udpate progressbar
			progressUpdate

			set errc $::errorCode;
			set erri $::errorInfo
			puts "errc: $errc \n\n"
			#puts "erri: $erri"
			if {$errc != "NONE"} {
				append ::lstmsg "EE: $i discarted\n"
				puts $msg
				continue
			}
			#Add png to argv file list on /tmp dir and originalpath to dict
			dict set ifiles [file join "/" "tmp" "$outname"] [file join $origin $i]
		}
	}
	return $ifiles
}
#Inkscape converter
proc processInkscape [list {outdir "/tmp"} [list olist $inkscapelist] ] {
	set ifiles ""
	set sizeval [getSizeSel]
	if [llength $olist] {
		foreach i $olist {
			set inksize "-d 90"
			if {$::sizesel || $::tilesel } {
				if {![string match -nocase {*[0-9]\%} $sizeval]} {
					set inksize [string range $sizeval 0 [string last "x" $sizeval]-1]
					set inksize "-w $inksize"
				} else {
					set inksize [string range $sizeval 0 [string last "%" $sizeval]-1]
					set inksize [expr {90 * ($inksize / 100.0)} ]
					set inksize "-d $inksize"
				}
			}
			#Sends file input for processing, stripping input directory
			set io [setOutputName $i "png" 0 0 0 1]
			set outname [file join $outdir [lindex $io 0]]
			set origin [lindex $io 1]
			#Make png to feed convert
			#Inkscape error handling works ok in most situations. errorCode is always reported as NONE so it isn't reliable.
			if { [catch { exec inkscape $i -z -C $inksize -e $outname } msg] } {
				append lstmsg "EE: $i discarted\n"
				puts $msg
				continue
			}
			#udpate progressbar
			progressUpdate
			#Add png to argv file list on /tmp dir and originalpath to dict
			dict set ifiles $outname [file join $origin $i]
		}
	}
	return $ifiles
}
#Calligra converter
proc processCalligra [list {outext "png"} [list olist $calligralist] {outdir "/tmp"} ] {
	set ifiles ""
	if [llength $olist] {
		foreach i $olist {
			#Sends file input for processing, stripping input directory
			set io [setOutputName $i $outext 0 0 0 1]
			set outname [file join $outdir [lindex $io 0]]
			set origin [lindex $io 1]
			#Make png to feed convert
			#We dont wrap calligraconverter on if else state because it reports all msg to stderror
			catch { exec calligraconverter --batch -- $i $outname } msg
			#udpate progressbar
			progressUpdate

			#Error reporting, if code NONE then png conversion success.
			set errc $::errorCode;
			set erri $::errorInfo
			puts "errc: $errc \n\n"
			if {$errc != "NONE"} {
				append ::lstmsg "EE: $i discarted\n"
				puts $msg
				continue
			}
			#Add png to argv file list on /tmp dir and originalpath to dict
			dict set ifiles $outname [file join $origin $i]
		}
	}
	return $ifiles
}

#Run convert
proc convert [list [list argv $argv] ] {
	global outextension iquality identify
	global renamesel prefixsel keep bgcolor

	#Create progress bar
	progressUpdate 0 0 1

	#Before checking all see if user only wants to rename
	if {$renamesel} {
		renameFile [concat $::gimplist $::calligralist $::inkscapelist $argv]
		exit
	}
	# Chek output extension, if asked for one with layers try to preserve them.
	if { [regexp {ora|kra} $outextension ] } {
		set inkfiles [processInkscape "."]
		set inklist [dict keys $inkfiles]
		set calfiles [processCalligra $outextension [concat $::gimplist $::calligralist $inklist $argv] ]
		renameFile [dict keys $calfiles] $calfiles
		append ::lstmsg "[llength [dict keys $calfiles]] files converted"

	} else {
		if { $outextension == "jpg" } {
			set alpha "-background $bgcolor -alpha remove"
		} else {
			set alpha ""
		}
	
		#Run watermark preprocess
		set watval [watermark]

		#We check if user wants resize and $sizeval not empty
		set resizeval [getSizeSel 0 0]

		#TODO Integrate to a function and to the whole program
		if {[string is list $::sizext] && $::sizesel} {
			set outsizes $::sizext
		} else {
			set outsizes [list $resizeval]
		}

		#Declare a empty list to fill with tmp files for deletion
		set tmplist ""

		#Declare empty dict to fill original path location
		set paths [dict create]

		#Call gimp batchmode and return tmp files location
		set gimfiles [processGimp]

		#Call calligra convert and return tmp files location
		set calfiles [processCalligra]

		#Call inkscape convert and return tmp files location
		set inkfiles [processInkscape]

		#Generate one dict to rule them all
		set tmpfiles [dict merge $gimfiles $calfiles $inkfiles]

		#Store total vector transformed files to later skip from resize.
		set tmpcount [ expr {[llength $inkfiles] /2}]

		#Unset unused vars
		unset gimfiles calfiles inkfiles

		#populate argv to convert and tmplist to remove at the end.
		#missing, used dict values to convert and erase
		dict for {tmpname origin} $tmpfiles {
				dict set paths $tmpname $origin
				lappend argv $tmpname
				lappend tmplist $tmpname
		}

		if [llength $argv] {
			set m 0
			# Real data validation
			# this operation populate a dict with image width and height.
			# so we only run identify once in the script to gain speed.
			set goodargv {}
			foreach i $argv {
				if { [catch {set finfo [exec {*}[split $identify " "] $i ] } msg ] } {
					puts $msg
					append ::lstmsg "EE: $i discarted\n"
					continue
				} else {
					lappend goodargv $i
					#we set double | to avoid mistakes with files layered or animated(GIF)
					set iminfo [split [string trim $finfo "|"] "|"]
					foreach { dm f n } $iminfo {
						 dict set collist $i geometry $dm
						 dict set collist $i iformat $f
						 dict set collist $i magicknam $n
					}
				}
			}
			set argv $goodargv
			#Get total files from raster formats
			set tmpcount [expr {[llength $goodargv] - $tmpcount} ]
			#Set new max value for files to convert, update progressbar
			progressUpdate 0 [llength $argv]

			if {$::tilesel && [llength $argv] > 0 } {
				#If paths comes empty we get last file path as output directory
				# else we use the last processed tmp file original path
				if {[string is false $paths]} {
					set path [file dirname [lindex $argv end] ]
				} else {
					set path [file dirname [dict get $paths $tmpname] ]
				}

				#Run command return list with file paths
				set clist [collage $argv $path $collist]

				set paths [dict merge $paths [lindex $clist 1]]
				#Overwrite image list with tiled image to add watermarks or change format
				set argv [lindex $clist 0]
				set tmplist [concat $tmplist $argv]
				#Add mesage to lastmessage
				append ::lstmsg "Collage done \n"
				#Set size to empty to avoid resizing
				set outsizes "100%"
			}
			foreach i $argv {
				#Set resize to none when index reachs first vector image.
				if {$tmpcount == $m} { set resizeval {} }
				incr m
				#Get outputname with suffix and extension
				if { $keep } { keepExtension $i }

				#Check if there is entry in tmp file dict to use original path
				if { [catch { set ordir [dict get $paths $i]} msg ] } {
					set ordir ""
				}
				#Setting this to zero avoids adding a size suffix if only one size selected
				set sizecounter [expr {[llength $outsizes]-1}]

				foreach resize $outsizes {
					set io [setOutputName $i $outextension $prefixsel 0 $ordir 0 $resize $sizecounter]
					set outname [lindex $io 0]
					set origin [lindex $io 1]

					set outputfile [file join $origin $outname]
					puts "outputs $outputfile"
					#If output is ora we have to use calligraconverter
					set unsharp [string repeat "-unsharp 0.48x0.48+0.50+0.012 " 1]
					if { ![string is boolean $resize] } {
						
						set resize "-colorspace RGB -interpolate bicubic -filter Lanczos2 -resize $resize\\> $unsharp -colorspace sRGB"
					}
					#Run command
					eval exec convert -quiet {$i} $alpha $resize $watval $unsharp -quality $iquality {$outputfile}
				}
				#udpate progressbar
				progressUpdate
			}
			#cleaning tmp files
			foreach tmpf $tmplist {  file delete $tmpf }
			append ::lstmsg "$m files converted"
		}
	}
	alert ok info "Operation Done\n" $::lstmsg
	exit
}
#Prepares output name adding Suffix or Prefix
#Checks if destination file exists and adds a standard suffix
proc setOutputName { oname fext { oprefix false } { orename false } {ordir false} {tmprun false} {size false} {singleresize 0} } {
	if { [string is boolean $size] || !$singleresize } {
		set size ""
	}
	set tmpprefix ""
	if {$tmprun} { set tmpsuffix "" } else { set tmpsuffix $::suffix }
	if {![string is boolean $ordir]} {
		set oname $ordir
	}
	set dir [file dirname $oname]
	set name [file rootname [file tail $oname]]
	set ext [file extension $oname]
	set safe ""
	if {$oprefix} {
		set tmpprefix $tmpsuffix
		set tmpsuffix ""
	}

	set newname [concat $tmpprefix [list $name] $tmpsuffix "$size"]
	set newname [join $newname "_"]
	if { [file exists [file join $dir "$newname.$fext"] ] } {
		incr s
		set safe "_atk$s"
	}
	append cname $newname $safe "." $fext
	#set fname [file join $dir $cname]

	set olist ""
	return [lappend olist $cname $dir]
}
#Return output name to use in GUI
proc getOutputName { {indx 0} } {
	#Concatenate both lists to always have an output example name
	set i [lindex [concat $::argv $::gimplist $::calligralist $::inkscapelist] $indx]
	return [lindex [setOutputName $i $::outextension $::prefixsel] 0]
}

