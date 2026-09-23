---
# SPDX-License-Identifier: 0BSD
title: Home
description: Mallow is an open-source way to run Windows games and apps on Apple Silicon Macs, sandboxed by default and free for any use. Pre-alpha, in design.
hide:
  - navigation
  - toc
---

<div class="mallow-hero" markdown>

![](assets/favicon.svg){ .mallow-hero__icon }

<span class="mallow-status">Pre-alpha · design phase</span>

# Mallow

<p class="mallow-hero__tagline">
Run Windows games and apps on your Apple Silicon Mac. Open source, sandboxed by default, and free for any use.
</p>

[How it works](how-it-works.md){ .md-button .md-button--primary }
[Read the devlog](blog/index.md){ .md-button }
[Contribute](contributing/index.md){ .md-button }

</div>

!!! warning "There is nothing to install yet"

    Mallow is in the **design phase**. No application code exists yet. Everything on this site describes what we **plan** to build, not features that work today. The [roadmap](roadmap.md) shows the order we will build things in, and the [devlog](blog/index.md) is where progress gets posted.

## What Mallow will be

Mallow is a planned open-source alternative to CrossOver. It will run Windows programs on Macs with Apple Silicon, using three proven pieces:

- **[Wine](how-it-works.md#wine-a-translator-not-an-emulator)**, which reimplements the Windows APIs on top of macOS;
- **[Rosetta 2](how-it-works.md#rosetta-2-intel-code-on-apple-silicon)**, which translates Intel (x86_64) code for Apple Silicon;
- **[DirectX-to-Metal translation](how-it-works.md#graphics-from-directx-to-metal)** (D3DMetal, DXMT, DXVK with MoltenVK, or Wine's own wined3d), so games can draw with your Mac's GPU.

It will ship as a native Mac app and a scriptable `mallow` command-line tool. Both sit on the same Swift library, so anything the app can do, the CLI can do too.

<div class="grid cards" markdown>

-   :material-shield-lock-outline:{ .lg .middle } **Sandboxed by default**

    ---

    Every Windows program is planned to run inside a macOS kernel sandbox. By default it can see only its own bottle: no `Z:` drive, and no links into your home folder. An **Untrusted** mode runs suspicious programs in a throwaway copy of a bottle.

    [:octicons-arrow-right-24: Security model](SECURITY_MODEL.md)

-   :material-scale-balance:{ .lg .middle } **0BSD: use it for anything**

    ---

    Mallow's own code, scripts and docs are 0BSD. You may use, change, sell and redistribute them, with no attribution required. The Wine runtime stays LGPL, and its source is published with every release.

    [:octicons-arrow-right-24: Legal & licensing](legal.md)

-   :material-source-branch:{ .lg .middle } **Built in the open**

    ---

    The Wine runtime will be built in public GitHub Actions from CodeWeavers' published LGPL Wine sources, then signed. Anyone can audit it or rebuild it.

    [:octicons-arrow-right-24: How it works](how-it-works.md#the-mallow-runtime)

-   :material-gamepad-variant-outline:{ .lg .middle } **The right graphics path per game**

    ---

    Mallow is designed to pick a graphics backend for each game, and with the Mallow Runtime that choice holds even when Steam starts the game. You can always override it. D3DMetal is supported if you import your own copy from Apple.

    [:octicons-arrow-right-24: Graphics backends](how-it-works.md#graphics-from-directx-to-metal)

-   :material-console-line:{ .lg .middle } **CLI first**

    ---

    Every feature lands in the library and the `mallow` CLI before it gets a button in the app. It has JSON output and stable exit codes, so you can use it in scripts.

    [:octicons-arrow-right-24: Architecture tour](contributing/architecture-tour.md)

-   :material-hand-heart-outline:{ .lg .middle } **Upstream first**

    ---

    Fixes go back to Wine, DXMT, MoltenVK and winetricks wherever possible. Every release will list its upstream contributions.

    [:octicons-arrow-right-24: Contributing](contributing/index.md)

</div>

## Where things stand

| | |
|---|---|
| **Status** | Pre-alpha. The design is written; code has not started. |
| **Next step** | Gate G0: name clearance, licence files, governance. Then v0.1 "Foundations", a CLI-only build for developers. |
| **First app for everyone** | Planned for v0.3 "Mac app". |
| **Platform** | Apple Silicon Macs with macOS 15 or later. Intel Macs are not supported. |

The [roadmap](roadmap.md) has the details, and the [design document](DESIGN.md) explains every decision behind them.

## Get involved

Mallow is at the stage where reading and questioning the design is the most useful thing anyone can do. Start with the [architecture tour](contributing/architecture-tour.md), then read the [contributing guide](contributing/index.md). Contributions use a [DCO](https://developercertificate.org/) sign-off (`git commit -s`).

## Standing on the shoulders of others

Mallow would not be possible without the [Wine](https://www.winehq.org/) project and its contributors. CodeWeavers funds much of Wine's macOS work and publishes the LGPL sources our runtime is built from. [DXMT](https://github.com/3Shain/dxmt), [DXVK-macOS](https://github.com/Gcenx/DXVK-macOS), [MoltenVK](https://github.com/KhronosGroup/MoltenVK) and Gcenx's macOS Wine builds do much of the heavy lifting. Earlier frontends such as Whisky showed what a good Mac experience looks like. We learn from their ideas and write our own code.

Mallow is an independent project. It is not affiliated with or endorsed by CodeWeavers, Apple, Microsoft or Valve. "CrossOver" is a trademark of CodeWeavers, and we use it here only to describe what Mallow is an alternative to.
