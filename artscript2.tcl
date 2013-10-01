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
#--====User variables
#Extension, define what file tipes artscript should read.
package require Tk
ttk::style theme use clam

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
set ::wmtxt {}
set ::watermarks [list \
	"Copyright (c) $autor" \
	"Copyright (c) $autor / $date" \
	"http://www.yourwebsite.com" \
	"Artwork: $autor" \
	"$date" \
]
set ::wmsize 10
set ::wmpos {SouthWest}
set ::wmpositions [list "NorthWest" "North" "NorthEast" "West" "Center" "East" "SouthWest" "South" "SouthEast"]
#Place image watermark URL. /home/user/image
set ::wmimsrc ""
set ::iwatermarks [list \
	"Logo" \
	"Client Watermark" \
]
set ::iwatermarkspath [dict create \
	"Logo" "/path/to/logo" \
	"Client Watermark" "/path/to/watermarkimg" \
]
# dict get $dic key
set ::wmimpos "Center"
set ::wmimsize "0"
set ::wmimcomp "Over"

set ::watsel false

set ::wmcol "#000000"

#Sizes
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

#--=====
#Don't modify below this line
set ::version "v2.0-alpha"
set ::lstmsg ""
set ::gvars {tcl_rcFileName|tcl_version|argv0|argv|tcl_interactive|tk_library|tk_version|auto_path|errorCode|tk_strictMotif|errorInfo|auto_index|env|tcl_pkgPath|tcl_patchLevel|argc|tk_patchLevel|tcl_library|tcl_platform}
#Function to send message boxes
proc alert {type icon title msg} {
		tk_messageBox -type $type -icon $icon -title $title \
		-message $msg
}
#Validation Functions
#Finds program trying to get program version, return 0 if program missing
#proc validate {program} {
#	catch {set fail [exec -ignorestderr $program --version]} msg
#	if { [catch {set fail}] eq "1"} {
#		puts "$msg"
#		return 0
#	}
#  puts "$program found"
#	return 1
# }
proc validate {program} {
	expr { ![catch {exec which $program}] ? [return 1] : [return 0] }
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
	global gimplist calligralist inkscapelist identify inputfiles handlers ops fc
	
	set inputfiles [dict create]
	set handlers [dict create]
	set gimplist {}
	set calligralist {}
	set inkscapelist {}
	set imlist {}
	set fc 1
	
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
		set iname [file tail $i]
		if {[lsearch $ext $filext ] >= 0 } {
			if { [regexp {.xcf|.psd} $filext ] && $hasgimp } {
				lappend gimplist $i

				dict set inputfiles $fc name $iname
				dict set inputfiles $fc oname $iname
				set sizel [exec identify -format "%wx%h " $i ]

				dict set inputfiles $fc size [lindex $sizel 0]
				dict set inputfiles $fc ext [string trim $filext {.}]
				dict set inputfiles $fc path [file normalize $i]
				dict set handlers $iname "g"
				#append lfiles "$fc Gimp: $i\n"
				incr fc
				continue

			} elseif { [regexp {.svg|.ai} $filext ] && $hasinkscape } {
				if { [catch { exec inkscape -S $i | head -n 1 } msg] } {
					append lstmsg "EE: $i discarted\n"
					puts $msg
					continue
				}
				lappend inkscapelist $i

				set svgcon [exec inkscape -S $i | head -n 1]
				set svgvals [lrange [split $svgcon {,}] end-1 end]
				set size [expr {round([lindex $svgvals 0])}]
				append size "x" [expr {round([lindex $svgvals 1])}]

				dict set inputfiles $fc name $iname
				dict set inputfiles $fc oname $iname
				dict set inputfiles $fc size $size
				dict set inputfiles $fc ext [string trim $filext {.}]
				dict set inputfiles $fc path [file normalize $i]
				dict set handlers $iname "i"
				#append lfiles "$fc Ink: $i\n"
				incr fc
				continue

			} elseif { [regexp {.kra|.ora|.xcf|.psd} $filext ] && $hascalligra } {
				lappend calligralist $i
				set size "N/A"
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

				dict set inputfiles $fc name $iname
				dict set inputfiles $fc oname $iname
				dict set inputfiles $fc size $size
				dict set inputfiles $fc ext [string trim $filext {.}]
				dict set inputfiles $fc path [file normalize $i]
				dict set handlers $iname "k"
				incr fc
				continue

			} else {
				lappend imlist $i
				if { [catch {set finfo [exec {*}[split $identify " "] $i ] } msg ] } {
					puts $msg
					append ::lstmsg "EE: $i discarted\n"
					continue
				} else {
					set iminfo [split [string trim $finfo "|"] "|"]
				}
				dict set inputfiles $fc name [list $iname]
				dict set inputfiles $fc oname [list $iname]
				dict set inputfiles $fc size [lindex $iminfo 0]
				dict set inputfiles $fc ext [string trim $filext {.}]
				dict set inputfiles $fc path [file normalize $i]
				dict set handlers $iname "m"
				incr fc
			}
		} elseif { [string is boolean [file extension $i]] && !$options } {
			if { [catch { set f [exec {*}[split $identify " "] $i ] } msg ] } {
				puts $msg
			} else {
				incr fc
				lappend imlist $i
				if { [catch {set finfo [exec {*}[split $identify " "] $i ] } msg ] } {
					puts $msg
					append ::lstmsg "EE: $i discarted\n"
					continue
				} else {
					set iminfo [split [string trim $finfo "|"] "|"]
				}
				dict set inputfiles $fc name [list $iname]
				dict set inputfiles $fc oname [list $iname]
				dict set inputfiles $fc size [lindex $iminfo 0]
				dict set inputfiles $fc ext "[string tolower [lindex $iminfo 1]]"
				dict set inputfiles $fc path [file normalize $i]
				dict set handlers $iname "m"
				incr fc
				#append lfiles "$fc Mag: $i\n"
			}
		}
	}
	incr fc -1
	set argv $imlist
	#Check if resulting lists have elements
	if {[llength [dict keys $inputfiles]] == 0} {
		alert ok info "Operation Done" "No image files selected Exiting"
		exit
	}
	proc putsHandlers {c} {
		global handlers
		set ${c}fdict [dict filter $handlers script {k v} {expr {$v eq $c}}]
		puts [dict keys [set ${c}fdict]]
		#or puts [dict keys [subst $${c}fdict]]
	}
	putsHandlers "g"
	putsHandlers "i"
	putsHandlers "k"
	putsHandlers "m"
}
#We run function to validate input mimetypes
listValidate

