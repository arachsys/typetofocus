all: FnToFocus.app TypeToFocus.app

clean:
	rm -f -r FnToFocus.app TypeToFocus.app

FnToFocus.app: fntofocus.swift bridge.h Makefile
	rm -f -r $@ && mkdir -p $@/Contents/MacOS
	swiftc -O -F /System/Library/PrivateFrameworks -framework SkyLight \
	  -import-objc-header bridge.h -o $@/Contents/MacOS/FnToFocus \
	  fntofocus.swift
	strip $@/Contents/MacOS/FnToFocus

	plutil -create xml1 $@/Contents/Info.plist
	plutil -insert CFBundleIdentifier -string uk.me.cdw.FnToFocus \
	  $@/Contents/Info.plist
	plutil -insert LSUIElement -bool true $@/Contents/Info.plist
	codesign -s - $@

TypeToFocus.app: typetofocus.swift bridge.h Makefile
	rm -f -r $@ && mkdir -p $@/Contents/MacOS
	swiftc -O -F /System/Library/PrivateFrameworks -framework SkyLight \
	  -import-objc-header bridge.h -o $@/Contents/MacOS/TypeToFocus \
	  typetofocus.swift
	strip $@/Contents/MacOS/TypeToFocus

	plutil -create xml1 $@/Contents/Info.plist
	plutil -insert CFBundleIdentifier -string uk.me.cdw.TypeToFocus \
	  $@/Contents/Info.plist
	plutil -insert LSUIElement -bool true $@/Contents/Info.plist
	codesign -s - $@

.PHONY: all clean
