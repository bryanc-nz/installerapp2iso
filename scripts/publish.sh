#!/bin/bash

NOTARIZEDPATH=$1
if [ x$NOTARIZEDPATH = x ]; then
	echo "Usage: $0 notarized-file"
	exit 1
fi

SPARKLE=/Users/bryan/Software-Swift5/Sparkle
KEYS=/Users/bryan/Software-Swift5/sparkle-keys

APPNAME=InstallerApp2ISO
APP=$APPNAME.app
NAME=installerapp2iso
APPCAST=$NAME"appcast".xml

SITE=https://www.whatroute.net
PUBLISH_URL=https://www.whatroute.net/software

STAGING=/Users/bryan/Sites/whatroute.net

rm -rf Publish
mkdir -p Publish
ditto -v $NOTARIZEDPATH Publish/$APP

cd Publish
short_version=$(defaults read $(pwd)/$APP/Contents/Info CFBundleShortVersionString)
code_version=$(defaults read $(pwd)/$APP/Contents/Info CFBundleVersion)

ZIPPED=$NAME-$short_version.zip

zip -r -y $ZIPPED $APP > /dev/null

dsa=$($SPARKLE/bin/old_dsa_scripts/sign_update $ZIPPED $KEYS/dsa_priv.pem)
edSignature=$($SPARKLE/bin/sign_update $ZIPPED)

head=$(cat <<EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"
				   xmlns:dc="http://purl.org/dc/elements/1.1/">
	<channel>
		<title>$APPNAME Changelog</title>
		<link>$SITE/$APPCAST</link>
		<description>Most recent changes.</description>
		<language>en</language>
EOF
)

item=$(cat <<EOF
		<item>
			<title>$APPNAME Version: $short_version</title>
			<description>
				<![CDATA[
				<h4>Enhancements</h4>
				<ul>
					<li>First release</li>
				</ul>
				]]>
			</description>
			<pubDate>$(date)</pubDate>
			<enclosure url="$PUBLISH_URL/$ZIPPED"
					   sparkle:shortVersionString="$short_version"
					   sparkle:version="$code_version"
					   sparkle:dsaSignature="$dsa"
					   $edSignature
					   type="application/octet-stream"
			/>
		</item>
EOF
)

foot=$(cat <<EOF
	</channel>
</rss>
EOF
)

rm -f $APPCAST
(
	echo "$head"
	echo "$item"
	echo "$foot"
) > $APPCAST

mkdir -p $STAGING
cp $APPCAST $STAGING

mkdir -p $STAGING/software
cp $ZIPPED $STAGING/software
