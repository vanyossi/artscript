#!/usr/bin/wish
# Script inspired by David Revoy (www.davidrevoy.com , info@davidrevoy.com )
# About format based on his Artscript comments.
#----------------:::: ArtscriptTk ::::----------------------
# IvanYossi colorathis.wordpress.com ghevan@gmail.com  GPL 3.0
#-----------------------------------------------------------
# Goal : Batch convert any image file supported by imagemagick and calligra.
# Dependencies (that I know of) : calligraconverter, imagemagick, tk 8.5
# Testednn: Xfce 4.10, thunar 1.4.0
#      Program should run on Mac if imagemagick is installed
#-------------------------------------------------------------
# Disclamer: I'm not a developer, I learn programming on spare time. Caution in use.
# 
# __How to install__ (XFCE)
#   Place script somewhere in your home folder
#   Make executable
#   Open thunar>Edit>Configure Custom Actions...
#   Add New action (+) 
#   Select a Name, Description and Icon. Add this to Command
#     --> wish path/to/script/ artscript.tcl %N
#   In Apperance Conditions Tab, set '*' as file pattern and select
#     Image files and Other files
#
# __Usage:__
#   A new submenu appears on right-click of Image Files
#   Select files, right-click , select the item on the menu, use GUI.
#   Watermark: Select any preset or add custom in empty field at bottom.
#     Select color and opacity value. By defult is white
#   Size: By default is off: Select from list or set a new value instead of "200x200"
#   Output Select from radioboxes or set custom in the field at the right
#   Suffix is off by default. Add any text to activate.
#     the string will have an underscore before any text you input
#   Press Convert to Run
#
#   Make grid Please checkbutton will generate a Tiled imagen containing all selected images
#
# __Customize:__
#   You can modify any variable between "#--=====" markers
#
#

#--====User variables, date preferences, watermarks, sizes, default values
set now [exec date +%F]
#Get a different number each run
set raninter [exec date +%N]
set autor "Your Name Here"
set watermarks [list \
  "Copyright (c) $autor" \
  "Copyright (c) $autor\_$now" \
  "http://www.yourwebsite.com" \
  "Artwork: $autor" \
  "$now" \
]
set sizes [list \
  "1920x1920" \
  "1650x1650" \
  "1280x1280" \
  "1024x1024" \
  "800x800" \
  "150x150" \
  "100x100" \
  "50%" \
]
set suffixes [list \
  "net" \
  "archive" \
  "by-[string map -nocase {{ } -} $autor]" \
  "my-cool-suffix" \
]
set sizext "200x200"
set opacity 0.8
set rgb "#ffffff"
#Image quality
set sliderval 92
#Extension & output
set ::outextension "jpg"
#Montage:
# mborder Adds a grey border around each image. set 0 disable
# mspace Adds space between images. set 0 no gap
set ::mborder 5
set ::mspace 3
# moutput Montarge filename output
set ::mname "collage-$raninter"
#--=====

#Las message variable
set lstmsg ""
set suffix ""

#Validation Functions
#Finds program in path using which, return 0 if program missing
proc validate {program} {
  if { [catch {exec which $program}] } {
     return 0
  }
  return 1
}
#Inkscape path, if true converts using inkscape to /tmp/*.png
set hasinkscape [validate "inkscape"]
#calligraconvert path, if true converts using calligra to /tmp/*.png
set hascalligra [validate "calligraconverter"]

