#!/bin/bash
#
# Script to create an ISO from the Apple application installers.
#
# Copyright (C) 2017-2019, socratis @ VirtualBox forums,
#          with help from granada29 @ VirtualBox forums.
#
# This file is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License (GPL) as published
# by the Free Software Foundation. It is distributed in the hope that it
# will be useful, but WITHOUT ANY WARRANTY of any kind.
#



# ---------------------------------------------------------------
# Clean up our mess from previously failed attempts.
# ---------------------------------------------------------------
hdiutil detach -force /Volumes/Install* -quiet
hdiutil detach -force /Volumes/OS\ X\ Base\ System -quiet



# ---------------------------------------------------------------
# Set some script strict checking
# ---------------------------------------------------------------
set -o errexit;
set -u
set -o pipefail



# ---------------------------------------------------------------
# Setup some global variables.
# ---------------------------------------------------------------
MY_INSTAPP=""
MY_DESTDIR=`(cd ~/Desktop; pwd)`
MY_TEMPDIR="/tmp"
MY_HOST_OSX="`(sw_vers | grep ProductVersion: | cut -d':' -f2 | awk '{$1=$1;print}')` (`(sw_vers | grep BuildVersion: | cut -d':' -f2 | awk '{$1=$1;print}')`)"
MY_OSXVERSION=""
MY_OSXBUILD=""
MY_OSXSCRIPT=""
MY_VERSION=""
MY_DESTFREE=0
MY_TEMPFREE=0
MY_CHECKSUM=0
MY_DRYRUN=0
MY_VERBOSE=1
MY_VERBOSECMD=""
MY_VERBOSEASR=""
MY_IGNOREPROMPT=0
MY_PRIVILEGED="sudo"
MY_COMMAND="$0"



# ---------------------------------------------------------------
# Display a simple welcome message first after clearing the screen.
# ---------------------------------------------------------------
clear
echo "================================================================================"
echo "Apple OSX Installer Application to ISO creation tool"
echo "================================================================================"
echo "Version: 2019-11-27"
echo "Copyright (C) 2017-2019, socratis @ VirtualBox forums,"
echo "         with help from granada29 @ VirtualBox forums."
echo "All rights reserved."
echo ""



# ---------------------------------------------------------------
# Version history
# ---------------------------------------------------------------
my_revision()
{
    echo ""
    echo "Version history:"
    echo ""
    echo "  2020-07-27"
    echo "      - Added support for 10.15.5, 10.15.6."
    echo ""
    echo "  2020-04-03"
    echo "      - Added support for 10.15.3, 10.15.4."
    echo ""
    echo "  2019-11-27"
    echo "      - Added support for 10.15.1, 10.15.2."
    echo "      - Disable Spotlight before unmounting sparse image."
    echo "      - Fixed an issue when running administrator tasks from within the app."
    echo ""
    echo "  2019-08-25"
    echo "      - Added support for 10.14.6."
    echo "      - Added support for 10.7."
    echo ""
    echo "  2019-06-05"
    echo "      - Added support for up to 10.15.beta and beyond."
    echo "      - When using the dry-run simply check for the existence of the installer."
    echo "        Do not check for the available free space or the output/temp directory,"
    echo "        since no actual conversion will take place."
    echo ""
    echo "  2019-05-28"
    echo "      - Small fixes for the 3rd party authentication."
    echo "      - Change the 'if' statements style from 'test' to '[]'."
    echo ""
    echo "  2019-05-26 (granada29 version)"
    echo "      - There is a GUI app by granada29 that encapsulates the script functionality"
    echo "        https://www.whatroute.net/installerapp2iso.html"
    echo "      - Incorporated changes by granada29 for authorization/batch processing."
    echo "      - Added support for up to 10.14.5."
    echo ""
    echo "  2019-01-04"
    echo "      - Added support for 10.14.0, .2 (18C54)."
    echo "      - Added support for (hopefully) all 10.8.x."
    echo "      - Added host OSX version information."
    echo ""
    echo "  2018-08-16"
    echo "      - Added support for 10.13.6 (17G65)."
    echo ""
    echo "  2018-06-10"
    echo "      - Added support for 10.13.5 (17F77)."
    echo "      - Added support for 10.14 beta (18A293u)."
    echo ""
    echo "  2018-04-18 (Dim version)"
    echo "      - Finally unified the 10.9-10.13 scripts!"
    echo "        Unfortunately the 10.13 scripts require 'admin' group membership."
    echo "      - Removed the \"--checksum\" option. It never worked to begin with."
    echo ""
    echo "  2017-07-25"
    echo "      - When using the dry-run it doesn't check for anything anymore."
    echo "        Not the existence of the installer nor the available free space."
    echo "      - Trimming of the free space from the sparsebundle is back."
    echo ""
    echo "  2017-06-18"
    echo "      - Fixed an issue where if the destination volume contained a space, the"
    echo "        calculation for the amount of free space generated an error."
    echo "      - Fixed inconsistencies in ISO vs iso."
    echo ""
    echo "  2017-05-17"
    echo "      - Updated to cover OSX 10.12.5 (16F73)."
    echo "      - Fixed verbosity flags for some cases."
    echo ""
    echo "  2017-04-02"
    echo "      - Updated to cover OSX 10.12.4 (16E195)."
    echo "      - The '--OSX' flag was ignored if the '--dry-run' was not set as well."
    echo "        Now you can use future OSX updates even if the script doesn't cover them."
    echo "      - Fixed a cosmetic error if the verbose level was set to 2 or 3."
    echo "      - Fixed a cosmetic error by closing the 'OSX Base System' window."
    echo "      - Added version and revision information."
    echo ""
    echo "  2017-03-01"
    echo "      - First release."
    echo ""
    exit 0;
}




