#!/bin/bash
# SPDX-License-Identifier: 0BSD
set -euo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[ "$(uname -s)" = Darwin ] || { echo "This integration check needs macOS." >&2; exit 1; }
# Explicit network integration test, never part of the offline unit suite. No Wine binary is executed.
BIN="$(/usr/bin/swift build -c release --arch arm64 --show-bin-path)/mallow"
ROOT="$(mktemp -d "${TMPDIR:-/tmp}/mallow-runtime-check.XXXXXX")"
trap 'rm -rf "$ROOT"' EXIT
export MALLOW_HOME="$ROOT/data"
/usr/bin/time -p "$BIN" setup --install-runtime --accept-download --json > "$ROOT/installed.json"
"$BIN" runtime verify --json > "$ROOT/verified.json"
python3 - "$ROOT" <<'PY'
import json, pathlib, sys
root = pathlib.Path(sys.argv[1])
installed = json.loads((root / 'installed.json').read_text())
verified = json.loads((root / 'verified.json').read_text())
assert installed['runtimeActivated'] is True
assert installed['readyToRunWindows'] is False
assert verified['problems'] == [] and verified['checkedFiles'] > 0
print('Installed pinned Wine; full integrity check passed:', verified)
PY
# Repeat setup must reuse the installed runtime; neither silently replace it nor require a new download.
"$BIN" setup --install-runtime --accept-download --json > /dev/null
RUNTIME="$("$BIN" runtime path)"
printf 'mallow-integrity-test' >> "$RUNTIME/Wine Stable.app/Contents/Resources/wine/bin/wine"
STATUS=0
"$BIN" runtime verify --json > "$ROOT/tampered.json" || STATUS=$?
[ "$STATUS" -eq 4 ] || { echo "Altered runtime was not rejected" >&2; exit 1; }
echo "Altered-file verification failed as expected; no Wine program was executed."
