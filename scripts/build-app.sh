#!/bin/bash
# SPDX-License-Identifier: 0BSD
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
[ "$(uname -s)" = Darwin ] && [ "$(uname -m)" = arm64 ] || {
  echo "Build the app on an Apple Silicon Mac." >&2; exit 1;
}
REVISION="${MALLOW_SOURCE_REVISION:-$(git rev-parse HEAD)}"
BUILD_NUMBER="${MALLOW_BUILD_NUMBER:-1}"
case "$REVISION" in *[!0-9a-f]*|'') echo "Invalid source revision" >&2; exit 1;; esac
[ "${#REVISION}" -eq 40 ] || { echo "Expected full source SHA" >&2; exit 1; }
case "$BUILD_NUMBER" in *[!0-9]*|'') echo "Invalid build number" >&2; exit 1;; esac
/usr/bin/swift build -c release --arch arm64 --product MallowApp
/usr/bin/swift build -c release --arch arm64 --product mallow
BIN="$(/usr/bin/swift build -c release --arch arm64 --show-bin-path)"
STAGE="$(mktemp -d "$ROOT/.build/mallow-bundle.XXXXXX")"
trap 'rm -rf "$STAGE"' EXIT
APP="$STAGE/Mallow.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Helpers" "$APP/Contents/Resources" "$ROOT/dist"
cp "$BIN/MallowApp" "$APP/Contents/MacOS/Mallow"
cp "$BIN/mallow" "$APP/Contents/Helpers/mallow"
cp Resources/Info.plist "$APP/Contents/Info.plist"
for name in LICENSE NOTICE THIRD_PARTY_LICENSES.md; do cp "$name" "$APP/Contents/Resources/$name"; done
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :MallowSourceRevision $REVISION" "$APP/Contents/Info.plist"
# Ad-hoc integrity signatures only: no Developer ID, notarisation, release key or sandbox claim.
/usr/bin/codesign --force --sign - "$APP/Contents/Helpers/mallow"
/usr/bin/codesign --force --sign - "$APP"
scripts/verify-app-bundle.sh "$APP"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$APP" "$ROOT/dist/Mallow-macos-arm64.zip"
(cd "$ROOT/dist" && /usr/bin/shasum -a 256 Mallow-macos-arm64.zip > SHA256SUMS)
printf '{"revision":"%s","build":"%s","channel":"development-preview","windowsLaunching":false}\n' \
  "$REVISION" "$BUILD_NUMBER" > "$ROOT/dist/build-info.json"
echo "Built dist/Mallow-macos-arm64.zip (development preview)."
