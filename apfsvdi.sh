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
# 3. Generate a bootable ISO installer file using a suitable script (InstallerApp2ISO comes to mind for this)
# 4. Use the generated ISO as input to this script to create a VirtualBox VDI file.
# 5. Run VirtualBox and create a new macOS 64 bit VM. Use your newly create .vdi file
# 6. Load your ISO file into the VM's DVD drive
# 7. Continue with the macOS Mojave installation
#

##
## Based on the macOS Mojave VirtualBox installer created by Alexander Willner
##
## https://github.com/AlexanderWillner/runMacOSinVirtualBox
##

#
# The 'cunning plan' being used in this script is to copy the APFS driver from the
# Apple macOS Installer ISO to the EFI file tree, along with the nifty EFI startup.nsh
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
ISO=""
DIR=""
PREFIX=""
SIZE=64
TMPDIR=""
SHOWPROGRESS=1
BASEMOUNT=""
DEVICE=""
EFI_DEV=""

my_usage()
{
    echo ""
    echo "Usage:"
    echo ""
    echo "apfsvdi.sh  -i|--iso <macOS Installer ISO>"
    echo "            [-q|--quiet]"
    echo "            [-s|--size <VDI disk size in GB - default 64>]"
    echo "            [-t|--tmpdir <Directory for temporary files>]"
	exit $1
}

errorcheck()
{
	local error=$1
	local msg=$2

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
	local volumes=$TMPDIR/$PREFIX.txt

	#
	# Create a sparse bundle - it will be converted to the VDI file
	#
	rm -rf $sparse
	hdiutil create -layout GPTSPUD -type SPARSEBUNDLE -fs APFS -size $SIZE"g" $sparse
	errorcheck $? "Cannot create sparse bundle:  $sparse"

	#
	# attach the sparse bundle and get the device ids for the file systems
	#
	hdiutil attach $sparse -nomount > "$volumes"
	errorcheck $? "Cannot attach $sparse"

	DEVICE=$(cat "$volumes"|awk '/GUID_partition_scheme / { print $1 }')
	EFI_DEV=$(cat "$volumes"|awk '/EFI/ { print $1 }')

	if [ x"DEVICE" == "x" ]; then
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

	local quiet="quiet"
	if [ $SHOWPROGRESS -ne 0 ]; then
		quiet=""
	fi

	#
	# Add the required entries to the EFI file system
	#
	diskutil $quiet mount $efi_dev
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

	cat <<EOT > /Volumes/EFI/startup.nsh
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
EOT

	diskutil $quiet unmount $efi_dev
}

