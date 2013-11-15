artscriptk
==========

Artscript is a small app to easy convert from production file images(KRA,XCF,PSD,ORA,SVG) to universal formats(JPG, PNG, GIF or WEBM). If installed tt uses gimp, inkscape and calligra in console mode to render PNG files in batch. Finally ImageMagick to arrange and finetune the final images. Artscript is made for digital painters, as such it aims for high quality results, not speed.


#About
*Script originally inspired by David Revoy (www.davidrevoy.com , info@davidrevoy.com )*

Imagemagick tools are used to scale, watermark and build image contact sheets(Collage Mode). It can accept all file formats supported by Imagemagick but for speed purposes I setted a filter for suggested input files.

*Input file formats:* .ai .bmp .dng .exr .gif .jpeg .jpg .kra .miff .ora .png .psd .svg .tga .tif .xcf .xpm .webp

Output formats are configured for quality, for that reason not all formats are supported yet.
*Output formats:* .jpg .png .gif .webm .webm(lossy)

There is a special output format mode to transform any image supported by Krita to ORA
*Make ora suggested:* .psd .kra .png

#### Goal
- Aid in the deploy of digital artwork for media with the best possible quality
- Core Dependencies: imagemagick, tk 8.5, zip, md5
- Optional dependencies: calligraconverter, inkscape, gimp
- Tested in: Xfce 4.10, thunar 1.4.0, dolphin and nautilus

###License
GPL 3.0
### Disclamer

I'm not a developer, what you have is the product of learning programming on my spare time.
There might be some rough edges and bugs and I encourage you to report them using github.

I tested artscript2 as much as I could to avoid corrupted files and unwanted overwrites, but bad things could happen. You use it at your own risk.

### Dependencies

- **Tcl/Tk:** 
- **ImageMagick (6.7.5 and up):** Library for manipulating image formats.
- **zip:** Get info from ORA and KRA files (width height and the likes)
- **md5:** Read and generate thumbnails
- **calligraconverter (optional):** Handles the extraction from ORA and KRA files to PNG. (Also does PSD if gimp is not present)
- **inkscape (optional):** Handles mostly SVG and AI converts. If not found Imagemagick will perform SVG transforms
- **gimp (optional):** Handles XCF and PSD extraction to PNG. If not found Imagemagick will perform XCF transforms


### What it does
In short, convert a bunch of images from format A to format B.

The advantage over other applications is the integration of gimp, inkscape and calligraconvert to the batch actions.

It's best used combined with a file manager (ex. thunar) or image manager (ex.geeqie) to quickly populate the file list from a selection. But it can be used standalone.

It's perfect for batch preparing images before publishing (web for ex), create thumbnails or collage of images in the directory, for example

# How to run it

- Place script somewhere in your hard drive ( I choose /home/User/.scripts )
- Make script executable if it isn't
```  $sh: chmod u+x artscripttk.tcl ```
- Run the script feeing files as arguments  
```	$sh: /path/to/script/artscripttk.tcl file1.jpg file2.png file3.ora```
- You can add a bash alias in ~/.bashrc file  
```      alias artscript='~/path/to/script/artscript'```
- And you can feed arguments using "xargs" feed pipe like  
```	find . -name '*.png' -print0 | xargs -0 ~/path/to/script/artscript.tcl```
- Or if you use an alias  
```	find . -name '*.png' -print0 | xargs -0 bash -cil 'artscript "$@"' arg0```
	
## Use in Context Menus

### XFCE

1. Open thunar>Edit>Configure Custom Actions...  
2. Add New action (+)  
3. Select a Name, Description and Icon.  
4. Add the next line to Command  
     --> ```wish path/to/script/artscript.tcl %N```  
5 In Apperance Conditions Tab, set '*' as file pattern and select  
     Image files and Other files
6. Other files is needed to make the dialog appear with .ora and .kra files  
*The script filters input file by mimetype so its safe to set the Appearance Conditions to all kind of files.*
7. A new submenu appears on right-click of Image Files
8. Select files, right-click , select the item on the menu, use GUI.


### Gnome / Nautilus

You will need "nautilus-actions" package installed.
```sudo apt-get install nautilus-actions```
```emerge nautilus-actions```
etc...

Tested on liveCD Mint 13

1. Open nautilus-actions (terminal 'nautilus-actions-config-tool')
2. Click on the plus (+) symbol to add a new action. (or go to "file > add new action")
3. On the action Tab set "Context Label" with "Artscript TCL"
4. In the Command tab set "Path:" as "/path/to/script.tcl" (absolute path)
5. In the same tab set "Parameters" as "%B"
6. On mimetype set Mimetype filter as "*/*" and "must match one of "selected"
7. Hit save.
8. Restart nautilus (On the liveCD I had to)
8. A new submenu appears "Nautilus-actions actions", click it, your action should be there.
9. Select files, right-click , select the item on the menu, use GUI.
10. To get "Artscriopt TCL" on root context menu, open "nautilus-actions-config-tool", in preferences "runtime preferences" uncheck "Create a root 'Nautilus actions' menu"

(references
http://techthrob.com/2009/03/02/howto-add-items-to-the-right-click-menu-in-nautilus/
http://www.howtogeek.com/116807/how-to-easily-add-custom-right-click-options-to-ubuntus-file-manager/
)


### KDE
Inside the KDE folder there is a file "arscript.desktop" tailored to use in Dolphin

1. Verify that ServiceMenus folder exists in ~/.kde/share/kde4/services/ServiceMenus (it can also be inside ~/.kde4/ or some variants) 
2. If ServiceMenus does not exist, create it.  
3. Copy "artscript.desktop" and "artscript.tcl" into ~/.kde/share/kde4/services/ServiceMenus. 
4. Open "artscript.desktop" with a text editor and check that the line "Exec=" points to the correct folder. (on my computer there is no .kde/ folder, it is called .kde4/ )
5. Go to Dolphin and right click an image. "Artscript TCL" menu should be available.
6. If it hasn't appear, check that file paths are correct and that "artscript.tcl" is executable
7. If you have the menu you are ready to use
8. Select files, right-click , select the item on the menu, use GUI.

As an alternative place for installation, you could place the "arscript.desktop" file inside "~/.local/share/applications" and place the script anywhere in your file system. Edit desktoip file to point to actual place in filesystem. I recommend using the ServiceMenus directory to keep everything organized.


# Usage GUI

All comboboxes can be edited pressing "Right CLick" to enter edit mode

### Watermark
- Select any preset, (you can edit text field)
- Set size, position and opacity of the waterarks options selected
- At the bottom the styles options are located. Color is for text color and Image blend mode defines how to combine the image pixels in the picture, I recomend Over, Multiply and Overlay

### Size
*By default resize is off:*
- Press + to add a new size.
- Size is organized as width x height.
- Selecting a Width value automatically selects the same value in the height box.
- Always set the widht first.
- Artscript can do multiple resize in the same operation. Add more sizes at will.

### Prefix and Suffix
- Left box corresponds to prefix, Box at the right is suffix
- Select Any value to activate it.
- Right click to edit the text in the box selected. (The edit will be lost if you select another list value)
- The string will join with an underscore with the original name

### Output format 
- Select an output extension
- Only rename will ignore the extension setting since no convert will be done.

Press Convert to Run options

### Collage (v2 In Development)
- To make a Collage from input files set "Make Collage Please" to on
- Make Collage Please checkbutton will generate a Tiled image containing all selected images. It will add a watermark if you set it so and a suffix.


# Customize:  
- Do not modify "artscript.tcl" file. Set your values using the presets file.


