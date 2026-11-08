#!/usr/bin/env bash
# Builds "Void Journal.app" into ./build using only the Swift toolchain (no Xcode needed).
# Usage: scripts/build-app.sh [debug|release] [native|universal]
# APP_VERSION and APP_BUILD_NUMBER optionally override the bundle version.
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG="${1:-release}"
ARCHITECTURE="${2:-native}"
APP="build/Void Journal.app"

case "$CONFIG" in
    debug|release) ;;
    *) echo "Configuration must be debug or release" >&2; exit 1 ;;
esac

case "$ARCHITECTURE" in
    native)
        swift build -c "$CONFIG"
        BIN="$(swift build -c "$CONFIG" --show-bin-path)/VoidJournal"
        ;;
    universal)
        # Separate output paths also work with toolchains that share Products/Release
        # across architectures, rather than including the architecture in the path.
        swift build -c "$CONFIG" --arch arm64 --scratch-path .build/universal/arm64
        ARM_BIN="$(swift build -c "$CONFIG" --arch arm64 --scratch-path .build/universal/arm64 --show-bin-path)/VoidJournal"
        swift build -c "$CONFIG" --arch x86_64 --scratch-path .build/universal/x86_64
        INTEL_BIN="$(swift build -c "$CONFIG" --arch x86_64 --scratch-path .build/universal/x86_64 --show-bin-path)/VoidJournal"
        mkdir -p build
        BIN="build/VoidJournal-universal"
        lipo -create "$ARM_BIN" "$INTEL_BIN" -output "$BIN"
        lipo "$BIN" -verify_arch arm64
        lipo "$BIN" -verify_arch x86_64
        ;;
    *) echo "Architecture must be native or universal" >&2; exit 1 ;;
esac

if [[ ! -f Resources/AppIcon.icns ]]; then
    swift scripts/make-icon.swift Resources
fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/VoidJournal"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
if [[ -n "${APP_VERSION:-}" ]]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $APP_VERSION" "$APP/Contents/Info.plist"
fi
if [[ -n "${APP_BUILD_NUMBER:-}" ]]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $APP_BUILD_NUMBER" "$APP/Contents/Info.plist"
fi
codesign --force --sign - "$APP" >/dev/null
codesign --verify --deep --strict "$APP"

echo "Built $APP"
