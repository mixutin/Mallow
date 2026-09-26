---
# SPDX-License-Identifier: 0BSD
description: Current MallowKit/setup architecture and the planned path toward safe runtime installation, bottles and Windows launching.
---

# Architecture tour

The repository contains a small implementation of a much larger design. Read [DESIGN.md](../DESIGN.md) for the intended architecture and [BOOTSTRAP.md](../BOOTSTRAP.md) for the current preview's staging decisions. This tour does not imply every named module exists.

## The three layers

**MallowKit** owns reusable models and effects. **mallow** is currently a bootstrap CLI exposing prerequisite inspection and setup acquisition. **MallowApp** is a native SwiftUI onboarding surface over the same setup service. The app target is enabled only on macOS; the portable library/CLI subset supports development testing on Linux.

## MallowKit's dependency direction

The intended order is:

```text
Support → Bottles → Runtime → Wine → Programs → Graphics → Launch → Operations → Recipes → Diagnostics → Composition
```

Folders may use only layers to their left. Shared identifiers and protocols belong low in the dependency graph. In this preview, Support defines download/host/locking primitives, Runtime supplies the compiled pin, Operations orchestrates setup, and the CLI/app call that orchestration. Support does not depend on the runtime catalog.

## What exists now

Partial WF0 supplies defaulted coding, strict tagged unions, local-path handling, bottle-settings values, `ProgramSource`, atomic JSON persistence and reference fixtures. Setup adds an injectable transport/hash boundary, an ownership-marked cache, a held advisory lock, exact-size/SHA-256 verification and explicit consent. The app supplies progress and a build-specific status report.

The runtime archive remains a cache file. There are no bottle stores, activation receipts, Wine process launches, graphics backends or kernel sandbox in this slice. The report encodes those readiness states as false.

## The launch planner

The full design's launch planner will be pure: inputs describing host, bottle, runtime, capabilities and request produce a launch plan without executing it. Effects will go through injectable services, keeping plans golden-testable. This separation is planned but is not yet a Windows launch implementation.

## State and persistence

Atomic file replacement is implemented; it is not sufficient for multi-step transactions. Future owning stores must lock complete read-modify-write operations, reject writes to unsupported schema versions and preserve data on failures. The preview's setup cache is separate from the future application-data root and must not be treated as a bottle or runtime installation.

## Security boundary

Wine is not a sandbox. Prefix settings are not a kernel boundary. The planned launch path must integrate and test the [security model](../SECURITY_MODEL.md) before exposing Windows execution. The preview never extracts or runs the acquired archive and never claims it has implemented that boundary.

## Build and test

The SwiftPM package, `scripts/test.sh`, app-bundle scripts and `Development app` workflow are real. CI tests the library, compiles the app, checks its bundle and exercises a non-GUI startup path. A user's Mac still needs to validate GUI, network and installer behavior. Use [development setup](dev-setup.md) and the [preview checklist](../development-preview.md).

## Where to start

Finish the missing WF0 families in [#9](https://github.com/mixutin/Mallow/issues/9), record preview results in [#42](https://github.com/mixutin/Mallow/issues/42), then build schema-safe stores and verified runtime activation. Keep the design, tests, roadmap and affected website pages synchronized. The early UI is a way to test progress, not permission to skip the remaining foundations.