# ---------------------------------------------------------------
# Print out basic instructions in case of erroneous input.
# ---------------------------------------------------------------
my_usage()
{
    echo ""
    echo "Usage:"
    echo ""
    echo "   InstallerApp2ISO  -i|--installer <InstallerApp>"
    echo "                    [-o|--output <OutputDir>]"
    echo "                    [-t|--tmpdir <TempDir>]"
    echo "                    [-v|--verbose <VerboseLevel>]"
    echo "                    [-d|--dry-run]"
    echo "                    [-p|--privileged <AltSudo>]"
    echo "                    [-x|--OSX <OSXVersion>]"
    echo "                    [-y|--yes]"
#    echo "                    [-c|--checksum]"
    echo "                    [-r|--revision]"
    echo "                    [-h|-?|--help]"
    echo ""
    echo "-i|--installer  The full path of the InstallerApp. *** MANDATORY ***"
    echo ""
    echo "-o|--output     The directory where the resulting ISO will be created."
    echo "                The name will be 10.x.y.iso. Default is your desktop."
    echo "                The directory will be checked for free space availability."
    echo ""
    echo "-t|--tmpdir     If you are running low on space, you can provide an"
    echo "                alternative temporary/scratch directory. The directory"
    echo "                will be checked for free space availability."
    echo "                *******************************************************"
    echo "                ***** DO NOT CHOOSE A NETWORK TEMPORARY DIRECTORY *****"
    echo "                *******************************************************"
    echo ""
    echo "-v|--verbose    Some OSX commands support --verbose and --quiet options."
    echo "                In addition, the verbose level can control whether the"
    echo "                the commands are printed before they are executed: "
    echo "                  0: Set the quiet flag in OSX. Commands are not printed."
    echo "                  1: Set no flags in OSX. Commands are not printed. DEFAULT."
    echo "                  2: Set no flags in OSX. Commands are printed."
    echo "                  3: Set the verbose flag in OSX. Commands are printed."
    echo ""
    echo "-d|--dry-run    Doesn't actually run the scripts, simply output the"
    echo "                commands that would be used with the given parameters."
    echo ""
    echo "-p|--privileged Command to use if 'sudo' is not available"
    echo ""
    echo "-x|--OSX        OSXVersion can be one of the following strings:"
    echo "                '10.7', '10.8', '10.9', '10.10', '10.11', '10.12', '10.13',"
    echo "                '10.14', '10.15'."
    echo "                You should use it in case that the OSX version cannot be"
    echo "                determined automatically, *OR* if you're running a dry run."
    echo ""
    echo "-y|--yes        Proceed without prompting user"
    echo ""
#    echo "-c|--checksum   Compare the output of the generated ISO with a list of"
#    echo "                known checksums. Optional, but useful."
#    echo ""
    echo "-r|--revision   Print the revision history of the script."
    echo ""
    echo "-h|-?|--help    Print this help message."
    echo ""
    exit $1;
}




# ---------------------------------------------------------------
# Parse the arguments.
# ---------------------------------------------------------------
if [ $# -eq "0" ]; then
    echo "*** ERROR: No arguments specified. The --installer option is mandatory."
    my_usage 1
fi

while test $# -ge 1;
do
    ARG=$1;
    shift;
    case "$ARG" in

        -i|--installer)
            if [ $# -eq 0 ] ; then
                echo "*** ERROR: missing --installer argument.";
                echo "";
                exit 1;
            fi
            MY_INSTAPP="$1";
            shift;
            ;;

        -o|--output)
            if [ $# -eq 0 ] ; then
                echo "*** ERROR: missing --output argument.";
                echo "";
                exit 1;
            fi
            MY_DESTDIR="$1";
            shift;
            ;;

        -t|--tmpdir)
            if [ $# -eq 0 ] ; then
                echo "*** ERROR: missing --tmpdir argument.";
                echo "";
                exit 1;
            fi
            MY_TEMPDIR="$1";
            shift;
            ;;

        -v|--verbose)
            if [ $# -eq 0 ] ; then
                echo "*** ERROR: missing --verbose argument.";
                echo "";
                exit 1;
            fi
            MY_VERBOSE="$1";
            shift;
            ;;

        -p|--privileged)
            if [ $# -eq 0 ] ; then
                echo "*** ERROR: missing --privileged argument.";
                echo "";
                exit 1;
            fi
            MY_PRIVILEGED="$1";
            shift;
            ;;

        -d|--dry-run)
            MY_DRYRUN=1;
            ;;

        -x|--OSX)
            if [ $# -eq 0 ] ; then
                echo "*** ERROR: missing --OSX argument.";
                echo "";
                exit 1;
            fi
            MY_OSXVERSION="$1";
            shift;
            ;;

        -y|--yes)
            MY_IGNOREPROMPT=1;
            ;;

#         -c|--checksum)
#             MY_CHECKSUM=1;
#             ;;

        -r|--revision)
            my_revision;
            ;;

## The --? was deprecated
        -h|-?|--help|--?)
            my_usage 0;
            ;;
        *)
            echo "*** ERROR: Invalid syntax."
            my_usage 1;
            ;;
    esac
done

# ---------------------------------------------------------------
# Verbose output.
# ---------------------------------------------------------------
if [ $MY_VERBOSE -ge "2" ]; then
    echo "--------------------------------------------------------------------------------"
    echo "VERBOSE OUTPUT"
    echo "--------------------------------------------------------------------------------"
    echo "MY_HOST_OSX   = $MY_HOST_OSX"
    echo "MY_COMMAND    = $MY_COMMAND"
    echo "MY_INSTAPP    = $MY_INSTAPP"
    echo "MY_DESTDIR    = $MY_DESTDIR"
    echo "MY_TEMPDIR    = $MY_TEMPDIR"
    echo "MY_DRYRUN     = $MY_DRYRUN"
    echo "MY_VERBOSE    = $MY_VERBOSE"
    echo "MY_OSXVERSION = $MY_OSXVERSION"
    echo "--------------------------------------------------------------------------------"
    echo ""
fi

