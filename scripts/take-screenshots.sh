#!/usr/bin/env bash
# Render sample text offscreen without capturing the desktop or changing preferences.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build
BIN="$(swift build --show-bin-path)/VoidJournal"
FRAMES="$(mktemp -d)"
trap 'rm -rf "$FRAMES"' EXIT
"$BIN" --snapshots "$FRAMES"

mkdir -p docs/screenshots
for theme in void dissolve; do
    for mode in dark light; do
        sips -s format jpeg -s formatOptions 88 -Z 1400 \
            "$FRAMES/$theme-$mode-0.png" --out "docs/screenshots/$theme-$mode.jpg" >/dev/null
    done
done
echo "Updated docs/screenshots"
