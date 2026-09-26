---
# SPDX-License-Identifier: 0BSD
description: What the Mallow setup preview can do, what remains planned, how builds are tested, and the project's security and licensing limits.
---

# FAQ

Mallow is a development setup preview, not a complete Windows launcher. See the [roadmap](roadmap.md), [bootstrap addendum](BOOTSTRAP.md) and [Mac test guide](development-preview.md) for current evidence and limits.

## The basics

### Can I use Mallow today?

You can test its native setup app, prerequisite checks and approved dependency acquisition through [development prereleases](https://github.com/mixutin/Mallow/releases). You cannot run Windows programs with this build. Runtime activation, GStreamer setup, bottles, graphics and the sandbox remain unimplemented.

### Is Mallow free?

The project has no paid edition. Mallow's own code, scripts and docs use [0BSD](legal.md). Planned external components keep their licences. The preview bundles neither a Wine runtime nor games or proprietary Apple graphics binaries.

### Is Mallow CrossOver? Is it made by CodeWeavers?

No. It is an independent project, not affiliated with or endorsed by CodeWeavers. The design uses openly licensed Wine sources and acknowledges upstream contributors. It does not copy proprietary content from CrossOver.app or claim support from another project's maintainers.

### Is Mallow an emulator? Do I need a copy of Windows?

The intended design uses Wine's Windows API implementation and Rosetta's instruction translation, not a full Windows virtual machine. See [How it works](how-it-works.md). That execution stack is not activated by the current preview. Individual programs and add-ons retain their own licence requirements.

### How fast will games run?

No game performance is claimed. CI compilation and a launchable onboarding window do not establish that a game works. The design's eventual compatibility results must record title, runtime, backend, Mac and observed outcome.

## Compatibility

### Does it run games with anti-cheat?

This preview runs no Windows games. Anti-cheat bypasses are outside the project scope; the full design does not promise anti-cheat compatibility.

### Will it run Steam?

Steam and dependency recipes remain a planned later milestone. The current app downloads no Steam installer and cannot run it.

### Does it work on Intel Macs?

The native app target is Apple Silicon with macOS 15 or later. Intel Mac support is not part of the v1 plan. Linux compilation of portable test code does not add another supported product host.

### What happens when Apple removes Rosetta?

The long-term design must track Apple's actual compatibility commitments. Native runtime research remains future work. No current development build guarantees operation on a future macOS release; review the design's assumptions and verification backlog before making that claim.

## Setup and testing

### Does it download dependencies automatically when I open it?

No download or licence acceptance happens just from opening the app. After you review the selected operations, approve their terms and press **Set up selected dependencies**, the app handles acquisition and verification. Rosetta requires separate Apple-licence consent. This avoids treating a first launch as permission to install software.

### Why does Wine say downloaded but not installed?

The preview acquires a pinned archive and verifies its size/SHA-256. Extraction, activation, GStreamer installation and capability probing are separate work. The app intentionally does not call a cached file a working runtime.

### What does a green build prove?

It establishes the checks actually run: unit tests, compilation, bundle/architecture/signature checks and non-GUI executable startup. The app smoke test exits before showing a window. It does not prove GUI usability, real downloads, Apple installer behavior or game compatibility. Record actual-Mac results with the source revision using the [preview checklist](development-preview.md).

### Why does macOS warn about the preview?

Development bundles are ad-hoc signed, not Developer ID signed or notarised. Follow the per-app instructions in the [test guide](development-preview.md#download-and-verify). Never disable Gatekeeper globally or ignore an unexpected malware/damaged-app warning.

## Security

### Is it safe to run Windows programs with Mallow?

There is no Windows launch feature in this preview. Do not treat it as a malware sandbox. The full product is intended to enforce a kernel boundary, but that integration and validation are not implemented. `SandboxSettings` is a configuration type, not a protection.

Wine itself is not a sandbox. The intended protections and residual risks are described in [SECURITY_MODEL.md](SECURITY_MODEL.md). No software checksum or green CI badge turns an untrusted program into a safe one.

### Are Mallow's downloads safe?

The implemented acquisition checks approved HTTPS hosts, response/size and a compiled-in SHA-256 pin before using the final cache filename. It does not execute the archive. This is an integrity control, not a malware verdict or independent audit. Signed catalogs and complete verified installation are planned later.

### How do I report a security problem?

Privately through [SECURITY.md](https://github.com/mixutin/Mallow/blob/main/SECURITY.md), not in a public issue or test report.

### Does Mallow collect telemetry?

No telemetry collection is implemented. The copyable test report is placed on your clipboard only when requested; you decide whether to share it. The longer-term policy remains part of the design process.

## Licensing and D3DMetal

### Why 0BSD?

It is the owner's licence choice for Mallow's own implementation, allowing reuse without an attribution requirement. External components retain their own terms. Read [Legal & licensing](legal.md) and the dated [0BSD devlog](blog/posts/02-why-mallow-is-0bsd.md).

### Why not just use Whisky?

Mallow is a separate design, not a fork. Its implementations are written for this repository; GPL frontend code and proprietary CrossOver files are not copied into the 0BSD frontend. Prior-art ideas are credited in NOTICE. This preview is not a replacement for a mature compatibility product yet.

### Will you ship D3DMetal?

No. It is never downloaded or bundled by Mallow. The eventual design calls for users to import their own copy after reviewing Apple's terms. That import workflow is not implemented in this preview.

### Why is it called Mallow?

The naming history is in the [dated naming post](blog/posts/04-from-decanter-to-mallow.md). The formal naming review remains open; a development build does not certify trademark clearance.

## Getting involved

### How can I help?

Test the preview on your Mac and record the exact source revision and behavior, complete a WF0 task, review an assumption or improve the docs. Start with [Contributing](contributing/index.md). Keep build evidence separate from actual runtime or game results.

### Where do I ask questions?

Use [Discussions](https://github.com/mixutin/Mallow/discussions) or a specific [issue](https://github.com/mixutin/Mallow/issues). Preview testing is tracked in [#42](https://github.com/mixutin/Mallow/issues/42).