# ---------------------------------------------------------------
# Verbose output. Unfortunately this cannot go after the argument parsing. WHY???
# ---------------------------------------------------------------
# if [ $MY_VERBOSE -ge "2" ]; then
#     echo "--------------------------------------------------------------------------------"
#     echo "VERBOSE OUTPUT"
#     echo "--------------------------------------------------------------------------------"
#     echo "Script full path        : $MY_COMMAND"
#     echo "All arguments           : $MY_ARGUMENTS"
#     for (( i=1; i<${#MY_ARGUMENTS[@]}; i++ ));
#     do
#         echo "Argument $((i+1))       : $i"
#     done
#     echo "--------------------------------------------------------------------------------"
#     echo ""
# fi



# ---------------------------------------------------------------
# Check the installer argument.
# ---------------------------------------------------------------

# Remove the trailing /, if any.
MY_INSTAPP=${MY_INSTAPP%/}

if ! [ -d "${MY_INSTAPP}" ]; then
    echo "*** ERROR: OSX InstallerApp does not exist, or you don't have read access:"
    echo "           -> $MY_INSTAPP";
    echo "";
    exit 1;
fi

if ! [ -f "${MY_INSTAPP}/Contents/version.plist" -a -f  "${MY_INSTAPP}/Contents/SharedSupport/InstallESD.dmg" ]; then
    echo "*** ERROR: The provided application is NOT a valid OSX InstallerApp:"
    echo "           -> $MY_INSTAPP";
    echo "           -> ${MY_INSTAPP}/Contents/SharedSupport/InstallESD.dmg file not found!";
    echo "";
    exit 1;
fi



# ---------------------------------------------------------------
# Check the destination argument.
# ---------------------------------------------------------------

# Remove the trailing /, if any.
MY_DESTDIR=${MY_DESTDIR%/}

if [ "$MY_DESTDIR" == "" ]; then
    echo "*** ERROR: You cannot select the root directory as a destination!"
    echo "";
    exit 1;
fi

# Get the available free space on the destination.
MY_DESTFREE=`(df "$MY_DESTDIR" | awk 'NR>1 {print $4}')`
MY_DESTFREE=$[ MY_DESTFREE/2/1024/1024 ];

# Skip the checks if we're simply dry-running the script
if [ $MY_DRYRUN -eq "0" ]; then
    if ! [ -d "${MY_DESTDIR}" ]; then
        echo "*** ERROR: Destination directory does not exist:"
        echo "           -> $MY_DESTDIR";
        echo "";
        exit 1;
    fi

    if ! [ -w "${MY_DESTDIR}" ]; then
        echo "*** ERROR: Destination directory is not writable:"
        echo "           -> $MY_DESTDIR";
        echo "";
        exit 1;
    fi

    # Check for available free space on the destination.
    if [ $MY_DESTFREE -lt 15 ]; then
        echo "*** ERROR: Not enough free space in destination directory:"
        echo "           -> $MY_DESTDIR";
        echo "           $MY_DESTFREE GiB free, at least 15 GiB needed.";
        echo "";
        exit 1;
    fi
fi



# ---------------------------------------------------------------
# Check the temporary argument.
# ---------------------------------------------------------------

# Remove the trailing /, if any.
MY_TEMPDIR=${MY_TEMPDIR%/}

if [ "$MY_TEMPDIR" == "" ]; then
    echo "*** ERROR: You cannot select the root directory as a temp directory!"
    echo "";
    exit 1;
fi

if [ "$MY_TEMPDIR" == "`(cd $TMPDIR; pwd)`" ]; then
    echo "*** ERROR: The temporary directory is the same as the system directory."
    echo "           This will definitely lead to errors. You should change it."
    echo "           We suggest using /tmp"
    echo "";
    exit 1;
fi

# Get available free space on the temp directory.
MY_TEMPFREE=`(df "$MY_TEMPDIR" | awk 'NR>1 {print $4}')`
MY_TEMPFREE=$[ MY_TEMPFREE/2/1024/1024 ];

# Skip the checks if we're simply dry-running the script
if [ $MY_DRYRUN -eq "0" ]; then
    if ! [ -d "${MY_TEMPDIR}" ]; then
        echo "*** ERROR: Temporary directory does not exist:";
        echo "           -> $MY_TEMPDIR"
        echo "";
        exit 1;
    fi

    if ! [ -w "${MY_TEMPDIR}" ]; then
        echo "*** ERROR: Temporary directory is not writable:"
        echo "           -> $MY_TEMPDIR";
        echo "";
        exit 1;
    fi

    # Check for available free space on the temp directory.
    if [ $MY_TEMPFREE -lt 15 ]; then
        echo "*** ERROR: Not enough free space in temporary directory:"
        echo "           -> $MY_TEMPDIR";
        echo "           $MY_TEMPFREE GiB free, at least 15 GiB needed.";
        echo "";
        exit 1;
    fi
fi



# ---------------------------------------------------------------
# Check the verbosity level.
# ---------------------------------------------------------------
case "$MY_VERBOSE" in
    0)
        MY_VERBOSECMD="-quiet"
        MY_VERBOSEASR=""
        ;;
    1|2)
        MY_VERBOSECMD=""
        MY_VERBOSEASR=""
        ;;
    3)
        MY_VERBOSECMD="-verbose"
        MY_VERBOSEASR="-verbose"
        ;;
    *)
        echo "*** ERROR: wrong --verbose argument ($MY_VERBOSE).";
        echo "";
        my_usage 1;
esac



# ---------------------------------------------------------------
# Check OSX version.
# http://loefflmann.blogspot.gr/2015/03/finding-os-x-version-and-build-in-install-os-x-app.html
# ---------------------------------------------------------------
if [ "$MY_OSXVERSION" == "" ]; then
    echo "- OSX version: attempting automatic OSX detection from the InstallerApp...";


