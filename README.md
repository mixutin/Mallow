<!-- SPDX-License-Identifier: 0BSD -->

# Mallow

**Building an open-source way to run Windows games and apps on Apple Silicon Macs.**

[![Status: development preview](https://img.shields.io/badge/status-development%20preview-orange)](https://github.com/mixutin/Mallow/releases)
[![Licence: 0BSD](https://img.shields.io/badge/licence-0BSD-blue)](https://github.com/mixutin/Mallow/blob/main/LICENSE)

> **Pre-alpha: setup preview, not a Windows launcher yet.** Mallow now has a native Mac onboarding app, a bootstrap CLI and tested library foundations. Runtime activation, bottles, graphics translation and the kernel sandbox are not implemented. **This build cannot run Windows programs.**

[Download development builds](https://github.com/mixutin/Mallow/releases) · [Test on your Mac](https://mixutin.github.io/Mallow/development-preview/) · [Roadmap](https://github.com/mixutin/Mallow/blob/main/ROADMAP.md) · [Documentation](https://mixutin.github.io/Mallow/)

## Try the development app

Choose a `dev-…` prerelease and download `Mallow-macos-arm64.zip` and `SHA256SUMS`. Verify the ZIP, unzip it, and move `Mallow.app` to Applications. It requires **Apple Silicon and macOS 15 or later**. The build is ad-hoc signed, not Developer ID signed or notarised. macOS may require a per-app approval under System Settings → Privacy & Security. Do not disable Gatekeeper globally.

Every successful **Development app** workflow on `main` publishes a new commit-addressed prerelease, unless that commit already has one. PR builds produce test artifacts but cannot publish releases. Each release includes the app ZIP, its checksum, the source revision and explicit limitations. Failed builds do not publish.

Opening the app checks prerequisites; it does not download anything automatically. Review the selected dependencies and their terms, then choose **Set up selected dependencies**. The app handles the approved operations with progress, cancellation and retry through the same setup service as the CLI.

### Implemented in this preview

| Area | What exists |
|---|---|
| Native app | Onboarding, host/prerequisite status, consent controls, setup progress, cancellation, archive reveal and a copyable test report |
| Rosetta | Detection and an explicit-consent installation request through Apple's `softwareupdate`; existing installations are skipped |
| Wine download | Acquisition of the pinned Wine 11.0_1 archive over approved HTTPS hosts, exact-size and SHA-256 checks, and verified-cache reuse |
| Library | Partial WF0 serialization and settings types, deterministic/atomic JSON persistence, a setup-cache ownership check and an advisory lock |
| CLI | `mallow doctor` and the limited `mallow setup` commands below; not the full planned CLI |
| Distribution | CI-built arm64 app bundles, executable/signature/architecture checks, checksums and automatic development prereleases |

**Downloaded does not mean installed.** The Wine archive is cached but is not extracted, activated or executed. GStreamer setup, capability probing, complete WF0 models, bottle creation and the secure launch pipeline are still on the roadmap. D3DMetal is never downloaded or bundled by Mallow.

### What has actually been tested

The initial app implementation in [PR #43](https://github.com/mixutin/Mallow/pull/43) passed **37 tests across four suites** on a macOS 26.6.2 Apple Silicon runner with Swift 6.3.3. Release-mode app/CLI builds, bundle architecture, licence files, ad-hoc signatures and executable startup checks passed. The setup subset also passed debug/release tests on Linux with injected downloads and hashes.

These checks do **not** prove GUI usability, a successful real dependency download or Rosetta installation on your network, every supported macOS version, or game compatibility. Please record actual Mac results against the build revision in [issue #42](https://github.com/mixutin/Mallow/issues/42), using the [testing checklist](https://mixutin.github.io/Mallow/development-preview/). No successful Windows-app or game test is claimed.

## Build and test from source

The package requires Swift 6.2 or newer; the full design targets Swift 6.3. The app target is built only on macOS. The current package has no third-party Swift dependencies.

```sh
git clone https://github.com/mixutin/Mallow.git
cd Mallow
swift build
scripts/test.sh
scripts/test.sh -c release
swift run mallow doctor --json
```

On an Apple Silicon Mac, assemble the development ZIP with:

```sh
scripts/build-app.sh
scripts/verify-app-bundle.sh dist/Mallow-macos-arm64.zip
```

The app contains the CLI at `Mallow.app/Contents/Helpers/mallow`. The implemented setup commands are:

```sh
# Inspect prerequisites; no download or installation.
mallow doctor --json

# Only after reviewing the displayed upstream release and licence information:
mallow setup --download-runtime --accept-download

# Only after reviewing and accepting Apple's software licence:
mallow setup --install-rosetta --accept-apple-license
```

There is no `mallow run`, `bottle create` or `runtime install` command yet. See [development setup](https://mixutin.github.io/Mallow/contributing/dev-setup/) and the [bootstrap design addendum](https://github.com/mixutin/Mallow/blob/main/docs/BOOTSTRAP.md) for the current scope and temporary interfaces.

## What Mallow is being built to do

Mallow will manage separate Wine environments called **bottles**, select graphics backends, verify runtime components, and run Windows programs inside a macOS kernel sandbox. A native SwiftUI app and a scriptable CLI will share MallowKit.

```text
Windows program → Wine → DirectX-to-Metal translation → macOS
                       x86-64 code runs through Rosetta 2
Mallow will manage bottles, verified components, launch plans and the sandbox.
```

The intended features include secure bottle defaults; explicit read-only folder sharing; disposable offline environments for untrusted programs; per-program graphics choices that survive Steam launching a game; one-click Steam and dependency recipes; and a separately distributed, openly built Wine runtime. These remain **planned**. The full [design](https://github.com/mixutin/Mallow/blob/main/docs/DESIGN.md) and [security model](https://github.com/mixutin/Mallow/blob/main/docs/SECURITY_MODEL.md) explain the architecture and its limits.

Wine itself is not a sandbox. A model named `SandboxSettings` does not provide isolation. Mallow will not enable Windows execution in this preview without the missing launch and sandbox work.

## Roadmap

The [roadmap](https://github.com/mixutin/Mallow/blob/main/ROADMAP.md) records implemented work, unverified behavior and the remaining milestone criteria. The website embeds that same file rather than maintaining a second copy.

The immediate sequence is to test this preview on real Macs; finish WF0 and schema-safe stores; safely activate the verified runtime and handle its dependencies; then build and validate bottle creation and sandboxed launching. The first Windows execution milestone remains Notepad, not a claim of broad game compatibility. The early app is a testing surface, **not completion of v0.1 or v0.3**. Outstanding G0/legal and production-release requirements remain tracked. There are no promised release dates.

## Contributing and maintenance

Read [CONTRIBUTING.md](https://github.com/mixutin/Mallow/blob/main/CONTRIBUTING.md), [AGENTS.md](https://github.com/mixutin/Mallow/blob/main/AGENTS.md) and the [Code of Conduct](https://github.com/mixutin/Mallow/blob/main/CODE_OF_CONDUCT.md). Changes include applicable tests and synchronized README, changelog, roadmap and website updates. A green CI build, a published artifact and a test on a user's Mac are separate facts and are reported separately.

Contributions use DCO sign-off. Never copy code from GPL frontends into Mallow's 0BSD frontend, or use proprietary files from CrossOver. Report security problems privately through [SECURITY.md](https://github.com/mixutin/Mallow/blob/main/SECURITY.md). Routine work can be performed with AI assistance on the owner's behalf; that is not an independent review or a second release-key custodian.

## Licence and acknowledgements

Mallow's own code, scripts and documentation are [0BSD](https://github.com/mixutin/Mallow/blob/main/LICENSE). Recipe data and JSON schemas are designated CC0-1.0. The separately planned Wine runtime and our Wine patches retain LGPL-2.1-or-later. Other components keep their own licences; see [THIRD_PARTY_LICENSES.md](https://github.com/mixutin/Mallow/blob/main/THIRD_PARTY_LICENSES.md) and [NOTICE](https://github.com/mixutin/Mallow/blob/main/NOTICE). The current app bundles no Wine runtime, Apple translation binaries, games or Microsoft redistributables.

Mallow builds on Wine and the work of its contributors, including CodeWeavers and Gcenx, and on the ideas documented in NOTICE. Implementations in this repository are written for Mallow rather than copied from other frontends.

Mallow is independent and is not affiliated with or endorsed by CodeWeavers, Apple, Microsoft, Valve or the Wine project. Product names are used descriptively; trademarks remain with their owners. The Mallow name remains subject to the outstanding naming review.

Copyright (C) 2026 Mixutin and the Mallow contributors
