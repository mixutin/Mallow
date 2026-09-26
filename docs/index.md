---
# SPDX-License-Identifier: 0BSD
title: Home
description: Mallow development previews for Apple Silicon. Test native onboarding and verified dependency acquisition; Windows launching is not implemented yet.
hide:
  - navigation
  - toc
---

<div class="mallow-hero" markdown>

![](assets/favicon.svg){ .mallow-hero__icon }

<span class="mallow-status">Pre-alpha · development setup preview</span>

# Mallow

<p class="mallow-hero__tagline">
Building an open-source way to run Windows games and apps on your Apple Silicon Mac.
</p>

[Get a development build](development-preview.md){ .md-button .md-button--primary }
[Follow the roadmap](roadmap.md){ .md-button }
[Read the devlog](blog/index.md){ .md-button }

</div>

!!! warning "A testable setup app, not a Windows launcher yet"

    Mallow has a native onboarding app, a bootstrap CLI and library foundations. You can test prerequisite checks and consent-gated dependency acquisition. **Wine activation, bottles, graphics translation and the kernel sandbox are not implemented. This build cannot run Windows programs.**

## What you can test now

<div class="grid cards" markdown>

-   :material-apple:{ .lg .middle } **Native onboarding**

    ---

    Inspect your Mac and Rosetta status, review setup choices, watch progress, cancel an operation and copy a build-specific test report.

    [:octicons-arrow-right-24: Mac testing checklist](development-preview.md#test-on-your-mac)

-   :material-download:{ .lg .middle } **Verified acquisition**

    ---

    After approval, acquire the pinned Wine archive over HTTPS and verify its size and SHA-256. Request Rosetta through Apple's installer only after accepting its licence. A cached archive is not an installed runtime.

    [:octicons-arrow-right-24: First-run setup](development-preview.md#first-run-setup)

-   :material-source-branch:{ .lg .middle } **Commit-addressed builds**

    ---

    Successful main-branch app workflows publish development prereleases with the source revision, app ZIP and checksum. PR artifacts are separate and cannot publish releases.

    [:octicons-arrow-right-24: Development releases](https://github.com/mixutin/Mallow/releases)

-   :material-console-line:{ .lg .middle } **Shared library and CLI**

    ---

    The app and limited `doctor`/`setup` CLI use the same setup service. Wire-format and persistence tests form the starting point for future bottle and runtime work.

    [:octicons-arrow-right-24: Build from source](contributing/dev-setup.md)

</div>

## What the checks mean

The initial app revision passed 37 unit tests, release compilation, bundle checks and executable startup on macOS Apple Silicon CI. **Those are not graphical usability or game-compatibility tests.** Real-Mac GUI, network and Apple-installer results are recorded separately against the build revision in [issue #42](https://github.com/mixutin/Mallow/issues/42). Use the [preview guide](development-preview.md) before testing.

The development app is ad-hoc signed, not Developer ID signed or notarised. It is intended for testing and does not claim production readiness.

## What Mallow will become

The [design](DESIGN.md) describes bottles, a verified open Wine runtime, per-program graphics choices, explicit file sharing and a kernel sandbox around Windows programs. The full app and CLI will share MallowKit. [How it works](how-it-works.md) explains the intended stack; the [security model](SECURITY_MODEL.md) explains the intended boundary and limitations.

The early preview does not waive those requirements. See the [bootstrap addendum](BOOTSTRAP.md) for what was brought forward for testing and the [roadmap](roadmap.md) for what remains.

## Get involved

Test the development build on your Mac, finish a shared-model task, improve the docs or verify a design assumption. Read the [contributor guide](contributing/index.md). Every implementation change includes documentation and roadmap review, so this site should describe the code that actually exists.

Mallow's own code, scripts and docs are 0BSD. The planned Wine runtime and other components keep their own licences. See [Legal & licensing](legal.md), [NOTICE](https://github.com/mixutin/Mallow/blob/main/NOTICE) and the [security reporting instructions](https://github.com/mixutin/Mallow/blob/main/SECURITY.md).

Mallow is independent and is not affiliated with or endorsed by CodeWeavers, Apple, Microsoft, Valve or the Wine project. Names are used descriptively; trademarks remain with their owners.
