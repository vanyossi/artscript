#! /usr/bin/env wish
#
# ---------------:::: ArtscriptTk ::::-----------------------
#  Version: 2.1.11
#  Author:IvanYossi / http://colorathis.wordpress.com ghevan@gmail.com
#  Script inspired by David Revoy artscript / www.davidrevoy.com info@davidrevoy.com
#  License: GPLv3 
# -----------------------------------------------------------
#  Goal : Aid in the deploy of digital artwork for media with the best possible quality
#   Dependencies: >=imagemagick-6.7.5, tk 8.5 zip
#   Optional deps: calligraconverter, inkscape, gimp
#
#  Customize:__
#   Make a config file (rename presets.config.example to presets.config)
#   File must be in the same directory as the script.
#
# ---------------------::::::::::::::------------------------
set ::version "v2.2-alpha"

package require Tk
package require platform
package require msgcat
namespace import ::msgcat::mc

proc setArtscriptDirs {} {
	set home [file normalize ~]
	switch -glob -- [platform::identify] {
		macosx* { set ::artscript(platform) osx }
		windows* { set ::artscript(platform) win }
		default { set ::artscript(platform) linux }
	}
	switch -- $::artscript(platform) {
		osx -
		linux {
			set agent_dirs [dict create \
			home $home \
			config [file join $home .config artscript] \
			thumb_normal [file join $home .thumbnails normal] \
			thumb_large [file join $home .thumbnails large] \
			tmp [file join / tmp] \
			]
		}
		windows {}
	}
	
	set ::artscript(home) [dict get $agent_dirs home]
	set ::artscript(config) [dict get $agent_dirs config]
	set ::artscript(tmp) [dict get $agent_dirs tmp]
	set ::artscript(thumb_normal) [dict get $agent_dirs thumb_normal]
	set ::artscript(thumb_large) [dict get $agent_dirs thumb_large]

	# If folder does not exists, create it
	foreach thumb_dir {thumb_normal thumb_large} {
		if { ![file exists $::artscript($thumb_dir)] } {
			file mkdir $::artscript($thumb_dir)
		}
	}
	# get current running dir for lib
	set ::artscript(dir) [file dirname [file normalize [info script]]]
	set ::artscript(lib) [file join $::artscript(dir) lib]
}
setArtscriptDirs

lappend auto_path $::artscript(lib)

if {[info exist ::env(LANG)]} {
	::msgcat::mclocale $::env(LANG)
}
::msgcat::mcload [file join $::artscript(dir) msg]

catch {package require md5}

#Set default theme to clam if supported
if { [catch {ttk::style theme use aqua}] } {
	ttk::style theme use clam
}
# Do not show .dot files by default.
if { $::artscript(platform) ne {osx} } {
	catch { tk_getOpenFile foo bar }
	set ::tk::dialog::file::showHiddenVar 0
	set ::tk::dialog::file::showHiddenBtn 1
}

namespace eval img { }

proc tkpngLoad {args} {
	set load 0
	if {[catch {package require tkpng}] && ($::artscript(platform) eq {linux})} {
		set tkpng_dir [file join $::artscript(lib) tkpng0.9]
		set sys_id [split [platform::identify] {-}]
		if {[string match *64  [lindex $sys_id end]]} {
			file link -symbolic [file join $tkpng_dir libtkpng0.9.so] [file join $tkpng_dir libtkpng_x64-0.9.so]
		} else {
			file link -symbolic [file join $tkpng_dir libtkpng0.9.so] [file join $tkpng_dir libtkpng_x86-0.9.so]
		}
		if {[file exists [file join $tkpng_dir libtkpng0.9.so] ]} {
			package require tkpng
			set load 1
		}
	} else {
		set load 1
	}
	if {$load} {
		puts [mc "Tk png enabled"]
		return 1
	}
}

