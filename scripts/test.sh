#!/bin/bash
# SPDX-License-Identifier: 0BSD
set -euo pipefail

cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# WF0 has no executable targets yet. Do not introduce fake launch commands.
swift build
# Explicitly disable XCTest so this entry point also works with Command Line Tools.
swift test --disable-xctest --enable-swift-testing "$@"
