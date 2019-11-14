#!/bin/bash

##
##  apfsvdi.sh
##
##  Created by Bryan Christianson (bryan@whatroute.net) on 1/05/19.
##  Copyright © 2019 Bryan Christianson. All rights reserved.
##
##
##    This program is free software: you can redistribute it and/or modify
##    it under the terms of the GNU General Public License as published by
##    the Free Software Foundation, either version 3 of the License, or
##    (at your option) any later version.
##
##    This program is distributed in the hope that it will be useful,
##    but WITHOUT ANY WARRANTY; without even the implied warranty of
##    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
##    GNU General Public License for more details.
##
##    You should have received a copy of the GNU General Public License
##    along with this program.  If not, see <https://www.gnu.org/licenses/>.
##

# This script creates an empty .vdi file that can be used for running macOS Mojave
# as a VirtualBox Virtual machine.
#
# 1. Download and install VirtualBox
# 2. Download the Mojave Installer application from Apple (apple.com)
# 3. Use the installer as input to this script to create a VirtualBox VDI file.
# 4. Run VirtualBox and create a new macOS 64 bit VM. Use your newly create .vdi file
# 5. Load your ISO file into the VM's DVD drive
# 6. Continue with the macOS Mojave installation
#

##
## Based on the macOS Mojave VirtualBox installer created by Alexander Willner
##
## https://github.com/AlexanderWillner/runMacOSinVirtualBox
##

#
# The 'cunning plan' being used in this script is to copy the APFS driver from the
# Apple macOS Installer Application to the EFI file tree, along with the nifty EFI startup.nsh
# borrowed from Alexander Willners code.
#
# There are no 3rd party binaries installed in the EFI tree or into the macOS filesystem
#

# ---------------------------------------------------------------
# Set some script strict checking
# ---------------------------------------------------------------
#set -o errexit;
set -u
#set -o pipefail

#
# Initialise global variables
#
INSTALLERAPP=""
DESTDIR=$(cd ~/Desktop; pwd)
VDINAME=""
DIR=""
SIZE=64
TMPDIR=""
SHOWPROGRESS=1
BASEMOUNT=""
DEVICE=""
EFI_DEV=""
INSTALLER=""
SPARSE=""
TMPIMG=""
TMPVDI=""
IGNOREPROMPT=0

VBOXMANAGE=/Applications/VirtualBox.app/Contents/MacOS/VBoxManage
VBOXIMGMOUNT=/Applications/VirtualBox.app/Contents/MacOS/vboximg-mount

my_usage()
{
    echo ""
    echo "Usage:"
    echo ""
    echo "apfsvdi.sh  -i|--installer <macOS Installer>"
    echo "            [-n|--name <VDI disk name>]"
    echo "            [-o|--output <OutputDir>]"
    echo "            [-q|--quiet]"
    echo "            [-s|--size <VDI disk size in GB - default 64>]"
    echo "            [-t|--tmpdir <Directory for temporary files>]"
    echo "            [-y|--yes] Reply 'yes' to all prompts"
	exit $1
}

errorcheck()
{
	local error="$1"
	local msg="$2"

	if [ $error -ne 0 ]; then
		echo "Error: $msg"
		exit 1
	fi
}

showprogress()
{
	if [ $SHOWPROGRESS -ne 0 ]; then
		echo "$@"
	fi
}

make_sparse()
{
	local sparse="$1"
	local volumes=$TMPDIR/$VDINAME.txt

	#
	# Create a sparse bundle - it will be converted to the VDI file
	#
	rm -rf "$sparse"
	showprogress hdiutil create -layout GPTSPUD -type SPARSEBUNDLE -fs \"JHFS+\" -volname \"Macintosh HD\" -size $SIZE"g" \"$sparse\"
	hdiutil create -layout GPTSPUD -type SPARSEBUNDLE -fs "JHFS+" -volname "Macintosh HD" -size $SIZE"g" "$sparse"
	errorcheck $? "Cannot create sparse bundle:  $sparse"

	#
	# attach the sparse bundle and get the device ids for the file systems
	#
	showprogress hdiutil attach \"$sparse\" -nomount > \"$volumes\"
	hdiutil attach "$sparse" -nomount > "$volumes"
	errorcheck $? "Cannot attach $sparse"

	DEVICE=$(cat "$volumes"|awk '/GUID_partition_scheme/ { print $1 }')
	EFI_DEV=$(cat "$volumes"|awk '/EFI/ { print $1 }')

	if [ x"$DEVICE" == "x" ]; then
		errorcheck 1 "$sparse is not a GUID disk."
	fi

	if [ x"$EFI_DEV" == "x" ]; then
		errorcheck 1 "There is no EFI partition in $sparse."
	fi

	## we're finished with the volume/device mapping file
	rm -f "$volumes"

	showprogress ""
	showprogress "New File System Devices"
	showprogress "          Whole disk: $DEVICE"
	showprogress "EFI partition device: $EFI_DEV"
	showprogress ""
}

