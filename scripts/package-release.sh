#!/usr/bin/env bash
# Build the same universal archive locally and in GitHub Actions.
# Usage: scripts/package-release.sh v1.0.0
set -euo pipefail
cd "$(dirname "$0")/.."

TAG="${1:-}"
if [[ ! "$TAG" =~ ^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]; then
    echo "Expected a release tag such as v1.0.0" >&2
    exit 1
fi

export APP_VERSION="${TAG#v}"
export APP_BUILD_NUMBER="${GITHUB_RUN_NUMBER:-1}"
scripts/build-app.sh release universal

ARCHIVE="Void-Journal-${TAG}-macOS-universal.zip"
ditto -c -k --sequesterRsrc --keepParent "build/Void Journal.app" "build/$ARCHIVE"
(cd build && shasum -a 256 "$ARCHIVE" > "$ARCHIVE.sha256")
echo "Packaged build/$ARCHIVE"