#--- Window options
wm title . "Artscript $version -- $fc Files selected"

#Gui construct
proc wmproc {value} {
	if { !$::watsel } {
		.f2.ac.wm.checkwm invoke
	}
	puts $value
}
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

pack [ttk::frame .f1] -side top -expand 0 -fill x
ttk::label .f1.title -text "Artscript 2.0alpha"
pack .f1.title -side left

# pack [ttk::frame .m1] -side left -expand 1 -fill both

# Paned view
ttk::panedwindow .f2 -orient vertical
ttk::frame .f2.fb
ttk::notebook .f2.ac
.f2 add .f2.fb
.f2 add .f2.ac

# krita-thumbnailer %f /home/tara/.thumbnails/normal/$(echo -n file://%f | md5sum | cut -d ' ' -f 1).png 128
# set path [file normalize $afile]
# set mdfile [exec echo -n file://$path \| md5sum]
# display $env(HOME)/.thumbnails/large/$mdfile.png
# exec unzip -p morsa.kra preview.png | convert - GIF:/tmp/preview.gif
# exec unzip -p mono.ora Thumbnails/thumbnail.png | convert - GIF:/tmp/preview.gif
# set oldimg $img
# set img [image create photo -file /tmp/preview.gif ]
# % set img [image create photo -file /tmp/preview.gif ]
# image1
# % ttk::label .l -image $img
# .l
# % pack .l
# .l configure -image $img
# image delete $img $oldimg