#Function to send message boxes
proc alert {type icon title msg} {
    tk_messageBox -type $type -icon $icon -title $title \
    -message $msg
}
#Check if we have files to work on, if not, finish program.
if {[catch $argv] == 0 } { 
  alert ok info "Operation Done" "No files selected Exiting"
  exit
}
# listValidate:
# Validates arguments input mimetypes, keeps images strip the rest
# Creates a separate list for .kra, .xcf, .psd and .ora to process separatedly
proc listValidate {} {
  global argv calligralist inkscapelist lfiles fc hasinkscape hascalligra
  set lfiles "Files to be processed\n"
  set fc 0
  set calligralist [list]
  set inkscapelist ""
  #We validate list elements
  foreach el $argv {
    #puts [exec file $el]
    #Append to new list if mime is from type.
    if { [ regexp {application/x-krita|image/openraster|GIMP XCF image data|Adobe Photoshop Image} [exec file $el] ] && $hascalligra } {
      lappend calligralist $el
      append lfiles "$fc Cal: $el\n"
      set argv [lsearch -all -inline -not -exact $argv $el]
      incr fc
      continue
    }
    #Append to inkscapelist
    if { [regexp {SVG Scalable Vector Graphics image} [exec file $el]] && $hasinkscape } {
      lappend inkscapelist $el
      append lfiles "$fc Ink: $el\n"
      set argv [lsearch -all -inline -not -exact $argv $el]
      incr fc
      continue
    }
    #Remove from list elements not supported by convert
    if { [catch { exec identify -quiet $el } msg] } {
      set argv [lsearch -all -inline -not -exact $argv $el]
    } else {
      append lfiles "$fc Img: $el\n"
      incr fc
    }
  }
  #Check if resulting lists have elements
  if {[llength $argv] + [llength $calligralist] + [llength $inkscapelist] == 0} {
    alert ok info "Operation Done" "No image files selected Exiting"
    exit
  }
}
#We run function to validate input mimetypes
listValidate

#For future theming
#tk_setPalette background black foreground white highlightbackground blue activebackground gray70 activeforeground black

#Gui construct. This needs to be improved a lot
#--- watermark options
labelframe .wm -bd 2 -padx 2m -pady 2m -font {-size 12 -weight bold} -text "Watermark options"  -relief ridge
pack .wm -side top -fill x

label .wm.title -font {-size 10} -text "Current color"

listbox .wm.listbox -selectmode single -height 6
foreach i $watermarks { .wm.listbox insert end $i }
bind .wm.listbox <<ListboxSelect>> { setSelectOnEntry [%W curselection] "wm" "watxt"}
entry .wm.entry -text "Custom" -textvariable watxt
bind .wm.entry <KeyRelease> { setSelectOnEntry false "wm" "watxt" }
label .wm.label -text "Selected:"

button .wm.color -text "Choose Color" -command setWmColor
canvas .wm.viewcol -bg $rgb -width 96 -height 32
.wm.viewcol create text 30 16 -text "click me"
canvas .wm.black -bg black -width 48 -height 16
canvas .wm.white -bg white -width 48 -height 16

label .wm.lopacity -text "Opacity:"
scale .wm.opacity -orient horizontal -from .1 -to 1.0 -resolution 0.1 \
  -variable opacity -showvalue 0 -command {writeVal .wm.lopacity "Opacity:" }

bind .wm.viewcol <Button> { setWmColor }
bind .wm.black <Button> { set rgb black; .wm.viewcol configure -bg $rgb }
bind .wm.white <Button> { set rgb white; .wm.viewcol configure -bg $rgb }

grid .wm.listbox -rowspan 5 -column 1 -sticky nesw
grid .wm.entry -row 5 -column 1 -sticky we
grid .wm.label -row 6 -column 1 -sticky ew
grid .wm.title -row 1 -column 2 -sticky nw
grid .wm.viewcol -row 2 -column 2 -sticky nesw
grid .wm.black -row 3 -column 2 -sticky nsew
grid .wm.white -row 3 -column 3 -sticky nsew
grid .wm.color -row 4 -column 2 -sticky ew
grid .wm.lopacity -row 5 -column 2 -sticky wns
grid .wm.opacity -row 6 -column 2 -sticky ew
grid .wm.title .wm.viewcol .wm.color .wm.lopacity .wm.opacity -columnspan 2
grid rowconfigure .wm 1 -weight 0
grid rowconfigure .wm 2 -weight 1
grid columnconfigure .wm 1 -weight 1
grid columnconfigure .wm {2 3} -weight 0
   
#--- Size options
labelframe .size -bd 2 -padx 2m -pady 2m -font {-size 12 -weight bold} -text "Size & Tile settings"  -relief ridge
pack .size -side top -fill x
#scrollbar binding function
proc showargs {args} {puts $args; eval $args}

listbox .size.listbox -selectmode single -relief flat -height 2
foreach i $sizes { .size.listbox insert end $i }
bind .size.listbox <<ListboxSelect>> { setSelectOnEntry [%W curselection] "size" "sizext"}
scrollbar .size.scroll -command {showargs .size.listbox yview} -orient vert
.size.listbox conf -yscrollcommand {showargs .size.scroll set}

message .size.exp -width 280 -justify center -text "\
 Size format can be expresed as: \nW x H or 40%, 50% \n\
 In Collage mode size refers to tile size\n\
 Size 200x200 + Tile 2x2 = w400 x h400"

