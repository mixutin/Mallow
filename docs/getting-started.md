---
# SPDX-License-Identifier: 0BSD
description: Install the pinned Wine runtime with Mallow's development app, verify its files and understand what still blocks Windows launching.
---

# Getting started

Mallow is an early runtime-installation preview, not yet a Windows launcher. [Suomenkielinen ohje](https://mixutin.github.io/Mallow/fi/getting-started/).

## What you can do today

Download a [development prerelease](https://github.com/mixutin/Mallow/releases), verify its checksum and follow the [Mac test guide](development-preview.md). The native dark-pink app checks prerequisites, requests Rosetta after consent, downloads/reuses and verifies the pinned Wine archive, unpacks it and registers the completed runtime. It also offers a full file-integrity check, cancellation and a copyable report.

## What you need

Apple Silicon and macOS 15 or later. Rosetta is not needed merely to open the native app. The archive is approximately 185 MB; allow at least 2 GB free for private staging and checks. Installation stays under Mallow's own application-support directory and preserves the upstream Wine bundle.

For building, use Swift 6.2 or newer; the full design targets Swift 6.3. Mac CI has exercised Swift 6.3.3/macOS 26.6.2; the complete CLT/Xcode and supported-OS matrix is still separate work. The archive reader links the operating system library, not a bundled Homebrew library.

## Install Wine

Open the app, select **Install Wine 11.0_1**, review the source/licence and approve installation. If Rosetta is missing, its installation has a separate Apple-licence checkbox. Press **Install selected dependencies**. Nothing is installed merely by opening the app.

The app rechecks a previous preview's cached archive before reuse. Installation checks a private snapshot, extracts within size/path/link constraints, records hashes and registers the complete tree. After success, use **Show runtime in Finder** or **Verify runtime**. A corrupt existing installation is preserved and reported, not silently replaced; repair/rollback is still planned.

!!! warning "Installed does not mean ready for Windows programs"

    GStreamer setup, runtime capability probing, bottle creation, graphics configuration and tested kernel isolation remain unfinished. The preview cannot run a game, `.exe` or Windows installer. The receipt is a corruption baseline, not a tamper-proof signature.

## Releases and security prompts

Successful canonical-main app workflows publish commit-addressed development prereleases with ZIP/checksum/source metadata. They are ad-hoc signed, not Developer ID signed or notarised, and not stable product releases. Read the [per-app approval instructions](development-preview.md#download-and-verify); never disable Gatekeeper globally or dismiss unexpected malware warnings.

## Implemented command-line operations

The CLI is bundled at `Mallow.app/Contents/Helpers/mallow`; it is not automatically added to PATH.

```sh
mallow doctor --json
mallow setup --install-runtime --accept-download
mallow runtime verify --json
mallow runtime path
mallow setup --install-rosetta --accept-apple-license
```

Review the upstream release and Apple licence before passing consent flags. `doctor` is metadata-only; add `--verify-archive` to check the cache hash. `runtime verify` checks the full installation. The older `setup --download-runtime --accept-download` remains explicitly cache-only.

The complete intended milestone sequence is still **planned, not implemented**:

```sh
mallow runtime install standard-wine-stable-11.0_1
mallow bottle create Test
mallow run --bottle Test --wait notepad
```

The [roadmap](roadmap.md) checks installation and verification separately from unfinished launch work. [Build from source](contributing/dev-setup.md) or [report your Mac test](development-preview.md#test-on-your-mac).

## What Mallow will not do

No games, anti-cheat bypasses, piracy tooling, bundled D3DMetal, automatic Homebrew installation or global Gatekeeper changes. Intel hosts are outside the v1 plan. See the [FAQ](faq.md) and [security model](SECURITY_MODEL.md).