proc showPreview { w f {tryprev 1}} {
	global inputfiles env

	proc makeThumb { path tsize } {
		set cmd [dict create]
		dict set cmd .ora {Thumbnails/thumbnail.png}
		dict set cmd .kra {preview.png}

		set filext [string tolower [file extension $path] ]

		if { [regexp {.ora|.kra} $filext ] } {
			set container [dict get $cmd $filext]
			catch {exec unzip $path $container -d /tmp/}
			set tmpfile "/tmp/$container"
			set path $tmpfile

			# remove gimp and psd thumnail if we cannot figure it out how to keep GUI responsive
		} elseif {[regexp {.xcf|.psd} $filext ]} {
			set tmpfile "atk-gimpprev.png"
			set cmd "(let* ( (image (car (gimp-file-load 1 \"$path\" \"$path\"))) (drawable (car (gimp-image-merge-visible-layers image CLIP-TO-IMAGE))) ) (gimp-file-save 1 image drawable \"/tmp/$tmpfile\" \"/tmp/$tmpfile\") )(gimp-quit 0)"
			#run gimp command, it depends on file extension to do transforms.
			catch { exec gimp -i -b $cmd } msg
			set tmpfile "/tmp/$tmpfile"
			set path $tmpfile
		}
		foreach {size dest} $tsize {
			catch {exec convert $path -thumbnail [append size x $size] -flatten PNG32:$dest} msg
		}
		catch {file delete $tmpfile}
	}

	set path [dict get $inputfiles $f path]

	set thumbname [lindex [exec echo -n "file://$path" \| md5sum] 0]
	set thumbdir "$env(HOME)/.thumbnails"
	set lthumb "${thumbdir}/large/$thumbname.png"
	set nthumb "${thumbdir}/normal/$thumbname.png"

	if { [file exists $lthumb ] } {
		global img oldimg
		set prevgif {/tmp/atkpreview.gif}
		
		exec convert $lthumb GIF:$prevgif
		catch {set oldimg $img}
		set img [image create photo -file /tmp/atkpreview.gif ]

		.f2.fb.lprev.im configure -image $img
		catch {image delete $oldimg}

		catch {file delete $prevgif}
		return

	} elseif { [file exists $nthumb] } {
		makeThumb $path [list 256 $lthumb]
	} else {
		makeThumb $path [list 128 $nthumb 256 $lthumb]
	}

	if {$tryprev} {
		showPreview w $f 0
	}
}

set fileheaders { id input ext size outname }
ttk::treeview .f2.fb.flist -columns $fileheaders -show headings
foreach col $fileheaders {
	set name [string totitle $col]
	.f2.fb.flist heading $col -text $name -command [list treeSort .f2.fb.flist $col 0 ]
}
#.f2.fb.flist heading input -text "File" -command { treeSort .f2.fb.flist input 0 }
#.f2.fb.flist heading output -text "Output Name" -command { treeSort .f2.fb.flist output 0 } 
#.f2.fb.flist heading size -text "Size" -command { treeSort .f2.fb.flist size 0 } 
.f2.fb.flist column id -width 48 -stretch 0
.f2.fb.flist column ext -width 48 -stretch 0
.f2.fb.flist column size -width 86 -stretch 0

dict for {inputfile datas} $inputfiles {
   dict with datas {
			set imgid$inputfile [.f2.fb.flist insert {} end  -values "{$inputfile} {$name} {$ext} {$size} {$oname}"]
   }
}

bind .f2.fb.flist <<TreeviewSelect>> { showPreview .m2.lprev.im [lindex [%W item [%W selection] -values] 0] }

ttk::labelframe .f2.fb.lprev -width 276 -height 276 -padding 6 -labelanchor n -text "Thumbnail"
# -labelwidget .f2.ac.checkwm
ttk::label .f2.fb.lprev.im -anchor center -text "No preview"

pack .f2.fb.flist -side left -expand 1 -fill both
pack .f2.fb.lprev -side left -expand 0 -fill both
pack propagate .f2.fb.lprev 0
pack .f2.fb.lprev.im -expand 1 -fill both


# ttk::checkbutton .f2.ac.checkwm -text "Watermark" -onvalue true -offvalue false -variable watsel

ttk::frame .f2.ac.wm

ttk::label .f2.ac.wm.ltext -text "Text"
ttk::combobox .f2.ac.wm.watermarks -state readonly -textvariable wmtxt -values $watermarks
.f2.ac.wm.watermarks set [lindex $watermarks 0]
bind .f2.ac.wm.watermarks <<ComboboxSelected>> { wmproc [%W get] }

