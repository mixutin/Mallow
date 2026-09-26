---
# SPDX-License-Identifier: 0BSD
date: 2026-09-26
authors:
  - mixutin
categories:
  - Project
  - Roadmap
slug: first-development-app
description: The first Mallow setup preview, automatic Mac development builds, and what still needs testing before Windows launching is enabled.
---

# A Mac app to test, before we claim the whole thing works

Mallow now has its first native setup preview. It follows the tested library foundation with a small SwiftUI app, a bootstrap CLI and automatic development-build packaging. It is a real test surface, but **not a Windows launcher yet**.

<!-- more -->

The repository owner asked for downloadable builds to test on an actual Mac, and for dependency setup to become part of first launch. The implementation is AI-assisted; its claims are limited to the code and tests that actually exist.

Opening the app checks prerequisites. After you review and approve the selected operations, it can request Rosetta installation through Apple's service and acquire the pinned Wine 11.0_1 archive with size and SHA-256 verification. The interface shows progress and cancellation, and can copy a report containing the source revision and prerequisite state.

**Acquiring the archive is not installing a runtime.** Extraction, activation, GStreamer setup, bottles, graphics and the kernel sandbox are still missing. Windows launching remains disabled. No proprietary Apple graphics payload is downloaded or bundled.

The initial app revision passed 37 tests on macOS Apple Silicon CI, along with release compilation, architecture/signature checks and executable startup. The startup smoke test does not open a window, and unit tests use injected downloads. GUI behavior, actual network setup and Apple installer behavior still need real-Mac reports. That distinction matters more than a green badge.

Successful main-branch app builds publish commit-addressed development prereleases with a ZIP, checksum and source metadata. These are ad-hoc signed, not notarised or stable releases. Start with the [development preview guide](../../development-preview.md) and record results against the exact build in [issue #42](https://github.com/mixutin/Mallow/issues/42).

The next work is in the [roadmap](../../roadmap.md): complete the shared models and safe stores, activate verified dependencies, then implement and test the secure bottle/launch pipeline. The early app is not a shortcut around those requirements. Documentation, changelog and website updates now accompany implementation work, and the site embeds the repository roadmap instead of maintaining a second copy.
