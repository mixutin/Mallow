---
# SPDX-License-Identifier: 0BSD
description: Current MallowKit runtime-installation architecture, integrity checks, performance boundaries and planned secure Windows launching.
---

# Architecture tour

This is a small implementation of a larger design. [DESIGN.md](../DESIGN.md) describes the target; [BOOTSTRAP.md](../BOOTSTRAP.md) and [runtime installation design](../runtime-installation.md) describe current staged interfaces.

## The three layers

**MallowKit** owns reusable models and effects. **mallow** exposes prerequisite inspection, approved setup and runtime verification/path commands. **MallowApp** supplies a native dark-pink SwiftUI interface over the same service. Only macOS builds the app; Linux can test the portable core with its system archive headers and injected hash implementations.

## MallowKit's dependency direction

```text
Support → Bottles → Runtime → Wine → Programs → Graphics → Launch → Operations → Recipes → Diagnostics → Composition
```

A folder may depend only on layers to its left. Support supplies download/host/lock/path/archive primitives. Runtime supplies compiled pins, the pinned installer and receipt verification. Operations orchestrates setup for CLI/app callers. The CArchive target exposes the system library's public ABI; no archive implementation is vendored.

## What exists now

Partial WF0 supplies defaulted/tagged/local-path coding, bottle-settings values, ProgramSource, atomic JSON persistence and reference fixtures. Setup uses pinned HTTPS acquisition, an owned cache, a private verified archive snapshot, confined extraction and a completed runtime tree. Root markers and held locks prevent accidental adoption or concurrent well-behaved writers. Installed-file receipts enable explicit corruption checks.

The app reports installed metadata separately from a fresh integrity check. No Wine/Windows program is launched by setup. Bottles, the general runtime catalog/probe/import APIs, multimedia setup, graphics and the kernel sandbox remain unfinished.

## The launch planner

The future planner will map host/bottle/runtime/request facts to a deterministic plan without effects. Injected services will apply it and manage processes. That architecture remains the next stage, not an implemented Windows launch function.

## State and persistence

Generic atomic JSON replacement does not make a whole store transaction safe. The current runtime installer holds its own advisory lock, publishes only a completed tree and rejects unsupported receipts or damaged existing installations without overwriting. Full schema-safe bottle/settings/runtime stores, repair/rollback and crash recovery remain planned.

Metadata-only startup avoids full file hashing. Streaming file work happens off the UI's main actor; full verification is explicit and reports elapsed time. Actual-Mac RSS/latency and later game performance must be measured. A local receipt is not a signed trust root against malicious same-user software.

## Security boundary

Archive validation, ownership and checksums protect the setup operation's defined inputs; they are not a Windows-process sandbox. Kernel isolation and prefix defaults must be implemented/tested before Windows execution is exposed. The [security model](../SECURITY_MODEL.md) keeps that target invariant explicit.

## Build and test

The package, unit suites, app/icon/ZIP scripts and development release workflow exist. Mac CI also installs the actual pinned archive, verifies it, repeats setup and detects an altered file in a disposable root. No Wine process runs in that integration test. The non-GUI smoke entry does not test window usability. Use [development setup](dev-setup.md) and [the real-Mac checklist](../development-preview.md) for the remaining evidence.

## Where to start

Finish [WF0 #9](https://github.com/mixutin/Mallow/issues/9), record [preview #44 results](https://github.com/mixutin/Mallow/issues/44), then work on capabilities/dependencies, schema-safe stores and the tested bottle/launch boundary. Update performance/security acceptance, roadmap and both website languages with each change.