#size and tile entry boxes and validation
entry .size.entry -textvariable sizext -validate key \
   -vcmd { regexp {^(\s*|[0-9])+(\s?|x|%%)(\s?|[0-9])+$} %P }
bind .size.entry <KeyRelease> { setSelectOnEntry false "size" "sizext" }
entry .size.tile -textvariable tileval -validate key \
   -vcmd { regexp {^(\s*|[0-9])+(\s?|x|%%)(\s?|[0-9])+$} %P }
bind .size.tile <KeyRelease> { .opt.tile select }
label .size.label -text "Size:"
label .size.txtile -text "Tile(ex 1x, 2x2):"

grid .size.listbox -row 1 -column 1 -sticky nwse
grid .size.scroll -row 1 -column 1 -sticky ens
grid .size.entry -row 2 -column 1 -sticky ews
grid .size.label -row 3 -column 1 -sticky wns
grid .size.exp -row 1 -column 2 -columnspan 2 -sticky nsew
grid .size.txtile -row 2 -column 2 -sticky e
grid .size.tile -row 2 -column 3  -sticky ws
grid rowconfigure .size 1 -weight 3
grid rowconfigure .size 2 -weight 1
grid columnconfigure .size 1 -weight 1
grid columnconfigure .size 2 -weight 0

#--- Format options
labelframe .ex -bd 2 -padx 2m -pady 2m -font {-size 12 -weight bold} -text "Output Format"  -relief ridge
pack .ex -side top -fill x
radiobutton .ex.jpg -value "jpg" -text "JPG" -variable outextension
radiobutton .ex.png -value "png" -text "PNG" -variable outextension
radiobutton .ex.gif -value "gif" -text "GIF" -variable outextension
radiobutton .ex.ora -value "ora" -text "ORA(No post)" -variable outextension
.ex.jpg select
label .ex.lbl -text "Other"
entry .ex.sel -text "custom" -textvariable outextension -width 4
text .ex.txt -height 3 -width 4
.ex.txt insert end $lfiles

#-- Select only rename no output transform
checkbutton .ex.rname -text "Only rename" \
    -onvalue true -offvalue false -variable renamesel
#-- Ignore output, use input extension as output.
checkbutton .ex.keep -text "Keep extension" \
    -onvalue true -offvalue false -variable keep
#--- Image quality options

scale .ex.scl -orient horizontal -from 10 -to 100 -tickinterval 25 \
    -label "" -length 150 -variable sliderval -showvalue 1
#    -highlightbackground "#666" -highlightcolor "#333" -troughcolor "#888" -fg "#aaa" -bg "#333" -relief flat
label .ex.qlbl -text "Quality:"
button .ex.good -text "Good" -command resetSlider;#-relief flat -bg "#888"
button .ex.best -text "Best" -command {set sliderval 100}
button .ex.poor -text "Poor" -command {set sliderval 30}

grid .ex.jpg .ex.png .ex.gif .ex.ora .ex.rname .ex.keep -column 1 -columnspan 2 -sticky w
grid .ex.jpg -row 1
grid .ex.png -row 2
grid .ex.gif -row 3
grid .ex.ora -row 4
grid .ex.sel -row 5 -column 2
grid .ex.lbl -row 5 -column 1
grid .ex.keep -row 6
grid .ex.rname -row 7
grid .ex.txt -column 3 -row 1 -columnspan 5 -rowspan 4 -sticky nesw
grid .ex.qlbl .ex.poor .ex.good .ex.scl .ex.best -row 6 -rowspan 2 -sticky we
grid .ex.qlbl -column 3
grid .ex.poor -column 4
grid .ex.good -column 5
grid .ex.scl  -column 6
grid .ex.best -column 7
grid columnconfigure .ex {1} -weight 0
grid columnconfigure .ex {6} -weight 1

#--- Suffix options
labelframe .suffix -padx 2m -pady 2m -font {-size 12 -weight bold} -text "Suffix"  -relief ridge
pack .suffix -side top -fill x

listbox .suffix.listbox -selectmode single -height 4
foreach i $suffixes { .suffix.listbox insert end $i }
bind .suffix.listbox <<ListboxSelect>> { setSelectOnEntry [%W curselection] "suffix" "suffix"}
label .suffix.label -text "Selected:"

