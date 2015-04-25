artscript
==========

Artscript is, in essence, a small app (or big script) to easily convert production file images (KRA, XCF, PSD, ORA, SVG, PNG) to universal formats (JPG, PNG, GIF or WEBM). Made with digital designers and painters in mind the final images aim for high quality results, not speed processing. Careful control and tests were made to ensure the quality is best. 

In between the production file and the final image you can decide many aspects of the final image. The final image can be of any size (or multiple), have a watermark placed (image or text), or a collection or images can be ensembled together to form a tiled image file (For more details read "How to use it" section below).

The script is configurable almost entirely and the last used settings are remembered between sessions making the usage the least intrusive as possible. This fastens deployment of several images made for a project at different moments in the preproduction stage. In the configuration file its possible to set more than one preset, so you can have a "personal" preset, with sizes tailored for your blog and a "Client work" with your personal information as a watermark label a proper size, or sizes, for the client needs.

![Loaded artscritp GUI](http://colorathis.files.wordpress.com/2013/12/2013-12-11_1386804177.png)

### How it works
Artscript uses Imagemagick to output the final images. This creates a problem as imagemagick does not support XCF, PSD, SVG or AI fully or KRA, ORA at all. But, if the programs are available on the system, artscript will use Gimp, Inkscape or Krita (XCF, SVG , KRA, ORA…) to render the formats to PNG before converting to the final output.

The resulting PNGs are then feed to Imagemagick to get the desired output. This has the great benefit of rendering the files exactly as you worked them.

Other input images supported are: BMP, DNG EXR GIF JPG TGA TIF XPM WEBP

### Goal
- Aid in the deploy of digital artwork for media with the best possible quality

### License
GPL 3.0

### Credits
Developer:**Ivan Yossi** (http://colorathis.wordpress.com/ , ghevan@gmail.com)
Original idea:**David Revoy** (www.davidrevoy.com , info@davidrevoy.com)
Other contributors: Vasco Alexander Basqué (Gui advices)

Project page: https://github.com/vanyossi/artscriptk

### Disclamer
I'm a developer in development. I have tested as much as possible but there might be some rough edges and bugs. I encourage you to report on the github project page.

Ok so… what do I need?
----------------------
At the moment it only runs perfectly on Linux, as long as the dependencies are met. It has been tested to run ok on OSX but it will only convert imagemagick supported formats.

### Dependencies
- **Tcl/Tk:** 
- **ImageMagick (6.7.5 and up):** Library for manipulating image formats.
- **zip:** Get info from ORA and KRA files (width height and the likes)
- **Krita (optional):** Handles the extraction from ORA and KRA files to PNG. (Also does PSD if gimp is not present)
- **Inkscape (optional):** Handles mostly SVG and AI converts. If not found Imagemagick will perform SVG transforms
- **GIMP (optional):** Handles XCF and PSD extraction to PNG. If not found Imagemagick will perform XCF transforms

Detailed info: * [Installing Dependencies](https://github.com/vanyossi/artscriptk/wiki/Dependencies)


How to use it
-------------
The original idea was to have a small script to run from the file manager (dolphin, thunar nautilus) to quickly deploy the desired images. As such, that is the best way to use it, however it is posible to call it as standalone application. 

It can be used in the following ways
* From the right click menu of your file manager (recommended)
* From terminal. while it doesn't accept input from pipes you can feed the script using "xargs"
* Standalone: the script can be launched as an application on it's own. adding files using the buttons or dragging and dropping files into the app window.

### How to run it
* [In a context menu](https://github.com/vanyossi/artscriptk/wiki/Setting-a-context-menu)
* [From the terminal](https://github.com/vanyossi/artscriptk/wiki/Using-from-command-line)
* [As a standalone app](https://github.com/vanyossi/artscriptk/wiki/Using-as-Stand-alone-application)

Artscript usage
---------------
Below you will find the detailed instructions on how to use the script to add your watermarks, do multi-resize operations, making collages as well as the configuration options available.

* [Managing images](https://github.com/vanyossi/artscriptk/wiki/Managing-images)
* [Add watermarks](https	://github.com/vanyossi/artscriptk/wiki/Add-a-Watermark)
* [Resizing](https://github.com/vanyossi/artscriptk/wiki/Resizing)
* [Assembling a Collage](https://github.com/vanyossi/artscriptk/wiki/Assembling-a-Collage)
* [Preparing the output](https://github.com/vanyossi/artscriptk/wiki/Preparing-the-output)
* [Convert](https://github.com/vanyossi/artscriptk/wiki/Convert)


Personalizing the script
------------------------
The file called **presets.config.example** in the root folder has all the information you need to configure the default values.

Rename **presets.config.example** to **presets.config** to allow the script to find it. The file must be in the same directory as the script to be found.

Artscript remembers
-------------------
Artscript has an option to remember the choices you made the previous run. It is off by default. Activation is done in **presets.config** file. Search for the key remember_state and change the value to 1
```
remember_state=1
```