ttk::label .f2.ac.wm.lsize -text "Size" -width 4
set fontsizes [list 8 10 11 12 13 14 16 18 20 22 24 28 32 36 40 48 56 64 72 144]
ttk::spinbox .f2.ac.wm.fontsize -width 4 -values $fontsizes -validate key \
	-validatecommand { string is integer %P }
.f2.ac.wm.fontsize set $wmsize
bind .f2.ac.wm.fontsize <ButtonRelease> { wmproc [%W get] }
bind .f2.ac.wm.fontsize <KeyRelease> { wmproc [%W get] }

ttk::label .f2.ac.wm.lpos -text "Position" -width 10
ttk::combobox .f2.ac.wm.position -state readonly -textvariable wmpossel -values $wmpositions -width 10
.f2.ac.wm.position set $wmpos
bind .f2.ac.wm.position <<ComboboxSelected>> { wmproc [%W get] }

ttk::label .f2.ac.wm.limg -text "Image"
ttk::combobox .f2.ac.wm.iwatermarks -state readonly -textvariable wmimsrc -values $iwatermarks
.f2.ac.wm.iwatermarks set [lindex $iwatermarks 0]
bind .f2.ac.wm.iwatermarks <<ComboboxSelected>> { wmproc [%W get] }

ttk::spinbox .f2.ac.wm.imgsize -width 4 -from 0 -to 100 -increment 10 -validate key \
	-validatecommand { string is integer %P }
.f2.ac.wm.imgsize set $wmimsize
bind .f2.ac.wm.imgsize <ButtonRelease> { wmproc [%W get] }
bind .f2.ac.wm.imgsize <KeyRelease> { wmproc [%W get] }

ttk::combobox .f2.ac.wm.iposition -state readonly -textvariable wmimpos -values $wmpositions -width 10
.f2.ac.wm.position set $wmpos
bind .f2.ac.wm.iposition <<ComboboxSelected>> { wmproc [%W get] }

grid .f2.ac.wm.lsize .f2.ac.wm.lpos -row 1 -sticky w
grid .f2.ac.wm.ltext .f2.ac.wm.watermarks .f2.ac.wm.fontsize .f2.ac.wm.position -row 2 -sticky we
grid .f2.ac.wm.limg .f2.ac.wm.iwatermarks .f2.ac.wm.imgsize .f2.ac.wm.iposition -row 3 -sticky we
grid .f2.ac.wm.ltext .f2.ac.wm.limg -column 1
grid .f2.ac.wm.watermarks .f2.ac.wm.iwatermarks -column 2
grid .f2.ac.wm.lsize .f2.ac.wm.fontsize .f2.ac.wm.imgsize -column 3
grid .f2.ac.wm.lpos .f2.ac.wm.position .f2.ac.wm.iposition -column 4
grid columnconfigure .f2.ac.wm {2} -weight 4


.f2.ac add .f2.ac.wm -text "Watermark"

ttk::frame .f2.ac.sz

.f2.ac add .f2.ac.sz -text "Resize"

ttk::treeview .f2.ac.sz.sizes -selectmode extended -show tree -yscrollcommand ".f2.ac.sz.sscrl set" -height 4
foreach size $sizes {
	.f2.ac.sz.sizes insert {} end -text $size
}
bind .f2.ac.sz.sizes <<TreeviewSelect>> { puts [%W selection] }
ttk::scrollbar .f2.ac.sz.sscrl -orient vertical -command { .f2.ac.sz.sizes yview }

pack .f2.ac.sz.sizes -side left -expand 1 -fill both
pack .f2.ac.sz.sscrl -side left -fill y


pack .f2 -side top -expand 1 -fill both


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

#gimp process
proc processGimp [list [list olist $gimplist] ] {
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

# width and height same as source (or BIG)
# exec
# convert -size 1284x897 xc:transparent -font Helvetica -pointsize 12 -gravity Center           -stroke rgba\(0,0,0,.2\) -strokewidth 1 -annotate 0 'Copyright ghevan' -blur 80x2   -background none +repage           -stroke none -fill rgba\(255,255,255,.7\) -annotate 0 'Copyright ghevan' -trim watermark2.png

# Make watermark to /tmp/image
# compose
# convert chara-design-test.png -gravity SouthEast watermark.png -compose dissolve -define compose:args=80 -composite  anno_fancy23.jpg
# args=80 = opacity 80%