make_efi()
{
	local efi_dev="$1"
	local driver="$2"
	local trys=0

	while [ 1 ]; do
		trys=$(($trys+1))
		if [ ! -f "$driver" ]; then
			if [ $trys -eq 10 ]; then
				errorcheck 1 "Cannot locate driver: $driver"
			fi
			showprogress "waiting for: $driver"
			sleep 1
		else
			break
		fi
	done

	local quiet="quiet"
	if [ $SHOWPROGRESS -ne 0 ]; then
		quiet=""
	fi

	#
	# Add the required entries to the EFI file system
	#
	showprogress diskutil $quiet mount \"$efi_dev\"
	diskutil $quiet mount "$efi_dev"
	errorcheck $? "Cannot mount EFI device: $efi_dev"

	#
	# copy the apfs.efi driver into the EFI file system
	#
	if [ ! -e "/Volumes/EFI" ]; then
		errorcheck 1 "/Volumes/EFI is not mounted."
	fi

	showprogress "Copy $driver to /Volumes/EFI/EFI/drivers"

	mkdir -p /Volumes/EFI/EFI/drivers
	cp "$driver" /Volumes/EFI/EFI/drivers/
	errorcheck $? "Cannot copy APFS driver: $driver"

	#
	# create startup.nsh and install the script to boot either macOS or the macOS installer
	#
	showprogress "Add script 'startup.nsh' to '/Volumes/EFI/'"

	cat <<EOF > /Volumes/EFI/startup.nsh
@echo -off
#fixme startup delay
set StartupDelay 0
load "fs0:\EFI\drivers\apfs.efi"
#fixme bcfg driver add 0 "fs0:\\EFI\\drivers\\apfs.efi" "APFS Filesystem Driver"
map -r
echo "Trying to find a bootable device..."
for %p in "macOS Install Data" "macOS Install Data\Locked Files\Boot Files" "OS X Install Data" "Mac OS X Install Data" "System\Library\CoreServices" ".IABootFiles"
  for %d in fs2 fs3 fs4 fs5 fs6 fs1
	if exist "%d:\%p\boot.efi" then
	  echo "Booting: %d:\%p\boot.efi ..."
	  #fixme: bcfg boot add 0 "%d:\\%p\\boot.efi" "macOS"
	  "%d:\%p\boot.efi"
	endif
  endfor
endfor
echo "Failed."
EOF

	diskutil $quiet unmount $efi_dev
}

make_vdi()
{
	local rawdevice="$1"
	local vdi="$2"

	showprogress ""
	showprogress "Creating the VDI file: $vdi"
	showprogress "This is going to take a while ..."

	rm -f "$vdi"

	local vdiname=$(basename "$vdi")
	local vdidir=$(dirname "$vdi")

	TMPVDI="$vdidir"/."$vdiname".tmp
	showprogress "Writing to: $TMPVDI"
	rm -f "$TMPVDI"

	if [ $SHOWPROGRESS -eq 0 ]; then
		echo \"$VBOXMANAGE\" convertfromraw \"$rawdevice\" \"$TMPVDI\" --format VDI
		"$VBOXMANAGE" convertfromraw "$rawdevice" "$TMPVDI" --format VDI
	else
		local imgfile="$TMPDIR"/"$VDINAME".img
		touch "$imgfile"
		TMPIMG="$imgfile"

		local imgsize=$(diskutil info "$rawdevice"|awk -F '[()]' '/Disk Size/ {print $2}'|awk '{print $1}')

		#
		# run the conversion in a separate shell
		#
		local start_time="$(date -u +%s)"
		{
			dd if="$rawdevice" bs=65536 2> /dev/null | tee "$imgfile" | \
			"$VBOXMANAGE" convertfromraw stdin "$TMPVDI" $imgsize --format VDI
		}&
		pid=$!

		sleep 1
		echo ""
		tput civis
		tput sc
		while ps $pid > /dev/null; do
			local now="$(date -u +%s)"
			local elapsed="$(($now-$start_time))"

			local progress=$(du -k "$imgfile" | awk '{print $1 * 1024}')

			#
			# Use awk to generate a progress message
			#
			local notification=$(echo "$elapsed $progress $imgsize" | awk '{
				elapsed=$1
				progress=$2
				totalsize=$3

				rate = 0
				if (elapsed > 0) {
					rate = progress / elapsed / 1024.0 / 1024.0
				}
				completed = progress / totalsize
				remaining = 0
				if (completed != 0) {
					total = elapsed / completed
					remaining = total - elapsed
				}
				printf("Completed: %.1f%%, Elapsed(sec): %.1f, Rate(MB/s): %.3f, Remaining(sec): %.1f",
						completed * 100.0, elapsed, rate, remaining)

			}')

			tput rc
			tput el
			/bin/echo -n "$notification"
			sleep 1
		done
		tput cnorm
		echo ""

		wait $pid
		rm -f "$imgfile"
		TMPIMG=""
	fi

	if [ $SHOWPROGRESS -ne 0 ]; then
		if [ -f "$vdi" ]; then
			echo ""
			local vdisize=$(du -k "$vdi" | awk '{printf("%.3f", $1 / 1024)}')
			echo "Created $vdisize MB VDI file: $vdi"
		fi
	fi

	showprogress "Move $TMPVDI to $vdi"
	mv "$TMPVDI" "$vdi"
	TMPVDI=""
}