entry .suffix.entry -textvariable suffix -validate key \
   -vcmd { string is graph %P }
bind .suffix.entry <KeyRelease> { setSelectOnEntry false "suffix" "suffix" }
checkbutton .suffix.date -text "Add Date Suffix" \
    -onvalue true -offvalue false -variable datesel -command setdateCmd
checkbutton .suffix.prefix -text "Prefix" \
    -onvalue true -offvalue false -variable prefixsel -command { setSelectOnEntry false "suffix" "suffix" }

grid .suffix.listbox -column 1 -rowspan 4 -sticky nsew
grid .suffix.label -row 1 -column 2 -columnspan 3 -sticky nsew
grid .suffix.entry -row 2 -column 2 -columnspan 3 -sticky ew
grid .suffix.date -row 3 -column 2 -sticky w
grid .suffix.prefix -row 3 -column 4 -sticky w
grid columnconfigure .suffix {1} -weight 0
grid columnconfigure .suffix {2} -weight 1

#pack .suffix.entry -side left -fill x -expand 1
#pack .suffix.rname .suffix.prefix .suffix.date -side right

#--- On off values for watermark, size, date suffix and tiling options
frame .opt -borderwidth 2
pack .opt
checkbutton .opt.watxt -text "Watermark" \
    -onvalue true -offvalue false -variable watsel
checkbutton .opt.sizext -text "Resize" \
    -onvalue true -offvalue false -variable sizesel
checkbutton .opt.tile -text "Make Collage" \
    -onvalue true -offvalue false -variable tilesel

pack .opt.watxt .opt.sizext .opt.tile -side left

#--- Submit button
frame .act -borderwidth 6
pack .act -side right
button .act.submit -text "Convert" -font {-weight bold} -command convert
pack .act.submit -side right -padx 0 -pady 0


#--- Window options
wm title . "Artscript -- $fc Files selected"

#General Functions

#Controls watermark text events.
#proc setWatermark { indx } {
#  global watxt
#  #Check if variable comes from list, if not then get value from entry text
#  if {$indx} { 
#    set val [.wcol.listbox get $indx]
#  } else {
#    set val [.wcol.custom get]
#  }
#  .wcol.label configure -text "Selected: $val"
#  #If anything is selected we set Watermark option on automatically
#  .opt.wm select
#  set watxt $val
#}

proc setWmColor {} {
  global rgb
  #Call color chooser and store value to set canvas color and get rgb values
  set choosercolor [tk_chooseColor -title "Watermark color" -initialcolor $rgb -parent .]
  if { [expr {$choosercolor ne "" ? 1 : 0}] } {
    uplevel set rgb $choosercolor
    .wm.viewcol configure -bg $rgb
  }
}
#Converts hex color value and returns rgb value with opacity setting to alpha channel
proc setRGBColor { } {
  global rgb opacity
  #Transform hex value to rgb 16bit
  set rgbval [ winfo rgb . $rgb ]
  set rgbn "rgba("
  foreach i $rgbval {
    #For each value we divide by 256 to get 8big rgb value (0 to 255)
    #I set it to 257 to get integer values, need to check this further.
    append rgbn "[expr $i / 257],"
  }
  append rgbn "$opacity)"
  return $rgbn
}

#Recieves an indexvalue a rootname and a global variable to call
#Syncs listbox values with other label values and entry values
proc setSelectOnEntry { indx r g } {
  global $g
  #Check if variable comes from list, if not then get value from entry text
  if { [string is integer $indx] } { 
    set val [.$r.listbox get $indx]
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
    .$r.label configure -text "Output: [getOutputName]"
  }
}


#Sets text label to $val This function needs to generalize a lot more.
proc writeVal { l text val } {
  $l configure -text "$text $val"
}

#Set slider value to 75
#The second funciton i made, probably its a good idea to strip it
proc resetSlider {} {
  global sliderval
  set sliderval 92
}

