#!/bin/bash

NOTARIZEDPATH=$1
if [ x$NOTARIZEDPATH = x ]; then
	echo "Usage: $0 notarized-file"
	exit 1
fi

APPNAME=InstallerApp2ISO
APP=$APPNAME.app
NAME=installerapp2iso
VERSIONPLIST=$NAME"version".plist

SITE=https://www.whatroute.net
PUBLISH_URL=https://www.whatroute.net/software

STAGING=/Users/bryan/Sites/whatroute.net

rm -rf Publish
mkdir -p Publish
ditto -v $NOTARIZEDPATH Publish/$APP

cd Publish
short_version=$(defaults read $(pwd)/$APP/Contents/Info CFBundleShortVersionString)
code_version=$(defaults read $(pwd)/$APP/Contents/Info CFBundleVersion)

versionplist=$(cat <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleShortVersionString</key>
	<string>$short_version</string>
	<key>CFBundleVersion</key>
	<string>$code_version</string>
</dict>
</plist>
EOF
)

rm -f $VERSIONPLIST
echo $versionplist > $VERSIONPLIST

ZIPPED=$NAME-$short_version.zip

zip -r -y $ZIPPED $APP > /dev/null

mkdir -p $STAGING
cp $VERSIONPLIST $STAGING

mkdir -p $STAGING/software
cp $ZIPPED $STAGING/software
