---
# SPDX-License-Identifier: 0BSD
title: Bootstrap design addendum
description: The owner-directed development preview scope, temporary interfaces, dependency acquisition boundary and release workflow.
---

# Bootstrap design addendum

**Decision: 26 September 2026, repository owner.** Ship a small, testable native Mac setup preview and automatic development builds before claiming that the complete Windows-launching product works. This addendum records the scope introduced by [PR #43](https://github.com/mixutin/Mallow/pull/43), following the partial WF0 foundation in [#41](https://github.com/mixutin/Mallow/pull/41).

The full [design](DESIGN.md) remains the intended architecture. This addendum is the explicit staging exception for the early preview's file ownership, temporary APIs, setup command and development distribution. It does not mark G0, WF0, v0.1 or v0.3 complete. Where the original design describes a not-yet-existing app or CLI, use this addendum and the [roadmap](roadmap.md) for current implementation status.

## Scope and sequencing

The preview implements prerequisite inspection, consent-gated Rosetta installation requests, acquisition of one pinned Wine archive, and a native test surface over that service. The CLI exposes these operations first through MallowKit; the app does not duplicate their effects.

Runtime activation, prefix creation, graphics setup and Windows process launching are deliberately absent. Downloading a file does not make the product ready to run Windows software. `SetupReport.runtimeActivated`, `sandboxImplemented` and `readyToRunWindows` remain false. The [security model](SECURITY_MODEL.md) is not relaxed to make an early launch work.

## File and type ownership

| File | Responsibility |
|---|---|
| `Support/SetupPlan.swift` | Download descriptor/policy, setup errors, host facts, progress and status values |
| `Support/VerifiedDownload.swift` | Injectable download/hash protocols, HTTPS transport and streaming CryptoKit hash |
| `Support/Rosetta.swift` | Fixed Apple installer invocation with per-invocation licence consent |
| `Support/FileLock.swift` | Advisory lock; a descriptor stays held across archive acquisition |
| `Runtime/BuiltinComponents.swift` | Compiled-in Standard Wine URL, byte count, digest and approved hosts |
| `Operations/SetupService.swift` | Cache ownership, acquisition orchestration, verification, reuse and status |
| `MallowCLI/MallowCommand.swift` | Temporary bootstrap parser and `doctor`/`setup` commands |
| `MallowApp/AppModel.swift`, `MallowApp.swift`, `Views/OnboardingView.swift` | Main-actor UI state, app entry and setup controls |
| `Tests/MallowKitTests/SetupServiceTests.swift` | Hermetic setup/consent/cache tests and macOS CryptoKit vector |
| `Resources/Info.plist` | Bundle identity, minimum OS, channel and source revision |
| `scripts/build-app.sh`, `verify-app-bundle.sh` | Bundle/ZIP construction and verification |
| `.github/workflows/app.yml` | PR artifacts and main-only development prereleases |

The Support layer does not import Runtime; `SetupReport` receives its runtime identifier. The app target is conditional on macOS in Package.swift, while the library/CLI can compile on Linux for portable tests. Production acquisition and installation are restricted to supported Apple Silicon Macs. Linux has no fallback homemade SHA-256 implementation.

## Temporary interfaces

The bootstrap CLI has `doctor [--json]` and `setup` with explicit `--download-runtime --accept-download` and/or `--install-rosetta --accept-apple-license`. It rejects unknown commands. It does not pretend to implement the full §3.8 CLI. Its temporary exits are 2 for usage and 3 for setup errors; the full error taxonomy and argument-parser integration remain future work.

`Rosetta.installationArguments(licenseAccepted:)` uses per-invocation consent rather than the future `ConsentRecord` store. No consent checkbox starts checked on the user's behalf. Dependency selection can be preselected, but approval cannot. The future consent persistence/schema must be added before claiming the full §3.4.1 API. The early `FileLock` reports bootstrap setup errors; it is not yet the full application-store error surface.

These setup-only structs do not replace the normative persisted bottle/runtime formats. The complete WF0 families and fixtures remain in [issue #9](https://github.com/mixutin/Mallow/issues/9).

## Dependency acquisition boundary

The first app launch inspects host facts and any existing cache. No network request or installation starts merely because the app was opened. The user reviews the source/licence information, approves the selected operations, then presses the setup button. A valid cached archive is rehashed and reused.

The [upstream Wine 11.0_1 release](https://github.com/Gcenx/macOS_Wine_builds/releases/tag/11.0_1) asset is pinned to 185,303,032 bytes and SHA-256 `b50dc50ec7f41d58b115a6b685d4d1315ba3c797bd3aa0f49213f2703cb82388`. The pin was checked against upstream asset ID 397814211 on 26 September 2026. It is compiled into the app, not fetched beside the download. Redirects must stay HTTPS on `github.com`, `release-assets.githubusercontent.com` or `objects.githubusercontent.com`; responses, sizes and hashes are checked before the final cache name is used.

The cache is separate from the future application data root: `~/Library/Caches/io.github.mixutin.Mallow.setup`, with a versioned ownership marker, owner check, non-group/world-writable directory and advisory lock. It is not a Wine prefix or installed runtime. A failed download/hash does not replace a previous cache file. Staging files are cleaned up. These controls do not promise isolation from malicious code already running as the same user.

Rosetta is installed only through `/usr/sbin/softwareupdate` after Apple's licence is accepted; no shell or sudo wrapper is introduced. Errors are reported rather than counted as success. Cancellation requests termination of that invocation, but an installation already handed off to an OS service may continue; recheck status afterwards.

**Not performed:** extraction, runtime activation, quarantine removal, GStreamer installation, Wine execution, Homebrew installation, Gatekeeper changes, or proprietary D3DMetal acquisition. The upstream archive includes Mono and Gecko, but those are not installed into a bottle by this preview.

## Development build distribution

The owner requested automated prereleases for personal-Mac testing. The workflow builds and tests on a macOS arm64 runner, bundles the app and helper CLI, copies licence notices, records the exact source commit, verifies architecture and ad-hoc signatures, exercises non-GUI entry points and produces a ZIP/checksum/build-info file.

PR jobs have read-only repository access and upload artifacts only. Only successful builds from canonical `mixutin/Mallow` main can publish `dev-<commit>` prereleases. The publication job has narrowly scoped contents-write permission and does not execute repository code. It verifies the downloaded artifact checksum, uploads assets to a draft, then publishes. An existing published preview is not overwritten. A failure leaves no new public release claiming success.

Ad-hoc integrity signatures are not Developer ID signatures or notarisation and use no project signing keys. This owner-directed early preview is not a production signing release and does not satisfy the v0.8 or v1.0 governance/key-custody criteria. No independent reviewer, legal clearance or human DCO certification is fabricated.

## Evidence and acceptance

The first app revision passed 37 tests on macOS 26.6.2/Apple Silicon with Swift 6.3.3, including the CryptoKit vector. Release app/CLI builds, bundle checks and executable startup passed in [the initial workflow run](https://github.com/mixutin/Mallow/actions/runs/36257897523). The `.app --smoke-test` entry exits before presenting a window; it is **not a GUI test**.

Real-Mac first launch, display/accessibility, network acquisition, Apple installer behavior and supported-OS coverage remain acceptance work in [issue #42](https://github.com/mixutin/Mallow/issues/42). Use the [development preview checklist](development-preview.md). No Windows execution or game compatibility result follows from CI compilation.
