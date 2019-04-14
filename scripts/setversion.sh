#!/bin/sh

AWK=/usr/bin/awk
DEFAULTS=/usr/bin/defaults
GENSTRINGS=/usr/bin/genstrings
ICONV=/usr/bin/iconv
PLUTIL=/usr/bin/plutil
PRINTF=/usr/bin/printf

FILE=$1

increment_build() {
	plist=$1

	build=$($DEFAULTS read $plist CFBundleVersion)
	newbuild=$(echo $build | $AWK '{print ($1 + 1)}')

	#
	# write the new value for CFBundleVersion and convert file to xml
	#
	$DEFAULTS write $plist CFBundleVersion $newbuild
	$PLUTIL -convert xml1 $plist
}

cd $PROJECT_DIR
increment_build $FILE
