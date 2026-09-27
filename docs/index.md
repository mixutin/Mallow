---
# SPDX-License-Identifier: 0BSD
title: Home
description: Mallow development previews for Apple Silicon. Install and verify Wine through a native dark-pink setup app; Windows launching remains in development.
hide:
  - navigation
  - toc
---

<div class="mallow-hero" markdown>

![](assets/favicon.svg){ .mallow-hero__icon }

<span class="mallow-status">Pre-alpha · runtime installation preview</span>

# Mallow

<p class="mallow-hero__tagline">Building an open-source way to run Windows games and apps on your Apple Silicon Mac.</p>

[Get a development build](development-preview.md){ .md-button .md-button--primary }
[Follow the roadmap](roadmap.md){ .md-button }
[Suomeksi](https://mixutin.github.io/Mallow/fi/){ .md-button }

</div>

!!! warning "Wine installation is here; Windows launching is not"

    The native app now verifies, unpacks and registers the pinned Wine runtime, and checks installed-file integrity. Bottles, graphics setup, GStreamer installation and the kernel sandbox are still unfinished. **This build cannot run Windows programs.**

## What you can test now

<div class="grid cards" markdown>

-   :material-flower:{ .lg .middle } **A native pink setup app**

    ---

    Dark-pink styling, the website's flower logo, a matching app icon and real-work loading indicators. Setup asks permission first and supports reduced motion.

    [:octicons-arrow-right-24: Mac test checklist](development-preview.md#test-on-your-mac)

-   :material-download:{ .lg .middle } **Install, not just download**

    ---

    Reuse a checked cache, verify a private archive snapshot, unpack a bounded tree and register the complete Wine bundle. Rosetta uses Apple's installer after separate consent.

    [:octicons-arrow-right-24: First-run setup](development-preview.md#first-run-setup)

-   :material-shield-check:{ .lg .middle } **Verify installed files**

    ---

    Check for missing, changed and unexpected files from the app or CLI. Ordinary startup stays metadata-only; a local receipt is not a signed trust root or sandbox.

    [:octicons-arrow-right-24: Installation and integrity](runtime-installation.md)

-   :material-source-branch:{ .lg .middle } **Testable development builds**

    ---

    Mac CI tests the package, bundle and real pinned-archive installation. Successful main workflows publish source-addressed ZIPs and checksums, not untested game claims.

    [:octicons-arrow-right-24: Releases](https://github.com/mixutin/Mallow/releases)

</div>

## Performance and security, together

Hashing and extraction stream through bounded buffers outside the UI's main actor. Progress updates are throttled, and loaders never add fake delays. Input validation, consent, ownership checks and safe installation remain required even when optimizing performance. Startup/RSS and game benchmarks must be measured before claims are made; the [roadmap](roadmap.md#performance-and-security-acceptance-track) makes these acceptance criteria explicit.

## What the checks mean

The installation revision passed the full macOS test/build workflow, including the real pinned-archive installation and altered-file detection, in [this CI run](https://github.com/mixutin/Mallow/actions/runs/36298503241). That check does not execute Wine. Actual-Mac UI, installer behavior, accessibility and performance remain separately tracked in [issue #44](https://github.com/mixutin/Mallow/issues/44). The owner has reported successful archive acquisition/checksum in the previous preview, not a Windows execution result.

These development apps are ad-hoc signed, not Developer ID signed or notarised. Follow the [preview guide](development-preview.md) and keep build success distinct from personal-Mac and game tests.

## What Mallow will become

The [design](DESIGN.md) describes secure bottles, an open Wine runtime, graphics choices, explicit sharing and kernel isolation. The app and CLI share MallowKit. [How it works](how-it-works.md), the [security model](SECURITY_MODEL.md) and the [staging addendum](BOOTSTRAP.md) distinguish that plan from current capabilities.

## Get involved

Test a preview, complete a shared-model task, verify a design assumption or improve the docs. Read the [contributor guide](contributing/index.md). The main user pages are now also [Finnish](https://mixutin.github.io/Mallow/fi/); the app, full design and historical devlogs remain English. Both languages deploy together, and each change reviews the roadmap and affected pages.

Mallow's own code and docs are 0BSD. Components retain their own licences. See [Legal & licensing](legal.md), [NOTICE](https://github.com/mixutin/Mallow/blob/main/NOTICE) and [security reporting](https://github.com/mixutin/Mallow/blob/main/SECURITY.md). Mallow is independent and not affiliated with CodeWeavers, Apple, Microsoft, Valve or Wine. Trademarks remain with their owners.


**New: [Mac client checks and debugging](mac-client-testing.md).** Run local self-tests, inspect missing prerequisites, export a privacy-minimized report and use the matching debug build/symbols. Windows launching remains unavailable.