check_disk_space()
{
	local path="$1"
	local required="$2"

	local available=$(df -g "$path" | awk '/^\/dev\// {print $4}')
	showprogress "Directory $path has $available""GB available"

	if [ $available -le $required ]; then
		errorcheck 1 "Insufficient space in $path. $required""GB required"
	fi
}

check_valid_installer_bundle()
{
	local app=$1

	if [ ! -d "$app" ]; then
		errorcheck 1 "macOS Installer application not found: $app"
	fi

	#
	# Check the CFBundleVersion
	#
	local plist="$app/Contents/Info.plist"

	if [ ! -f "$plist" ]; then
		errorcheck 1 "$app does not contain an Info.plist file"
	fi

	local version="$(/usr/libexec/PlistBuddy -c "print :CFBundleVersion" "${plist}")"
	if [ $version -lt 14000 ]; then
		errorcheck 1 "Cannot create APFS file system from $app"
	fi
}

check_vdi_exists()
{
	local vdi="$1"

	if [ -f "$vdi" ]; then
		if [ $IGNOREPROMPT -eq 0 ]; then
			echo "File already exists: $vdi"
			/bin/echo -n "Overwrite existing file? (yes/no): "
			read answer
			echo ""

			if test "$answer" != "Yes" -a "$answer" != "YES" -a "$answer" != "yes" -a "$answer" != "Y" -a "$answer" != "y"; then
				errorcheck 1 "Aborting VDI creation. Your answer was: '""$answer""'."
			fi
			showprogress "Deleting file: $vdi"
		fi
		rm -f "$vdi"
	fi
}

get_options()
{
	# ---------------------------------------------------------------
	# Parse the arguments.
	# ---------------------------------------------------------------
	if [ $# -eq "0" ]; then
		echo "*** ERROR: No arguments specified. The --installer option is mandatory."
		my_usage 1
	fi

	while test $# -ge 1;
	do
		ARG=$1
		shift;
		case "$ARG" in
		-i|--installer)
			if test $# -eq 0; then
				echo "*** ERROR: missing --installer argument."
				echo ""
				myusage 1
			fi
			INSTALLERAPP="$1"
			shift
			;;

		-n|--name)
			if test $# -eq 0; then
				echo "*** ERROR: missing --name argument."
				echo ""
				myusage 1
			fi
			VDINAME="$1"
			shift
			;;

        -o|--output)
            if test $# -eq 0; then
                echo "*** ERROR: missing --output argument."
                echo ""
                exit 1
            fi
            DESTDIR="$1"
            shift
            ;;

		-q|--quiet)
			SHOWPROGRESS=0
			;;

		-s|--size)
			if test $# -eq 0; then
				echo "*** ERROR: missing --size argument."
				echo ""
				myusage 1
			fi
			SIZE="$1";
			if test "$SIZE" -lt 10; then
				echo "$SIZE GB is too small to install macOS."
				myusage 1
			fi
			if test "$SIZE" -gt 100000; then
				echo "$SIZE GB is too large to install."
				myusage 1
			fi
			shift
			;;

		-t|--tmpdir)
			if test $# -eq 0; then
				echo "*** ERROR: missing --tmpdir argument."
				echo ""
				myusage 1
			fi
			TMPDIR="$1"
			shift
			;;

		-y|--yes)
			IGNOREPROMPT=1
			;;

		*)
			echo "*** ERROR: Invalid syntax."
			my_usage 1
			;;
		esac
	done

	if [ x"$INSTALLERAPP" == "x" ]; then
		errorcheck 1 "macOS Installer application not specified. The --installer option is mandatory."
	fi
	check_valid_installer_bundle "$INSTALLERAPP"

	if [ ! -e "$DESTDIR" ]; then
		errorcheck 1 "Destination directory is missing: $DESTDIR"
	fi

	showprogress "DESTDIR: $DESTDIR"
	#local required=$SIZE
	#if [ $SHOWPROGRESS -ne 0 ]; then
	#	required=$(($SIZE * 2))
	#fi
	#check_disk_space "$DESTDIR" $required

	local prefix=$(basename -s .app "$INSTALLERAPP")

	if [ x"$VDINAME" == "x" ]; then
		VDINAME="$prefix"
	fi
	showprogress "VDI: $DESTDIR/$VDINAME"".vdi"

	if [ x"$TMPDIR" == "x" ]; then
		TMPDIR=$DESTDIR
	fi

	if [ ! -e "$TMPDIR" ]; then
		errorcheck 1 "Temporary directory is missing: $TMPDIR"
	fi
	showprogress "TMPDIR: $TMPDIR"
	#check_disk_space "$TMPDIR" $SIZE
}

