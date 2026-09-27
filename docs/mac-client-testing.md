---
# SPDX-License-Identifier: 0BSD
title: Mac client testing
description: Run Mallow's local client checks, export privacy-minimized diagnostics, and debug an exact development build with matching symbols.
---

# First Mac client tests

This is the **client test-readiness** preview, not the first working Windows launcher. Use it to establish what works on your Mac without executing Wine or a Windows installer. [Issue #48](https://github.com/mixutin/Mallow/issues/48) tracks actual-Mac acceptance. Never substitute CI results for your observations.

## Choose the right build

Download assets from the **same** `dev-…` [release](https://github.com/mixutin/Mallow/releases). `Mallow-macos-arm64.zip` is the optimized app for normal testing. `Mallow-debug-macos-arm64.zip` is a separate unoptimized build for stepping through code. Both contain `Mallow.app`: use one at a time, and do not compare debug-build timings with release-build performance.

Each app has a matching `…-symbols.zip`. The build verifies that each dSYM's UUID matches its binary and that debug information is present. `Mallow-source.tar.gz` contains that exact tracked source; it includes no working-directory caches or Git credentials. `Mallow-test-kit.zip` contains a helper script and this guide. `build-info.json` and `debug-build-info.json` identify the source and configuration.

`SHA256SUMS` covers the apps, symbols, source, kit and metadata. After downloading all the listed assets, run `shasum -a 256 -c SHA256SUMS`. Missing assets produce missing-file warnings; to verify only the standard app, use `grep '  Mallow-macos-arm64.zip$' SHA256SUMS | shasum -a 256 -c -`.

These remain ad-hoc signed, not Developer ID signed or notarised. Follow the [per-app approval instructions](development-preview.md#download-and-verify). Never disable Gatekeeper or SIP, strip quarantine globally, or ignore a malware warning to make a test pass.

## Test from the app

Open Mallow and choose **Run client checks**. The loader represents actual work. The report distinguishes supported-host detection, Rosetta's marker, owned runtime metadata, Wine/GStreamer architecture headers, local self-tests and unimplemented launch/sandbox features. Missing dependencies must remain visible; a green self-test is not a Windows-readiness verdict.

The local self-tests check atomic JSON replacement, file-lock exclusion, a known SHA-256 vector and the download-host policy. They use only a small private temporary directory, clean it on normal completion/error/cancellation, never download files and never execute vendor binaries. An abrupt process kill can leave a small temporary directory.

Choose **Verify runtime** separately for the expensive full inventory/hash check. Then choose **Run client checks** again to include its timestamped counts and outcome in a fresh report. Setup or verification invalidates the previous client report. Ordinary startup still does not hash the runtime.

Choose **Export report…** to save a new JSON file or **Copy test report**. Exports refuse to overwrite an existing file. Review the report before attaching it to an issue. Nothing is uploaded automatically. Operation history is limited to the last 32 actions in this app session.

## Test from Terminal

The helper is inside the app; no Homebrew, Python or Xcode is needed for these client commands:

```sh
"/Applications/Mallow.app/Contents/Helpers/mallow" diagnostics --json
"/Applications/Mallow.app/Contents/Helpers/mallow" diagnostics --self-test --json --output "$HOME/Desktop/mallow-client-report.json"
"/Applications/Mallow.app/Contents/Helpers/mallow" runtime verify --json
```

The first command is read-only preflight. `--self-test` explicitly requests temporary test I/O. `--output` requires a new writable filename. Exit 0 means report capture/self-tests completed, **not** that dependencies or Windows launching are ready; inspect each check. Exit 2 is invalid usage, 3 is collection/export failure and 4 means at least one requested self-test did not pass. Cancellation is not a passing result.

Alternatively, unzip the test kit and run `Run-Mallow-Client-Checks.command`, passing an app path as its first argument when it is not in Applications. It verifies the app signature, runs the local self-tests, saves results in a private temporary directory and opens that directory. It installs nothing. `report.json` is the shareable allowlisted report; review any extra local console/error text separately before sharing it.

## Debug an exact build

With Apple's Command Line Tools installed, unzip the debug app, its matching symbols and the source archive from the same release. Launch the app binary directly in LLDB:

```sh
xcrun lldb "/path/to/Mallow.app/Contents/MacOS/Mallow"
```

In LLDB, use `target symbols add /path/to/symbols/Mallow.dSYM`, set `settings set target.source-map /Users/runner/work/Mallow/Mallow /path/to/Mallow`, then `run`. On a failure, `thread backtrace all` records stacks. The CLI's symbols are `mallow.dSYM`. Symbol archives also record toolchain, build OS, source revision and UUIDs. Do not mix symbols from different builds. Raw debugger/crash output can contain personal paths or application data; inspect and redact it before posting. This preview does not automatically collect crash files or upload reports.

## What to record on your Mac

Record source revision, release/debug configuration, macOS version, Mac model/chip, the exact action, expected/actual result and screenshot or report. Test initial launch, existing-cache installation, offline reopen, explicit integrity verification, cancellation/retry, keyboard navigation, VoiceOver and Reduce Motion. Leave a test pending until you perform it.

Reports measure collection time, recent action durations and the **current process's lifetime peak resident memory**. They do not measure time to the first rendered window, GPU memory, child processes, frame times or FPS. Capture both cold/warm observations with the same optimized build before claiming an improvement. CPU count and RAM capacity are included; serial numbers, usernames, home paths, environment variables, raw logs, game lists, bottle contents and proprietary payloads are excluded.

## Implementation contract

`Diagnostics/ClientDiagnostics.swift`, `ClientSelfTests.swift` and `Support/MachOHeader.swift` are staged APIs for the early client, not replacements for the full normative `Doctor` or bottle `DiagnosticsBundle`. The report has `schemaVersion: 1`, UTC whole-second dates and explicit false Windows/sandbox flags. No persisted bottle/runtime format changes. The header parser reads at most 4 KiB and accepts at most 64 universal-header entries; it reports declared CPU types only, not loadability, signatures, slice integrity or graphics capabilities. The GStreamer check examines the expected framework library, not arbitrary user paths.

Failure summaries are fixed strings, not raw exceptions. Report exports are capped at 256 KiB, use exclusive creation and mode 0600, and never follow an existing symlink. Runtime-file integrity details are reduced to counts in the shareable report. Full authenticated catalogs, dependency installation, repair, bottles, fake-wine, the complete launch planner and the kernel sandbox remain on the [roadmap](roadmap.md).
