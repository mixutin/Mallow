#!/bin/bash
# SPDX-License-Identifier: 0BSD
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
[ "$(uname -s)" = Darwin ] && [ "$(uname -m)" = arm64 ] || {
  echo "Build the app on an Apple Silicon Mac." >&2; exit 1;
}
CONFIGURATION="${1:-release}"
case "$CONFIGURATION" in
  release) ASSET=Mallow-macos-arm64; METADATA=build-info.json;;
  debug) ASSET=Mallow-debug-macos-arm64; METADATA=debug-build-info.json;;
  *) echo "Usage: build-app.sh [release|debug]" >&2; exit 2;;
esac
REVISION="${MALLOW_SOURCE_REVISION:-$(git rev-parse HEAD)}"
BUILD_NUMBER="${MALLOW_BUILD_NUMBER:-1}"
case "$REVISION" in *[!0-9a-f]*|'') echo "Invalid source revision" >&2; exit 1;; esac
[ "${#REVISION}" -eq 40 ] || { echo "Expected full source SHA" >&2; exit 1; }
case "$BUILD_NUMBER" in *[!0-9]*|'') echo "Invalid build number" >&2; exit 1;; esac
/usr/bin/swift build -c "$CONFIGURATION" --arch arm64 --product MallowApp -Xswiftc -g
/usr/bin/swift build -c "$CONFIGURATION" --arch arm64 --product mallow -Xswiftc -g
BIN="$(/usr/bin/swift build -c "$CONFIGURATION" --arch arm64 --show-bin-path)"
STAGE="$(mktemp -d "$ROOT/.build/mallow-bundle.XXXXXX")"
trap 'rm -rf "$STAGE"' EXIT
APP="$STAGE/Mallow.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Helpers" "$APP/Contents/Resources" "$ROOT/dist"
cp "$BIN/MallowApp" "$APP/Contents/MacOS/Mallow"
cp "$BIN/mallow" "$APP/Contents/Helpers/mallow"
cp Resources/Info.plist "$APP/Contents/Info.plist"
for name in LICENSE NOTICE THIRD_PARTY_LICENSES.md; do cp "$name" "$APP/Contents/Resources/$name"; done
cp docs/assets/logo.svg "$APP/Contents/Resources/MallowLogo.svg"
/usr/bin/swift scripts/make-icns.swift "$STAGE/AppIcon.iconset"
/usr/bin/iconutil -c icns "$STAGE/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"
/usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :MallowSourceRevision $REVISION" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :MallowBuildConfiguration string $CONFIGURATION" "$APP/Contents/Info.plist"
SYMBOLS="$STAGE/symbols"
mkdir -p "$SYMBOLS"
# Apple requires each dSYM UUID to match its exact distributed binary.
# https://developer.apple.com/documentation/xcode/locating-a-missing-debug-symbol-file
for pair in "MallowApp:Mallow" "mallow:mallow"; do
  INPUT="${pair%%:*}"; OUTPUT="${pair##*:}"
  /usr/bin/xcrun dsymutil "$BIN/$INPUT" -o "$SYMBOLS/$OUTPUT.dSYM"
  BINARY_UUID="$(/usr/bin/xcrun dwarfdump --uuid "$BIN/$INPUT" | awk '{print $2}')"
  SYMBOL_UUID="$(/usr/bin/xcrun dwarfdump --uuid "$SYMBOLS/$OUTPUT.dSYM" | awk '{print $2}')"
  [ -n "$BINARY_UUID" ] && [ "$BINARY_UUID" = "$SYMBOL_UUID" ]
  /usr/bin/xcrun dwarfdump --debug-info "$SYMBOLS/$OUTPUT.dSYM" > "$STAGE/debug-info.txt"
  grep -q DW_TAG_compile_unit "$STAGE/debug-info.txt"
  printf '%s %s\n' "$OUTPUT" "$BINARY_UUID" >> "$SYMBOLS/UUIDS.txt"
done
printf '{"revision":"%s","configuration":"%s","build":"%s"}\n' "$REVISION" "$CONFIGURATION" "$BUILD_NUMBER" > "$SYMBOLS/build.json"
/usr/bin/swift --version > "$SYMBOLS/toolchain.txt"
/usr/bin/sw_vers > "$SYMBOLS/build-os.txt"
/usr/bin/codesign --force --sign - "$APP/Contents/Helpers/mallow"
/usr/bin/codesign --force --sign - "$APP"
scripts/verify-app-bundle.sh "$APP"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$APP" "$ROOT/dist/$ASSET.zip"
/usr/bin/ditto -c -k --keepParent "$SYMBOLS" "$ROOT/dist/$ASSET-symbols.zip"
printf '{"revision":"%s","build":"%s","configuration":"%s","channel":"development-preview","runtimeInstallation":true,"windowsLaunching":false,"debugSymbols":true}\n' \
  "$REVISION" "$BUILD_NUMBER" "$CONFIGURATION" > "$ROOT/dist/$METADATA"
(cd "$ROOT/dist" && /usr/bin/shasum -a 256 "$ASSET.zip" "$ASSET-symbols.zip" "$METADATA" > "$ASSET.sha256" && cat Mallow-*.sha256 > SHA256SUMS)
echo "Built dist/$ASSET.zip and UUID-matched debug symbols."
