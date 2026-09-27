#!/bin/bash
# SPDX-License-Identifier: 0BSD
set -euo pipefail
umask 077
APP="${1:-/Applications/Mallow.app}"
if [ "$(uname -s)" != Darwin ] || [ ! -x "$APP/Contents/Helpers/mallow" ]; then
  echo "Usage: run-client-checks.command /path/to/Mallow.app (macOS only)" >&2
  exit 2
fi
# Do not remove quarantine or disable Gatekeeper. A signature failure is a test failure.
/usr/bin/codesign --verify --deep --strict "$APP"
OUT="$(mktemp -d "${TMPDIR:-/tmp}/Mallow-client-results.XXXXXX")"
STATUS=0
"$APP/Contents/Helpers/mallow" diagnostics --self-test --json --output "$OUT/report.json" > "$OUT/console.txt" 2> "$OUT/errors.txt" || STATUS=$?
echo "Checks exit status: $STATUS"
echo "Local results: $OUT"
echo "Review report.json before sharing it. No report was uploaded."
echo "A passing self-test does not mean Windows launching or sandboxing is available."
/usr/bin/open "$OUT"
exit "$STATUS"
