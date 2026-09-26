---
# SPDX-License-Identifier: 0BSD
description: Start with Mallow's development setup preview on Apple Silicon. Download, build, test, and distinguish implemented setup from planned Windows launching.
---

# Getting started

Mallow is in early implementation. There is now a **development setup app**, but there is not yet a working Windows launcher.

## What you can do today

Download a commit-addressed [development prerelease](https://github.com/mixutin/Mallow/releases), verify it and follow the [Mac test guide](development-preview.md). The native app can inspect prerequisites, request Rosetta installation after consent, and download/check the pinned Wine archive after approval. It includes progress, cancellation and a copyable report.

You can also build the library, CLI and Mac app from source using the [development setup guide](contributing/dev-setup.md). The current code has no third-party Swift package dependencies.

!!! warning "An acquired archive is not an installed runtime"

    Wine activation, GStreamer setup, bottle creation, graphics and sandboxed Windows launching are not implemented. The app is not ready to run a game or installer. The security model is still the intended design, not a claim about a released Windows execution feature.

## What you will need

For the native preview: Apple Silicon and macOS 15 or later. Rosetta is not needed to open the native app. The runtime acquisition uses about 185 MB for the compressed download plus temporary storage. Actual runtime extraction and bottle disk requirements belong to later work.

For building: Swift 6.2 or newer; the full design's development target is Swift 6.3. The Apple Silicon CI build uses Swift 6.3.3. No local Xcode GUI, real Wine installation or game is required for the current unit tests. The separate Command Line Tools-only acceptance matrix still needs verification.

## The first releases

Successful main-branch app workflows publish **development** prereleases with checksums and source revisions. These are ad-hoc signed, not notarised, and are not stable releases. The [preview guide](development-preview.md) explains per-app security prompts and the actual-Mac testing checklist.

Full milestones remain on the [roadmap](roadmap.md): v0.1's secure runtime/bottle/CLI flow, v0.2's own runtime, v0.3's complete native app, v0.4's Steam and recipes, and v0.5's user-supplied graphics toolkit import. The early onboarding window does not complete those milestones.

## A preview of the command-line tool

These commands exist now:

```sh
mallow doctor --json
mallow setup --download-runtime --accept-download
mallow setup --install-rosetta --accept-apple-license
```

Read the upstream release and Apple's licence before giving the corresponding acceptance flag. The first setup command acquires an archive only. The CLI is bundled at `Mallow.app/Contents/Helpers/mallow`; it is not installed into your PATH automatically.

The intended end-to-end command sequence is still **planned, not implemented**:

```sh
mallow runtime install standard-wine-stable-11.0_1
mallow bottle create Test
mallow run --bottle Test --wait notepad
```

## What Mallow won't do

Mallow does not provide games, anti-cheat bypasses, piracy tooling or bundled D3DMetal. The preview never installs Homebrew or disables Gatekeeper. The v1 host target is Apple Silicon, not Intel Macs. See the [FAQ](faq.md), [bootstrap addendum](BOOTSTRAP.md) and [security model](SECURITY_MODEL.md) for scope and limits.