#Function that controls suffix date construction
proc setdateCmd {} {
  global datesel now suffix
  #We add the date string if checkbox On
  if {$datesel} {
    uplevel append suffix $now
    .suffix.label configure -text "Output: [getOutputName]"
  } else {
  #If user checkbox to off
  #We erase it when suffix is same as date
    if { $suffix == "$now" } {
      uplevel set suffix "{}"
    } else {
  #Search date string to erase from suffix
      uplevel set suffix [string map -nocase "$now { }" $suffix ]
    }
  }
}
proc keepExtension { i } {
  global outextension
  uplevel set outextension [ string trimleft [file extension $i] "."]
}
#Run function
proc convert {} {
  global outextension sliderval watsel watxt sizesel sizext tilesel now argv calligralist inkscapelist
  global renamesel prefixsel tileval keep mborder mspace mname
  set sizeval $sizext
  # For extension with no alpha channel we have to add this lines so the user gets the results
  # he is expecting
  if { $outextension == "jpg" } {
    set alpha "-background white -alpha remove"
  } else {
    set alpha ""
  }
  #Before checking all see if user only wants to rename
  if {$renamesel} {
    if [llength $calligralist] {
      foreach i $calligralist {
        if {$keep } { keepExtension $i }
        set io [setOutputName $i $outextension $prefixsel $renamesel]
        file rename $i $io
      }
    }
    if [llength $argv] {
      foreach i $argv {
        if {$keep } { keepExtension $i }
        set io [setOutputName $i $outextension $prefixsel $renamesel]
        file rename $i $io
      }
    }
    exit
  }
  set rgbout [setRGBColor]
  #Watermarks, we check if checkbox selected to add characters to string
  set watval ""
  if {$watsel} {
    set watval "-pointsize 10 -fill $rgbout -gravity SouthEast -draw \"text 10,10 \'$watxt\'\""
#png32:- | convert - -pointsize 10 -fill  -gravity SouthEast -annotate +3+3 "
  }
  #Size, checbox = True set size command
  #We have to trim spaces?
  set sizeval [string trim $sizeval]
  #We check if user wants resize and $sizeval not empty
  if {!$sizesel || [string is boolean $sizeval] || $sizeval == "x" } {
    set sizeval ""
    set resizeval ""
  } else {
    set resizeval "-resize $sizeval\\>"
  }
  #Declare a empty list to fill with tmp files for deletion
  set tmplist ""
  #Declare empty dict to fill original path location
  set paths [dict create]
  if [llength $calligralist] {
    foreach i $calligralist {
      #Make png to feed convert, we feed errors to dev/null to stop calligra killing
      # the process over warnings, and exec inside a try/catch event as the program send
      # a lot of errors on some of my files breaking the loop
      #Sends file input for processing, stripping input directory
      set io [setOutputName $i "artscript_temppng" 0 0 1]
      set outname [lindex $io 0]
      set origin [lindex $io 1]
      catch [ exec calligraconverter --batch $i -mimetype image/png /tmp/$outname 2> /dev/null ]
      #Add png to argv file list on /tmp dir and originalpath to dict
      dict set paths /tmp/$outname $origin
      lappend argv /tmp/$outname
      lappend tmplist /tmp/$outname
    }
  }
  if [llength $inkscapelist] {
    foreach i $inkscapelist {
      set inksize ""
      if {$sizesel || $tilesel } {
        if {![string match -nocase {*[0-9]\%} $sizeval]} {
          set mgap [expr [expr $mborder + $mspace ] *2 ]
          set inksize [string range $sizeval 0 [string last "x" $sizeval]-1]
          set inksize "-w $inksize"
        } else {
          set inksize [expr 90 * [ expr 50 / 100.0 ] ]
          set inksize "-d $inksize"
        }
      }
      #Make png to feed convert, we try catch, inkscape cant be quiet
      #Sends file input for processing, stripping input directory
      set io [setOutputName $i "artscript_temppng" 0 0 1]
      set outname [lindex $io 0]
      set origin [lindex $io 1]
      catch [ exec inkscape $i -z -C $inksize -e /tmp/$outname 2> /dev/null ]
      #Add png to argv file list on /tmp dir and originalpath to dict
      dict set paths /tmp/$outname $origin
      lappend argv /tmp/$outname
      lappend tmplist /tmp/$outname
    }
  }
  if [llength $argv] {
    if {$tilesel} {
      #we set a name for tiled image (temp)
      set tmpvar ""
      set mname [ append tmpvar "/tmp/" $mname ".artscript_temppng" ]
      #If paths comes empty we get last file path as output directory
      # else we use the last processed tmp file original path
      if {[string is false $paths]} {
        dict set paths $mname [file dirname [lindex $argv end] ]
      } else {
        set origin [dict get $paths /tmp/$outname]
        dict set paths $mname $origin
      }
      #Run command
      # We still have to add a way to resize it and set tile preferences (1x, 2x2 etc)
      #We removed -label '%f' because we cant choose name placement.
      if {![string is boolean $tileval]} {
        set tileval "-tile $tileval"
      }
      #We have to substract the margin from the tile value, in this way the user gets
      # the results is expecting (200px tile 2x2 = 400px)
      if {![string match -nocase {*[0-9]\%} $sizeval]} {
        set mgap [expr [expr $mborder + $mspace ] *2 ]
        set xpos [string last "x" $sizeval]
        set sizelast [expr [string range $sizeval $xpos+1 end]-$mgap]
        set sizeval [expr [string range $sizeval 0 $xpos-1]-$mgap]
        set sizeval "$sizeval\x$sizelast\\>"
      }
      eval exec montage -quiet $argv -geometry "$sizeval+$mspace+$mspace" -border $mborder $tileval "png:$mname"
      #Overwrite image list with tiled image to add watermarks or change format
      set argv $mname
      lappend tmplist $mname
      #Add mesage to lastmessage
      append lstmsg "Collage done \n"
      #Set size to empty to avoid resizing
      set resizeval ""
    }
    foreach i $argv {
      incr m
      #Get outputname with suffix and extension
      if { $keep } { keepExtension $i }
      set io [setOutputName $i $outextension $prefixsel]
      set outname [lindex $io 0]
      if {[dict exists $paths $i]} {
        set origin [dict get $paths $i]
      } else {
        set origin [lindex $io 1]
      }
      set outputfile [append origin "/" $outname]
      puts $outputfile
      #If output is ora we have to use calligraconverter
      if { [regexp {ora|kra|xcf} $outextension] } {
        if {!$keep } {
          eval exec calligraconverter --batch $i $outputfile 2> /dev/null
        }
      } else {
    #Get color space to avoid color shift
    set colorspace [lindex [split [ exec identify -quiet -format %r $i ] ] 1 ]
    #Run command
        eval exec convert -quiet $i $alpha -colorspace $colorspace $resizeval $watval -quality $sliderval $outputfile
        #Add messages to lastmessage
        #append lstmsg "$i converted to $io\n"
      }
    }
    #cleaning tmp files
    foreach tmpf $tmplist {  file delete $tmpf }
    append lstmsg "$m files converted"
 }
  alert ok info "Operation Done" $lstmsg
  exit
}
#Prepares output name adding Suffix or Prefix
#Checks if destination file exists and adds a standard suffix
proc setOutputName { fname fext { opreffix false } { orename false } {tmpdir false} } {
  global suffix
  set tmpsuffix $suffix
  set ext [file extension $fname]
  set finalname ""
  #Checks if path is defined as absolute path, like when we create a file in /tmp directory
  #Strips directory leaving file in current directory
  #if { [file pathtype $fname] == "absolute" } {
    #get filepath origin path
    set origpath [file dirname $fname]
    set fname [lindex [file split $fname] end]
  #}
  #Append suffix if user wrote something in entryfield
  if { [catch $tmpsuffix] && !$tmpdir} {
    if {$opreffix && $orename} {
    #Makes preffix instead of suffix
      set fname [append tmpsuffix _$fname]
    } elseif {$orename} {
    #Makes suffix but rename
      set fname [string map -nocase "$ext _$tmpsuffix$ext" $fname ]
    } elseif {$opreffix} {
      set newnam [string map -nocase "$ext .$fext" $fname ]
      set fname [append tmpsuffix _$newnam]
    } else { 
    append finalname _$tmpsuffix
    }
  }
  #If file exists we add string to avoid overwrites
  if { [file exists [string map -nocase "$ext $finalname.$fext" $fname ] ] } {
    append finalname "_artkFile_"
  }
  append finalname ".$fext"

  #If no extension we add the extension
  if { $ext == "" } {
    set fname [append fname $finalname]
  } else {
    #we search for the extension string and replace it with (suffix and/or date) and extension
    set fname [string map -nocase "$ext $finalname" $fname ]
  }
  #If file is called from tmpdir we return a tupple with the original file location
  return [lappend fname $origpath]
}
proc getOutputName { {indx 0} } {
  global outextension prefixsel argv calligralist inkscapelist
  #Concatenate both lists to always have an output example name
  set i [lindex [concat $argv $calligralist $inkscapelist] $indx]
  return [lindex [setOutputName $i $outextension $prefixsel] 0]
}