mount_base_system()
{
	local installer="$1"
	#
	# Locate the Base System image within the installer
	#
	local base_system="$(find "$installer" -name BaseSystem.dmg 2> /dev/null)"

	showprogress "Attempt to mount: $base_system"

	#
	# Mount the base system and find the path to the APFS boot driver
	#
	showprogress hdiutil attach \"$base_system\" \| awk -F '\t' '/Apple_HFS/ {print $3}'
	BASEMOUNT="$(hdiutil attach "$base_system" | awk -F '\t' '/Apple_HFS/ {print $3}')"
	if [ x"$BASEMOUNT" == "x" ]; then
		errorcheck 1 "Cannot attach Base System Image: $base_system"
	fi

	showprogress "$base_system mounted at $BASEMOUNT"

	#
	# disable indexing of the mounted image
	#
	while [ 1 ]
	do
		showprogress mdutil -v -i off \"$BASEMOUNT\"
		mdutil -v -i off "$BASEMOUNT"
		local rc=$?
		if [ $rc -eq 0 ]; then
			break
		else
			sleep 1
		fi
	done
}

cleanup()
{
	#
	# cleanup
	#
	if [ x"$DEVICE" != "x" ]; then
		hdiutil detach "$DEVICE"
		DEVICE=""
	fi

	if [ x"$BASEMOUNT" != "x" ]; then
		hdiutil detach "$BASEMOUNT"
		BASEMOUNT=""
	fi

	if [ x"$SPARSE" != "x" ]; then
		rm -rf "$SPARSE"
		showprogress "Deleted sparse bundle: $SPARSE"
		SPARSE=""
	fi

	if [ x"$TMPIMG" != "x" ]; then
		rm -rf "$TMPIMG"
		showprogress "Deleted temporary image file: $TMPIMG"
		TMPIMG=""
	fi

	if [ x"$TMPVDI" != "x" ]; then
		rm -rf "$TMPVDI"
		showprogress "Deleted temporary VDI file: $TMPVDI"
		TMPVDI=""
	fi

	if [ $SHOWPROGRESS -ne 0 ]; then
		# make the cursor visible
		tput cnorm
	fi
}

run_make_vdi()
{
	local vdi="$DESTDIR"/"$VDINAME".vdi
	check_vdi_exists "$vdi"

	SPARSE="$TMPDIR"/"$VDINAME".sparsebundle

	mount_base_system "$INSTALLERAPP"

	make_sparse "$SPARSE"
	make_efi $EFI_DEV "$BASEMOUNT"/usr/standalone/i386/apfs.efi

	# we're finished with the installer and can unmount the Base System
	hdiutil detach "$BASEMOUNT" -quiet
	BASEMOUNT=""

	## convert the sparseimage disk to a VirtualBox .vdi file
	make_vdi "$DEVICE" "$vdi"

	if [ -e "$VBOXIMGMOUNT" ]; then
		"$VBOXIMGMOUNT" -l -i "$vdi"
	fi

	echo "--> Created VDI file: $vdi"
}

exitfunc()
{
	showprogress ""
	showprogress "Script is exiting ..."
	cleanup
}

trap 'exitfunc' TERM
trap 'exitfunc' EXIT

if [ ! -e "$VBOXMANAGE" ]; then
	errorcheck 1 "Please install VirtualBox (https://www.virtualbox.org/) before running."
fi

get_options "$@"
run_make_vdi

cleanup
exit 0
