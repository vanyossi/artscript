artscriptk
==========

## How to install

* KDE
Inside the KD folder there is a file "arscript.desktop" tailored to use in Dolphin

1. Verify that ServiceMenus folder exists in ~/.kde/share/kde4/services/ServiceMenus (it can also be inside ~/.kde4/ or some variants) 
2. If ServiceMenus does not exist, create it.  
3. Copy "artscript.desktop" and "artscript.tcl" into ~/.kde/share/kde4/services/ServiceMenus. 
4. Open "artscript.desktop" with a text editor and check that the line "Exec=" points to the correct folder. (on my computer there is no .kde/ folder, it is called .kde4/ )
5. Go to Dolphin and right click an image. "Artscript TCL" menu should be available.
6. If it hasn't appear, check that file paths are correct and that "artscript.tcl" is executable
7. If you have the menu you are ready to use
8. Select files, right-click , select the item on the menu, use GUI.

As an alternative place for installation, you could place the "arscript.desktop" file inside "~/.local/share/applications" and place the script anywhere in your file system. Edit desktoip file to point to actual place in filesystem. I recommend using the ServiceMenus directory to keep everything organized.


