# InstallerApp2ISO

InstallerApp2ISO is a macOS wrapper GUI application designed to run the bash script InstallerApp2ISO.sh developed by socratis @ VirtualBox forums.

If you have problems with InstallerApp2ISO then please email bryan@whatroute.net

#### Why do I need this application?
Unfortunately, many users are daunted by the macOS Terminal command line. A GUI gives them more confidence in what they are doing.

#### Can I run the shell script without this application?
Indeed you can. You can export (File/Export) the embedded bash script, InstallerAppToISO.sh, to any folder (for which you have access) on your Mac and execute it from the Terminal command line.

### Building InstallerApp2ISO
#### Prerequisites
* Xcode 10.2 or later
* An Apple Developer Code Signing Certificate. This is not essential but does make life easier. The source references my own certificate and you will nedd to replace/remove this to successfully build InstallerApp2ISO.

You can build InstallerApp2ISO with either the Xcode 10.2 IDE or from the command line using the supplied Makefile.