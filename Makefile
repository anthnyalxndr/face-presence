PREFIX ?= $(HOME)/.local
BIN     = build/face-presence
SRC     = Sources/face-presence.swift
PLIST   = Sources/Info.plist

.PHONY: build check install uninstall clean

build: $(BIN)

# The Info.plist is embedded so macOS accepts the camera usage description
# from a plain executable. Ad-hoc signing with a stable identifier keeps the
# camera grant across rebuilds.
$(BIN): $(SRC) $(PLIST)
	mkdir -p build
	swiftc -O -Xlinker -sectcreate -Xlinker __TEXT -Xlinker __info_plist -Xlinker $(PLIST) -o $@ $(SRC)
	codesign --force --sign - --identifier com.anthnyalxndr.face-presence $@

# Compile-only checks plus argument handling, which need no camera.
check: $(BIN)
	swiftc -typecheck $(SRC)
	./tests/cli_test.sh $(BIN)

install: $(BIN)
	mkdir -p $(PREFIX)/bin
	install -m 755 $(BIN) $(PREFIX)/bin/face-presence

uninstall:
	rm -f $(PREFIX)/bin/face-presence

clean:
	rm -rf build
