---
# SPDX-License-Identifier: 0BSD
title: Development previews
description: Download the pink Mac preview, install and verify Wine, measure setup behavior and report real-Mac evidence separately from CI.
---

# Development previews

Development builds expose implemented capabilities for actual-Mac testing. [Suomenkielinen testausohje](https://mixutin.github.io/Mallow/fi/development-preview/).

!!! warning "Windows launching remains unavailable"

    The app installs and verifies the pinned Wine runtime. It does not install GStreamer, create bottles, configure graphics or enforce a Windows-process sandbox. No Wine or Windows program is executed by setup. This is not yet a game launcher or malware sandbox.

## Download and verify

Open [GitHub Releases](https://github.com/mixutin/Mallow/releases) and choose a `dev-<commit>` prerelease. Download **Mallow-macos-arm64.zip**, **SHA256SUMS** and optionally **build-info.json** from that same release. In their directory:

```sh
grep '  Mallow-macos-arm64.zip$' SHA256SUMS | shasum -a 256 -c -
```

The result should be `Mallow-macos-arm64.zip: OK`. A checksum detects corrupted/mismatched bytes; it is not proof of an independent audit.

Unzip and move `Mallow.app` to Applications. It requires Apple Silicon and macOS 15 or later. The native app itself does not require Rosetta or Wine to open. The bundle is ad-hoc signed, not Developer ID signed or notarised. A normal developer-identification warning may require approving this specific app under **System Settings → Privacy & Security**. Do not disable Gatekeeper globally. An unexpected malware/damaged-app warning needs investigation, not a bypass.

## How automatic builds work

PR workflows build/test and upload artifacts, with no release-write access. Successful canonical-main workflows publish new source-addressed prereleases with checksums and build metadata. The pipeline checks the package, generated icon/bundle, binary startup and real pinned-runtime installation/integrity. It never executes Wine in that integration test. Published previews are not overwritten; an unsuccessful job cannot publish a fresh preview.

A green PR build does not prove that main publication or Pages deployment succeeded. Check those outcomes separately. Development builds are not marked as the latest stable release.

## First-run setup

Opening the app checks metadata, not every archive/runtime hash, and does not download or accept licences. Choose **Install Wine 11.0_1**, review its source/licence and approve installation. Rosetta, when missing, requires separate Apple-licence approval. Press **Install selected dependencies**.

| Stage | What happens |
|---|---|
| Acquire | Rehash/reuse the previous preview's cache or fetch the fixed approximately 185 MB archive over approved HTTPS hosts |
| Verify | Check the private snapshot's exact size and compiled-in SHA-256 |
| Extract | Unpack only supported entries within path, link, entry-count and expanded-size limits |
| Register | Check the bundle/entry points, record file hashes and move the completed tree to the runtime directory |
| Reopen | Lightweight receipt/layout check; no automatic full hash or new download |
| Verify runtime | Explicit, cancellable comparison of installed files against the local receipt |

Allow at least 2 GB of free space. The spinner names the current work; byte progress is shown only where meaningful. It pauses for reduced motion/inactive scenes. No artificial delay is added.

An already installed runtime is verified rather than downloaded again on an explicit repeat setup. Corrupt installations are preserved and rejected. Automatic repair/removal/rollback and GStreamer setup remain future work. D3DMetal is never downloaded or bundled.

Cancellation cleans ordinary in-progress staging; an abruptly terminated process can leave staging for later recovery work. Cancelling Apple's installer invocation may not undo OS-service work already started. Recheck status after cancellation. A registered runtime is not removed if cancellation arrives after its final publication.

## Test on your Mac

The previous preview's owner reported successful Wine archive acquisition and SHA-256 verification. That is not a test of the new installation flow. All rows below remain pending for the new revision until actual tester results are supplied.

| Check | Expected behavior | Actual result |
|---|---|---|
| Window and icon | Dark-pink window, readable text and the original flower icon | Pending |
| Prerequisites | Host/Rosetta state matches the Mac; no automatic effects | Pending |
| Consent | Selected actions require their relevant affirmative approval | Pending |
| Cached installation | Existing archive is checked/reused, extracted and registered | Pending |
| Fresh installation | Download and installation succeed with real network/disk conditions | Pending |
| Integrity | Verify runtime reports no problems, with file/byte/time totals | Pending |
| Responsiveness | Window/scrolling remain responsive during hashing and extraction | Pending |
| Cancel/retry | Clear result, no half-installed active tree, retry possible | Pending |
| Reopen offline | Metadata status loads without full rehash or forced download | Pending |
| Accessibility | Keyboard/VoiceOver labels usable; Reduce Motion stops rotation | Pending |
| Performance | Record cold/warm startup, verification time and peak memory with Mac details | Pending |
| Readiness | Windows launching remains disabled and is not claimed | Pending |

Use **Copy test report** and [issue #44](https://github.com/mixutin/Mallow/issues/44). Include Mac model/chip, OS, source revision, action and actual result. The report includes prerequisite and integrity data, not your home path. Redact private data from screenshots. Do not remove Rosetta or damage your real runtime for testing; negative integration checks use disposable data roots. Security reports go privately through [SECURITY.md](https://github.com/mixutin/Mallow/blob/main/SECURITY.md).

## What CI has established

The implementation at `97219c95e899` passed the macOS package/test, app/icon/bundle and real-archive integration workflow: [run 36298503241](https://github.com/mixutin/Mallow/actions/runs/36298503241). The integration installed the pinned Wine archive, checked all recorded files, repeated setup and required failure after altering a runtime file. No Wine process was launched. Exact final-head results and publication are recorded in [PR #45](https://github.com/mixutin/Mallow/pull/45).

The new suite adds 12 functions to the initial 37 macOS tests. Synthetic tests cover consent, cancellation, ownership, corruption, traversal, duplicate names, special files and confined links. The application smoke entry exits before displaying a window, so GUI/accessibility, actual Apple installation and the broader supported-OS matrix remain separate. CI timings are not performance guarantees for a personal Mac.

## Paths and removal

The original cache remains `~/Library/Caches/io.github.mixutin.Mallow.setup`. The runtime lives at `~/Library/Application Support/Mallow/Runtimes/standard-wine-stable-11.0_1/`. The ownership marker prevents adopting unrelated directories. `MALLOW_HOME` sets an isolated absolute test root for the CLI.

Moving the app to Trash does not remove its cache/runtime. Do not manually merge the installed Wine tree into another product. Automatic runtime removal and repair are still planned. A local receipt is not a signed security boundary against malicious software already running as the same user.

## Next step toward Windows execution

The [roadmap](roadmap.md) now checks off pinned installation, ownership and integrity verification. It still requires complete models/stores, capability/dependency checks, bottle creation, process planning and a tested kernel sandbox before the Notepad milestone.


For the new **Run client checks** / **Export report…** actions, debug builds, matching symbols and test-kit instructions, read [Mac client testing](mac-client-testing.md). These are client tests, not Windows-compatibility tests.