# The key difference in the 10.13/14 installers is that the BaseSystem.dmg is now in the InstallerApp
# and not inside the InstallESD.dmg image. So if the BaseSystem.dmg exists => >10.13.x.
# Also, we need to check membership in the "admin" group, otherwise the 'sudo' that's required for
# the conversion will fail later down the road.

    if [ -f "${MY_INSTAPP}/Contents/SharedSupport/BaseSystem.dmg" ]; then
        MY_OSXSCRIPT="10.13-10.15"
        echo "- OSX version: 10.13, 10.14 or 10.15 InstallerApp detected!"
    fi

    if [ "$MY_OSXSCRIPT" == "10.13-10.15" ] ; then
        echo "- OSX version: Testing for 10.13-10.15"
        hdiutil attach "$MY_INSTAPP/Contents/SharedSupport/BaseSystem.dmg" $MY_VERBOSECMD -noverify -nobrowse -mountpoint /Volumes/BaseSystem -quiet
    else
        echo "- OSX version: Testing for 10.7, 10.8, 10.9, 10.10, 10.11, 10.12"
        hdiutil attach "$MY_INSTAPP/Contents/SharedSupport/InstallESD.dmg" $MY_VERBOSECMD -noverify -nobrowse -mountpoint /Volumes/InstallESD -quiet
        hdiutil attach "/Volumes/InstallESD/BaseSystem.dmg" $MY_VERBOSECMD -noverify -nobrowse -mountpoint /Volumes/BaseSystem -quiet
    fi

    MY_SYSTEMPLIST=$(<"/Volumes/BaseSystem/System/Library/CoreServices/SystemVersion.plist")
    if [[ "$MY_SYSTEMPLIST" =~ \<key\>ProductVersion\</key\>[[:space:]]*\<string\>([0-9\.]+)\</string\> ]]; then
        MY_OSXVERSION=${BASH_REMATCH[1]}
    fi
    if [[ "$MY_SYSTEMPLIST" =~ \<key\>ProductBuildVersion\</key\>[[:space:]]*\<string\>([0-9A-Za-z]+)\</string\> ]]; then
        MY_OSXBUILD=${BASH_REMATCH[1]}
    fi

    echo "- OSX version detected: $MY_OSXVERSION ($MY_OSXBUILD)"

# Eject the BaseSystem.dmg mount
    hdiutil detach -force "/Volumes/BaseSystem" $MY_VERBOSECMD -quiet
    sleep 2

# There was an additional mount for < 10.13-10.15, the InstallESD.dmg, eject that as well.
    if [ "$MY_OSXSCRIPT" != "10.13-10.15" ] ; then
        hdiutil detach -force "/Volumes/InstallESD" $MY_VERBOSECMD -quiet
    fi
else
    MY_OSXBUILD="* MANUAL *"
    echo "* WARNING: OSX version set manually to '$MY_OSXVERSION' ($MY_OSXBUILD)."
    echo "           The InstallerApp will not be checked for its existence and"
    echo "           no version information will be automatically retrieved."
fi


case $MY_OSXVERSION in
    "")
        echo "*** ERROR: OSX version could not be determined."
        echo "           You need to rerun the script and specify the --OSX switch.";
        my_usage 1;
        ;;
    10.7|10.7.1|10.7.2|10.7.3|10.7.4|10.7.5)
        MY_OSXSCRIPT="10.7-10.10";;
    10.8|10.8.1|10.8.2|10.8.3|10.8.4|10.8.5)
        MY_OSXSCRIPT="10.7-10.10";;
    10.9|10.9.1|10.9.2|10.9.3|10.9.4|10.9.5)
        MY_OSXSCRIPT="10.7-10.10";;
    10.10|10.10.1|10.10.2|10.10.3|10.10.4|10.10.5)
        MY_OSXSCRIPT="10.7-10.10";;
    10.11|10.11.1|10.11.2|10.11.3|10.11.4|10.11.5|10.11.6)
        MY_OSXSCRIPT="10.11-10.12";;
    10.12|10.12.1|10.12.2|10.12.3|10.12.4|10.12.5|10.12.6)
        MY_OSXSCRIPT="10.11-10.12";;
    10.13|10.13.1|10.13.2|10.13.3|10.13.4|10.13.5|10.13.6)
        MY_OSXSCRIPT="10.13-10.15";;
    10.14|10.14.1|10.14.2|10.14.3|10.14.4|10.14.5|10.14.6)
        MY_OSXSCRIPT="10.13-10.15";;
    10.15|10.15.1|10.15.2|10.15.3|10.15.4|10.15.5|10.15.6)
        MY_OSXSCRIPT="10.13-10.15";;
    *)
        echo "*** ERROR: Invalid OSX version specified: $MY_OSXVERSION";
        echo "           You need to rerun the script with an appropriate --OSX switch.";
        my_usage 1;;
esac



# ---------------------------------------------------------------
# Check if intermediate files exist. We need to delete them to avoid errors.
# ---------------------------------------------------------------
if [ -f "${MY_DESTDIR}/${MY_OSXVERSION}.iso" -o -f "${MY_TEMPDIR}/${MY_OSXVERSION}.cdr" -o -f "${MY_TEMPDIR}/${MY_OSXVERSION}.sparseimage" ]; then
    echo "* WARNING: The following file(s) already exist in the destination/temporary directory:"
    if [ -f "${MY_DESTDIR}/${MY_OSXVERSION}.iso" ]; then
        echo "           -> $MY_DESTDIR/$MY_OSXVERSION.iso"
    fi
    if [ -f "${MY_TEMPDIR}/${MY_OSXVERSION}.cdr" ]; then
        echo "           -> $MY_TEMPDIR/$MY_OSXVERSION.cdr"
    fi
    if [ -f "${MY_TEMPDIR}/${MY_OSXVERSION}.sparseimage" ]; then
        echo "           -> $MY_TEMPDIR/$MY_OSXVERSION.sparseimage"
    fi

    if [ $MY_IGNOREPROMPT -eq "0" ]; then
        echo ""
        echo "*** IF YOU CONTINUE THE FILE(S) WILL BE DELETED! ***"
        echo ""
        echo "Continue? (Yes/No)"
        printf "\a"

        read MY_ANSWER
        if [ "$MY_ANSWER" != "Yes" -a "$MY_ANSWER" != "YES" -a "$MY_ANSWER" != "yes" -a "$MY_ANSWER" != "Y" -a "$MY_ANSWER" != "y" ] ; then
            echo "Aborting app conversion. Your answer was: '$MY_ANSWER')".
            exit 2;
        fi
    fi

    if [ -f "${MY_DESTDIR}/${MY_OSXVERSION}.iso" ]; then
        rm "${MY_DESTDIR}/${MY_OSXVERSION}.iso"
    fi
    if [ -f "${MY_TEMPDIR}/${MY_OSXVERSION}.cdr" ]; then
        rm "${MY_TEMPDIR}/${MY_OSXVERSION}.cdr"
    fi
    if [ -f "${MY_TEMPDIR}/${MY_OSXVERSION}.sparseimage" ]; then
        rm "${MY_TEMPDIR}/${MY_OSXVERSION}.sparseimage"
    fi