# TkDND module lookup
proc tkdndLoad {} {
	if {[catch {package require tkdnd}]} {
		set tkdnd_dir [file join $::artscript(lib) tkdnd]
		source [file join $tkdnd_dir "tkdnd.tcl"]
		foreach dll [glob -type f [file join $tkdnd_dir *tkdnd*[info sharedlibextension]] ] {
			catch{ tkdnd::initialise $tkdnd_dir [file tail $dll] tkdnd}
		}
	}
	puts [mc "Tk drag and drop enabled"]
	foreach {type} {DND_Text DND_Files } {
		::tkdnd::drop_target register .f2 $type
		bind .f2 <<Drop:$type>> { listValidate %D }
	}
	return -code ok
}
# lambda template
proc lambda {params body} {
	list apply [list $params $body]
}
# Declare default values for setting vars
proc artscriptSettings {} {
	# Date values
	set now [split [clock format [clock seconds] -format %Y/%m/%d/%u] "/"]
	lassign $now ::year ::month ::day
	set ::date [join [list $::year $::month $::day] "-"]
	
	#--==== Artscript Default Settings
	set mis_settings [dict create \
		ext ".ai .bmp .dng .exr .gif .jpeg .jpg .kra .miff .ora .png .psd .svg .tga .tif .xcf .xpm .webp" \
		autor "Autor" \
	]
	# Watermark options
	set wat_settings [dict create     \
		watermark_text  {}            \
		watermark_text_list           [list {Copyright (c) $::autor} {http://www.yourwebsite.com} {Artwork: $::autor} {$::date}] \
		watermark_text_size                10                  \
		artscript(watermark_color)              "#000000"           \
		watermark_text_opacity        80                  \
		watermark_text_position            [mc "BottomRight"]       \
		watermark_image_list          [dict create ] \
		watermark_image_position      [mc "Center"]            \
		watermark_image_size          "0"                 \
		watermark_image_style         "Over"              \
		watermark_image_opacity       100                 \
		artscript(watermark_color_swatches)     {}        \
		]
	#Sizes
	set siz_settings [dict create \
		sizes_set([mc "wallpaper"]) [list "2560x1440" "1920x1080" "1680x1050" "1366x768" "1280x1024" "1280x720" "1024x768"] \
		sizes_set([mc "percentage"]) "90% 80% 50% 25%" \
		sizes_set([mc "icon"]) "128x128 96x96 48x48 36x36" \
		sizes_set([mc "texture"]) "256x256 512x512" \
		sizes_set([mc "default"]) "" \
	]
	#Collage
	set col_settings [dict create \
		collage_styles([mc neutral]) "bg_color grey50 border_color grey40 label_color grey30 img_color grey50" \
		collage_styles([mc bright]) "bg_color grey88 border_color grey66 label_color grey30 img_color grey99" \
		collage_styles([mc dark]) "bg_color grey10 border_color grey20 label_color grey50 img_color grey5" \
		collage_styles([mc darker]) "bg_color grey5 border_color grey10 label_color grey45 img_color black" \
		collage_layouts([mc "Photo sheet"]) "ratio 3:2 wid 275 hei 183 col 6 row 5 range 30 border 1 padding 4 label {%f: (%G)} mode {}" \
		collage_layouts([mc "Storyboard"]) "ratio 16:9 wid 500 hei 281 col 3 row 3 range 9 border 1 padding 8 label {%f} mode {}" \
		collage_layouts([mc "Image Strip v"]) [list ratio 4:3 wid 300 hei {} col 1 row {} range {} border 0 padding 0 label {} mode [mc "Zero geometry"]] \
		collage_layouts([mc "Image Strip h"]) [list ratio 4:3 wid {} hei 300 col {} row 1 range {} border 0 padding 0 label {} mode [mc "Zero geometry"]] \
		collage_layouts([mc "Square 3x3"]) "ratio 1:1 wid 350 hei 350 col 3 row 3 range {} border 0 padding 2 label {} mode {}" \
	]

	#Suffix and prefix ops
	set suf_settings [dict create   \
		suffix_list    [list "net" "archive" {by-[string map -nocase {{ } -} $::autor]}] \
		out_prefix    {}              \
		out_suffix    {}              \
	]
	#General checkboxes
	set bool_settings [dict create  \
		artscript(select_watermark)        0          \
		artscript(select_watermark_text)   0          \
		artscript(select_watermark_image)  0          \
		artscript(select_size)             0          \
		artscript(select_collage)          0          \
		artscript(select_suffix)           0          \
		artscript(overwrite)               0          \
		artscript(alfaoff)		           {}         \
		artscript(alfa_color)	           "white"    \
		artscript(remember_state)          0          \
	]
	#Extension & output
	set supported_files_string [mc "Suported Images"]
	set out_settings [dict create \
		out_extension      "png"   \
		artscript(image_quality)    92      \
		artscript(supported_files) [dict create \
			all [list $supported_files_string    [dict get $mis_settings ext] ] \
			magick [list $supported_files_string  {.png .jpg .jpeg .gif .bmp .miff .svg .tif .webp} ] \
			calligra [list {KRA, ORA}       {.ora .kra}  ] \
			inkscape [list {SVG, AI}        {.svg .ai}   ] \
			gimp [list {XCF, PSD}           {.xcf .psd}  ] \
			png [list {PNG}                 {.png}       ] \
			jpg [list {JPG, JPEG}           {.jpg .jpeg} ] \
			gif [list {GIF}                 {.gif} ] \
		] \
		artscript(window_geom) {}
	]
	#--==== END of Artscript Default Settings
	set settings [dict merge $mis_settings $wat_settings $siz_settings $col_settings $suf_settings $bool_settings $out_settings]
	dict for {key value} $settings {
		set ::$key [subst $value]
	}
}

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
	puts [mc "Program %s not found" $program]
	return 0
}

# Modifies iname adding suffix, prefix, size and ext.
# If destination name file exists adds a standard suffix
# iname => file string, preffix suffix sizesuffix => string to append,
# orloc => filepath: Used to return destination to orignal loc in case of tmp files (KRA,ORA)
# returns filename.ext
proc getOutputName { iname out_extension { prefix {} } { suffix {} } { sizesufix {} } } {
	
	if {!$::artscript(select_suffix)} {
		set prefix {}
		set suffix {}
	} else {
		foreach val {prefix suffix} {
			set $val [expr {[set $val] eq "%mtime" ? [clock format [file mtime $iname] -format %Y-%m-%d] : [set $val]}]
		}
	}
	if {[string is upper [string index $out_extension 0]]} {
		set out_extension [string trim [file extension $iname] {.}]
	}
	
	set dir [file normalize [file dirname $iname]]
	set name [file rootname [file tail $iname]]
	# Name in brackets to protect white space
	set lname [concat $prefix [list $name] $suffix $sizesufix ]
	append outname [join $lname "_"] "." [lindex $out_extension 0]
	if {!$::artscript(overwrite)} {
		set tmpname $outname
		while { [file exists [file join $dir "$outname"] ] } {
			set outname $tmpname
			incr s
			set outname [join [list [string trimright $outname ".$out_extension"] "_$s" ".[lindex $out_extension 0]"] {} ]
		}
		unset tmpname
	}
	return $outname
}
# Replace % escapes for date values
proc replaceDateEscapes { name } {
	return [string map [list %% % %d $::day %m $::month %y $::year %D $::date] $name ]
}

# Parses the list $argv for (:key value) elements. breaks if string is file
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

# Get image properties Size, format and path of Image
# Receives an absolute (f)ile path
# Returns dict or error if file is not supported
proc identifyFile { f } {
	set identify [list identify -quiet -format {%wx%h:%m:%M:%b:%[colorspace]@@} -ping]
	if { [catch {set finfo [exec {*}$identify $f] } msg ] } {
		return -code break "$msg"
	} else {
		lassign [split [lindex [split $finfo @@] 0] ":"] size ext path fsize colorspace 
		set valist [list size $size ext [string tolower $ext] path $path colorspace $colorspace]
		return [dict merge $valist]
	}
}
# Read only the first n lines of a textFile and return the data
proc readFileHead { file_name {n 10} } {
	set file_path [file normalize $file_name]
	set data [open $file_path r]
	incr i
	while {(-1 != [gets $data line]) && ($i <= $n )} {
		append data_read $line\n
		incr i
	}
    close $data
    return $data_read
}

# Get SVG and AI Width and Height.
# Works with plain and normal svg saved from inkscape. TODO: testing
# returns string {widtxheight} or 0 if nothing found
proc getWidthHeightSVG { lines } {
	foreach l [split $lines] {
		set value [string trim [lsearch -inline -regexp -all [list $l] {^(.)*(width|height)} ] {<xapGImg/\"\\=:whidte>}]
		if {[string is integer -strict $value]} {
			lappend size $value
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
proc setDictEntries { id fpath size ext mode h {add 1}} {
	dict set ::inputfiles $id [dict create \
		name      [file tail $fpath] \
		output    [getOutputName $fpath $::out_extension $::out_prefix $::out_suffix] \
		size      $size \
		osize     [getOutputSizesForTree $size 1] \
		ext       [string trim $ext {.}] \
		path      [file normalize $fpath] \
		color     $mode \
		deleted   0 \
	]
	dict set ::handlers $id $h

	if {$add} {
		addTreevalues $::widget_name(flist) $id
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
		return -code break [mc "%s is not a valid ORA/KRA" $image_file]
	}
	set zipkey [regexp -inline -all -- {(w|h|width|height)="([[:digit:]]*)"} $zipcon]
	foreach {s val1 val2} $zipkey {
		lappend size_list [list $val1 $val2]
	}
	lassign [lsort -decreasing -index 0 $size_list] width height
	set size [join [list [lindex $width 1] [lindex $height 1]] {x}]

	return $size
}

# Validates the files supplied to be Filetypes supported by script
# Search order: gimp(xcf,psd) > inkscape(svg,ai) > calligra(kra,ora,xcf,psd) > allelse
# files list
proc listValidate { files {step 0} } {
	# global fc
	switch $step {
	0 {
		set ::artscript_in(count) 0
		after idle [list after 0 [list listValidate $files 1]]
	} 1 {
		set idnumber [lindex $files $::artscript_in(count)]
		incr ::artscript_in(count)
		
		if { $idnumber eq {} } { 
			updateWinTitle
			return
		}

		set i [encoding convertfrom $idnumber]
		set msg {artscript_ok}

		# Call itself with directory contents if arg is dir
		if {[file isdirectory $i]} {
			lappend files {*}[glob -nocomplain -directory $i -type f *]
			set msg directory
		} else {
			set filext [string tolower [file extension $i] ]
			if {[lsearch $::ext $filext] == -1} {
				set filext {}
			}
			# Get initial data to validate filetype
			switch -- $filext {
				.xcf     { binary scan [readFileHead $i 2] A14III f w h m
					set colormodes [list 0 sRGB 1 Grayscale 2 Indexed]
				 }
				.psd     { binary scan [readFileHead $i 2] a4SS3SIISS f s t fo h w depth m
					if {$s != 1} { set msg [mc "%s not a valid PSD file" $i] }
					set colormodes [dict create 0 Bitmap 1 Grayscale 2 Indexed 3 RGB 4 CMYK 7 Multichannel 8 Duotone 9 Lab]
				} 
				.ora     -
				.kra     { if { ![catch {set size [getOraKraSize $i $filext]} msg]} { set msg {artscript_ok} } }
				.svg     { set lines [readFileHead $i 34] }
				.ai      { binary scan [readFileHead $i 34] a10h18a145h14a2000 f s t fo lines 
					if {![string match %PDF* $f]} { set msg "error PDF" }
				}
				{}       { set msg [mc "%s file format not supported" $i] }
				default  { if { ![catch {set finfo [identifyFile $i ] } msg]} { set msg {artscript_ok} } }
			}
		}
		# If msg carries error, print and skip next phase
		if { $msg == "artscript_ok" } {
			set mode sRGB
			# Parse data into size and converter program
			switch -- $filext {
				.xcf     -
				.psd     {
					set handler [expr {$::hasgimp ? "g" : "k"}]
					set size [format {%dx%d} $w $h]
					set mode [dict get $colormodes $m]
				} 
				.ora     { set handler [expr {$::hasgimp ? "g" : "k"}] }
				.kra     { set handler [expr {$::hascalligra ? "k" : ""}]}
				.svg     -
				.ai      { 
					set size [getWidthHeightSVG $lines]
					set handler [expr {$::hasinkscape ? "i" : ""}]
				}
				default  {
					set size [dict get $finfo size]
					set ext [dict get $finfo ext]
					set mode [dict get $finfo colorspace]
					set handler "m"
				}
			}
			# Confirm calligra is available if not, do not add to list
			if { $handler eq "k" && !$::hascalligra } {
				set handler {}
			}
			if { $size != 0 && $handler ne {} } {
				setDictEntries $::fc $i $size $filext $mode $handler
			}
			
		} else {
			puts $msg
		}
		incr ::fc
		if {($::fc % 11) == 0} {
			# reduce the amount of list calculation, useful for extremely long lists
			updateWinTitle
		}
		after idle [list after 0 [list listValidate $files 1]]
	}}
}

# Searchs for presets.config in script directory, parses and set values from file to global
proc getUserPresets {} {
	global ops
	set presets [dict create]
	
	set configfile [file join $::artscript(dir) "presets.config"]

	if { [file exists $configfile] } {
		puts [mc "Configuration file found in %s" $configfile]
		puts [mc "Presets config name keys changed drastically from v2.0 to 2.1 \
		If your presets does not load please review presets.config.example file to check the new names."]

		set File [open $configfile r]
		#read each line of File and store "key=value"
		while {-1 != [gets $File line]} {
			set line_init [string index $line 0]
			if {$line_init ne {#} && ![string is space $line_init] } {
				set values [split $line "="]
				if {[llength $values] < 2} { continue } ; #Do not append if list is malformed
				lappend lista $values
			}
		}
		close $File
		if {![info exists lista]} { return 0 }

		#declare default dictionary to add defaut config values
		if {[dict exists $ops ":preset"]} {
			lappend preset [dict get $ops ":preset"]
		}
		#iterate list and populate dictionary with values
		set preset_dict "default"
		foreach i $lista {
			lassign $i key value
			if { $key == "preset" } {
				set preset_dict $value
				dict set presets $preset_dict [dict create]
				continue
			}
			dict set presets $preset_dict $key $value
		}
	}
	return $presets
}
# Change settings values from $::presets dict key "select"
proc setUserPresets { select } {
	if {$select eq {}} {
		return 0
	}
	set preset_values [dict get $::presets $select]
	array set preset $preset_values

	set catalogue [artscriptWidgetCatalogue]
	dict with catalogue {
	    set settings [dict create]
	    set sizes_presets [dict filter $preset_values key sizes_set*]
	    # catch { dict set settings sizes_selected [dict create values [dict get $sizes_presets sizes_set(default)] selected {} ]}
	    catch { dict set settings sets $sizes_presets }
	    catch { dict lappend settings sets {*}[dict filter $preset_values key collage_sty*] }
	    catch { dict lappend settings sets {*}[dict filter $preset_values key collage_lay*] }
	    catch { dict set settings img_src [dict create values $preset(watermark_image_list) selection {}] }

		foreach prop_lists [list $get_values $col_styles [concat $variables $preset_variables] $lists collage_label]\
			prop_names {get_values col_styles variables lists entries} {
			foreach prop $prop_lists {
				catch {dict set settings $prop_names $prop $preset(${prop})}
			}
		}
	}
	artscriptSetWidgetValues $settings
	sizeTreeAddPreset default

	return
}
# Set preset dict values. remove all sizes in list to prevent overflood
proc loadUserPresets { preset } {
	sizeTreeDelete [array names ::sdict]
	setUserPresets $preset
}
# Returns total of files in dict except for flagged as deleted.
# get_del bool, true = get all files loaded
# returns integer
proc getFilesTotal { { get_del 0} } {
	set size [dict size $::inputfiles]
	if { $get_del == 1 } {
		return $size
	}
	set deleted 0
	dict for {id datas} $::inputfiles {
		if {[dict get $::inputfiles $id deleted]} {
			incr deleted
		}
	}
	return [expr {$size - $deleted}]
}

proc updateWinTitle { } {
	wm title . [mc {Artscript %1$s -- %2$s Files selected} $::version [getFilesTotal]]
}

# Returns a list of ids of all elements that have args string in value
# args string list (gimp inkscape, magick, calligra)
proc putsHandlers {args} {
	dict for {id val} $::handlers {
		if {[lsearch -all $args $val] >= 0} {
			lappend images $id
		}
	}
	return [expr {[info exists images] ? $images : {}}]
}
# Shows open dialog for supported types
proc openFiles { args } {
	lassign [list {all calligra inkscape gimp png jpg gif} openpath 1 . files] formats path_var multiple path mode
	foreach {key value} $args { set $key $value	}

	if {[info exists ::artscript($path_var)]} { set path $::artscript($path_var) }

	foreach key $formats {
		lappend types [dict get $::artscript(supported_files) $key]
	}
	# Get selected files and set path to file folders
	if {$mode eq "files"} {
		set files [tk_getOpenFile -filetypes $types -initialdir $path -multiple $multiple]
	} else {
		set files [tk_chooseDirectory -initialdir $path -title "Choose a directory"]
	}
	if { $files ne {}} {	
		set ::artscript($path_var) [file dirname [lindex $files 0]]
	}

	return $files
}
		
# Loads chosen file to watermark combobox
proc loadImageWatermark {w args} {
	set path [openFiles formats "magick png jpg gif" path_var imagepath multiple 0]
	if {$path ne {}} {
		set file [file tail $path]
		dict set ::watermark_image_list $file $path
		set iwatermarksk [dict keys $::watermark_image_list]
		$w configure -values $iwatermarksk
		$w set $file
	}
}

# ----=== Gui proc events ===----

# Add key values into new treeview item id
# Receives w=widget name and id= key name of global dict
proc addTreevalues { w id } {
	global inputfiles
	
	dict with ::inputfiles $id {
		set values [list $id $ext $name $size $output $osize]
		set ::img::imgid$id [$w insert {} end -values $values]
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
	if {$::artscript(select_suffix) || $w != 0} {
		set ::artscript(select_suffix) 1
	}
	treeAlterVal {getOutputName $value $::out_extension $::out_prefix $::out_suffix} $::widget_name(flist) path output
}

# Check id of thumbnail shown sends it to convert to preview.
# TODO add size preview selection
proc showPreview {} {
	if {[info exists ::artscript(preview_id)]} {
		prepConvert Convert $::artscript(preview_id) 1
	}
	return
}
# TODO: Break appart preview function to allow loading thumbs from tmp folder
# Creates a thumbnail and places it in user thumbnail folders
# It uses md5 string to store the file name in thumbs dir
proc makeThumb { path filext tsize } {
	set cmd [dict create]
	set i 1

	dict set cmd .ora {Thumbnails/thumbnail.png}
	dict set cmd .kra {preview.png}

	if {![catch {set container [dict get $cmd $filext]}] } {
		set Cmd [list unzip -p $path $container | convert PNG:- ]

	} elseif {[lsearch -exact {.psd .xcf} $filext ] >= 0 } {
		$::widget_name(thumb-im) configure -compound text -text [mc "No Thumbnail"]
		return 0
	} else {
		lappend Cmd convert -quiet $path		
	}
	dict for {size dest} $tsize {
		if { $i < [dict size $tsize] } {
			lappend Cmd ( +clone -thumbnail [append size x $size] -flatten -write PNG32:$dest +delete )
			incr i
			continue
		}
		lappend Cmd -thumbnail [append size x $size] -flatten PNG32:$dest
	}
	puts $Cmd
	catch { exec {*}$Cmd } msg
	puts $msg
}

proc readBinaryFile { f var } {
	set ::artscript(data) [append ::artscript(data) [read $f]]
	if { [eof $f] } {
		fconfigure $f -blocking true
    	close $f
    	after idle set $var 1
	}
}
proc getBinaryData { script var} {
	catch {close $::artscript(thumb_chan)}
	set ::artscript(data) {}
	set ::artscript(thumb_chan) [open "| $script 2>@1" rb]
	fconfigure $::artscript(thumb_chan) -blocking false
		fileevent $::artscript(thumb_chan) readable [list readBinaryFile $::artscript(thumb_chan) $var]
}
proc setThumbGif { path } {
	getBinaryData [list convert $path -strip GIF:-] ::thumb
	vwait ::thumb
	set ::artscript(thumb) $::artscript(data)

	set ::img_thumb [image create photo]
		$::img_thumb put $::artscript(thumb)

	$::widget_name(thumb-im) configure -compound image -image $::img_thumb
	unset ::artscript(thumb)
}
proc setThumbPng { path } {
	set ::img_thumb [image create photo -file $path]
	$::widget_name(thumb-im) configure -compound image -image $::img_thumb
}

# Attempts to load a thumbnail from thumbnails folder if exists.
# Creates a thumbnail for files missing Large thumbnail
proc showThumb { w f {tryprev 1}} {
	global inputfiles env

	# Do not process if selection is multiple
	if {[llength $f] > 1 || $f eq {} } {
		return -code break
	}
	set ::artscript(preview_id) [$::widget_name(flist) set $f id]
	
	set path [dict get $inputfiles $::artscript(preview_id) path]
	set filext [string tolower [file extension $path] ]
	# Get png md5sum name.
	set thumbname [string tolower [::md5::md5 -hex "file://$path"]]
	set nthumb [file join $::artscript(thumb_normal) "$thumbname.png"]
	set lthumb [file join $::artscript(thumb_large) "$thumbname.png"]

	set thumbCmd [expr {[string is bool -strict $::artscript(tkpng)] ? {setThumbPng} : {setThumbGif}}]
	# Displays preview in widget
	if { [file exists $lthumb ] } {
		$thumbCmd $lthumb
		return 

	} elseif { [file exists $nthumb] } {
		puts [mc "%s has normal thumb" $path]
		if {[lsearch -exact {.xcf .psd} $filext] >= 0} {
			$thumbCmd $nthumb
			return
		}
		makeThumb $path $filext [dict create 256 $lthumb]
	} else {
		puts [mc "%s has no thumb" $path]
		makeThumb $path $filext [dict create 128 $nthumb 256 $lthumb]
	}
	if {$tryprev} {
		showThumb w $f 0
	}
}

# Scroll trough tabs on a notebook. (dir = direction)
proc scrollTabs { w i {dir 1} } {
		set tlist [llength [$w tabs]]

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
proc comboBoxEditEvents { w {script {} }} {
	bind $w <<ComboboxSelected>> $script
	bind $w <KeyRelease> $script
	foreach event {Button-3 Control-Button-1 FocusIn} {
		bind $w <$event> { %W configure -state normal } ; #space
	}
	bind $w <FocusOut> { %W configure -state readonly; %W selection clear }
}

# Validates input for quality spinbox, has to be a positive number not bigger than.
proc validateQualitySpinbox { value } {
	if {[string is integer $value]} {
		if { ( ($value <= $::artscript(quality_maximum)) && ($value > 0) ) || $value eq {} } {
			return 1
		}
	}
	return 0
}

# Convert RGB to HSV, to calculate contrast colors
# Returns float list => hue, saturation, value, lightness, luma 
proc rgbtohsv { r g b } {
	foreach color {r g b} {
		set ${color}1 [expr {[set ${color}]/255.0}]
	}
	set max [expr {max($r1,$g1,$b1)}]
	set min [expr {min($r1,$g1,$b1)}]
	set delta [expr {$max-$min}]
	set h -1
	set s {}

	lassign [lrepeat 3 $max] v l luma

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
		"bg"          { set title [mc "Collage Background Color"]}
		"border"      { set title [mc "Collage Border Color"]}
		"label"       { set title [mc "Collage Label Color"]}
		"watermark"   { set title [mc "Watermark Text Color"]}
		"default"     { set title [mc "Choose color"]}
	}
	set col [lindex $col end]

	if { $chooser } {
		set col [tk_chooseColor -title $title -initialcolor $col -parent .]
	}
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
	if { [catch {set col [setColor $w {*}$args]} msg] } {
		return
	}
	$w itemconfigure $::canvas_element(watermark_main_color) -outline [getContrastColor $col]
	set ::artscript(watermark_color) $col
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
		$w bind $::canvasWatermark($i) <Button-1> [list setColorAndContrast $w $::canvas_element(watermark_main_color) $col 0 ]
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
	ttk::style configure menu.TButton -padding {6 2} -width 0
	ttk::style configure small.TButton -padding {6 0} -width 0
	# ttk::style configure TCombobox -padding {8 1 0} -width 0
	ttk::style layout no_indicator.TCheckbutton { 
		Checkbutton.padding -sticky nswe -children { 
			Checkbutton.focus -side left -sticky w -children {
				Checkbutton.label -sticky nswe}
			}
		}
	ttk::style configure no_indicator.TCheckbutton -font "-weight bold"
	ttk::style configure TLabelFrame -background red
}

# ----=== Gui Construct ===----
# Adds the widgets given top to bottom
proc addFrameTop { args } {
	foreach widget [list {*}$args] {
		pack $widget -side top -fill x
	}
}
# Horizontal panel for placing operations that affect Artscript behaviour
proc guiTopBar { w } {
	pack [ttk::frame $w] -side top -expand 0 -fill x -pady 4 -padx 4
	# ttk::label $w.version -text [mc "Artscript %s" $::version]
	ttk::separator $w.sep -orient horizontal

	if {[llength [dict keys $::presets]] > 1} {
		ttk::label $w.preset_label -text [mc "Load preset:"]
		ttk::combobox $w.preset -state readonly -values [dict keys $::presets]
		$w.preset set [lindex $::presets 0]
		bind $w.preset <<ComboboxSelected>> { loadUserPresets [%W get] }
		pack $w.sep $w.preset_label $w.preset -side left -ipady {4}
		pack configure $w.sep -expand 1 -fill x -padx {18}
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
	pack $paned_big -side top -expand 1 -fill both -padx 4

	set file_pane $paned_big.fb
	ttk::frame $file_pane
	set paned_botom [guiMakePaned $paned_big.ac horizontal]
	guiAddChildren $paned_big $file_pane $paned_botom
	$paned_big pane $file_pane -weight 1

	guiFileList $file_pane
	guiThumbnail $file_pane

	# Add frame notebook to pane left.
	set ::option_tab [guiOptionTabs $paned_botom.n]
	set gui_out [guiOutput $paned_botom.onam]
	
	guiAddChildren $paned_botom $::option_tab $gui_out
	$paned_botom pane $::option_tab -weight 6
	$paned_botom pane $gui_out -weight 5
	
	pack $file_pane.flist -side left -expand 1 -fill both
	pack $file_pane.thumb -side left -expand 0 -fill both -pady {6 0}
	pack propagate $file_pane.thumb 0
	pack $file_pane.thumb.im -expand 1 -fill both
	
	return $w
}

proc guiFileList { w } {

	ttk::frame $w.flist
	ttk::frame $w.flist.action
	ttk::frame $w.flist.tree

	set a $w.flist.action

	set compound left
	#set image [list -image [list $::plus_normal active $::plus_g focus $::plus_g] -compound $compund]
	set im_add [list $::folder_on]
	set im_selall [list $::select_all]
	set im_selinv [list $::select_inv]
	set im_selnone [list $::select_none]
	set im_remove [list $::symbol_x]

	ttk::button $a.add -text [mc "Add files"] -image $im_add -compound $compound -style menu.TButton -command { listValidate [openFiles] }
	ttk::button $a.add_folder -text [mc "Add folder"] -image $im_add -compound $compound -style menu.TButton -command { listValidate [openFiles mode folder]}
	ttk::label $a.select_label -text [mc "Select"]
	ttk::button $a.select_all -text [mc "All"] -image $im_selall -compound $compound -style menu.TButton \
		-command { $::widget_name(flist) selection add [$::widget_name(flist) children {}] }
	ttk::button $a.select_inv -text [mc "Inverse"] -image $im_selinv -compound $compound -style menu.TButton\
		-command { $::widget_name(flist) selection toggle [$::widget_name(flist) children {}] }
	ttk::button $a.select_none -text [mc "None"] -image $im_selnone -compound $compound -style menu.TButton\
		-command { $::widget_name(flist) selection remove [$::widget_name(flist) children {}] }
	ttk::button $a.clear -text [mc "Remove Selected"] -image $im_remove -compound $compound -style menu.TButton \
		-command { removeTreeItem $::widget_name(flist) [$::widget_name(flist) selection] }

	ttk::label $a.sep
	ttk::label $a.sep_sels

	lassign [list $w.flist.tree.files $w.flist.tree.sscrl] tree_files tree_scroll

	set header_strings [dict create id [mc "ID"] ext [mc "ext."] input [mc "Input"] size [mc "Size"] output [mc "Output"] osize [mc "Size out"] ]
	set fileheaders [dict keys $header_strings]
	set ::widget_name(flist) [ttk::treeview $tree_files -columns $fileheaders -show headings -yscrollcommand "$tree_scroll set"]
	foreach col $fileheaders {
		$tree_files heading $col -text [dict get $header_strings $col] -command [list treeSort $tree_files $col 0 ]
	}
	$tree_files column id -width 32 -stretch 0
	$tree_files column ext -width 48 -stretch 0
	$tree_files column size -width 86 -stretch 0
	$tree_files column osize -width 86

	bind $tree_files <<TreeviewSelect>> { showThumb $::widget_name(thumb-im) [%W selection] }
	bind $tree_files <Key-Delete> { removeTreeItem %W [%W selection] }
	bind $::widget_name(flist) <Control-a> { $::widget_name(flist) selection add [$::widget_name(flist) children {}] }
	bind $::widget_name(flist) <Control-d> { $::widget_name(flist) selection remove [$::widget_name(flist) children {}] }
	bind $::widget_name(flist) <Control-i> { $::widget_name(flist) selection toggle [$::widget_name(flist) children {}] }

	ttk::scrollbar $tree_scroll -orient vertical -command [list $tree_files yview ]
	$::widget_name(flist) tag configure exists -foreground #f00

	pack $a $w.flist.tree -side top -fill x
	pack $a.add $a.sep $a.select_label $a.select_all $a.select_inv $a.select_none $a.sep_sels $a.clear -side left -padx {0 2}
	pack $tree_files $tree_scroll -side left -fill y
	pack configure $a.sep $a.sep_sels $w.flist.tree $tree_files -expand 1 -fill both
	pack configure $a.clear -padx {0 15}

	return $w
}

proc guiThumbnail { w } {
	ttk::labelframe $w.thumb -width 276 -height 316 -padding 6 -labelanchor n -text [mc "Thumbnail"]
	set ::widget_name(thumb-im) [ttk::label $w.thumb.im -anchor center -text [mc "No Thumbnail"]]
	set ::widget_name(thumb-prev) [ttk::button $w.thumb.prev -text [mc "Preview"] -style small.TButton -command { showPreview }]
	pack $w.thumb.prev -side bottom
}

# --== Option tabs
proc guiTabCheckbox {w previous selected} {
	set tabs [$w tabs]
	set prev_index [lsearch $tabs $previous]
	if {$prev_index == $selected} {
		guiTabToggleCheck [$w tab $selected]
	}
}
proc guiTabToggleCheck {args} {
	set vals {*}$args
	set tabnames [dict create $::atk_msg(tab_watermark) Watermark $::atk_msg(tab_resize) Resize  $::atk_msg(tab_collage) Collage ]
	dict with vals {
		if {$::tab_on == ${-image}} {
			set image {}
		} else {
			set image $::tab_on
		}
		set tab_name [dict get $tabnames ${-text}]
		$::option_tab tab $::widget_name(tab_${tab_name}) -image $image
		set bool [expr {$image eq {} ? 0 : 1}]
		switch -exact -- $tab_name {
			"Collage" {
				set ::artscript(select_collage) $bool
				eventCollage
			}
			"Resize"   { set ::artscript(select_size) $bool }
			"Watermark" { eventWatermark parent              }
		}
	}
}

proc guiOptionTabs { w } {
	ttk::notebook $w
	ttk::notebook::enableTraversal $w
	
	bind $w <ButtonPress-4> { scrollTabs %W [%W index current] 1 }
	bind $w <ButtonPress-5> { scrollTabs %W [%W index current] 0 }

	set ::atk_msg(tab_watermark) [mc "Watermark"]
	set ::atk_msg(tab_resize) [mc "Resize"]
	set ::atk_msg(tab_collage) [mc "Collage"]
	
	set ::widget_name(tab_Watermark) [tabWatermark $w.wm]
	set ::widget_name(tab_Resize) [tabResize $w.sz]
	set ::widget_name(tab_Collage) [tabCollage $w.cl]
	set ::wt $::widget_name(tab_Watermark) ; #TODO remove, bidsetACtion locks this variable name

	bind $w <Button> {guiTabCheckbox %W [%W select] [%W identify tab %x %y]}
	
	$w add $::widget_name(tab_Watermark) -text $::atk_msg(tab_watermark) -underline 0 -compound left
	$w add $::widget_name(tab_Resize) -text $::atk_msg(tab_resize) -underline 0 -sticky nesw -compound left
	$w add $::widget_name(tab_Collage) -text $::atk_msg(tab_collage) -underline 0 -sticky nesw -compound left

	return $w
}

proc eventWatermark { { type {} } } {
	if {$type eq "parent"} {
		lassign {0 0} ::artscript(select_watermark_text) ::artscript(select_watermark_image)
		return
	} elseif { $type ne {} } {
		set bool $::artscript(select_watermark_${type})
		set ::artscript(select_watermark_${type}) [expr {($bool == 0) ? 1 : $bool}]
	}
	set result [expr {$::artscript(select_watermark_text) + $::artscript(select_watermark_image)}]
	if {$result >= 1} {
		set ::artscript(select_watermark) 1
		$::option_tab tab $::widget_name(tab_Watermark) -image $::tab_on
	} else {
		set ::artscript(select_watermark) 0
		$::option_tab tab $::widget_name(tab_Watermark) -image {}
	}
}

proc tabWatermark { wt } {

	ttk::frame $wt -padding 6
	set water_ops [tabWatermarkOptions $wt.ops]

	ttk::frame $wt.style
	grid [tabWatermarkTextStyle $wt.style.text] [tabWatermarkImageStyle $wt.style.image] -sticky wens -padx 4 -pady 2
	grid columnconfigure $wt.style all -weight 2

	addFrameTop $water_ops $wt.style
	pack configure $water_ops -pady {0 8}

	return $wt
}
proc tabWatermarkOptions { wt } {

	ttk::frame $wt

	ttk::label $wt.lsize -text [mc "Size"] -width 4
	ttk::label $wt.lrot -text [mc "Rotation"]
	ttk::label $wt.lop -text [mc "Opacity"]

	tabWatermarkText $wt
	tabWatermarkImage $wt

	ttk::button $wt.img_select -image $::folder_on -text [mc "New"] -style small.TButton \
			-command [list loadImageWatermark $wt.iwatermarks]

	grid x x x $wt.lsize $wt.lrot $wt.lop -sticky we
	grid $wt.text_checkbox $wt.text_watermark_list - $wt.text_size $wt.text_rotation \
		$wt.text_opacity $wt.text_opacity_label -sticky we -padx 2
	grid $wt.image_checkbox $wt.image_watermark_list $wt.img_select $wt.image_size $wt.image_rotation \
		$wt.image_opacity $wt.image_opacity_label -sticky we -padx 2
	grid rowconfigure $wt {all} -pad 2
	grid columnconfigure $wt {5} -weight 1

	return $wt
}
proc tabWatermarkText { wt } {

	tabWatermarkGeneralOps $wt "text"

	set fontsizes [list 8 10 11 12 13 14 16 18 20 22 24 28 32 36 40 48 56 64 72 144]
	$::widget_name(watermark_text) configure -state readonly -values $::watermark_text_list

	$::widget_name(watermark_text) current 1
	$::widget_name(watermark_text_size) configure -width 4 -values $fontsizes
	$::widget_name(watermark_text_size) set $::watermark_text_size
}
proc tabWatermarkImage { wt } {

	tabWatermarkGeneralOps $wt "image"

	set iwatermarksk [dict keys $::watermark_image_list]
	$::widget_name(watermark_image) configure -state readonly -values $iwatermarksk
	$::widget_name(watermark_image_size) configure -width 4 -from 0 -to 100 -increment 10
	$::widget_name(watermark_image_size) set $::watermark_image_size
}
proc tabWatermarkPosition { wt type } {
	ttk::label $wt.lpos -text [mc "Position"]
	set ::widget_name(watermark_${type}_position) [ttk::combobox $wt.position -state readonly -textvariable ::watermark_${type}_position -values $::artscript(human_pos) -width 10]
	bind $wt.position <<ComboboxSelected>> [ list eventWatermark $type ]
	ttk::label $wt.plus -image $::plus_normal
	set ::widget_name(watermark_${type}_offset_x) [ttk::spinbox $wt.offset_x -width 3 -from -100 -to 100 \
		-validate key -validatecommand { string is integer %P }]
	set ::widget_name(watermark_${type}_offset_y) [ttk::spinbox $wt.offset_y -width 3 -from -100 -to 100 \
		-validate key -validatecommand { string is integer %P }]
	$wt.offset_x set 0
	$wt.offset_y set 0
}

proc tabWatermarkGeneralOps { wt type } {
	ttk::checkbutton $wt.${type}_checkbox -text [string totitle [mc $type]] -onvalue 1 -offvalue 0 \
		-variable ::artscript(select_watermark_${type}) -command { eventWatermark }

	set ::widget_name(watermark_${type}) [ttk::combobox $wt.${type}_watermark_list -state readonly -width 28]
	comboBoxEditEvents $wt.${type}_watermark_list [list eventWatermark $type ]

	set ::widget_name(watermark_${type}_size) [ttk::spinbox $wt.${type}_size -validate key \
			-validatecommand { string is integer %P }]
	bind $wt.${type}_size <ButtonRelease> [list eventWatermark $type ]
	bind $wt.${type}_size <KeyRelease> [list eventWatermark $type ]
 
	set ::widget_name(watermark_${type}_rotation) [ttk::combobox $wt.${type}_rotation -state readonly -width 5 -values {0 90 -90 180}]

	set ::widget_name(watermark_${type}_opacity) [ttk::scale $wt.${type}_opacity -from 10 -to 100 -variable ::watermark_${type}_opacity \
		 -orient horizontal -command [list progressBarSet watermark_${type}_opacity ]]
	bind $wt.${type}_opacity <ButtonRelease> [list eventWatermark $type ]
	ttk::label $wt.${type}_opacity_label -width 3 -textvariable ::watermark_${type}_opacity
}
proc tabWatermarkStyleGrid { wt } {
	grid $wt.style_label $wt.color - - -sticky n
	grid $wt.lpos $wt.position $wt.offset_x $wt.offset_y -pady 4 -padx 2 -sticky we
	grid configure $wt.color -sticky we
	grid rowconfigure $wt {0} -weight 1 -min 12
	grid columnconfigure $wt {1 2 3} -weight 1
}
proc tabWatermarkTextStyle { wt } {

	ttk::labelframe $wt -text [mc "Text Style"] -padding {2}

	tabWatermarkPosition $wt text
	$::widget_name(watermark_text_position) set $::watermark_text_position
	
	ttk::label $wt.style_label -text [mc "Color"]
	set ::widget_name(watermark_canvas) [canvas $wt.color  -width 62 -height 28]
	set ::canvas_element(watermark_main_color) [$wt.color create rectangle 2 2 26 26 -fill $::artscript(watermark_color) -width 2 -outline [getContrastColor $::artscript(watermark_color)] -tags {watermark main}]
	$wt.color bind main <Button-1> { setColorAndContrast %W $::canvas_element(watermark_main_color) [%W itemconfigure $::canvas_element(watermark_main_color) -fill] }

	set wmswatch [getswatches $::artscript(watermark_color_swatches)]
	drawSwatch $wt.color $wmswatch

	tabWatermarkStyleGrid $wt

	return $wt
}
proc tabWatermarkImageStyle { wt } {

	ttk::labelframe $wt -text [mc "Image Style"] -padding {2}

	tabWatermarkPosition $wt image
	$::widget_name(watermark_image_position) set $::watermark_image_position

	ttk::label $wt.style_label -text [mc "Mode"]
	set iblendmodes [list Bumpmap ColorBurn ColorDodge Darken Exclusion HardLight Hue Lighten LinearBurn LinearDodge LinearLight Multiply Overlay Over Plus Saturate Screen SoftLight VividLight]
	set ::widget_name(watermark_image_style) [ttk::combobox $wt.color -state readonly -textvariable ::watermark_image_style -values $iblendmodes ]
	$wt.color set $::watermark_image_style
	bind $wt.color <<ComboboxSelected>> { eventWatermark image }

	tabWatermarkStyleGrid $wt

	return $wt
}

# --== Size options
proc getArrayNamesIfValue { aname } {
	foreach key [array name $aname] {
		if {[llength [subst $[set aname]($key)]] > 0 } {
			lappend presets $key
		}
	}
	return $presets
}

# Create checkbox images
proc createImageVars {} { 
	set ::img_off [image create photo]
	$::img_off put {
        R0lGODlhDAAMAPMAAJKNg5aSh5iTiuDe2+Lg3OTj3+fm4urp5u3s6fDv7fLy8PX18/j49/n5+Pv7
+gAAACH5BAAAAAAAIf8LSW1hZ2VNYWdpY2sOZ2FtbWE9MC40NTQ1NDUALAAAAAAMAAwAAAQyMIBJ
qxwk6zxm+WA4GWRpTkeqrhPivvCUzHQ9KXiuT0vv/xOGcEicNBoOpDIJEFSezQgAOw== 
    }
	set ::img_on [image create photo]
	$::img_on put {
        R0lGODlhDAAMAPUAAFJZPkpIQVRZQXuuK4CuN4rGK4zGLo3GMY7GNY/GOJHGPJLGP6//MbL/ObP/
O5PGQpXGRpbGSbj/SLj/S7v/T8D/XsL/Y8T/ZsX/acb/bMf/b8n/c8n/dMr/dM3/fM7/f87/gdD/
hdH/h9D/iNT/j9X/lNX/ldb/l9f/m9n/ntv/pNz/pgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACH5BAAAAAAAIf8LSW1hZ2VNYWdpY2sO
Z2FtbWE9MC40NTQ1NDUALAAAAAAMAAwAAAZmQEBgSCwKB4WkMjkYGhgMh0TigBqGBwcF0+lgKI7D
EDHRjEqlkWaCGFdAJZWq9KkkhopLCLVaoUIXCkMPFnApKSUgFoIBhB1nJCEdFg9DEBoYGx4fGxoa
EEMEEaMQpBEEAQJFq6lBADs=
    }
    set ::tab_on [image create photo]
	$::tab_on put {
R0lGODlhCgAKAPMAAB4cGSMhHigmIywrJzEwLDY1MTs6Nj48OAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAACH5BAEAAAgAIf8LSW1hZ2VNYWdpY2sOZ2FtbWE9MC40NTQ1NDUALAAAAAAKAAoAAAQhEMlJ
J7ighs2n+NInSMNAlRJBUKpUvC4sGXRdHfhR7VIEADs=
    }
	set ::tab_off [image create photo]
	$::tab_off put {
R0lGODlhCgAKAPAAAAAAAAAAACH5BAEAAAAAIf8LSW1hZ2VNYWdpY2sOZ2FtbWE9MC40NTQ1NDUA
LAAAAAAKAAoAAAIIhI+py+0PYysAOw==
	}
	set ::folder_on [image create photo]
	$::folder_on put {
        R0lGODlhEAAOAPUAACIgHCgmITQyLT89N0dEPkpGPkxIQFBMRFVQSVlVTWZhWmplXmhmXm5pYm9s
ZHBsZHBtZXJuZnRwaXd1bXl0bHh2c315cXt5dX98dIB9dIaEe4uHfouIf42JgI6KgY6Lg56akZ2a
lLy6tNra2Ojo5+/v7wAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACH5BAEAACYAIf8LSW1hZ2VNYWdpY2sO
Z2FtbWE9MC40NTQ1NDUALAAAAAAQAA4AAAZ3wIJwKDQZj8bCYMksIJEFgXRKrBoCl2y2wu0CAIaN
Q0Quj87n7wGUabtBpHj8i+gw7nhQab//JiwQgYIgIYWFEhIdEBOMjRyPkI8gChiVlpeXFAwanJ2e
ngwNHx0fo6WkpqMNEBESga4QrrKxEAUEBLa5uLe2uEEAOw==
    }
    set ::select_all [image create photo]
	$::select_all put {
R0lGODlhDgAOAPMAAB0cGSEfHDQxLDo4MkE/OUlGP0tIQFBNRlFOR1ZUTF5bUmViWWhlXLq1qwAA
AAAAACH5BAAAAAAAIf8LSW1hZ2VNYWdpY2sOZ2FtbWE9MC40NTQ1NDUALAAAAAAOAA4AAAQ3MIBJ
6wwi673HaGAoekRpnmdRiGyjHnAsy0nSirWi7zy/LLfQj0EsGo+MIAjJbDoPhqh0Gj1EAAA7 
    }
    set ::select_none [image create photo]
	$::select_none put {
R0lGODlhDgAOAPMAACwqJSwqJjQxLDo4MkE/OUlGP1BNRlZUTF5bUmViWWhlW2hlXK2rpry5s9za
1QAAACH5BAAAAAAAIf8LSW1hZ2VNYWdpY2sOZ2FtbWE9MC40NTQ1NDUALAAAAAAOAA4AAAQvEMhJ
qWAu683E2KA2EGFIFCVoGOlmHK12IHGGJLWTLPnC177eohFrLBS+pDKpiAAAOw== 
    }
    set ::select_inv [image create photo]
	$::select_inv put {
R0lGODlhDgAOAPMAAB0cGSEfHDQxLDo4MkE/OUI/OUlGP0tIQFBNRlFOR1ZUTF1aUl5bUmViWWhl
XNza1SH5BAAAAAAAIf8LSW1hZ2VNYWdpY2sOZ2FtbWE9MC40NTQ1NDUALAAAAAAOAA4AAAQ8MIBJ
6wwi673HeGAoekRpnqdhiOyjInAsy0pt3zfTtkzzoKhHw7FjOYiMpHL5OBZFx6h06kAcrtjsFREB
ADs= 
    }
    set ::symbol_x [image create photo]
	$::symbol_x put {
R0lGODlhDgAOAPMAAC8tKDAsKTg1MTg2MEE+OEI+OElGQElHQFJPSFNPSFtXUFtYUGRhV2RhWGhl
XAAAACH5BAEAAA8AIf8LSW1hZ2VNYWdpY2sOZ2FtbWE9MC40NTQ1NDUALAAAAAAOAA4AAAQr8MlJ
q704B0BBsEIohcJVnGhmGIeRPUicZMqyPItyMQ0j8T6LgzJ8GY/HCAA7 
    }
    set ::plus_b [image create photo]
	$::plus_b put {
    	R0lGODlhDgAOAPMAABw3PCAoJxdGURNVZg9legt0jwaDpAKSuQCaxAAAAAAAAAAAAAAAAAAAAAAA
    AAAAACH5BAEAAAkAIf8LSW1hZ2VNYWdpY2sOZ2FtbWE9MC40NTQ1NDUALAAAAAAOAA4AAAQjMMlJ
    q702BEwB4JMggNIwYESqrlThvjBmGGRyHDWC5HvtYxEAOw==
}
	set ::plus_g [image create photo]
		$::plus_g put {
		R0lGODlhDgAOAPMAACYqGi8/FzhTE0l8DEFoEFKRCVulBWS6AmjEAAAAAAAAAAAAAAAAAAAAAAAA
	AAAAACH5BAEAAAkAIf8LSW1hZ2VNYWdpY2sOZ2FtbWE9MC40NTQ1NDUALAAAAAAOAA4AAAQjMMlJ
	q70WAExD4JMggBJBYEOqrlThvjBmGGRyHDWC5HvtYxEAOw==
	}
	set ::plus_normal [image create photo]
		$::plus_normal put {
		R0lGODlhDgAOAPMAACYkIC8tKDg2MEE+OElHQFJPSFtYUGRhWGhlXAAAAAAAAAAAAAAAAAAAAAAA
	AAAAACH5BAEAAAkAIf8LSW1hZ2VNYWdpY2sOZ2FtbWE9MC40NTQ1NDUALAAAAAAOAA4AAAQjMMlJ
	q70WAExD4JMggNIwYESqrlThvjBmGGRyHDWC5HvtYxEAOw==
	}
	set ::plus_r [image create photo]
		$::plus_r put {
			R0lGODlhDgAOAPMAACwhGkAiF1UjE30mDGklEJEoCaYpBboqAsQrAAAAAAAAAAAAAAAAAAAAAAAA
	AAAAACH5BAEAAAkAIf8LSW1hZ2VNYWdpY2sOZ2FtbWE9MC40NTQ1NDUALAAAAAAOAA4AAAQjMMlJ
	q70WAExD4JMggBJBYEOqrlThvjBmGGRyHDWC5HvtYxEAOw==
	}
}

# Hides or shows height combobox depending if value is wxh or w%
# size => stringxstring or string%x
# returns pair list
proc sizeToggleWidgetWxH { size {name "resize"} } {
	set w $::widget_name(${name}_size)

	scan $size "%d%s" width height
	set sep [string index $height 0]
	set height [string range $height 1 end]

	if { ($sep eq "x") && $height ne {} } {
		pack $w.hei -side left -after $w.xmu
		$w.hei state !disabled
		$w.xmu configure -text "x" -anchor center
		bind $w.xmu <Button> [list toggleRatio $name]
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
# Calculate current ratio for the given values. if ratio format 1:2, flips values 2:1
proc sizeAlterRatio { name args } {
	foreach {key value} $args { set $key $value }
	set rawratio [$::widget_name(${name}_ratio) get]
	
	if { [info exist setratio] || (($rawratio ne {}) && ([string is double $rawratio])) } {
		set ratio [expr {[format "%.1f" $hei] / $wid}]
		$::widget_name(${name}_ratio) set $ratio
	} else {
		$::widget_name(${name}_ratio) set [join [lreverse [split $rawratio {:}]] {:}]
	}
}
# Flips width and heigth field values and sets a new ratio if it's set
proc toggleRatio { name } {
	if { ![catch {lassign [getWidthAndHeight $name] wid hei}] } {
		$::widget_name(${name}_wid) set $hei
		$::widget_name(${name}_hei) set $wid
		sizeAlterRatio $name wid $wid hei $hei
	}
}
# set calculated ratio value
proc setRatio { name } {
	if { ![catch {lassign [getWidthAndHeight $name] wid hei}] } {
		sizeAlterRatio $name wid $hei hei $wid setratio 1
	}
}
# get current wid and hei value from "name" widgets
proc getWidthAndHeight { name } {
	lassign [list [$::widget_name(${name}_wid) get] [$::widget_name(${name}_hei) get]] wid hei
	if { ($wid eq {}) || ($hei eq {}) } {
		return -code error "Width or Height: empty"
	}
	return [list $wid $hei]
}

# Changes dimension, width or height in respect to Aspect ratio
# Alter == wid or hei   w, widget father.
proc sizeAlter { w alter name } {
	set ratio [sizeRatioToFloat $w.rat]
	set wid [$::widget_name(${name}_wid) get]
	set hei [$::widget_name(${name}_hei) get]

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
	$::widget_name(${name}_${target}) set $val
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
	sizeTreeAdd $size
	return
}
# Add all preset values to sizeTree
proc sizeTreeAddPreset { preset } {
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
	eventSize
	return
}

# Constructs size box (Probably this has to be cut into pieces)
proc addSizeBox { w name } {
	ttk::frame $w
	
	set ratiovals {{} 1:1 1.4142 2:1 3:2 4:3 5:4 5:7 8:5 1.618 16:9 16:10 14:11 12:6 2.35 2.40}
	set ::widget_name(${name}_ratio) [ttk::combobox $w.rat -width 6 -state readonly -values $ratiovals -validate key -validatecommand { regexp {^(()|[0-9])+(()|(\.)|(:))?(([0-9])+|())$} %P } ]
	comboBoxEditEvents $w.rat [list sizeAlter $w wid $name]
	
	ttk::label $w.lwxh -text " : " -font "-size 18" -anchor center -cursor hand1
	set ::widget_name(${name}_wid) [ ttk::spinbox $w.wid -width 5 -increment 10 -from 1 -to 5000 \
	  -validate key -validatecommand { regexp {^(()|[0-9])+(()|%%)$} %P } ]
	bind $::widget_name(${name}_wid) <ButtonRelease> [list sizeAlter $w wid $name]
	bind $::widget_name(${name}_wid) <KeyRelease> [list sizeAlter $w wid $name]

	set ::widget_name(${name}_hei) [ ttk::spinbox $w.hei -width 5 -increment 10 -from 1 -to 5000 \
		-validate key -validatecommand { string is integer %P } ]
	bind $::widget_name(${name}_hei) <ButtonRelease> [list sizeAlter $w hei $name]
	bind $::widget_name(${name}_hei) <KeyRelease> [list sizeAlter $w hei $name]

	set wheel_bind [expr {$::artscript(platform) eq {osx} ? "MouseWheel" : "ButtonPress"}]
	foreach bind_key [list <$wheel_bind> <Shift-$wheel_bind> <Shift-Control-$wheel_bind>] inc {10 1 100} {
		bind $::widget_name(${name}_wid) $bind_key [list $w.wid configure -increment $inc]
		bind $::widget_name(${name}_hei) $bind_key [list $w.hei configure -increment $inc]
	}

	ttk::label $w.xmu -text "x" -font "-size 18" -anchor center -cursor hand1
	ttk::label $w.empty
	bind $w.xmu <Button> [list toggleRatio $name]
	bind $w.lwxh <Button> [list setRatio $name]

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

	set w $::widget_name(resize_size)
	dict with sizes {
		$w.wid set $wid
		$w.hei set $hei
		$::widget_name(resize_ratio) set [expr {[format "%.2f" $wid] / $hei}]
	}
	return 0
}

proc addPresetBrowser { w } {
	ttk::frame $w
	
	ttk::frame $w.preset
	ttk::frame $w.set_sizes
	
	ttk::label $w.preset.browser -text [mc "Collections"] -padding {0 0 8}

	set presets [lsort [getArrayNamesIfValue ::sizes_set]]

	set ::widget_name(size_preset_list) [ttk::combobox $w.preset.sets -state readonly -values $presets]
	bind $w.preset.sets <<ComboboxSelected>> [list sizeSetPreset %W $w.set_sizes.size]
	$w.preset.sets set [lindex $presets end]

	ttk::button $w.preset.add -text "+" -image [list $::plus_normal active $::plus_g focus $::plus_g] -padding {2 0} -style small.TButton -command {sizeTreeAddPreset [$::widget_name(size_preset_list) get]}
	
	set ::widget_name(size_preset_list_items) [ttk::combobox $w.set_sizes.size -state readonly]
	bind $w.set_sizes.size <<ComboboxSelected>> [list sizeEdit %W]
	ttk::button $w.set_sizes.add -text "+" -image [list $::plus_normal active $::plus_g focus $::plus_g] -padding {2 0} -style small.TButton -command [list sizeTreeAddPresetChild $w.set_sizes.size]
	
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
	set size_tree_colname [list size]
	set ::widget_name(resize_tree) [ttk::treeview $w.sizetree -columns $size_tree_colname -height 5 -yscrollcommand "$w.sscrl set"]
	foreach tag {selected nonselected} {
		$w.sizetree tag bind $tag <Button-1> { sizeTreeToggleClick %W [%W selection] %x %y }
	}
	foreach add_key {<KP_Add> <plus> <a>} del_key {<KP_Subtract> <minus> <d>} {
		bind $w.sizetree $add_key { sizeTreeSetTag %W [%W selection] selected }
		bind $w.sizetree $del_key { sizeTreeSetTag %W [%W selection] nonselected }
	}

	bind $w.sizetree <Control-a> { %W selection add [%W children {}] }
	bind $w.sizetree <Control-d> { %W selection remove [%W children {}] }
	bind $w.sizetree <Control-i> { %W selection toggle [%W children {}] }
	bind $w.sizetree <Key-Delete> { sizeTreeDelete [%W selection] }
	bind $w.sizetree <x> { sizeTreeDelete [%W selection] }

	ttk::scrollbar $w.sscrl -orient vertical -command [list $w.sizetree yview ]
	
	pack $w.sizetree $w.sscrl -side left -fill both
	pack configure $w.sizetree -expand 1
	
	$w.sizetree heading #0 -text {} -image $::img_off -command [list treeSortTagPair $w.sizetree #0 selected nonselected ]
	$w.sizetree column #0 -width 34 -stretch 0
	$w.sizetree column size -width 50 -stretch 1
	foreach col $size_tree_colname {
		set name [string totitle $col]
		$w.sizetree heading $col -text [string totitle [mc $name]] -command [list treeSort $w.sizetree $col 0 ]
	}
    $w.sizetree tag configure selected -image $::img_on
    $w.sizetree tag configure nonselected -image $::img_off

	return $w
}
# Selects size for processing, setting tag as selected
# w = widget name, sel = item ids, x = pointer x coordinate, y = yposition
proc sizeTreeToggleClick { w sel {x 0} {y 0} } {
	#Only change image if we press over it (check box)
	if { [$w identify element $x $y] eq "image" } {
		set id [$w identify item $x $y]
		set val [$w set $id size]
		set state [expr {$::sdict($val) eq "on"}]
		set tag [expr {$state ? "nonselected" : "selected"}]
		set ::sdict($val) [expr {$state ? "off" : "on"}]
		sizeTreeSetTag $w $id $tag
	}
	return
}
# Sets selected tag to given treeview ids
# w = target widget, id = list of ids, tag = tag to place
# returns widget name
proc sizeTreeSetTag { w id tag } {
	foreach el $id {
		set val [$w set $el size]
		$w item [set ::sdict_$val] -tag $tag
	}
	eventSize
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
	
	ttk::button $w.clear -text [mc "clear"] -style small.TButton -command {sizeTreeDelete [array names ::sdict]}
	ttk::separator $w.separator -orient horizontal
	ttk::label $w.selectl -text [mc "Select:"]
	ttk::button $w.all -text [mc "all"] -style small.TButton -command {$::widget_name(resize_tree) selection add [$::widget_name(resize_tree) children {}] }
	ttk::button $w.inv -text [mc "inv."] -style small.TButton -command {$::widget_name(resize_tree) selection toggle [$::widget_name(resize_tree) children {}] }
	ttk::button $w.sels -text [mc "sels"] -image $::img_on -style small.TButton -padding {2 1} -command {$::widget_name(resize_tree) selection set [$::widget_name(resize_tree) tag has selected]}

	#Set focus on tree after pressing the buttons
	foreach widget [list $w.all $w.inv $w.sels] {
		bind $widget <ButtonRelease> { focus $::widget_name(resize_tree) }
	}

	pack $w.clear $w.separator $w.selectl $w.all $w.inv $w.sels -side left
	pack $w.separator -expand 1 -padx 12
	return $w
}

proc sizeOptions { w } {
	ttk::frame $w -padding {0 12 0 24}

	ttk::label $w.label_operator -text [mc "Mode:"]

	set ::artscript(size_operators) [dict create [mc "Scale"] Scale [mc "Stretch"] Stretch [mc "OnlyGrow"] OnlyGrow [mc "OnlyShrink"] OnlyShrink [mc "Zoom"] Zoom]
	set ::widget_name(resize_operators) [ttk::combobox $w.operator -width 12 -state readonly -values [dict keys $::artscript(size_operators)] ]
	$w.operator set [mc "OnlyShrink"]
	bind $w.operator <<ComboboxSelected>> { showOperatorOptions $::widget_name(resize_size_options) [%W get] }

	ttk::frame $w.zoom

	set ::widget_name(resize_zoom_position) [ttk::combobox $w.zoom.position -width 12 -state readonly -values $::artscript(human_pos)]
	$w.zoom.position set [lindex $::artscript(human_pos) 0]
	set ::widget_name(resize_zoom_offset_x) [ttk::spinbox $w.zoom.offset_x -width 3 -from -100 -to 100 \
		-validate key -validatecommand { string is integer %P }]
	set ::widget_name(resize_zoom_offset_y) [ttk::spinbox $w.zoom.offset_y -width 3 -from -100 -to 100 \
		-validate key -validatecommand { string is integer %P }]
	$w.zoom.offset_x set 0
	$w.zoom.offset_y set 0
	pack $w.zoom.position $w.zoom.offset_x $w.zoom.offset_y -side left

	pack $w.label_operator $w.operator -side left

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

proc showOperatorOptions { w mode } {
	if {[dict get $::artscript(size_operators) $mode] eq "Zoom"} {
		place $w.zoom -in $w -anchor nw -relx 0.145 -y 20
	} else {
		catch { place forget $w.zoom }
	}
	eventSize
}

#set to <<TreeviewSelect>>
# and add to '+' action buttons
proc eventSize { } {
	set sizes [getSizesSel]

	treeAlterVal {getOutputSizesForTree $value 1} $::widget_name(flist) size osize

	if { [llength $sizes] > 0 } {
		$::option_tab tab $::widget_name(tab_Resize) -image $::tab_on
		set ::artscript(select_size) 1
	} else {
		$::option_tab tab $::widget_name(tab_Resize) -image {}
		set ::artscript(select_size) 0
	}
}


proc tabResize { st } {
	ttk::frame $st -padding 6
	
	ttk::frame $st.lef
	ttk::frame $st.rgt
	
	pack $st.lef -side left -fill y -padx {6 12}
	pack $st.rgt -expand 1 -fill both

	set preset_browse [addPresetBrowser $st.lef.broswer]
	set ::widget_name(resize_size) [addSizeBox $st.lef.size "resize"]
	# pack widgets around addSizeBox
	set w $::widget_name(resize_size)
	ttk::label $w.title -text [mc "Add custom size. ratio : wxh"] -font "-size 12" 
	ttk::button $w.add -text "+" -image [list $::plus_normal active $::plus_g focus $::plus_g] -padding {2 0} -style small.TButton -command [list sizeTreeAddWxH $w.xmu $w.wid $w.hei]
	
	pack $w.title -before $w.rat -side top -fill x
	pack $w.add -after $w.empty -side left

	set ::widget_name(resize_size_options) [sizeOptions $st.lef.options]
	
	addFrameTop $preset_browse $::widget_name(resize_size) $::widget_name(resize_size_options)
	pack [sizeTreeOps $st.rgt.size_ops ] -fill x
	pack [sizeTreeList $st.rgt.size_tree] -expand 1 -fill both

	sizeSetPreset $::widget_name(size_preset_list) $::widget_name(size_preset_list_items)
	return $st
}

# --== Collage options
proc colBorderPreview { pixel } {
	if { $pixel eq {} } {
		set pixel 0
	}
	lassign [$::widget_name(collage_canvas) coords $::canvas_element(collage_img_color)] ox oy fx fy
	$::widget_name(collage_canvas) coords $::canvas_element(collage_border_color) [expr {$ox-$pixel}] [expr { $oy-$pixel }] [expr { $fx+$pixel }] [expr { $fy+$pixel }]
}
proc colPaddingPreview { } {
	lassign {2 2 79 55} ox oy fx fy
	foreach var {padding border} {
		set value [$::widget_name(collage_${var}) get]
		set $var [expr { $value eq {} ? 0 : $value }]
	}

	$::widget_name(collage_canvas) coords $::canvas_element(collage_img_color) [expr {$ox+$padding+$border}] [expr { $oy+$padding+$border }] [expr { $fx-$padding-$border }] [expr { $fy-$padding-$border }]
	colBorderPreview $border
}
proc setColageStyle { style {erase true}} {
	dict for {prop value} $style {
		set type [split $prop {_}]
		if { [lindex $type end] eq "color"} {
			$::widget_name(collage_canvas) itemconfigure $::canvas_element(collage_$prop) -fill $value
		} else {
			switch -- $prop {
				"label" {
					$::widget_name(collage_${prop}) delete 0 end
					$::widget_name(collage_${prop}) insert 0 $value
				}
				"default" {
					$::widget_name(collage_${prop}) set $value
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

	ttk::label $w.label_border -text [mc "Border"]
	set ::widget_name(collage_border) [ttk::spinbox $w.value_border -from 0 -to 10 -width $width \
		-validate key -validatecommand { string is integer %P }]
	$::widget_name(collage_border) set 1
	bind $::widget_name(collage_border) <ButtonRelease> { colPaddingPreview }
	bind $::widget_name(collage_border) <KeyRelease> { colPaddingPreview }

	ttk::label $w.label_pad -text [mc "Padding"]
	set ::widget_name(collage_padding) [ttk::spinbox $w.value_pad -from 0 -to 20 -width $width \
		-validate key -validatecommand { string is integer %P }]
	$::widget_name(collage_padding) set 6
	bind $::widget_name(collage_padding) <ButtonRelease> { colPaddingPreview }
	bind $::widget_name(collage_padding) <KeyRelease> { colPaddingPreview }

	grid $w.label_border $w.label_pad -sticky w -pady {6 0}
	grid $w.value_border $w.value_pad -sticky w
	grid columnconfigure $w {0} -pad 6

	return $w
}
proc colGetRange {} {
	lassign [list [$::widget_name(collage_col) get] [$::widget_name(collage_row) get]] col row
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
		$::widget_name(collage_range) set [format %.f $range]
	}
	return
}

proc colLayout { w } {
	ttk::frame $w ; #-padding {0 4 0 0}
	set width 4

	ttk::label $w.label_col -text [mc "Columns:"]
	set ::widget_name(collage_col) [ttk::spinbox $w.col -width $width -to 20 -command colSetRange \
		-validate key -validatecommand { string is integer %P }]
	ttk::label $w.label_row -text [mc "Rows:"] -padding {6 0 0}
	set ::widget_name(collage_row) [ttk::spinbox $w.row -width $width -to 20 -command colSetRange \
		-validate key -validatecommand { string is integer %P }]
	ttk::label $w.label_ran -text [mc "Range:"]
	set ::widget_name(collage_range) [ttk::spinbox $w.ran -width $width -from 1 -to 56 \
		-validate key -validatecommand { string is integer %P }]

	bind $::widget_name(collage_col) <KeyRelease> colSetRange
	bind $::widget_name(collage_row) <KeyRelease> colSetRange

	grid $w.label_col $w.label_row $w.label_ran -sticky w
	grid $w.col $w.row $w.ran -sticky w
	grid columnconfigure $w {0 1} -pad 6

	return $w

}
# Return string escape sequences substituted.
proc colFilterLabel { id } {
	set input [$::widget_name(collage_label) get]

	return [string map [list \
		%% % \
		%f [list [dict get $::inputfiles $id name] ] \
		%e [list [dict get $::inputfiles $id ext] ] \
		%G [list [dict get $::inputfiles $id size]] \
	] $input]
}

proc colLabel { w } {
	ttk::frame $w -padding {0 12 0 0}

	ttk::label $w.label_title -text [mc "Label:"]
	set ::widget_name(collage_label) [ ttk::entry $w.label_text \
		-validate key -validatecommand { string is print %P } ]
	ttk::label $w.subst -text [mc "%f => file.ext, %e => ext, %G => WxH"]

	set col_ops [ttk::frame $w.options -padding {12 0 0 0} ]
	ttk::label $col_ops.prev -text "" -anchor e
	ttk::button $col_ops.show_prev -text [mc "Estimate size"] -style small.TButton -width 12 -command [list colEstimateSize $col_ops.prev]
	ttk::label $col_ops.label_mode -text [mc "Mode:"] -anchor e
	set ::artscript(collage_modes) [dict create {} {} [mc "Concatenation"] Concatenation [mc "Zero geometry"] {Zero geometry} \
		[mc "Crop"] {Crop} [mc "Wrap"] {Wrap}]
	set ::widget_name(collage_mode) [ttk::combobox $col_ops.mode -width 12 -state readonly -values [dict keys $::artscript(collage_modes)]]

	grid $col_ops.prev $col_ops.show_prev -sticky e
	grid $col_ops.label_mode $col_ops.mode -sticky e
	grid configure $col_ops.label_mode -padx {0 4}
	grid columnconfigure $col_ops {0} -weight 1
	grid rowconfigure $col_ops "all" -pad 4 -weight 1

	grid $w.label_title $w.label_text $col_ops -sticky nwe
	grid $w.subst - -sticky nwe
	grid configure $w.label_title $w.label_text -pady {2 0}
	grid configure $col_ops -rowspan 2
	grid columnconfigure $w {1} -weight 1
	grid columnconfigure $w {2} -weight 2
	grid rowconfigure $w {0 1} -pad 6

	return $w
}

proc colStyle { w } {
	ttk::frame $w -padding {4 0}

	ttk::label $w.label_head -text [mc "Style:"] -width 12 -anchor w -padding {0 0 0 6}
	set ::widget_name(collage_canvas) [canvas $w.preview -width 80 -height 78]
	set ::canvas_element(collage_bg_color) [$w.preview create rectangle 1 1 79 77 -fill "grey10" -width 1 -outline "grey20" -tags {bg click}]
	set ::canvas_element(collage_border_color) [$w.preview create rectangle 5 5 75 51 -fill "grey27" -width 0 -tags {border click}]
	set ::canvas_element(collage_img_color) [$w.preview create rectangle 5 5 75 51 -fill "grey5" -width 0 -tags {img}]
	set ::canvas_element(collage_label_color) [$w.preview create text 40 56 -text [mc "label"] -font "-size 14 -weight bold" -anchor n -fill "grey80" -tags {label click}]
	$w.preview bind click <Button-1> { setColor %W [%W find closest %x %y] [%W itemconfigure [%W find closest %x %y] -fill] }
	$w.preview bind img <Button-1> { setColor %W 2 [%W itemconfigure 2 -fill] }

	ttk::label $w.label_styles

	set swatches [lsort [getArrayNamesIfValue ::collage_styles]]
	set ::widget_name(collage_styles) [ttk::combobox $w.styles -width 0 -state readonly -values $swatches]
	bind $w.styles <<ComboboxSelected>> { setColageStyle $::collage_styles([%W get])}

	pack $w.label_head [colSpacing $w.space] -side top -expand 1 -fill x -ipady 2
	pack $w.preview -after $w.label_head -side top
	place $w.styles -in $w.label_head -relwidth .6 -x 40 ; #-expand 1 -fill x -ipady 2
	
	# Update style preview with border padding values.
	after idle colPaddingPreview

	return $w
}
proc eventCollage {} {
	switch -- $::artscript(select_collage) {
		0 {set ops [list {} ? [mc "Convert"] {prepConvert} end] }
		1 {set ops [list $::tab_on ! [mc "Make Collage"] {prepConvert "Collage"} end-2 ] }
	}
	lassign $ops image mode convert_string convert_cmd format_range
	#set image [append ::tab_$state]
	$::widget_name(col_select) configure -text [mc "Make Collage%s" $mode]
	$::option_tab tab $::widget_name(tab_Collage) -image [subst $image]
	set ::artscript(bconvert_string) $convert_string
	set ::artscript(bconvert_cmd) $convert_cmd
	$::widget_name(convert-but) configure -text $convert_string -command $convert_cmd
	# Disable unsupported formats for collage
	$::widget_name(format) configure -values [lrange [dict keys $::artscript(formats)] 0 $format_range]
	if { [$::widget_name(format) current] == -1 } { $::widget_name(format) current 0 }
}

proc colLayoutsSelect { w } {
	ttk::frame $w -padding {0 0 0 6}
	set ::artscript(select_collage) 0
	set ::widget_name(col_select) [ttk::checkbutton $w.sel_collage -text [mc "Make Collage?"] -variable ::artscript(select_collage) -command eventCollage \
		-style no_indicator.TCheckbutton -image [list $::img_off selected $::img_on]  -compound left]

	ttk::label $w.label_layouts -text [mc "Layouts:"]
	
	set swatches [lsort [getArrayNamesIfValue ::collage_layouts]]
	set ::widget_name(collage_layouts) [ttk::combobox $w.layouts -width 16 -state readonly -values $swatches]
	bind $w.layouts <<ComboboxSelected>> { setColageStyle $::collage_layouts([%W get])}

	ttk::label $w.separator

	pack $::widget_name(col_select) $w.separator $w.label_layouts $w.layouts -side left -fill x
	pack configure $w.separator -expand 1
	# place  -in $w.label_layouts -relwidth .3 -x 60

	return $w
}
proc colNameOptions { w } {
	ttk::frame $w

	set ::artscript(collage_name) "Collage"
	ttk::label $w.name_label -text [mc "Collage file name:"]
	set ::widget_name(collage_name) [ ttk::entry $w.name -textvariable ::artscript(collage_name) -width 14 -validate key -validatecommand { string is graph %P } ]

	pack $w.name $w.name_label -side right

	return $w
}

proc tabCollage { w } {
	ttk::frame $w -padding 6

	ttk::frame $w.lef
	ttk::frame $w.rgt

	pack $w.lef -side left -expand 1 -fill both -padx {6 12}
	pack $w.rgt -expand 1 -fill both

	set col_title [colLayoutsSelect $w.lef.title]
	
	ttk::frame $w.lef.tilesize
	ttk::label $w.lef.tilesize.separate

	set ::widget_name(collage_size) [addSizeBox $w.lef.tilesize.size "collage"]
	pack $::widget_name(collage_size) $w.lef.tilesize.separate [colLayout $w.lef.tilesize.layout] -side left
	pack configure $w.lef.tilesize.separate -expand 1

	set size_frame $::widget_name(collage_size)
	ttk::label $size_frame.title -text [mc "Tile size. ratio : w x h"]
	pack $size_frame.title -before $size_frame.rat -side top -fill x

	addFrameTop $col_title $w.lef.tilesize [colLabel $w.lef.label] [colNameOptions $w.lef.name ]

	pack [colStyle $w.rgt.col_style ] -fill x

	return $w
}
# Estimate ouptput size. TODO make the code less repetitive with prepCollage 
proc colEstimateSize { w } {
	foreach {value} {border padding col row } {
		set $value [$::widget_name(collage_${value}) get]
	}
	# Calculate space needed for padding and border
	set pixel_space [expr {($border + $padding)*2} ]

	foreach var {width height} value [colGetTileSize] {
		set $var [expr {$value - $pixel_space}]
	}
	if { [catch {set fsize "[expr {$col * ($width + $pixel_space)}]x[expr {$row * ($height + $pixel_space)}]"}] } {
		$w configure -text [mc "Need more data"]
	} else {
		$w configure -text $fsize
	}
}

proc colGetTileSize {} {
	set width [$::widget_name(collage_wid) get]
	set height [$::widget_name(collage_hei) get]

	if {($width eq {}) && ($height eq {}) } {
		return [list 0 0]
	} elseif {$width eq {}} {
		set width 0
	} elseif {$height eq {}} {
		set height 0
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

	if { $::artscript(collage_name) eq {}} { set ::artscript(collage_name) "Collage" }
	set file_name [replaceDateEscapes $::artscript(collage_name)]

	# get Border padding range col row
	foreach {value} {border padding col row range mode} {
		set $value [$::widget_name(collage_${value}) get]
	}

	# Calculate space needed for padding and border
	set pixel_space [expr {($border + $padding)*2} ]

	#Add Conditional settings
	lassign [list 0 0 {} 0 0] concatenate zero_geometry trim crop wrap
	switch -nocase -glob -- [dict get $::artscript(collage_modes) $mode] {
		{conc*}	{ set concatenate 1 }
		{zero*} { set zero_geometry 1 }
		{crop}	{ set crop 1 }
		{wrap}	{ set wrap 1 }
	}

	# Set width height minus spacing from border padding.
	foreach var {width height} value [colGetTileSize] {
		set $var [expr {$value - $pixel_space}]
	}
	if {($zero_geometry == 0) && ($concatenate == 0)} {
		set width [expr {$width == (0 - $pixel_space) ? $height : $width}]
		set height [expr {$height == (0 - $pixel_space) ? $width : $height}]
	} else {
		set trim {-trim}
	}

	# Calculate range validity (less than col * row)
	set auto_range [colGetRange]

	if { $auto_range != 0 && $range ne {} } {
		set range [expr {min($range,$auto_range)}]
	}
	if {$wrap} {
		set len [llength $input_files]
		set range [expr {[string is false $range] ? $len : $range }]
		foreach id $input_files {
			lappend range_lists [lrepeat $range $id]
		}
	} else {
		if { $range eq {} || $range == 0 } {
			set range_lists [list $input_files]
			set range 1
		} else {
			set range_lists [colRange $input_files $range]
		}		
	}

	pBarUpdate $::widget_name(pbar-main) cur max [expr { ceil([llength $input_files] / [format %.2f $range]) * 2 + $::artscript_convert(total_renders) * [llength [getFinalSizelist]] }] current [expr {$::cur -2}]

	# Place color values
	foreach {color} {bg_color border_color img_color label_color} {
		dict set ::artscript_convert(collage_vars) $color [$::widget_name(collage_canvas) itemcget $::canvas_element(collage_$color) -fill]
	}
	# Add row col size label range border padding to dict
	foreach {value} {file_name width height col row range border padding pixel_space concatenate zero_geometry trim crop wrap} {
		dict set ::artscript_convert(collage_vars) $value [set $value]
	}
	# puts $::artscript_convert(collage_vars)
	return $range_lists
}
proc doCollage { files {step 1} args } {
	switch $step {
	0 {
		if {$::artscript_convert(extract)} {
			# wait until extraction ends to begin converting
			vwait ::artscript_convert(extract)
		}
		puts [mc "Powering up Collage Assembly line"]
		set ::artscript_convert(count) 0
		set range_files [prepCollage $files]
		after idle [list after 0 [list doCollage $range_files]]

	} 1 {

		set range_pack [lindex $files $::artscript_convert(count)]
		incr ::artscript_convert(count)

		pBarControl [format {%s %d/%d} "Assembling..." ${::artscript_convert(count)} [llength $files]] update

		dict with ::artscript_convert(collage_vars) {
			# Stop process if no more collages in cue
			if { ($range_pack eq {}) } {
				puts [mc "All collages assembled"]
				doConvert $::artscript_convert(collage_ids) 0 trim $trim
				return
			}

			foreach id $range_pack {
				set path [dict get $::inputfiles $id path]
				set opath $path
				catch {set opath [dict get $::inputfiles $id tmp]}

				set clabel [colFilterLabel $id]

				lassign [scan [dict get $::inputfiles $id size] "%dx%d"] wid hei
				set rsize [getSizeZoom $wid $hei $width $height]
				if {$clabel ne {}} {
					lappend collage_names -label $clabel
				}
				if {$crop} {
					set position [lindex $::artscript(magick_pos) [expr {int(rand()*9)}]]
					lappend collage_names -gravity $position +repage
				}
				# Make concatenate mode remove read in size
				set format {"%s"}
				if {$concatenate == 0} {
					set format {"%s[%s]"}
					if {[file extension $opath] eq {.gif}} {
						set format [format {( %s -flatten )} $format]
					}
				}
				lappend collage_names [format $format $opath $rsize]
			}
			# Force value 0 on col and row when left empty
			foreach {var} {col row} {
				set value [set $var]
				set x$var [expr {($value eq {} || $value == 0) ? 1 : $value}]
			}
			# finalsize convert 50% > wid = row x destw
			set fsize "[expr {$xcol * ($width + $pixel_space)}]x[expr {$xrow * ($height + $pixel_space)}]"

			#Add filename to dict
			set output_path [format {%s_%02d.%s} [file join $::artscript(tmp) ${file_name}] $::artscript_convert(count) "png"]
			set geometry [expr { $zero_geometry || $wrap ? "1x1+${padding}+${padding}\\<" : "${width}x${height}+${padding}+${padding}" }]

			set Cmd [concat montage -quiet [expr { $crop ? "-crop [list $geometry]" : {} }] {*}$collage_names \
				-geometry [list $geometry] [expr { $concatenate ? "-mode Concatenate" : {}}] -tile ${col}x${row} \
				-border $border -background $bg_color -bordercolor $border_color -fill $label_color \
				"PNG32:$output_path" ]
			puts $Cmd
		}
		runCommand $Cmd [list relaunchCollage $output_path $path $files]
	}}
}
proc relaunchCollage { file_generated destination files } {
	# global fc deleteFileList
	if {[file exists $file_generated]} {
		set size [dict get [identifyFile $file_generated] size] 
		set output_dir [file dirname $destination]
		set name [file join $output_dir [file tail $file_generated]]

		lappend ::artscript_convert(collage_ids) $::fc
		setDictEntries $::fc $name $size {.png} sRGB {m} 0
		dict set ::inputfiles $::fc tmp $file_generated
		lappend ::deleteFileList $file_generated
		incr ::fc
	}
	after idle [list after 0 [list doCollage $files]]
}


# --== Suffix and prefix ops
proc guiOutput { w } {

	ttk::frame $w
	set preffix_suffix_string [mc "Prefix and Suffix"]
	set ::widget_name(cb-prefix) [ttk::checkbutton $w.cbpre -onvalue 1 -offvalue 0 -variable ::artscript(select_suffix) -text $preffix_suffix_string -command {printOutname 0 } ]
	ttk::labelframe $w.efix -text $preffix_suffix_string -labelwidget $w.cbpre -padding 6

	frameSuffix $w.efix

	set ::widget_name(frame-output) [frameOutput $w.f]
	
	pack $w.efix $w.f -side top -fill both -expand 1 -padx 2
	pack configure $w.efix -fill x -pady {0 8} -expand 0
	pack configure $w.f -fill both -expand 1
	
	return $w
}

proc frameSuffix { w } {
	lappend ::suffix_list "$::date" "%mtime" {} ; # Appends an empty value to allow easy deselect
	set ::suffix_list [lsort $::suffix_list]
	foreach suf $::suffix_list {
		lappend suflw [string length $suf]
	}
	set suflw [lindex [lsort -integer -decreasing $suflw] 0]
	set suflw [expr {int($suflw+($suflw*.2))}]
	expr { $suflw > 16 ? [set suflw 16] : [set suflw] }

	set ::widget_name(out_prefix) [ttk::combobox $w.pre -width $suflw -state readonly -textvariable ::out_prefix -values $::suffix_list]
	$w.pre set [lindex $::suffix_list 0] 
	comboBoxEditEvents $w.pre { printOutname %W }
	set ::widget_name(out_suffix) [ttk::combobox $w.suf -width $suflw -state readonly -textvariable ::out_suffix -values $::suffix_list]
	$w.suf set [lindex $::suffix_list 0]
	comboBoxEditEvents $w.suf { printOutname %W }

	pack $w.pre $w.suf -padx 2 -side left -fill x -expand 1

	return $w
}

proc frameOutput { w } {
	ttk::labelframe $w -text [mc "Output & Quality"] -padding {6 6}

	set ::artscript(quality_maximum) 100
	ttk::label $w.label_quality -width 8.2 -anchor e -text [mc "Quality:"]
	set ::widget_name(quality) [ttk::scale $w.slider_qual -from 10 -to 100 -variable ::artscript(image_quality) \
		-value $::artscript(image_quality) -orient horizontal -command { progressBarSet artscript(image_quality) }]
	set ::widget_name(quality_label) [ttk::spinbox $w.slider_qual_val -width 3 -from 10 -to $::artscript(quality_maximum) \
		-textvariable ::artscript(image_quality) -validate key -validatecommand { validateQualitySpinbox %P } ]
	bind $w.slider_qual_val <FocusIn> {%W selection range 0 end}
	bind $w.slider_qual_val <FocusOut> {%W selection clear}

	set ::artscript(formats) [dict create png png jpg jpg gif gif webp webp [mc "webp lossy"] {webp lossy} ora ora [mc "Rename"] {Rename} [mc "Keep format"] {Keep format}]
	ttk::label $w.label_format -text [mc "Format:"]
	set ::widget_name(format) [ttk::combobox $w.format -state readonly -width 9 -values [dict keys $::artscript(formats)]]
	$w.format set png
	bind $w.format <<ComboboxSelected>> [list setFormatOptions $w ]

	ttk::checkbutton $w.overwrite -text [mc "Allow Overwrite"] -onvalue 1 -offvalue 0 -variable ::artscript(overwrite) -command { treeAlterVal {getOutputName $value $::out_extension $::out_prefix $::out_suffix} $::widget_name(flist) path output }
	ttk::checkbutton $w.alfa_off -text [mc "Remove Alfa"] -onvalue "-background %s -alpha remove" -offvalue "" -variable ::artscript(alfaoff)
	set ::widget_name(canvas_alpha_color) [canvas $w.alpha_color -width 16 -height 16]
	set ::widget_name(alfa_color) [$w.alpha_color create rectangle 1 1 15 15 -fill $::artscript(alfa_color) -width 1 -outline "grey20" -tags {alfa}]
	$w.alpha_color bind alfa <Button-1> { set ::artscript(alfa_color) [setColor %W $::widget_name(alfa_color) [%W itemconfigure $::widget_name(alfa_color) -fill]] }

	grid $w.label_quality $w.slider_qual - $w.slider_qual_val -row 1 -padx 2 -sticky we
	grid $w.label_format $w.format - x -row 2 -sticky we
	grid $w.overwrite - $w.alfa_off - -row 3 -sticky e -pady {12 1}
	grid configure $w.label_quality $w.label_format -sticky e -padx 0
	place $w.alpha_color -in $w.alfa_off -relx 1 -y 1 -anchor ne

	grid columnconfigure $w {1 2} -weight 12 -pad 4 
	grid rowconfigure $w "all" -pad {6}
	grid configure $w.alfa_off -ipadx 12

	return $w
}

# Alters ouput widgets to show format output options
# w = widget name
proc setFormatOptions { w } {
	set ::out_extension [dict get $::artscript(formats) [$::widget_name(format) get]]
	treeAlterVal {getOutputName $value $::out_extension $::out_prefix $::out_suffix} $::widget_name(flist) path output
	$::widget_name(convert-but) configure -text $::artscript(bconvert_string) -command $::artscript(bconvert_cmd)
	$::widget_name(thumb-prev) state !disabled
	$::widget_name(quality_label) state !disabled
	set quality_string [mc "Quality:"]
	switch -glob -nocase -- $::out_extension {
		jpg	{
			lassign {92 100} ::artscript(image_quality) ::artscript(quality_maximum)
			$w.label_quality configure -text $quality_string
			$w.slider_qual configure -from 10 -to 100
			$::widget_name(quality_label) configure -from 10 -to 100
		}
		png	{
			lassign {9 9} ::artscript(image_quality) ::artscript(quality_maximum)
			$w.label_quality configure -text [mc "Compress:"]
			$w.slider_qual configure -from 0 -to 9
			$::widget_name(quality_label) configure -from 0 -to 9
		}
		gif	{
			lassign {256 256} ::artscript(image_quality) ::artscript(quality_maximum)
			$w.label_quality configure -text [mc "Colors:"]
			$w.slider_qual configure -from 1 -to 256
			$::widget_name(quality_label) configure -from 1 -to 256
		}
		ora	{
			lassign {0 0} ::artscript(image_quality) ::artscript(quality_maximum)
			$w.label_quality configure -text $quality_string
			$w.slider_qual configure -from 0 -to 0
			$::widget_name(convert-but) configure -text [mc "Make ORA"] -command {prepOra}
			$::widget_name(thumb-prev) state disabled
			$::widget_name(quality_label) state disabled
		}
		webp {
			lassign {100 100} ::artscript(image_quality) ::artscript(quality_maximum) 
			$w.label_quality configure -text $quality_string
			$w.slider_qual configure -from 10 -to 100
			$::widget_name(quality_label) configure -from 10 -to 100
		}
		webp* { 
			lassign {60 100} ::artscript(image_quality) ::artscript(quality_maximum)
			$w.label_quality configure -text $quality_string
			$w.slider_qual configure -from 10 -to 100
			$::widget_name(quality_label) configure -from 10 -to 100
		}
		Keep* -
		Rename {
			set action [string tolower [lindex $::out_extension 0]]
			lassign {0 0} ::artscript(image_quality) ::artscript(quality_maximum)
			$w.label_quality configure -text $quality_string
			$w.slider_qual configure -from 0 -to 0
			$::widget_name(convert-but) configure -text $::out_extension -command [list ${action}Files]
			$::widget_name(thumb-prev) state disabled
			$::widget_name(quality_label) state disabled
		}
	}
}

# ----==== Status bar
proc guiStatusBar { w } {
	# set default button Convert string
	set ::artscript(bconvert_string) [mc "Convert"]
	set ::artscript(bconvert_cmd) {prepConvert}
	pack [ttk::frame $w] -side top -expand 0 -fill x -padx 4 -pady {0 4}

	ttk::frame $w.rev
	ttk::frame $w.do

	set ::widget_name(pbar-main) [ttk::progressbar $w.do.pbar -maximum [getFilesTotal] -variable ::cur -length "260"]
	set ::widget_name(pbar-label) [ttk::label $w.do.plabel -textvariable pbtext -anchor e]
	set ::widget_name(convert-but) [ttk::button $w.do.bconvert -text $::artscript(bconvert_string) -command {prepConvert}]
	setFormatOptions $::widget_name(frame-output)

	pack $w.rev -side left
	pack $w.do -side right -expand 1 -fill x
	pack $w.do.bconvert -side right -fill x -padx 2 -pady 8

	return $w
}
# Ttk progress: Set a given float as integer.
proc progressBarSet { gvar value } {
	upvar #0 $gvar variable
	set variable [format "%.0f" $value]
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
	update idletasks
	if {$delay > 0} {
		after idle [list after $delay [list set wait 1]]
		vwait wait
	}
	switch -- $action {
		"create" { 
			pack $::widget_name(pbar-label) $::widget_name(pbar-main) -side left -expand 1 -fill x -padx 2 -pady 0
			pack configure $::widget_name(pbar-main) -expand 0
			pBarUpdate $::widget_name(pbar-main) cur max $max current -1
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
proc getSizeScale { w h dw dh {mode "OnlyShrink"} } {
	set ratio [expr { $h / [format "%0.2f" $w]} ]
	set dratio [expr { $dh / [format "%0.2f" $dw]} ]
	lassign [list $dw $dh] ow oh

	if { $dratio > $ratio } {
		set dh [ expr {round($h * $dw / [format "%0.2f" $w])} ]
	} else {
		set dw [ expr {round($w * $dh / [format "%0.2f" $h])} ]
	}
	lassign [list [expr {$w * $h}] [expr {$ow * $oh}] ] a da

	switch -- $mode {
		OnlyShrink {
			if { $da > $a } { return "${w}x${h}" }
		}
		OnlyGrow {
			if { $da < $a } { puts [mc "Image area is bigger"] ;return "${w}x${h}" }
		}
		Stretch -
		Zoom { return "${ow}x${oh}" } 
	}
	return "${dw}x${dh}"
}

proc getSizeZoom { w h dw dh } {
	set ratio [expr { $h / [format "%0.2f" $w]} ]
	set dratio [expr { $dh / [format "%0.2f" $dw]} ]
	if { $ratio > $dratio } {
		set dh [ expr {round($dw * $ratio)} ]
	} else {
		if { $ratio < 1 } {
			set dw [ expr {round($dh / $ratio)} ]
		} else {
			set dw [ expr {round($dh * $ratio)} ]
		}
	}
	return "${dw}x${dh}"
}

# Calculates scaling destination for size in respect of chosen sizes
# size, string WidthxHeight, the original file size,
# Returns a list of wxh elements, Bool returns formated list
proc getOutputSizesForTree { size {formated 0}} {
	lassign [split $size {x}] cur_w cur_h
	
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
			lassign [split $dimension {x}] dest_w dest_h
		}
		# get final size
		set mode [dict get $::artscript(size_operators) [$::widget_name(resize_operators) get]]
		set finalscale [getSizeScale $cur_w $cur_h $dest_w $dest_h $mode]
		#TODO Add resize filter (better quality)
		lappend fsizes $finalscale
	}
	#Do not return repeated sizes
	set fsizes [lsort -unique $fsizes]
	if {$formated} {
		return [join $fsizes {, }]
	}
	return $fsizes
}
# Return offset x y in format +n+n
#TODO make apply function to return 0 if empty
proc widgetGetOffset { family type } {
	foreach var {x y} {
		set value [$::widget_name(${family}_${type}_offset_${var}) get]
		set $var [expr { $value eq {} ? 0 : $value }]
	}
	return [format {%+d%+d} $x $y]
}
#Preproces functions
# Renders watermark images based on parameters to tmp folder
# returns string
proc watermark {} {
	global deleteFileList
	set wmcmd {}

	set wm_im_sel [$::widget_name(watermark_image) get]

	if { $::artscript(select_watermark_text) } {
		set text_size [$::widget_name(watermark_text_size) get]
		set watermark_text [$::widget_name(watermark_text) get]
		set wmpossel [lindex $::artscript(magick_pos) [$::widget_name(watermark_text_position) current] ]
		set rotation [$::widget_name(watermark_text_rotation) get]
		if {($rotation != 0) && ($rotation ne {} )} {
				set rotate "+distort ScaleRotateTranslate $rotation +repage"
		} else {
			set rotate {}
		}
		set wmtmptx [file join $::artscript(tmp) "artk-tmp-wtmk.png" ]
		set width [expr {[string length $watermark_text] * 3 * ceil($text_size/4.0)}]
		set height [expr {[llength [split $watermark_text {\n}]] * 30 * ceil($text_size/8.0)}]
		set watermark_color_inverse [getContrastColor $::artscript(watermark_color) ]
		
		set wmtcmd [list convert -quiet -size ${width}x${height} xc:transparent -pointsize $text_size -gravity Center -fill $::artscript(watermark_color) -annotate 0 "$watermark_text" -trim \( +clone -background $watermark_color_inverse  -shadow 80x2+0+0 -channel A -level 0,60% +channel \) +swap +repage -gravity center -composite {*}$rotate $wmtmptx]
		catch { exec {*}$wmtcmd }
		
		lappend deleteFileList $wmtmptx
		
		set offset [widgetGetOffset watermark text]
		append wmcmd [list -gravity $wmpossel $wmtmptx -compose dissolve -define compose:args=$::watermark_text_opacity -geometry $offset -composite ]
	}
	if {$wm_im_sel eq {}} { return $wmcmd }

	set wmimsrc [dict get $::watermark_image_list $wm_im_sel]
	if { $::artscript(select_watermark_image) && [file exists $wmimsrc] } {
		set identify {identify -quiet -format "%wx%h:%m:%M "}

		if { [catch {set finfo [identifyFile $wmimsrc ] } msg ] } {
			puts $msg
		} else {
			set wmimpossel [lindex $::artscript(magick_pos) [$::widget_name(watermark_image_position) current] ]
			set rotation [$::widget_name(watermark_image_rotation) get]
			if {($rotation != 0) && ($rotation ne {} )} {
				set rotate "+distort ScaleRotateTranslate $rotation +repage"
			} else {
				set rotate {}
			}
			set size [dict get $finfo size]
			set wmtmpim [file join $::artscript(tmp) "artk-tmp-wtmkim.png" ]
			set wmicmd [ list convert -quiet -size $size xc:transparent -gravity Center $wmimsrc -compose dissolve -define compose:args=$::watermark_image_opacity -composite {*}$rotate $wmtmpim]
			catch { exec {*}$wmicmd }

			lappend deleteFileList $wmtmpim ; # add wmtmp to delete list

			set offset [widgetGetOffset watermark image]
			append wmcmd " " [list -gravity $wmimpossel $wmtmpim -compose $::watermark_image_style -define compose:args=$::watermark_image_opacity -geometry $offset -composite ]
		}
	}
	return $wmcmd
}

# Makes resize command, takes a size and calculates intermediate resize steps
# size = image size, dsize = destination size, filter = resize filter
# unsharp = unsharp string options
# return string
proc getResize { size dsize set_space } {
	# Operator is force size (!)
	set operator "\\!"
	set resize {}
	lassign [concat [split $size {x}] [split $dsize {x}] ] cur_w cur_h dest_w dest_h
	lassign [list [expr {$cur_w * $cur_h}] [expr {$dest_w * $dest_h}] ] cur_area dest_area

	if {[dict get $::artscript(size_operators) [$::widget_name(resize_operators) get]] eq "Zoom"} {
		set finalscale [getSizeZoom $cur_w $cur_h $dest_w $dest_h ]
		set position [lindex $::artscript(magick_pos) [$::widget_name(resize_zoom_position) current] ]
		set offset [widgetGetOffset resize zoom]
		set crop [format {-gravity %s -crop %sx%s%s} $position $dest_w $dest_h $offset]
	} else {
		set finalscale $dsize
		set crop {}
	}

	# - Lagrange Lanczos2 Catrom Lanczos Parzen Cosine + (sharp)
	# with -distort Resize instead of -resize Lanczos "or LanczosRadius"
	set sigma [format %.2f [expr { ( (1 / ([format %.1f $dest_w] / $cur_w)) / 4 ) * .8 }] ]
	# set filter "-interpolate bicubic -filter LanczosRadius -define filter:blur=.9891028367558475"
	# set unsharp "	-unsharp 0x$sigma+0.80+0.010"
	# set filter "-interpolate bicubic -filter Parzen"
	# set unsharp [string repeat "-unsharp 0x0.55+0.25+0.010 " 1]
	#
	# - Deevad Custom scaling + unsharp method , to mimic manual work he did on Gimp
	#  Sharp and crispy , for my own painting only 
	set filter "-filter LanczosRadius"
        set unsharp " -unsharp 1x1+0.5+0.010"

	if {$set_space} {
		set resize "-colorspace RGB"
	}
	#Check if enlarging or not.
	if {$cur_area > $dest_area} {
		set resize [concat $resize $filter]
		# while { [expr {[format %.1f $cur_w] / $dest_w}] > 1.5 } {
		# 	set cur_w [expr {round($cur_w * 0.8)}]
		# 	set resize [concat $resize -resize 80% +repage $unsharp]
		# }
		set resize [concat $resize -distort Resize ${finalscale}${operator}]
	} else {
		  set contrast 1.0
		  set resize [concat +sigmoidal-contrast $contrast -filter Lanczos ]
		  set resize [concat -define filter:blur=.9264075766146068 -distort Resize ${finalscale} -sigmoidal-contrast $contrast ]
	}
	# Final resize output
	set resize [concat $resize $crop +repage [expr {$set_space ? "-colorspace sRGB" : ""}] $unsharp]

	return $resize
}

# set quality options depending on extension
# returns string
proc getQuality { ext } {
	switch -glob -- $ext {
		jp*g	{ set quality "-sampling-factor 1x1,1x,1x1 -quality $::artscript(image_quality)" }
		png	{ set quality "-type TrueColorMatte -define png:format=png32 -define png:compression-level=$::artscript(image_quality) -define png:compression-filter=8" }
		gif	{ set quality "-channel RGBA -separate \( +clone -dither FloydSteinberg -remap pattern:gray50 \) +swap +delete -combine -channel RGB -dither FloydSteinberg -colors $::artscript(image_quality)" }
		webp { set quality "-quality $::artscript(image_quality) -define webp:auto-filter=true -define webp:lossless=true -define webp:method=5" }
		webp* { set quality "-quality $::artscript(image_quality) -define webp:auto-filter=true -define webp:lossless=false -define webp:alpha-quality=100"}
		default { set quality {} }
	}
	return $quality
}

proc renameFiles { {index 0} {step 0} } {
	switch -exact -- $step {
		0 {
			pBarControl {} create 0 1
			set ::artscript_convert(files) [processIds]
			pBarUpdate $::widget_name(pbar-main) cur max [llength $::artscript_convert(files)] current -1
			renameFiles 0 1
		}
		1 {
			set id [lindex $::artscript_convert(files) $index]
			incr index
			if {$id eq {}} {
				pBarControl [mc "Rename Images Done!"] forget 600
				puts [mc "Rename finished."]
				afterConvert "Renaming" $index
				return
			}

			dict with ::inputfiles $id {
				puts [mc "renaming... %s" $name]
				pBarControl [mc "Renaming..."] update

				set dir [file dirname $path]
				# puts "Rename $path to [file join $dir $output]"
				file rename $path [file join $dir $output]
			}
			renameFiles $index 1
		}
	}
}
proc keepFiles { } {
	set images_id [processIds]
	set forbid_ids [putsHandlers g i k]

	set ids {}
	foreach id $images_id {
		if { [lsearch $forbid_ids $id] >= 0 } { continue }
		lappend ids $id
	}
	prepConvert Convert $ids
}
	
# Adds command to fileevent handler
# cmd exec command, script last cmd executed
proc runCommand {cmd script {var ""} } {
    set f [open "| $cmd 2>@1" r]
    fconfigure $f -blocking false
    fileevent $f readable [list handleFileEvent $f $script $var]
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
        puts ["Operation encounter error: %s" $err]
    }
    after idle [list after 0 $script]
}
# Do something depending on what the fileevent returns
# f fileevent, script, pass to closePipe
proc handleFileEvent {f script {var ""}} {
	set status [catch { gets $f line } result]
	if { $status != 0 } {
		# unexpected error
		puts [mc "Error! %s" $result]
		closePipe $f $script

	} elseif { $result >= 0 } {
		# we got some output
		catch {set $var $line}
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
		pBarControl [mc "ORA Image Files Ready!"] forget 600
		afterConvert "Make Ora" $index
		return
	}
	
	set datas [dict get $::inputfiles $idnumber]
	dict with datas {
		if {!$deleted} {
			pBarControl [mc "Oraizing... %s" $name] update

			set outname [file join [file dirname $path] $output]
			set Cmd [list calligraconverter --batch -- $path $outname]
			runCommand $Cmd [list makeOra $index $ilist]
		}
	}
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
		puts [mc "Starting File extractions..."]
		after idle [list after 0 [list processHandlerFiles $index $ilist]]
	} 1 {
		
		incr index
		
		# Stop process if no more files to convert
		if { ($imgv eq {}) || ($handler($imgv) eq {m})} {
			set ::artscript_convert(extract) false
			puts [mc "File extractions finished"]
			return
		}
		set msg {}
		
		array set id [dict get $inputfiles $imgv]
		
		set outname [file join $::artscript(tmp) [file root $id(name)]]
		append outname ".png"
		
		set ::artscript_convert(outname) $outname
		set ::artscript_convert(imgv) $imgv
		
		set extracting_string [mc "Extracting file %s" $id(name)]
		puts $extracting_string
		pBarControl $extracting_string update

		# Review if any requested size is bigger than normal size to render biggest (SVG)
		if { $handler($imgv) == {i} } {
			set id_output_sizes [lsort -command [lambda {a b} {
				expr ([string map {x *} $a]) < ([string map {x *} $b])
			} ] [getOutputSizesForTree $id(size)]]

			set bigger_size [expr [string map {x *} [lindex $id_output_sizes 0]] ]
			set original_size [expr [string map {x *} $id(size)] ]
			set make_bigger [expr {$bigger_size > $original_size}]
		}
		# we do not want to re render svg on each preview, so we only re-render if size is bigger.
		if { ![file exists $outname] || ([info exists make_bigger] && $make_bigger) } {
			if { $handler($imgv) == {g} } {
				puts [mc "Rendering Gimps"]
				set i $id(path)
				set cmd [format {(let* (
					(image (car (gimp-file-load 1 "%1$s" "%1$s")))
					(gimp-image-convert-rgb image)
					(drawable (car (gimp-image-merge-visible-layers image CLIP-TO-IMAGE)))
					)
					(file-png-save-defaults 1 image drawable "%2$s" "%2$s"))(gimp-quit 0)} $i $outname]
				#run gimp command, it depends on file extension to do transforms.
				# puts $cmd
				set extractCmd [list gimp -i -b "$cmd"]
			}
			if { $handler($imgv) == {i} } {
				puts [mc "Rendering Ink Scapes"]
				if {$make_bigger} {
					lassign [split [lindex $id_output_sizes 0] {x}] width height
					set inksize "-w $width"
				} else {
					set inksize "-d 90"
				}
				set extractCmd [concat inkscape $id(path) -z -C $inksize -e $outname]
			}
			if { $handler($imgv) == {k} } {
				puts [mc "Rendering Kriters"]
				set extractCmd [list calligraconverter --mimetype "image/png" --batch -- $id(path) $outname]
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
		puts [mc "error: %s" "$errc\n"]
		if {$errc != "NONE"} {
			# puts $msg
		}
		error [mc "Something went wrong, tmp png wasn't created"]
	} else {
		puts [mc "file %s found!" $outname]
		dict set ::inputfiles $imgv tmp $outname
		lappend ::deleteFileList $outname
	}
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
proc doConvert { files {step 1} args } {
	lassign { 0 {} } preview trim
	foreach {key value} $args {
		set $key $value
	}
	switch $step {
	0 {
		puts [mc "Starting Convert..."]
		set ::artscript_convert(count) 0
		after idle [list after 0 [list doConvert $files 1 {*}$args]]
	} 1 {
		if {$::artscript_convert(extract)} {
			# wait until extraction ends to begin converting
			vwait ::artscript_convert(extract)
		}
		set idnumber [lindex $files $::artscript_convert(count)]
		incr ::artscript_convert(count)
		
		if { $idnumber eq {} } {
			pBarControl [mc "File Conversions Done!"] forget 600
			puts [mc "Convert done."]
			# erase all collage from lists
			if {[llength $::artscript_convert(collage_ids)] > 0} {
				foreach i $::artscript_convert(collage_ids) {
					dict unset ::inputfiles $i
				}
				set ::artscript_convert(collage_ids) {}
			}
			afterConvert "Convert" $::artscript_convert(count) {*}$args
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
				# necessary for resize sRGB inputfiles.
				set file_info [exec identify $opath]
				set colorspace_make_linear [expr {[lsearch $file_info sRGB] >= 0 ? 1 : 0}]
				# get make resize string
				set sizes [getOutputSizesForTree $size]
				
				foreach dimension $sizes {
					incr i
					set resize {}
					if { ($size != $osize) && $::artscript(select_size) } {
						set resize [getResize $size $dimension $colorspace_make_linear]
					}
					set converting_string [mc {Converting... %1$s to %2$s} ${name} $dimension]
					puts $converting_string
					pBarControl $converting_string update
					
					if {$i == 1} { set dimension {}	}
					if {$::out_extension eq {Keep format}} {
						set ::artscript_convert(quality) [getQuality $ext]
					}
					
					if {$preview} {
						puts [mc "Generating preview"]
						set soname "show:"
					} else {
						set soname \"[file join $outpath [getOutputName $path $::artscript_convert(out_extension) $::artscript_convert(out_prefix) $::artscript_convert(out_suffix) $dimension] ]\"
					}
					# puts $::artscript_convert(alfa_off)
					set convertCmd [concat convert -quiet \"$opath\" $trim $resize $::artscript_convert(wmark) $::artscript_convert(alfa_off) $::artscript_convert(quality) $soname]
					puts $convertCmd
					runCommand $convertCmd [list doConvert $files 1 {*}$args]
				}
			}
		}
	}}
	return 0
}

# Set convert global and values total files to process
# id = files to convert, if none given, all will be processed
proc prepConvert { {type "Convert"} {ids ""} { preview 0} } {

	pBarControl {} create 0 1

	set ::artscript_convert(alfa_off) [format $::artscript(alfaoff) $::artscript(alfa_color)]
	foreach var {out_extension out_prefix out_suffix} {
		set ::artscript_convert($var) [set ::$var]
	}

	set ::artscript_convert(files) [processIds $ids]
	set ::artscript_convert(collage_ids) [list]
	if {[llength $::artscript_convert(files)] == 0} {
		pBarControl [mc "No images loaded!"] forget 600
		return -code break
	}
	set ::artscript_convert(wmark) [watermark]
	set ::artscript_convert(quality) [getQuality $::out_extension]

 	#controls all extracts are done before convert
	set ::artscript_convert(extract) true
	
	#process Gimp Calligra and inkscape to Tmp files
	set ::artscript_convert(files) [processIds $ids]
	set ::artscript_convert(total_renders) [prepHandlerFiles $::artscript_convert(files)]

	#Create progressbar
	pBarUpdate $::widget_name(pbar-main) cur max [expr {([llength $::artscript_convert(files)] + $::artscript_convert(total_renders)) * [llength [getFinalSizelist]]}] current -1
	
	do$type $::artscript_convert(files) 0 preview $preview
}

proc afterConvert { type n args} {
	array set vars $args
	if {!$vars(preview)} {
		incr n -1
		set message [mc {Artscript %1$s finished %2$s images processed} $type "\n$n" ]
		if {[catch {exec notify-send -i [file join $::artscript(dir) icons "artscript.gif"] -t 4000 $message}]} {
			tk_messageBox -type ok -icon info -title [mc "Operations Done"] -message $message
		}
	}
}

proc artscriptWidgetCatalogue {} {
	set catalogue [dict create]

	dict set catalogue variables {watermark_color collage_name select_suffix select_collage select_watermark select_watermark_text select_watermark_image overwrite alfaoff image_quality remember_state window_geom}
	dict set catalogue preset_variables {watermark_color_swatches}
	dict set catalogue col_styles {watermark_main_color collage_bg_color collage_border_color collage_label_color collage_img_color}
	dict set catalogue get_values {collage_ratio collage_wid collage_hei collage_col collage_row collage_range collage_border collage_padding collage_mode watermark_text watermark_text_position watermark_text_offset_x watermark_text_offset_y watermark_image_offset_x watermark_image_offset_y watermark_text_rotation watermark_image_rotation watermark_image_position watermark_image_style watermark_text_size watermark_text_opacity watermark_image_size watermark_image_opacity out_suffix out_prefix quality format resize_operators resize_zoom_position resize_zoom_offset_x resize_zoom_offset_y format}
	dict set catalogue lists {watermark_text_list suffix_list}
	return $catalogue
}
proc artscriptSetWidgetValues { dictionary } {
	dict for {type elements} $dictionary {
		switch -- $type {
			"sizes_selected" {
				if {[llength [dict get $elements values]] > 0} {
					sizeTreeDelete [array names ::sdict]
				}
				dict for {name values} $elements {
					foreach size $values {
						#if {([lsearch -exact $::sizes_set(default) $size] >= 0) && ($name eq "values")} { continue }
						sizeTreeAdd $size nonselected off
					}
				}
			}
			"sets" {
				foreach {key value} $elements { set ::$key $value }
				$::widget_name(size_preset_list) configure -values [lsort [getArrayNamesIfValue ::sizes_set]]
				$::widget_name(collage_styles) configure -values [lsort [getArrayNamesIfValue ::collage_styles]]
				$::widget_name(collage_layouts) configure -values [lsort [getArrayNamesIfValue ::collage_layouts]]

			}
			"get_values" {
				foreach {key value} $elements {
					$::widget_name(${key}) set $value
				}
				setFormatOptions $::widget_name(frame-output)
			}
			"col_styles" {
				foreach {key value} $elements {
					lassign [split $key {_}] parent type color
					$::widget_name(${parent}_canvas) itemconfigure $::canvas_element(${key}) -fill $value
				}
			}
			"entries" {
				foreach {key value} $elements {
					$::widget_name(${key}) delete 0 end
					$::widget_name(${key}) insert 0 $value
				}
			}
			"img_src" {
				dict for {name src} [dict get $elements values] {
					if {[file exists $src]} {
						dict set ::watermark_image_list $name $src
					}
				}
				$::widget_name(watermark_image) configure -values [dict keys $::watermark_image_list]
				set selection [dict get $elements selection]
				if {[lsearch -exact [dict keys $::watermark_image_list] $selection] >= 0 } {
					$::widget_name(watermark_image) set $selection
				}
			}
			"variables" {
				foreach {key value} $elements {
					set ::artscript($key) $value
				}
				drawSwatch $::widget_name(watermark_canvas) [getswatches $::artscript(watermark_color_swatches)]
			}
			"lists" {
				foreach {key value} $elements {
					if {$key eq "suffix_list"} {
						set value [lsort [lappend value "$::date" %mtime {}]]
						$::widget_name(out_prefix) configure -values $value
						$::widget_name(out_suffix) configure -values $value
					} elseif {$key eq "watermark_text_list"} {
						global year month day autor
						$::widget_name(watermark_text) configure -values [subst $value]
						$::widget_name(watermark_text) current 0 
					}
				}
			}
		}
	}
	eventCollage
	eventWatermark
	setFormatOptions $::widget_name(frame-output)
}
proc artscriptSaveOnExit {} {
	catch {file delete {*}$::deleteFileList }
	after idle [after 0 exit] ; #Ensure always exit even if misterious error
	scan [wm geometry .] {%dx%d+%d+%d} gw gh gx gy; # 954x624 min
	set ::artscript(window_geom) [format {%dx%d%+d%+d} [expr {$gw < 954 ? 954 : $gw}] [expr {$gh < 624 ? 624 : $gh}] $gx $gy]

	if {$::artscript(remember_state) == 1} {
		set catalogue [artscriptWidgetCatalogue]
		dict with catalogue {
		    set save_settings [dict create]

		    dict set save_settings sizes_selected [dict create values [array names ::sdict] selected [getSizesSel] ]
		    dict set save_settings img_src [dict create values $::watermark_image_list selection [$::widget_name(watermark_image) get]]
			dict set save_settings entries collage_label [$::widget_name(collage_label) get]

		    foreach prop $get_values {
					dict set save_settings get_values $prop [$::widget_name(${prop}) get]
			}
			foreach prop $col_styles {
				lassign [split $prop {_}] parent
				dict set save_settings col_styles $prop [lindex [$::widget_name(${parent}_canvas) itemconfigure $::canvas_element($prop) -fill] end]
			}
			foreach prop $variables {
				dict set save_settings variables $prop [set ::artscript($prop)]
			}
		}
		puts [mc {Writing temporary settings file in %s
		If you experience any problem, delete it to force refresh} $::artscript_rc]
		set file [open $::artscript_rc w]
		puts $file $save_settings
		close $file
	}
}

proc artscriptOpenState { } {
	if {$::artscript(remember_state) == 0} {
		return
	}

	if {[file exists $::artscript_rc]} {

		set ofile [open $::artscript_rc r]
		set save_settings [read $ofile]
		close $ofile

		artscriptSetWidgetValues $save_settings
	}
}

proc osAdjusts { args } {
	# ::artscript(platform)
	# canvas default margins
	foreach canvas {canvas_alpha_color watermark_canvas} {
		# osx systemTransparent -background red -highlightbackground red
		$::widget_name($canvas) configure -highlightthickness 0 -borderwidth 0 -insertborderwidth 0 -insertwidth 0
	}
}

#-==== Global variable declaration
artscriptSettings
array set ::widget_name {}
set ::artscript_rc [file join [file dirname [info script]] ".artscriptrc"]
set ::artscript(tkpng) [tkpngLoad]
#-==== Global dictionaries, files values, files who process
set ::inputfiles [dict create]
set ::handlers [dict create]
set ::ops [getUserOps $::argv]
#-==== Find Optional dependencies (as global to search file only once)
set ::hasgimp [validate "gimp"]
set ::hasinkscape [validate "inkscape"]
set ::hascalligra [validate "calligraconverter"]
#-====# Global file counter TODO: separate delete to a list
set ::fc 1
set ::artscript(human_pos) [list [mc "TopLeft"] [mc "Top"] [mc "TopRight"] [mc "Left"] [mc "Center"] [mc "Right"] [mc "BottomLeft"] [mc "Bottom"]  [mc "BottomRight"]]
set ::artscript(magick_pos) [list "NorthWest" "North" "NorthEast" "West" "Center" "East" "SouthWest" "South" "SouthEast"]

# ---===  GUI Construct
updateWinTitle
wm protocol . WM_DELETE_WINDOW { artscriptSaveOnExit }
# Set close actions
bind . <Control-q> { artscriptSaveOnExit }

# We test if icon exist before addin it to the wm
set icon_image [expr {[string is bool -strict $::artscript(tkpng)] ? "artscript_48x48.png" : "artscript.gif"}]
set wmiconpath [file join $::artscript(dir) icons $icon_image]
if {![catch {set wmicon [image create photo -file $wmiconpath  ]} msg ]} {
	wm iconphoto . -default $wmicon
}

#-==== Get user presets from file
set ::presets [getUserPresets]

artscriptStyles
createImageVars

# Pack Top: menubar. Middle: File, thumbnail, options, suffix output.
# Bottom: status bar
guiTopBar .f1
guiMiddle .f2
guiStatusBar .f3

# Load drag and drop, after windows construct
catch { tkdndLoad }
# Set user presets
setUserPresets [lindex [dict key $::presets] 0]

# Os specifyc adjusts
osAdjusts

# ---=== Validate input filetypes
catch { artscriptOpenState }
wm geometry . $::artscript(window_geom)
set argvnops [lrange $::argv [llength $::ops] end]
listValidate $argvnops
