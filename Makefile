XCODE = /usr/bin/xcodebuild -verbose
PRODUCT = InstallerApp2ISO
BUNDLE	= $(PRODUCT).app
SCHEME	= $(PRODUCT)
PROJECT	= $(PRODUCT)
SCHEME	= $(PRODUCT)
SRC		= $(PRODUCT)
DIR = ${CURDIR}

ARCHIVE   = $(DIR)/archive/$(SCHEME).xcarchive
EXPORT    = $(DIR)/archive/export
NOTARIZED = $(DIR)/archive/export/$(BUNDLE)

all:	debug release

debug:
	$(XCODE) -project $(PROJECT).xcodeproj \
		-alltargets \
		-configuration Debug \
		CONFIGURATION_BUILD_DIR=$(DIR)/build/Debug

release: clean
	$(XCODE) -project $(PROJECT).xcodeproj \
	-alltargets \
	-configuration Release \
	CONFIGURATION_BUILD_DIR=$(DIR)/build/Release

$(ARCHIVE): clean
	$(XCODE) -project $(PROJECT).xcodeproj \
	-scheme $(SCHEME) \
	-archivePath $(ARCHIVE) \
	archive

$(EXPORT): $(ARCHIVE)
	$(XCODE) \
	-exportArchive \
	-archivePath $(ARCHIVE) \
	-exportPath $(EXPORT) \
	-exportOptionsPlist $(DIR)/$(SRC)/ExportOptions.plist

$(NOTARIZED): $(EXPORT)
	rm -rf $(NOTARIZED)
	while true; do \
		date; \
		$(XCODE) \
			-exportNotarizedApp \
			-archivePath $(ARCHIVE) \
			-exportPath $(EXPORT); \
		if [ $$? -eq 0 ]; then \
			echo "Notarize complete for:" $(NOTARIZED); \
			break; \
		fi; \
		echo wait 10s...; \
		sleep 10; \
	done
	test -e $(NOTARIZED) && $(XCRUN) stapler staple $(NOTARIZED)

notarized: $(NOTARIZED)

publish: notarized
	sh scripts/publish.sh $(NOTARIZED)

clean:
#	$(XCODE) -project $(PROJECT).xcodeproj -alltargets -configuration Debug clean
#	$(XCODE) -project $(PROJECT).xcodeproj -alltargets -configuration Release clean
	rm -rf archive
	rm -rf build
	rm -rf Publish
