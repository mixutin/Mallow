#!/bin/bash
# SPDX-License-Identifier: 0BSD
set -euo pipefail
INPUT="${1:?Usage: verify-app-bundle.sh path-to-app-or-zip}"
TEMP=""
trap 'if [ -n "$TEMP" ]; then rm -rf "$TEMP"; fi' EXIT
case "$INPUT" in
  *.zip)
    TEMP="$(mktemp -d "${TMPDIR:-/tmp}/mallow-verify.XXXXXX")"
    /usr/bin/ditto -x -k "$INPUT" "$TEMP"
    APP="$TEMP/Mallow.app";;
  *.app) APP="$INPUT";;
  *) echo "Expected a .app or .zip" >&2; exit 1;;
esac
for name in LICENSE NOTICE THIRD_PARTY_LICENSES.md AppIcon.icns MallowLogo.svg; do test -s "$APP/Contents/Resources/$name"; done
test -x "$APP/Contents/MacOS/Mallow"
test -x "$APP/Contents/Helpers/mallow"
[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Contents/Info.plist")" = io.github.mixutin.Mallow ]
[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' "$APP/Contents/Info.plist")" = AppIcon ]
[ "$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$APP/Contents/Info.plist")" = 15.0 ]
[ "$(/usr/bin/lipo -archs "$APP/Contents/MacOS/Mallow")" = arm64 ]
[ "$(/usr/bin/lipo -archs "$APP/Contents/Helpers/mallow")" = arm64 ]
/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP"
"$APP/Contents/MacOS/Mallow" --smoke-test | grep -qx 'mallow-app-bootstrap-ok'
"$APP/Contents/Helpers/mallow" doctor --json
"$APP/Contents/Helpers/mallow" diagnostics --self-test --json > "${APP%/Mallow.app}/client-report.json"
python3 - "$APP/Contents/Info.plist" "${APP%/Mallow.app}/client-report.json" <<'PYCHECK'
import json, plistlib, sys
with open(sys.argv[1], "rb") as file:
    info = plistlib.load(file)
with open(sys.argv[2]) as file:
    report = json.load(file)
assert report["build"]["revision"] == info["MallowSourceRevision"]
assert report["build"]["configuration"] == info["MallowBuildConfiguration"]
assert report["selfTests"] and all(check["status"] == "passed" for check in report["selfTests"])
assert report["windowsLaunching"] is False and report["sandboxImplemented"] is False
PYCHECK
# A smoke check proves executable startup, not graphical usability or Wine compatibility.
echo "Verified bundle, icon, architecture, licence files, signature and bootstrap entry points."