make_vdi()
{
	local rawdevice="$1"
	local vdi="$2"

	echo ""
	echo "Creating the VDI file: $vdi"
	echo "This is going to take a while ..."

	rm -f "$vdi"
	if [ $SHOWPROGRESS -eq 0 ]; then
		VBoxManage convertfromraw "$rawdevice" "$vdi" --format VDI
	else
		local imgfile="$TMPDIR"/"$PREFIX".tmp
		touch $imgfile

		local imgsize=$(diskutil info "$rawdevice"|awk -F '[()]' '/Disk Size/ {print $2}'|awk '{print $1}')

		#
		# run the conversion in a separate shell
		#
		local start_time="$(date -u +%s)"
		{
			dd if="$rawdevice" bs=65536 2> /dev/null | tee "$imgfile" | \
			VBoxManage convertfromraw stdin "$vdi" $imgsize --format VDI
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

				completed = progress / totalsize
				remaining = 0
				if (completed != 0) {
					total = elapsed / completed
					remaining = total - elapsed
				}
				printf("Completed: %.1f%%, Elapsed(sec): %.1f, Remaining(sec): %.1f",
						completed * 100.0, elapsed, remaining)

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
	fi

	if [ $SHOWPROGRESS -ne 0 ]; then
		if [ -f "$vdi" ]; then
			echo ""
			local vdisize=$(du -k "$vdi" | awk '{printf("%.3f", $1 / 1024)}')
			echo "Created $vdisize MB VDI file: $vdi"
		fi
	fi
}

get_options()
{
	# ---------------------------------------------------------------
	# Parse the arguments.
	# ---------------------------------------------------------------
	if [ $# -eq "0" ]; then
		echo "*** ERROR: No arguments specified. The --iso option is mandatory."
		my_usage 1
	fi

	while test $# -ge 1;
	do
		ARG=$1;
		shift;
		case "$ARG" in
		-i|--iso)
			if test $# -eq 0; then
				echo "*** ERROR: missing --installer argument.";
				echo "";
				myusage 1;
			fi
			ISO="$1";
			shift;
			;;

		-q|--quiet)
			SHOWPROGRESS=0
			;;

		-s|--size)
			if test $# -eq 0; then
				echo "*** ERROR: missing --size argument.";
				echo "";
				myusage 1;
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
			shift;
			;;

		-t|--tmpdir)
			if test $# -eq 0; then
				echo "*** ERROR: missing --tmpdir argument.";
				echo "";
				myusage 1;
			fi
			TMPDIR="$1";
			shift;
			;;

		*)
			echo "*** ERROR: Invalid syntax."
			my_usage 1;
			;;
		esac
	done

	if [ x"$ISO" == "x" ]; then
		errorcheck 1 "No ISO file specified. The --iso option is mandatory."
	fi

	if [ ! -f "$ISO" ]; then
		errorcheck 1 "ISO file not found: $ISO"
	fi

	PREFIX="$(basename -s .iso $ISO)"
	DIR="$(dirname $ISO)"

	if [ x"$TMPDIR" == "x" ]; then
		TMPDIR=$DIR
	fi

	if [ ! -e "$TMPDIR" ]; then
		errorcheck 1 "Temporary directory is missing: $TMPDIR"
	fi
}

check_valid_installer_bundle()
{
	local installer=$1
	#
	# Check the CFBundleVersion
	#
	local app=$(ls -d "$installer"/*.app)
	local plist="$app/Contents/Info.plist"

	if [ ! -f "$plist" ]; then
		errorcheck 1 "$installer does not contain an Info.plist file"
	fi

	local version="$(/usr/libexec/PlistBuddy -c "print :CFBundleVersion" "${plist}")"
	if [ $version -lt 14000 ]; then
		errorcheck 1 "Cannot create APFS file system with $installer"
	fi
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
	BASEMOUNT="$(hdiutil attach "$base_system" | awk -F '\t' '/Apple_HFS/ {print $3}')"
	if [ x"BASEMOUNT" == "x" ]; then
		errorcheck 1 "Cannot attach Base System Image: $base_system"
	fi

	showprogress "$base_system mounted at $BASEMOUNT"
}

cleanup()
{
	#
	# cleanup
	#
	hdiutil detach $DEVICE
	rm -rf $SPARSE
}

get_options $@

VDI=$DIR/$PREFIX.vdi
SPARSE=$TMPDIR/$PREFIX.sparsebundle

#
# Mount the ISO and find its mounted volume name
#
INSTALLER="$(hdiutil attach "$ISO" | awk -F '\t' '/Apple_HFS/ {print $3}')"
if [ x"$INSTALLER" == "x" ]; then
	errorcheck 1 "Cannot attach installer: $ISO"
fi

check_valid_installer_bundle "$INSTALLER"
mount_base_system "$INSTALLER"
make_sparse "$SPARSE"
make_efi $EFI_DEV "$BASEMOUNT"/usr/standalone/i386/apfs.efi

# we're finished with the ISO and can unmount the file systems
hdiutil detach "$BASEMOUNT" -quiet
hdiutil detach "$INSTALLER" -quiet

## convert the sparseimage disk to a VirtualBox .vdi file
make_vdi "$DEVICE" "$VDI"

cleanup
exit 0
