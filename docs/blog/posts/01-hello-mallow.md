---
# SPDX-License-Identifier: 0BSD
date: 2026-09-23
authors:
  - mixutin
categories:
  - Announcements
  - Roadmap
slug: hello-mallow
description: Mallow is a new open-source project to run Windows games and apps on Apple Silicon Macs. What it is, what we learned in research, and the plan. Pre-alpha, design only.
---

# Devlog #0: Hello, Mallow

Mallow is a new open-source project with a simple goal: make it easy, and safe, to run Windows games and apps on Apple Silicon Macs. It builds on Wine, Rosetta 2 and DirectX-to-Metal translation, and it aims to be an open alternative to CodeWeavers' CrossOver.

First, the honest part. Mallow is **pre-alpha and in the design phase**. No application code exists yet, so there's nothing to download or try. This devlog is where we'll share how it goes, starting from zero.

<!-- more -->

## What CrossOver does, and why an open alternative

CrossOver is a commercial Mac app from CodeWeavers. At a high level, it takes Wine, the compatibility layer that lets Windows programs run on other systems, and wraps it in a friendly Mac experience. Each program lives in its own "bottle", popular apps and games install in a few clicks, and DirectX games are translated so they draw through Apple's Metal. CodeWeavers also funds much of the work on Wine for macOS, and publishes the source of its Wine changes under the LGPL.

If CrossOver works for you, great. Buying it funds Wine development that everyone, including us, benefits from.

So why build another one? Because we think there should also be an option that's open all the way down: a frontend anyone can read, audit, fork and reuse; a Wine runtime built in public; and security treated as a headline feature. The other posts in this devlog cover each of those.

## What we learned in research

Before designing anything, we read a lot of source code, issue trackers and licences. Four findings shaped the plan most.

**Whisky's story.** Whisky was the best-known free Wine frontend for the Mac. Its maintainer archived it in 2025, citing burnout, and called free CrossOver-derived frontends "parasitic" on CodeWeavers' funding of Wine on macOS. We took that seriously. Our answers: at least two maintainers with release rights, and no signed release until the second one joins (we're looking now); everything scripted in CI, so no single person carries the runtime build; fixes sent upstream to Wine, DXMT, MoltenVK and winetricks; and no support load pushed onto CodeWeavers, because our runtime's crash dialog points at our own tracker. We learned from Whisky's bugs too. For example, Mallow won't key per-program settings by bare file name, which breaks when two games both ship a `launcher.exe`.

**Homebrew's Wine casks are gone.** Homebrew disabled its `wine-*` casks on 2026-09-01, so "just `brew install` Wine" is no longer an answer. Several libraries Wine needs no longer have Intel Homebrew builds either. So Mallow will download its own signed runtime, and we'll build that runtime's dependencies from pinned source in CI.

**Rosetta has a clock on it.** Apple has said macOS 27 is the last release with full Rosetta 2. macOS 28 keeps a subset for games, and its exact scope isn't clear yet. Mallow runs an x86_64 Wine under Rosetta, so this matters a lot. We'll track Apple's wording closely, and a native arm64 approach is on the research list for after 1.0.

**D3DMetal can't ship with us.** Apple's D3DMetal, part of its Game Porting Toolkit, is the only DirectX 12 route in our plan. But its licence limits use to developing, testing or evaluating games, allows distribution only for non-commercial purposes, and forbids modification. That doesn't fit a project anyone may reuse for anything. So Mallow will never download, bundle or host it. Instead, the plan is that you import it from your own copy of Apple's toolkit, after reading and accepting Apple's licence yourself.

## The plan

Mallow is designed as three layers:

- **MallowKit**, a Swift library that does the real work: bottles, runtimes, graphics backends, launching and diagnostics.
- **`mallow`**, a command-line tool that exposes all of it. Every feature lands here first.
- **The Mallow app**, a native SwiftUI frontend over the same library.

The Wine runtime isn't inside the app. It will be a separate, signed download, built in public GitHub Actions from the LGPL Wine source CodeWeavers publishes (Wine 11.0, from the CrossOver 26.3.0 source release), plus three small patches of our own. Graphics backends (DXMT, DXVK over MoltenVK, and Wine's own wined3d) are separate signed components, and D3DMetal is the user-supplied import described above. Bottles are secure by default, and every Windows program is planned to run inside a macOS kernel sandbox.

Mallow itself is designed to build with Swift 6.3 and Apple's Command Line Tools alone, so contributors won't need Xcode.

The roadmap, roughly:

1. **Gate G0, before any code:** name clearance, governance and licence files.
2. **v0.1 "Foundations":** the library and CLI, bottles, and an interim, pinned Wine build.
3. **v0.2 "Own runtime":** our CI-built runtime, signing, DXMT and MSync.
4. **v0.3 "Mac app"**, then **v0.4 "Steam and dependencies"** and **v0.5 "D3DMetal and upscalers"**, followed by polish, distribution and community recipes on the way to **1.0**.

We're deliberately not putting dates on this. It's a small volunteer effort, and we'd rather be late than wrong.

## How to follow along

- Star or watch the repository: [github.com/mixutin/Mallow](https://github.com/mixutin/Mallow).
- Read the [design document](https://github.com/mixutin/Mallow/blob/main/docs/DESIGN.md) and the [security model](https://github.com/mixutin/Mallow/blob/main/docs/SECURITY_MODEL.md). They're long and candid, and the design document tags every factual claim by how well it has been verified.
- Spot a mistake? [Open an issue](https://github.com/mixutin/Mallow/issues). At this stage, a good correction is as valuable as code.
- Want to help? Start with the [contributing guide](https://github.com/mixutin/Mallow/blob/main/CONTRIBUTING.md).

See you in Devlog #1.
