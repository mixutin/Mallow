---
# SPDX-License-Identifier: 0BSD
description: What the Mallow runtime-installation preview can do, how it is tested, and its security, performance and language limits.
---

# FAQ

Mallow installs a runtime but is not yet a complete Windows launcher. [Suomeksi](https://mixutin.github.io/Mallow/fi/faq/).

## The basics

### Can I use Mallow today?

You can test the native dark-pink setup app, approved Wine/Rosetta installation, runtime integrity checks and source-addressed releases. You cannot run Windows programs with this build. GStreamer, bottles, graphics configuration, capability probing and the kernel sandbox remain unfinished.

### Is Mallow free?

There is no paid edition. Mallow's own code/scripts/docs use [0BSD](legal.md); components retain their licences. The app bundles neither Wine nor games or proprietary Apple graphics binaries.

### Is Mallow CrossOver? Is it made by CodeWeavers?

No. It is independent, not affiliated with or endorsed by CodeWeavers. Implementations are written for this repository, not copied from CrossOver's proprietary files or GPL frontends. Prior-art ideas and upstream work are credited in NOTICE.

### Is Mallow an emulator? Do I need Windows?

The planned execution stack uses Wine's Windows APIs and Rosetta's instruction translation, not a full Windows virtual machine. [How it works](how-it-works.md) explains the plan. Installation alone does not complete that stack; individual programs/add-ons retain their own licence requirements.

### How fast will games run?

No game-performance claim is made. This slice reduces unnecessary startup hashing and bounds background file work; it does not launch games. Reproducible benchmarks must eventually record title, runtime/backend, Mac, OS and observed results.

## Compatibility

### Does it run games with anti-cheat?

This preview runs no Windows games. Anti-cheat bypasses are outside project scope, and compatibility is not promised by the long-term design.

### Will it run Steam?

Steam and dependency recipes remain later work. The current app does not download or run Steam.

### Does it work on Intel Macs?

The app targets Apple Silicon/macOS 15+. Linux library tests do not imply a supported Linux product or Intel Mac app.

### What happens when Apple removes Rosetta?

Future compatibility must follow Apple's actual commitments and the design's verification backlog. No current preview promises future macOS compatibility. Native-runtime research remains later work.

## Setup and testing

### Does opening the app automatically install everything?

No. It checks prerequisites first. After you review and approve selected actions, **Install selected dependencies** handles Wine acquisition, verification, unpacking and registration. Rosetta needs separate Apple-licence consent. GStreamer and Windows-launch prerequisites are still incomplete, so the app does not say the whole Windows environment is ready.

### Why did my previous build only download the archive?

PR #43 implemented acquisition only. The next preview in PR #45 adds installation and reuses that previous cache after checking it. Its normal status becomes **Installed** after a complete tree is registered. Choose **Verify runtime** for a fresh file-integrity check.

### Is an installed runtime automatically verified every time I open the app?

No. Startup checks metadata/layout to avoid unnecessary I/O. The explicit verifier reads files and compares sizes, hashes, executable bits and links with the installation receipt. Installed status is not a claim that a full hash ran just now.

### What happens if the verifier finds damage?

The error is reported and an explicit repeat setup refuses to silently overwrite that runtime. Existing data is preserved. Automatic repair/rollback remains future work. Report the result rather than treating it as success.

### Why does the spinner sometimes not appear?

Loaders show actual work, not a forced delay. The app mounts the animation only while busy and pauses it for reduced motion or inactivity. The website spinner never hides content; it clears on page readiness, back/forward navigation or timeout. Fast navigation may finish before you notice it.

### What does a green build prove?

Only the checks run: unit tests, compilation, icon/bundle/signature checks, executable startup and the separate real-archive installation/integrity test. That test does not execute Wine. The smoke entry exits before presenting a GUI. Actual Mac usability, accessibility, Apple installation and game compatibility remain separate.

### Why does macOS warn about the preview?

Bundles are ad-hoc signed, not Developer ID signed or notarised. Follow [the per-app guide](development-preview.md#download-and-verify), not global Gatekeeper disabling. Unexpected malware/damaged-app warnings need investigation.

## Security

### Is it safe to run Windows programs with Mallow?

No Windows launch feature exists yet. The planned kernel boundary is not implemented or validated. Wine itself is not a sandbox; `SandboxSettings` is only configuration. Read the [security model](SECURITY_MODEL.md) and [installer boundary](runtime-installation.md).

### What protects installation?

Compiled-in HTTPS source/size/hash, private staging, bounded entry validation, confined links, an ownership-marked data root and held advisory locks. No archive executable is run, and no system-wide Gatekeeper setting changes. The local receipt detects corruption but is not a tamper-proof signature against a process able to change both it and the files.

### How do I report a security problem?

Privately through [SECURITY.md](https://github.com/mixutin/Mallow/blob/main/SECURITY.md), not a public issue or test report.

### Does Mallow collect telemetry?

No collection is implemented. Copy test report uses the clipboard only when requested; you choose whether to share it. No website analytics/loader service was introduced.

## Languages and licensing

### Is there a Finnish version?

The principal [user website](https://mixutin.github.io/Mallow/fi/) is Finnish, including setup, testing, roadmap, security and FAQ. Navigation/search are localized. The app, long technical documents and historical devlogs remain English; full app localization is not checked off.

### Why 0BSD?

It is the owner's licence choice for Mallow's implementation. External components keep their terms; see [Legal & licensing](legal.md) and [the dated 0BSD post](blog/posts/02-why-mallow-is-0bsd.md).

### Why not just use Whisky?

Mallow is a separate design, not a fork or a mature compatibility replacement yet. Ideas may be credited, but GPL frontend code is not copied into the 0BSD codebase.

### Will you ship D3DMetal?

No. It is never downloaded or bundled. User-supplied GPTK import after reviewing Apple's terms is still planned.

### Why is it called Mallow?

See the [naming history](blog/posts/04-from-decanter-to-mallow.md). The formal review remains open; a development build is not trademark clearance.

## Getting involved

### How can I help?

Use the [actual-Mac checklist](development-preview.md), implement a WF0 task, measure performance, test error handling or improve both language versions. Read [Contributing](contributing/index.md). Keep implementation progress, CI and personal-device evidence distinct.

### Where do I ask questions?

[Discussions](https://github.com/mixutin/Mallow/discussions) or a specific issue. New preview results are tracked in [#44](https://github.com/mixutin/Mallow/issues/44).
