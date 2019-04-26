# InstallerApp2ISO

InstallerApp2ISO is a macOS wrapper GUI application designed to run the bash script InstallerApp2ISO.sh developed by socratis @ VirtualBox forums.

It is compiled to run on Macintosh computers that run macOS 10.9 (Mavericks) or later.

It can generate bootable ISO installer files for macOS 10.8 and later.

<!-- NB - add link to download site for codesigned/notarized binary -->

If you have problems with InstallerApp2ISO then please email bryan@whatroute.net

#### Why do I need this application?
Unfortunately, many users are daunted by the macOS Terminal command line. A GUI gives them more confidence in what they are doing.

#### Can I run the shell script without this application?
Indeed you can. You can export (**File/Export Script**) the embedded bash script, InstallerAppToISO.sh, to any folder (for which you have access) on your Mac and execute it from the Terminal command line.

### Building InstallerApp2ISO
#### Prerequisites
* Xcode 10.2 or later
* An Apple Developer Code Signing Certificate. This is not essential but does make life easier. The source references my own certificate and you will nedd to replace/remove this to successfully build InstallerApp2ISO.

You can build InstallerApp2ISO with either the Xcode 10.2 IDE or from the command line using the supplied Makefile.

### Running InstallerApp2ISO
Double click InstallerApp2ISO to launch the application.

1. **Click-Drag** an 'Install macOS \<system\>' application (where \<system\> is e.g. Mojave or Sierra) and **Drop** it onto the panel at top left of the window (where it says - 'Drop Installer File'). Alternatively you can use the File/Open menu to select the input installer application.
2. Click the Create ISO button and wait for the spinning indicator to stop. Progress messages (or heaven forbid, errors!!) will be displayed in the lower panel.
3. On completion of the ISO creation, you will see a button 'Show in Finder'. If you click this, the folder containing your new ISO will be opened. By default, this will be your desktop.
4. You can select a different folder than the default (Desktop) by clicking the folder icon at top right of the window before clicking the Create ISO button.

This screenshot shows a successful run of InstallerApp2ISO.

![](images/installerapp2iso.png)

### Advanced Usage
#### Run from the command line
You can use **File/Export Script** to export the embedded shell script engine (InstallerApp2ISO.sh) to another folder on your machine and then run it from the Terminal command line.

List the shell script (in your favourite text editor or using commands such as *cat* or *less* - but take care not to modify it) to view the usage and allowable options.

### Logging
InstallerApp2ISO.sh produces extensive logging of its activities. Using the **Log Detail** button you are able to control the verbosity of this logging. Set the detail you want *before* creating the ISO file.

You can save the output logging to a text file with the menu commands:
 
* Save Log...
* Save Log As...