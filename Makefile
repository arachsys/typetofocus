all: fntofocus typetofocus

clean:
	rm -f fntofocus typetofocus

fntofocus: fntofocus.swift bridge.h Makefile
	swiftc -F /System/Library/PrivateFrameworks -framework SkyLight \
	  -import-objc-header bridge.h -o fntofocus fntofocus.swift
	strip fntofocus

typetofocus: typetofocus.swift bridge.h Makefile
	swiftc -F /System/Library/PrivateFrameworks -framework SkyLight \
	  -import-objc-header bridge.h -o typetofocus typetofocus.swift
	strip typetofocus

.PHONY: all clean