fi



# ---------------------------------------------------------------
# Confirmation output.
# ---------------------------------------------------------------
echo "--------------------------------------------------------------------------------"
echo "The conversion will use the following parameters:"
echo "    - Host OSX version        : $MY_HOST_OSX"
echo "    - Installer application   : $MY_INSTAPP"
echo "    - OSX version (build)     : $MY_OSXVERSION ($MY_OSXBUILD)"
echo "    - Destination directory   : $MY_DESTDIR ($MY_DESTFREE GiB/$(($MY_DESTFREE*1024*1024/1000/1000)) GB free)"
echo "    - Temporary directory     : $MY_TEMPDIR ($MY_TEMPFREE GiB/$(($MY_TEMPFREE*1024*1024/1000/1000)) GB free)"
echo "    - OSX version scripts     : $MY_OSXSCRIPT scripts for version $MY_OSXVERSION ($MY_OSXBUILD)"
echo "    - Verbosity level         : $MY_VERBOSE"
# echo "    - Calculate ISO checksum  : $MY_CHECKSUM"
echo "    - Dry-run cmd. output     : $MY_DRYRUN"

# Check for membership in the "admin" group for the 10.13-10.15 installer
# The check will only happen if the authentication is using 'sudo'
# In any other case, a 3rd party authentication app is used, deal with it in the app.
if [ "$MY_OSXSCRIPT" == "10.13-10.15" ] ; then
    if [ "$MY_PRIVILEGED" != "sudo" ] ; then
        echo "    - Admin group membership  : Will be verified."
    elif id -nG | grep -qw "admin"; then
        echo "    - Admin group membership  : Required and met."
    else
        echo "    - Admin group membership  : *** Required but not met! ***"
        echo ""
        if [ $MY_DRYRUN -eq "0" ]; then
            echo "************************   I M P O R T A N T   ************************"
            echo "\"$USER\" does *not* belong to the admin group, conversion can *not*"
            echo "proceed. The 10.13-10.15.x conversion requires the use of \`sudo\`,"
            echo "something only available to users belonging to the 'admin' group."
            echo ""
            echo "Run again the script as a user that belongs in the admin group,"
            echo "typically the computer 'owner'."
            echo "***********************************************************************"
            exit 1;
        fi
    fi
# No admin required if not 10.13-10.15
else
    echo "    - Admin group membership  : Not required"
fi

echo ""
if [ $MY_DRYRUN -eq "0" ]; then
    echo "************************   I M P O R T A N T   ************************"
    echo "Please understand that there is feedback for most processes, but not"
    echo "for all of them, such as copying and moving. They can take up to ten"
    echo "minutes or more, depending on your HD speed. If you selected a network"
    echo "location or an external HD, these times can vary a lot."
    echo "***********************************************************************"
else
    echo "************************   I M P O R T A N T   ************************"
    echo "You chose to execute a dry-run of the script. No commands will actually"
    echo "execute, but the appropriate commands will be printed based on the"
    echo "input parameters that you have chosen above."
    echo "***********************************************************************"
fi
echo ""

if [ $MY_IGNOREPROMPT -eq "0" ]; then
    echo "Continue? (Yes/No)"
    printf "\a"

    read MY_ANSWER
    if [ "$MY_ANSWER" != "Yes" -a "$MY_ANSWER" != "YES" -a "$MY_ANSWER" != "yes" -a "$MY_ANSWER" != "Y" -a "$MY_ANSWER" != "y" ] ; then
        echo "Aborting app conversion. Your answer was: '$MY_ANSWER')".
        exit 2;
    fi
fi
echo ""



# ---------------------------------------------------------------
# ---------------------------------------------------------------
# ---------------------------------------------------------------
# ---------------------------------------------------------------
# ---------------------------------------------------------------



MY_TIMESTART=$(date +%s) 
MY_TIMEEND=$(date +%s)
if [ $MY_DRYRUN -eq "0" ]; then
    echo ""
    echo "Conversion script started on: $(date +'%F %T %Z')"
    echo "--------------------------------------------------------------------------------"
fi

# ---------------------------------------------------------------
# The actual conversion scripts.
# Mounting the InstallESD. Not needed for 10.13-10.15.x
# ---------------------------------------------------------------

if [ "$MY_OSXSCRIPT" != "10.13-10.15" ] ; then
    if [ $MY_DRYRUN -eq "0" ]; then
        echo ""
        echo "Mount the installer image..."
        echo "--------------------------------------------------------------------------------"
    fi
    if [ $MY_VERBOSE -ge "2" -o $MY_DRYRUN -ne "0" ]; then
        echo "hdiutil attach \"$MY_INSTAPP/Contents/SharedSupport/InstallESD.dmg\" -noverify -nobrowse -mountpoint /Volumes/InstallESD $MY_VERBOSECMD"
        echo "osascript -e \"tell application \\\"Finder\\\" to close window \\\"OS X Install ESD\\\"\""
    fi
    if [ $MY_DRYRUN -eq "0" ]; then
        hdiutil attach  "$MY_INSTAPP/Contents/SharedSupport/InstallESD.dmg"  -noverify -nobrowse -mountpoint /Volumes/InstallESD $MY_VERBOSECMD
        set +o errexit;
        osascript -e "tell application \"Finder\" to close window \"OS X Install ESD\"" > /dev/null
        set -o errexit;
    fi
