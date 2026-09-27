---
# SPDX-License-Identifier: 0BSD
title: Bootstrap design addendum
description: Owner-directed development previews, staged APIs, runtime installation boundaries and release validation.
---

# Bootstrap design addendum

**Initial decision: 26 September 2026, repository owner. Updated 27 September 2026.** Publish small native Mac previews for real-device testing before claiming the complete Windows-launching product works. [PR #41](https://github.com/mixutin/Mallow/pull/41) introduced partial WF0; [#43](https://github.com/mixutin/Mallow/pull/43) introduced acquisition/onboarding; [#45](https://github.com/mixutin/Mallow/pull/45) adds installation, integrity verification, branding and Finnish website pages.

The full [design](DESIGN.md) remains the intended architecture. This addendum and the [runtime installation design](runtime-installation.md) explicitly record early file ownership, temporary APIs, sequencing and development distribution. They do not mark G0, WF0, v0.1 or v0.3 complete. Use the [roadmap](roadmap.md) for current implementation rather than reading future architecture as shipped code.

## Scope and sequencing

The preview checks prerequisites, requests Rosetta installation after consent, downloads and verifies the one pinned Wine archive, and now extracts/registers that runtime. It provides full installed-file verification from the native app and limited CLI, all over MallowKit.

Prefix creation, graphics configuration and Windows launching remain absent. `SetupReport.runtimeActivated` now reports recognized installation metadata; `sandboxImplemented` and `readyToRunWindows` stay false. The [security model](SECURITY_MODEL.md) is not weakened to enable an early unsafe launch. GStreamer installation, generic imports/provenance, capabilities, signed catalogs and lifecycle repair remain future work.

## File ownership and temporary interfaces

The original preview files remain: `Support/SetupPlan.swift`, `VerifiedDownload.swift`, `Rosetta.swift`, `FileLock.swift`, `Runtime/BuiltinComponents.swift`, `Operations/SetupService.swift`, `MallowCLI/MallowCommand.swift`, the MallowApp entry/model/onboarding view, `SetupServiceTests.swift`, bundle scripts and `.github/workflows/app.yml`. Newly introduced ownership and receipt fields are enumerated in [runtime installation design](runtime-installation.md#staged-file-ownership-and-apis).

The Support layer does not import Runtime. The app target is macOS-only; portable library tests compile on Linux. Production install/acquisition require supported Apple Silicon/macOS. Linux has no homemade SHA-256 fallback; tests inject it.

Implemented CLI: `doctor [--json] [--verify-archive]`, `setup` with `--install-runtime` or cache-only `--download-runtime`, optional Rosetta setup, `runtime verify [--json]` and `runtime path`. Unknown commands are rejected. Temporary exit codes are 2 for usage, 3 for operation errors and 4 for a failed integrity report. The full argument-parser/error taxonomy remains planned.

Rosetta consent is per invocation, not a fabricated persistent consent record. Dependency selection may be preselected; consent is never prechecked. Setup preflights selected consents before effects. Bootstrap structs/receipts do not replace the normative persisted bottle or signed runtime formats. Full WF0 remains in [#9](https://github.com/mixutin/Mallow/issues/9).

## Acquisition and installation boundaries

Opening the app checks metadata only. The user reviews source/licence information and approves selected actions before setup. A cached archive is rehashed before reuse; installation validates a private snapshot again before extraction.

The [Wine 11.0_1 upstream asset](https://github.com/Gcenx/macOS_Wine_builds/releases/tag/11.0_1) is pinned to 185,303,032 bytes and SHA-256 `b50dc50ec7f41d58b115a6b685d4d1315ba3c797bd3aa0f49213f2703cb82388`. Upstream asset ID 397814211 was checked on 26 September 2026. Its URL/size/hash are compiled in, not downloaded next to the archive. Redirects stay HTTPS on approved GitHub release hosts.

The default cache remains `~/Library/Caches/io.github.mixutin.Mallow.setup` so older downloads can be reused. Runtime installations live under the separately ownership-marked `~/Library/Application Support/Mallow/Runtimes/`. `MALLOW_HOME` may isolate both for tests. Cache and runtime locks span their whole operations. Failure does not replace a previous cache or runtime. The data root, archive constraints, staging and receipt limits are detailed in [the installer design](runtime-installation.md).

Rosetta uses only `/usr/sbin/softwareupdate` after Apple's licence is accepted; no sudo wrapper or elevated helper. Cancellation requests termination, but an OS-service installation already started may continue. Recheck afterwards.

**Never performed by this slice:** Wine/Windows execution, Homebrew installation, system-wide Gatekeeper changes, D3DMetal acquisition or GStreamer package installation. Extraction does not restore archive-supplied extended attributes. This is not a general quarantine-removal feature. Mono and Gecko are in the upstream bundle, not installed into any bottle by this preview.

## Development distribution

The workflow tests and builds arm64 on macOS, renders the original flower icon, bundles notices/source revision, verifies architecture/ad-hoc signatures and non-GUI startup, then installs/verifies the actual pinned archive in a temporary data root without executing it. PRs upload artifacts with read-only access. Only successful canonical-main builds publish commit-addressed prereleases from a separate contents-write job; that job does not execute repository code.

Published previews are not overwritten by this workflow. ZIP checksums are verified before release publication. No production signing key, Developer ID or notarisation is used. This owner-requested preview is not v0.8/v1.0 release acceptance and does not invent an independent reviewer, legal clearance or DCO certification.

## Website and localization

`docs/` is the English site. `docs-fi/` contains Finnish user pages; its inherited configuration localizes navigation and search. Both strict builds produce one Pages artifact. A header language selector links both sites. Full technical design and historical devlogs remain English; this scope is stated in the Finnish pages.

The navigation spinner reports real page work without intercepting navigation, hiding content, delaying rendering or trapping focus. It supports reduced motion and cleans up on completion, back/forward navigation and timeout. No external analytics or loader service is added.

## Evidence and acceptance

The initial app had 37 passing macOS tests; this installer adds 12 synthetic test functions and real-archive integration. Exact-head CI results, fixes and deployment outcomes are recorded on PR #45. The owner reported previous-preview archive acquisition/checksum success; that is not a new-installer or game result.

The app's `--smoke-test` exits before showing a window. Personal-Mac GUI, memory/startup latency, cancellation, accessibility and broader OS/toolchain validation remain explicit tasks in [#44](https://github.com/mixutin/Mallow/issues/44) and [the preview checklist](development-preview.md). No Windows/game compatibility follows from compilation or installation alone.


The next staged client APIs and their privacy/performance contract are documented in [Mac client testing](mac-client-testing.md#implementation-contract). They add diagnostic export and local self-tests without changing persisted bottle/runtime formats or enabling Wine execution.
