.PHONY: app run debug install clean reset-intro format lint

app:
	scripts/build-app.sh release

debug:
	scripts/build-app.sh debug

run: app
	open "build/Void Journal.app"

install: app
	rm -rf "/Applications/Void Journal.app"
	cp -R "build/Void Journal.app" /Applications/

reset-intro:
	defaults delete dev.voidjournal.VoidJournal hasSeenIntro || true

SWIFT_SOURCES = Sources scripts Package.swift

format:
	swift format --in-place --recursive $(SWIFT_SOURCES)

lint:
	swift format lint --strict --recursive $(SWIFT_SOURCES)

clean:
	rm -rf .build build