fi



# ***************************************************************
# Create the image that is going to hold the end result
# ***************************************************************

# ---------------------------------------------------------------
# Conditional for 10.7, 10.8, 10.9, 10.10.
# ---------------------------------------------------------------
if [ "$MY_OSXSCRIPT" == "10.7-10.10" ] ; then
    if [ $MY_DRYRUN -eq "0" ]; then
        echo ""
        echo "Convert the boot image to a sparse bundle... (patience is a virtue)"
        echo "--------------------------------------------------------------------------------"
    fi
    if [ $MY_VERBOSE -ge "2" -o $MY_DRYRUN -ne "0" ]; then
        echo "hdiutil convert /Volumes/InstallESD/BaseSystem.dmg -format UDSP -o \"$MY_TEMPDIR/$MY_OSXVERSION.sparseimage\" $MY_VERBOSECMD"
    fi
    if [ $MY_DRYRUN -eq "0" ]; then
              hdiutil convert /Volumes/InstallESD/BaseSystem.dmg -format UDSP -o  "$MY_TEMPDIR/$MY_OSXVERSION.sparseimage" $MY_VERBOSECMD
    fi

    if [ $MY_DRYRUN -eq "0" ]; then
        echo ""
        echo "Increase the sparse bundle capacity to 8GiB to accommodate the packages..."
        echo "--------------------------------------------------------------------------------"
    fi
    if [ $MY_VERBOSE -ge "2" -o $MY_DRYRUN -ne "0" ]; then
        echo "hdiutil resize -size 8g \"$MY_TEMPDIR/$MY_OSXVERSION.sparseimage\" $MY_VERBOSECMD"
    fi
    if [ $MY_DRYRUN -eq "0" ]; then
              hdiutil resize -size 8g  "$MY_TEMPDIR/$MY_OSXVERSION.sparseimage"  $MY_VERBOSECMD
    fi
fi
# ---------------------------------------------------------------
# End of conditional for 10.7, 10.8, 10.9, 10.10.


# ---------------------------------------------------------------
# Conditional for 10.11, 10.12, 10.13, 10.14, 10.15.
# ---------------------------------------------------------------
if [ "$MY_OSXSCRIPT" != "10.7-10.10" ] ; then
    if [ $MY_DRYRUN -eq "0" ]; then
        echo ""
        echo "Create $MY_OSXVERSION blank ISO image with a Single Partition - Apple Partition Map..."
        echo "--------------------------------------------------------------------------------"
    fi
    if [ $MY_VERBOSE -ge "2" -o $MY_DRYRUN -ne "0" ]; then
        echo "hdiutil create -o \"$MY_TEMPDIR/$MY_OSXVERSION.sparseimage\" -size 8g -layout SPUD -fs HFS+J -type SPARSE $MY_VERBOSECMD"
    fi
    if [ $MY_DRYRUN -eq "0" ]; then
              hdiutil create -o  "$MY_TEMPDIR/$MY_OSXVERSION.sparseimage"  -size 8g -layout SPUD -fs HFS+J -type SPARSE $MY_VERBOSECMD
    fi
fi
# ---------------------------------------------------------------
# End of conditional for 10.11, 10.12, 10.13, 10.14, 10.15.




# ***************************************************************
# Mount the sparse bundle
# ***************************************************************

if [ $MY_DRYRUN -eq "0" ]; then
    echo ""
    echo "Mount the sparse bundle for package addition..."
    echo "--------------------------------------------------------------------------------"
fi
if [ $MY_VERBOSE -ge "2" -o $MY_DRYRUN -ne "0" ]; then
    echo "hdiutil attach \"$MY_TEMPDIR/$MY_OSXVERSION.sparseimage\" -noverify -nobrowse -mountpoint /Volumes/OS\ X\ Base\ System $MY_VERBOSECMD"
fi
if [ $MY_DRYRUN -eq "0" ]; then
          hdiutil attach  "$MY_TEMPDIR/$MY_OSXVERSION.sparseimage"  -noverify -nobrowse -mountpoint /Volumes/OS\ X\ Base\ System $MY_VERBOSECMD
fi



# ---------------------------------------------------------------
# Conditional for 10.11, 10.12.
# ---------------------------------------------------------------
if [ "$MY_OSXSCRIPT" == "10.11-10.12" ] ; then
    if [ $MY_DRYRUN -eq "0" ]; then
        echo ""
        echo "Restore the Base System into the $MY_OSXVERSION ISO image..."
        echo "--------------------------------------------------------------------------------"
    fi
    if [ $MY_VERBOSE -ge "2" -o $MY_DRYRUN -ne "0" ]; then
        echo "asr restore -source /Volumes/InstallESD/BaseSystem.dmg -target /Volumes/OS\ X\ Base\ System -noprompt -noverify -erase $MY_VERBOSEASR"
        echo "osascript -e \"tell application \\\"Finder\\\" to close window \\\"OS X Base System\\\"\""
    fi
    if [ $MY_DRYRUN -eq "0" ]; then
              asr restore -source /Volumes/InstallESD/BaseSystem.dmg -target /Volumes/OS\ X\ Base\ System -noprompt -noverify -erase $MY_VERBOSEASR
              set +o errexit;
              osascript -e  "tell application   \"Finder\"   to close window   \"OS X Base System\"" > /dev/null
              set -o errexit;
    fi
fi
# ---------------------------------------------------------------
# End of conditional for 10.11, 10.12.



