#!/bin/bash
# SPDX-License-Identifier: 0BSD
set -euo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STAGE="$(mktemp -d "${TMPDIR:-/tmp}/mallow-test-kit.XXXXXX")"
trap 'rm -rf "$STAGE"' EXIT
mkdir -p "$STAGE/Mallow-Test-Kit" dist
cp scripts/run-client-checks.command "$STAGE/Mallow-Test-Kit/Run-Mallow-Client-Checks.command"
cp docs/mac-client-testing.md "$STAGE/Mallow-Test-Kit/README.md"
/usr/bin/ditto -c -k --keepParent "$STAGE/Mallow-Test-Kit" dist/Mallow-test-kit.zip
git archive --format=tar --prefix=Mallow/ HEAD | gzip -n > dist/Mallow-source.tar.gz
(cd dist && /usr/bin/shasum -a 256 Mallow-test-kit.zip Mallow-source.tar.gz > Mallow-test-kit.sha256 && cat Mallow-*.sha256 > SHA256SUMS)
