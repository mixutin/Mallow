<!-- SPDX-License-Identifier: 0BSD -->

# Mallow

**Building an open-source way to run Windows games and apps on Apple Silicon Macs—with performance and security as core requirements.**

[![Status: development preview](https://img.shields.io/badge/status-development%20preview-orange)](https://github.com/mixutin/Mallow/releases)
[![Licence: 0BSD](https://img.shields.io/badge/licence-0BSD-blue)](https://github.com/mixutin/Mallow/blob/main/LICENSE)

> **Pre-alpha: client test-readiness preview, not a Windows launcher yet.** Mallow now installs the verified Wine runtime and checks installed-file integrity through a native Mac app and CLI. Bottles, graphics setup and the kernel sandbox are still missing. **This build cannot run Windows programs.**

[Download development builds](https://github.com/mixutin/Mallow/releases) · [Test on your Mac](https://mixutin.github.io/Mallow/development-preview/) · [Roadmap](https://github.com/mixutin/Mallow/blob/main/ROADMAP.md) · [English docs](https://mixutin.github.io/Mallow/) · [Suomeksi](https://mixutin.github.io/Mallow/fi/)

## Mac client checks and debugging

The test-readiness preview adds **Run client checks**, a read-only dependency/architecture preflight, bounded local self-tests and **Export report…**. Use `mallow diagnostics --self-test --json` for the same checks from Terminal. Reports include the exact build/configuration, check outcomes, action timings and process peak RSS, without raw logs, personal paths or environment variables. Nothing is automatically uploaded. A passing client self-test is not a Windows-launch or sandbox verdict.

Releases now include optimized and debug app ZIPs, UUID-matched dSYM archives, exact tracked sources and a Mac test kit. Use the optimized app for performance observations. Read [Mac client testing](https://mixutin.github.io/Mallow/mac-client-testing/) or [ohje suomeksi](https://mixutin.github.io/Mallow/fi/mac-client-testing/) before testing. GStreamer architecture-header detection does not install or validate its complete dependency stack. Bottle creation and Windows execution remain unfinished.

## Try the development app

Choose a `dev-…` prerelease and download `Mallow-macos-arm64.zip` and `SHA256SUMS` from the same release. Verify the ZIP, unzip it, and move `Mallow.app` to Applications. It requires **Apple Silicon and macOS 15 or later**. The build is ad-hoc signed, not Developer ID signed or notarised. Approve only this specific app under System Settings → Privacy & Security if macOS asks. Do not disable Gatekeeper globally.

The app now uses a dark-pink theme, the website's flower logo and a generated matching icon. Its loading indicator follows actual setup work and respects Reduce Motion; there is no artificial wait.

Opening Mallow checks prerequisites but does not download or install anything. Select **Install Wine 11.0_1**, review the upstream source/licence, and approve installation. Rosetta, if missing, has a separate Apple-licence consent. Choose **Install selected dependencies**. The approximately 185 MB archive is reused from the previous preview's cache when valid; allow at least 2 GB free for staging.

Setup verifies a private copy of the pinned archive, unpacks it, checks the tree, records per-file hashes and registers the complete runtime under `~/Library/Application Support/Mallow/Runtimes/standard-wine-stable-11.0_1/`. The upstream `Wine Stable.app` layout stays intact. **Verify runtime** performs a full integrity check; **Show runtime in Finder** reveals it.

### Implemented in this preview

| Area | What exists |
|---|---|
| Native app | Pink onboarding, original flower branding, prerequisite/consent controls, real-work loaders, installation, verification, cancellation and copyable reports |
| Rosetta | Detection and explicit-consent request through Apple's installer; existing installations are skipped |
| Wine | Pinned HTTPS acquisition, exact-size/SHA-256 checks, private bounded extraction and completed-tree registration |
| Integrity | Recorded file sizes/hashes/link targets; missing, modified and unexpected-file detection; repeat-install verification without a new download |
| Data protection | Ownership-marked application root, cache ownership, advisory transaction locks and staging cleanup |
| Performance | Metadata-only startup, streamed hashing/extraction, throttled UI progress and explicit verification timing |
| CLI | `doctor`, `diagnostics`, setup acquisition/installation, `runtime verify` and `runtime path` |
| Distribution/site | Mac CI builds and commit-addressed prereleases, combined English/Finnish site and a non-blocking page spinner |

**Installed is not the same as ready to run Windows.** GStreamer setup, runtime capability probing, complete WF0 models, bottle creation, graphics and the secure launch pipeline remain unfinished. A local integrity receipt detects corruption; it is not a tamper-proof signature or a sandbox. Damaged installations are preserved and rejected rather than silently overwritten. Automatic repair/rollback is still planned.

## Performance and security

Routine startup does not hash hundreds of megabytes. Full checks happen during installation or when requested, outside the UI's main actor. Extraction and hashing use bounded 1 MiB buffers, and download progress is throttled to avoid flooding the UI. The native loader is absent when idle and pauses for reduced motion or an inactive app. The website spinner never hides content or traps focus.

Speed does not justify skipping integrity checks: the archive's expected size and SHA-256 are compiled in; extraction rejects traversal, escaping links, duplicate paths and special files; runtime publication happens only after validation. No downloaded Wine program is executed during setup. These controls are not yet the planned Windows-program sandbox. Game FPS, startup latency across Macs, memory consumption and sandbox compatibility must be measured before claims are made.

## What has actually been tested

[PR #49](https://github.com/mixutin/Mallow/pull/49) adds 12 diagnostic regression tests and packaged release/debug client checks, including a macOS 15 job. The full portable package passed 60 tests in debug and release on Linux; exact macOS CI outcomes are recorded on that PR. These are not graphical-user-interface or game tests.

The foundation preview in PR #43 passed 37 tests on a macOS Apple Silicon runner. The new installer adds 12 test functions covering successful installation, corruption, cancellation, consent, foreign roots, traversal, links, duplicate entries and special files. A separate network integration step installs and verifies the actual pinned archive, repeats setup and checks that altering an installed file is detected. It does not execute Wine. See [PR #45](https://github.com/mixutin/Mallow/pull/45) for exact-head CI results and any build fixes.

The owner reported a successful archive download/checksum in the previous preview. New installer behavior, graphical usability, accessibility and performance on the owner's Mac remain separate acceptance checks in [issue #44](https://github.com/mixutin/Mallow/issues/44). A green build or a local receipt is not evidence of game compatibility.

## Build and test from source

The package requires Swift 6.2 or newer; the full design targets Swift 6.3. The app builds only on macOS. There are no external Swift-package dependencies. Extraction links the operating system's libarchive; the repository supplies the small public ABI declaration bridge for Mac SDKs without headers. Linux development needs its system libarchive development package.

```sh
git clone https://github.com/mixutin/Mallow.git
cd Mallow
swift build
scripts/test.sh
scripts/test.sh -c release
swift run mallow doctor --json
```

On Apple Silicon, `scripts/build-app.sh` builds the app ZIP and `scripts/verify-app-bundle.sh dist/Mallow-macos-arm64.zip` checks it. `scripts/test-runtime-install.sh` is a separate opt-in network test. Unit tests use synthetic inputs and injected downloads, not real Wine.

The app includes the CLI at `Mallow.app/Contents/Helpers/mallow`:

```sh
mallow doctor --json
mallow setup --install-runtime --accept-download
mallow runtime verify --json
mallow runtime path
# Cache-only acquisition remains available:
mallow setup --download-runtime --accept-download
# Only after accepting Apple's licence:
mallow setup --install-rosetta --accept-apple-license
```

`doctor` is metadata-only by default; `--verify-archive` additionally rehashes the cached archive. `runtime verify` exits 4 on integrity problems. `MALLOW_HOME` may name an absolute isolated data root for tests. There is no `mallow run` or `bottle create` command yet.

## What Mallow is being built to do

Mallow will manage isolated Wine environments called bottles, select graphics backends, verify runtime components and start Windows programs inside a tested kernel sandbox. The SwiftUI app and CLI share MallowKit. Planned features include explicit read-only sharing, disposable offline bottles, per-program graphics choices, Steam and dependency recipes, and a separately built open Wine runtime.

Wine itself is not a sandbox. `SandboxSettings` is configuration, not isolation. The [full design](https://github.com/mixutin/Mallow/blob/main/docs/DESIGN.md), [bootstrap staging addendum](https://github.com/mixutin/Mallow/blob/main/docs/BOOTSTRAP.md), [installation design](https://mixutin.github.io/Mallow/runtime-installation/) and [security model](https://github.com/mixutin/Mallow/blob/main/docs/SECURITY_MODEL.md) describe the intended system and current boundaries.

## Roadmap and maintenance

The [roadmap](https://github.com/mixutin/Mallow/blob/main/ROADMAP.md) checks off implemented subfeatures without marking incomplete milestones finished. Next are complete models/stores, runtime capability/dependency checks, bottle creation and tested sandboxed launching. The first end-to-end target is Notepad, not broad game compatibility. v0.1/v0.3, G0 and production release gates remain open.

Every successful Development app workflow on canonical `main` publishes a new commit-addressed prerelease unless one already exists; PRs publish artifacts only. Tests include the real runtime-install check before publication. English/Finnish docs build into one Pages artifact. Build success, publication, website deployment and actual Mac tests are reported separately.

Read [CONTRIBUTING.md](https://github.com/mixutin/Mallow/blob/main/CONTRIBUTING.md), [AGENTS.md](https://github.com/mixutin/Mallow/blob/main/AGENTS.md) and the [Code of Conduct](https://github.com/mixutin/Mallow/blob/main/CODE_OF_CONDUCT.md). Changes update tests, README, changelog, roadmap and affected pages in both languages. Historical devlogs remain historical. The app and full technical documents are currently English; the principal user website pages are also Finnish.

Contributions use DCO sign-off. Never copy GPL frontend code or CrossOver's proprietary files into Mallow. Report vulnerabilities privately through [SECURITY.md](https://github.com/mixutin/Mallow/blob/main/SECURITY.md). AI-assisted owner-directed maintenance is not an independent review or a second signing-key custodian.

## Licence and acknowledgements

Mallow's own code, scripts and documentation are [0BSD](https://github.com/mixutin/Mallow/blob/main/LICENSE). Recipes/schemas are designated CC0-1.0. The separately planned Wine runtime and our Wine patches retain LGPL-2.1-or-later; other components keep their licences. See [THIRD_PARTY_LICENSES.md](https://github.com/mixutin/Mallow/blob/main/THIRD_PARTY_LICENSES.md) and [NOTICE](https://github.com/mixutin/Mallow/blob/main/NOTICE). The app bundles no Wine runtime, D3DMetal, games or Microsoft redistributables. Wine is downloaded from its pinned upstream release after approval.

Mallow builds on Wine and its contributors, including CodeWeavers and Gcenx, and the ideas credited in NOTICE. It is independent, not affiliated with or endorsed by CodeWeavers, Apple, Microsoft, Valve or Wine. Trademarks remain with their owners; the Mallow name remains subject to the naming review.

Copyright (C) 2026 Mixutin and the Mallow contributors