# ---------------------------------------------------------------
# Conditional for 10.7, 10.8, 10.9, 10.10, 10.11, 10.12.
# ---------------------------------------------------------------
if [ "$MY_OSXSCRIPT" != "10.13-10.15" ] ; then
    if [ $MY_DRYRUN -eq "0" ]; then
        echo ""
        echo "Remove Package link and replace with actual files... (go get some coffee)"
        echo "  *** TIP *** You can press 'Ctrl-T' to watch the copying progress..."
        echo "--------------------------------------------------------------------------------"
    fi
    if [ $MY_VERBOSE -ge "2" -o $MY_DRYRUN -ne "0" ]; then
        echo "rm /Volumes/OS\ X\ Base\ System/System/Installation/Packages"
    fi
    if [ $MY_DRYRUN -eq "0" ]; then
              rm /Volumes/OS\ X\ Base\ System/System/Installation/Packages
    fi
    if [ $MY_VERBOSE -ge "2" -o $MY_DRYRUN -ne "0" ]; then
        echo "cp -rp /Volumes/InstallESD/Packages /Volumes/OS\ X\ Base\ System/System/Installation/"
    fi
    if [ $MY_DRYRUN -eq "0" ]; then
              cp -rp /Volumes/InstallESD/Packages /Volumes/OS\ X\ Base\ System/System/Installation/
    fi

    if [ $MY_VERBOSE -ge "2" -o $MY_DRYRUN -ne "0" ]; then
        echo "cp -rp /Volumes/InstallESD/BaseSystem.* /Volumes/OS\ X\ Base\ System/"
    fi
    if [ $MY_DRYRUN -eq "0" ]; then
              cp -rp /Volumes/InstallESD/BaseSystem.* /Volumes/OS\ X\ Base\ System/
    fi



    if [ $MY_DRYRUN -eq "0" ]; then
        echo ""
        echo "Unmount the installer image..."
        echo "--------------------------------------------------------------------------------"
    fi
    if [ $MY_VERBOSE -ge "2" -o $MY_DRYRUN -ne "0" ]; then
        echo "hdiutil detach -force /Volumes/InstallESD $MY_VERBOSECMD"
    fi
    if [ $MY_DRYRUN -eq "0" ]; then
              hdiutil detach -force /Volumes/InstallESD $MY_VERBOSECMD
    fi
fi
# ---------------------------------------------------------------
# End of conditional for 10.7, 10.8, 10.9, 10.10, 10.11, 10.12.

# ---------------------------------------------------------------
# Conditional for 10.13-10.15.
# ---------------------------------------------------------------
if [ "$MY_OSXSCRIPT" == "10.13-10.15" ] ; then
    if [ $MY_DRYRUN -eq "0" ]; then
        echo ""
        echo "Create the installer media..."
        echo "--------------------------------------------------------------------------------"
    fi
    INTERACTION=""
    if [ $MY_IGNOREPROMPT -ne "0" ]; then
        INTERACTION="--nointeraction"
    fi

    if [ $MY_VERBOSE -ge "2" -o $MY_DRYRUN -ne "0" ]; then
        echo "$MY_PRIVILEGED \"$MY_INSTAPP/Contents/Resources/createinstallmedia\" $INTERACTION --volume /Volumes/OS\ X\ Base\ System"
    fi
    if [ $MY_DRYRUN -eq "0" ]; then
        "$MY_PRIVILEGED" "$MY_INSTAPP/Contents/Resources/createinstallmedia" $INTERACTION --volume /Volumes/OS\ X\ Base\ System
    fi
fi



# ***************************************************************
# Unmount the sparse bundles
# ***************************************************************

if [ $MY_DRYRUN -eq "0" ]; then
    sleep 2
    echo ""
    echo "Unmount the sparse bundle..."
    echo "--------------------------------------------------------------------------------"
fi
if [ "$MY_OSXSCRIPT" != "10.13-10.15" ] ; then
    if [ $MY_VERBOSE -ge "2" -o $MY_DRYRUN -ne "0" ]; then
        echo "hdiutil detach -force /Volumes/OS\ X\ Base\ System $MY_VERBOSECMD"
    fi
    if [ $MY_DRYRUN -eq "0" ]; then
              hdiutil detach -force /Volumes/OS\ X\ Base\ System $MY_VERBOSECMD
    fi
else
    if [ $MY_VERBOSE -ge "2" -o $MY_DRYRUN -ne "0" ]; then
        echo "mdutil -i off /Volumes/Install*"
        echo "hdiutil detach -force /Volumes/Install*"
    fi
    if [ $MY_DRYRUN -eq "0" ]; then
              mdutil -v -i off /Volumes/Install*
              hdiutil detach -force /Volumes/Install*
    fi
fi


# ***************************************************************
# Shrink the partitions to save space
# ***************************************************************

if [ $MY_DRYRUN -eq "0" ]; then
    MY_SRUNKSIZE=`( hdiutil resize -limits  "$MY_TEMPDIR/$MY_OSXVERSION.sparseimage"  | tail -n 1 | awk '{ print $1 }' )`
    echo ""
    echo "Resize the partition to remove any free space..."
    echo "--------------------------------------------------------------------------------"
fi
if [ $MY_VERBOSE -ge "2" -o $MY_DRYRUN -ne "0" ]; then
    echo "hdiutil resize -size \`hdiutil resize -limits \"$MY_TEMPDIR/$MY_OSXVERSION.sparseimage\" | tail -n 1 | awk '{ print \$1 }'\`b \"$MY_TEMPDIR/$MY_OSXVERSION.sparseimage\" $MY_VERBOSECMD"
fi
if [ $MY_DRYRUN -eq "0" ]; then
          hdiutil resize -size  `hdiutil resize -limits  "$MY_TEMPDIR/$MY_OSXVERSION.sparseimage"  | tail -n 1 | awk '{ print  $1 }'`b   "$MY_TEMPDIR/$MY_OSXVERSION.sparseimage" $MY_VERBOSECMD
