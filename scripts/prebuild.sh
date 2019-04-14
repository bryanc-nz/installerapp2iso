#!/bin/sh

AWK=/usr/bin/awk
DEFAULTS=/usr/bin/defaults
GENSTRINGS=/usr/bin/genstrings
ICONV=/usr/bin/iconv
PLUTIL=/usr/bin/plutil
PRINTF=/usr/bin/printf

#
# Update localisable strings
#
cd $PROJECT_DIR/InstallerApp2ISO
$GENSTRINGS *.swift -o en.lproj
cd en.lproj
$ICONV -f utf-16 -t utf-8 < Localizable.strings > Localizable.strings.utf-8
mv Localizable.strings.utf-8 Localizable.strings
