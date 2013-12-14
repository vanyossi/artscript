artscript Services
==========

## Files
Artscript                    Nautilus >=3.10 context menu
artscript.desktop            Dolphin KDE desktop action service
artscript.nemo_action        Nemo context menu

## How to install
Thanks to David Revoy for making and testing the files for Nemo and Nautilus
Up to date information: [Adding artscript as a context menu](https://github.com/vanyossi/artscriptk/wiki/Setting-a-context-menu)

### Nemo
1. Copy the file ```Artscript.nemo_action``` to ```~/.local/share/nemo/actions/```
2. Open file and edit the line containing
```
Exec=/path/to/artscriptk/artscript2.tcl %F
```
3. Change ```/path/to/artscript/``` to the actual path where you installed artscript2.tcl
4. From Cinnamon file explorer: right-click to view the new entry.

### Nautilus 3.10
1. Copy the file ```Artscript``` to ```~/.local/share/nautilus/scripts/```
2. Open file and edit the last line
```
/path/to/artscriptk/artscript2.tcl/ $NAUTILUS_SCRIPT_SELECTED_FILE_PATHS
```
3. Change ```/path/to/artscript/``` to the actual path where you installed artscript2.tcl
4. After doing that in Nautilus: right click ( Script > Artscript )

### Dolphin KDE
1. Copy the file ```artscript.desktop``` to ```~/.kde/share/kde4/services/ServiceMenus```
2. Open file and edit the line containing
```
Exec=/path/to/artscriptk/artscript2.tcl %F
```
3. Change ```/path/to/artscript/``` to the actual path where you installed artscript2.tcl
4. From Dolphin file explorer: right-click > Artscript.

### Thunar
[Wiki page Xfce menu](https://github.com/vanyossi/artscriptk/wiki/Setting-a-context-menu#xfce)