fi



# ***************************************************************
# Convert the sparse bundle to an ISO
# ***************************************************************

if [ $MY_DRYRUN -eq "0" ]; then
    echo ""
    echo "Convert the sparse bundle to ISO/CD master... (this could take until next year)"
    echo "--------------------------------------------------------------------------------"
fi
if [ $MY_VERBOSE -ge "2" -o $MY_DRYRUN -ne "0" ]; then
    echo "hdiutil convert \"$MY_TEMPDIR/$MY_OSXVERSION.sparseimage\" -format UDTO -o \"$MY_TEMPDIR/$MY_OSXVERSION.cdr\" $MY_VERBOSECMD"
fi
if [ $MY_DRYRUN -eq "0" ]; then
          hdiutil convert  "$MY_TEMPDIR/$MY_OSXVERSION.sparseimage"  -format UDTO -o  "$MY_TEMPDIR/$MY_OSXVERSION.cdr"  $MY_VERBOSECMD
fi



if [ $MY_DRYRUN -eq "0" ]; then
    echo ""
    echo "Remove the sparse bundle..."
    echo "--------------------------------------------------------------------------------"
fi
if [ $MY_VERBOSE -ge "2" -o $MY_DRYRUN -ne "0" ]; then
    echo "rm \"$MY_TEMPDIR/$MY_OSXVERSION.sparseimage\""
fi
if [ $MY_DRYRUN -eq "0" ]; then
          rm  "$MY_TEMPDIR/$MY_OSXVERSION.sparseimage"
fi



if [ $MY_DRYRUN -eq "0" ]; then
    echo ""
    echo "Rename the ISO and move it to its destination..."
    echo "This can take a * really * long time if the destination is on the network..."
    echo "--------------------------------------------------------------------------------"
fi
if [ $MY_VERBOSE -ge "2" -o $MY_DRYRUN -ne "0" ]; then
    echo "mv \"$MY_TEMPDIR/$MY_OSXVERSION.cdr\" \"$MY_DESTDIR/$MY_OSXVERSION.iso\""
fi
 if [ $MY_DRYRUN -eq "0" ]; then
          mv  "$MY_TEMPDIR/$MY_OSXVERSION.cdr"   "$MY_DESTDIR/$MY_OSXVERSION.iso"
fi



# if [ $MY_CHECKSUM -eq "1" ]; then
#     if [ $MY_DRYRUN -eq "0" ]; then
#         echo ""
#         echo "Calculate the checksum of the ISO... *** COMPLETELY USELESS!!! ***"
#         echo "--------------------------------------------------------------------------------"
#     fi
#     if [ $MY_VERBOSE -ge "2" -o $MY_DRYRUN -ne "0" ]; then
#         echo "shasum -b \"$MY_DESTDIR/$MY_OSXVERSION.iso\""
#     fi
#     if [ $MY_DRYRUN -eq "0" ]; then
#         shasum -b  "$MY_DESTDIR/$MY_OSXVERSION.iso"
#        echo ""
#        echo "For reference, here are some well known checksums:"
#        echo ""
#        echo "Version   Build     SHASUM"
#        echo "------------------------------------------------------------"
#        echo "10.9      13A603    c9bc41612b569ab354b9663bf01cd3c9700b3796"
#        echo "10.9.1    13B42     ?"
#        echo "10.9.2    13C64     ?"
#        echo "10.9.3    13D65     ?"
#        echo "10.9.4    13E28     ?"
#        echo "10.9.5    13F34     d8615284361cb85a688322a08a8c7f57a0cb09b8"
#        echo "10.10     14A389    ?"
#        echo "10.10.1   14B25     ?"
#        echo "10.10.2   14C109    7b9969ffe2a9d5cd6881d370076d54e794884694"
#        echo "10.10.3   14D136    ?"
#        echo "10.10.4   14E46     ?"
#        echo "10.10.5   14F27     42ddb520671baae6b70b484dce76c41271bb4714"
#        echo "10.11     15A284    f2223bcee5c8631d9dd2d48ca3ef64e79f21acb6"
#        echo "10.11.1   15B42     ?"
#        echo "10.11.2   15C50     ?"
#        echo "10.11.3   15D21     ?"
#        echo "10.11.4   15E65     ?"
#        echo "10.11.5   15F34     ?"
#        echo "10.11.6   15G31     9a8af4cd887863b4df4341ec9686b4f2efbc3ef7"
#        echo "10.12     16A323    a9147a9cf62bcfea519cae3b746371dd756ce6dd"
#        echo "10.12.1   16B2557   ?"
#        echo "10.12.2   16C67     ?"
#        echo "10.12.3   16D32     b09b242bb8f8258d7e4a5e20179f68f8e63498d5"
#        echo "10.12.4   16E195    ?"
#        echo "--------------------------------------------------------------------------------"
#     fi
# fi



MY_TIMEEND=$(date +%s)
MY_TIMETOTAL=$(expr $MY_TIMEEND - $MY_TIMESTART)

if [ $MY_DRYRUN -eq "0" ]; then
    afplay /System/Library/Components/CoreAudio.component/Contents/SharedSupport/SystemSounds/system/burn\ complete.aif
    echo ""
    echo ""
    echo "================================================================================"
    echo "                            !!!  DONE !!!"
    echo "================================================================================"
    echo "Conversion script ended at         : $(date +'%F %T %Z')"
    echo "Conversion script took a total of  : $(($MY_TIMETOTAL/60)) min, $(($MY_TIMETOTAL%60)) sec ($MY_TIMETOTAL s)."
    echo "--------------------------------------------------------------------------------"
    echo "You can find the OSX $MY_OSXVERSION installation DVD in:"
    echo "    --> $MY_DESTDIR/$MY_OSXVERSION.iso"
    echo "--------------------------------------------------------------------------------"
fi
echo ""
printf "\a"
