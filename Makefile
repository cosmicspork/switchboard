APP_NAME = Switchboard

.PHONY: run build release test bundle install uninstall clean

# Run from source (dev). A menu bar icon appears; no Dock icon.
run:
	swift run $(APP_NAME)

build:
	swift build

release:
	swift build -c release

# Note: `swift test` needs the XCTest module, which ships with full Xcode.
# Command Line Tools alone do not include it.
test:
	swift test

bundle:
	./scripts/make-app-bundle.sh

install:
	./scripts/install.sh

uninstall:
	./scripts/uninstall.sh

clean:
	swift package clean
	rm -rf $(APP_NAME).app
