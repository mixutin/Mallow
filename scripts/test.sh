#!/bin/bash
# SPDX-License-Identifier: 0BSD
set -euo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Builds the library, the bootstrap CLI, and the native app target on macOS.
# fake-wine and Windows-launch integration tests are not implemented yet.
swift build
export MALLOW_CLI="$(swift build --show-bin-path)/mallow"
swift test --disable-xctest --enable-swift-testing "$@"
