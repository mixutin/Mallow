---
# SPDX-License-Identifier: 0BSD
date: 2026-09-27
authors:
  - mixutin
categories:
  - Project
slug: runtime-installation-and-finnish
description: Wine installation and integrity checks, a pink native app, Finnish user docs, and concrete performance/security requirements.
---

# From a verified download to an installed runtime

The first Mac preview downloaded Wine and checked its hash. The next step now unpacks and registers it, adds a full integrity check, and gives setup the site's flower branding and a dark-pink interface.

<!-- more -->

The owner reported successful archive acquisition in the previous build. This release addresses the next missing operation: install the checked bytes into a private, owned runtime directory. Setup preserves Wine's bundle layout and does not publish a partial tree. The verification command finds missing, changed and unexpected files. It does not pretend the local receipt is a signed trust root.

The macOS tests caught two issues before publication: missing libarchive headers in the SDK and a Foundation path-normalization difference affecting receipts. Both were fixed rather than skipped. The implementation passed [the real pinned-archive integration workflow](https://github.com/mixutin/Mallow/actions/runs/36298503241), including repeated installation and altered-file rejection. No Wine program was executed by that test.

Performance is now explicit in the roadmap: startup uses metadata, expensive work runs outside the UI's main actor, buffers are bounded, and progress updates are throttled. The loaders show real work and honor reduced motion; they never add a fake delay. These are implementation decisions, not claimed FPS or universal startup benchmarks.

The main user website is also available in Finnish, with localized navigation/search. Both language trees share one deployment. Full technical documents, app strings and old blog posts are still English.

There is still no Windows launch button. GStreamer, capability checks, bottle creation and the kernel sandbox must come together before the first Notepad milestone. The roadmap now checks off installation and integrity work while keeping those remaining steps and personal-Mac acceptance visible.

[Test the preview](../../development-preview.md), read [the installation design](../../runtime-installation.md), or use [the Finnish site](https://mixutin.github.io/Mallow/fi/). Exact final build/publication outcomes are recorded in [PR #45](https://github.com/mixutin/Mallow/pull/45).
