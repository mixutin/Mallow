---
# SPDX-License-Identifier: 0BSD
title: Development previews
description: Download the Mac setup preview, verify its build and checksum, test first-run dependency acquisition, and report what actually worked on your Mac.
---

# Development previews

These builds are for testing Mallow on an actual Mac before making product-compatibility claims. They expose what is implemented now, not a mock promise that every roadmap feature works.

!!! warning "Windows launching is not available"

    The app can inspect prerequisites, request Rosetta installation with your consent, and acquire a verified Wine archive. It does not extract or activate Wine, install GStreamer, create bottles, translate graphics or enforce a Windows-program sandbox. Do not use this preview to run suspicious executables; it has no Windows launch function.

## Download and verify

Open [GitHub Releases](https://github.com/mixutin/Mallow/releases), choose a development prerelease named `dev-<commit>`, and download **Mallow-macos-arm64.zip**, **SHA256SUMS** and optionally **build-info.json** from the same release. The source commit is also displayed in the app.

In the directory containing the ZIP and checksum file:

```sh
shasum -a 256 -c SHA256SUMS
```

The result should say `Mallow-macos-arm64.zip: OK`. A checksum helps detect corrupted or mismatched bytes; it is not proof that the software has been independently reviewed.

Unzip the archive and move `Mallow.app` to Applications. It requires an **Apple Silicon Mac with macOS 15 or later**. No Wine, Rosetta, Homebrew or Xcode is needed merely to open the native preview.

The app is **ad-hoc signed**, not signed with an Apple Developer ID and not notarised. A normal developer-identification warning may require approval for this specific app in **System Settings → Privacy & Security → Open Anyway**. Approve only a build you intentionally obtained from this repository after checking its source and checksum. Do not disable Gatekeeper globally. A damaged-app, malware or other unexpected warning is a test failure to investigate, not a reason to turn off system protections.

## How automatic builds work

The `Development app` workflow runs on pull requests and pushes to `main`. PRs produce artifacts for inspection. After its build, tests and bundle checks succeed on canonical `main`, the workflow publishes a commit-addressed prerelease with the ZIP, checksum and metadata. It does not overwrite an already published build of that commit. A failed build does not publish a new preview.

Development builds are not marked as the latest stable release. A green PR run is not proof that a main-branch release or the website has deployed; those outcomes are checked separately.

## First-run setup

Opening Mallow checks the OS, hardware and Rosetta marker and inspects any existing owned cache. **It does not start a download or accept licence terms.**

Review **Set up dependencies**. Wine acquisition is selected as a convenience, but its approval checkbox is unchecked. When Rosetta is missing, its installation can also be selected; Apple's licence requires a separate affirmative checkbox. Review the linked source/licence information and then choose **Set up selected dependencies**.

The operations are:

| Choice | What the preview does | What it does not do |
|---|---|---|
| Rosetta | Calls Apple's `softwareupdate` with the accepted licence; checks completion and its installed marker | Does not install Homebrew, a privileged helper or a Wine runtime |
| Wine 11.0_1 | Downloads the pinned 185,303,032-byte archive, verifies SHA-256 and caches it | Does not unpack it, clear quarantine, activate it or execute any binary |
| GStreamer | Displays that this setup is pending | Does not install a system-wide package |
| D3DMetal | Nothing | Never downloads or bundles Apple's proprietary translator |

Watch the progress and status messages. After acquisition, the app says **Verified cache · not installed** and can reveal the archive in Finder. Subsequent checks rehash the cached archive; approval of another acquisition reuses verified content instead of downloading it again.

Cancellation cleans up the acquisition staging file. Cancelling an Apple installer invocation may not undo work already handed off to an OS service; use **Recheck** before drawing conclusions. Failed operations display an error, not “ready to run.” A retry is a fresh attempt, not resumable partial-download support.

## Test on your Mac

Report against the exact source revision shown in the app or `build-info.json`. Do not install Rosetta again solely to test this flow when it is already installed, and do not remove OS components for a test.

| Check | Expected behavior | Actual Mac result |
|---|---|---|
| First launch | A readable native window appears; no automatic dependency download or licence acceptance | Pending tester report |
| Host inspection | OS and Apple Silicon status match the machine | Pending tester report |
| Existing Rosetta | “Detected” appears and installation is skipped | Pending tester report |
| Consent gate | Setup cannot proceed for a selected operation without its relevant approval | Pending tester report |
| Wine acquisition | Progress is visible; completion says verified cache, not installed runtime | Pending tester report |
| Cancel and retry | Cancellation/error is shown; another approved attempt can proceed | Pending tester report |
| Reopen with cached archive | Cache is verified again and can be reused without a new download | Pending tester report |
| Offline launch | The window/status check still opens; a required uncached download fails visibly rather than claiming success | Pending tester report |
| Copy test report | Report contains build revision and prerequisite state, not personal document contents | Pending tester report |
| Windows readiness | Remains false; no game or `.exe` launch is offered | Pending tester report |

Use **Copy test report** and add the results to [issue #42](https://github.com/mixutin/Mallow/issues/42). Include Mac model/chip, macOS version, source revision, the precise action, expected/actual outcome and any visible error. Redact usernames, paths, tokens and other private information from screenshots or logs. Report possible security vulnerabilities privately via [SECURITY.md](https://github.com/mixutin/Mallow/blob/main/SECURITY.md).

## What CI has established

The initial preview revision passed 37 tests in four suites on an Apple Silicon runner using macOS 26.6.2 and Swift 6.3.3. Release builds, arm64 architecture, bundled notices, ad-hoc signature verification, the non-GUI app entry point and the CLI status command passed. [Initial workflow evidence](https://github.com/mixutin/Mallow/actions/runs/36257897523).

The download tests use injected transports; Rosetta tests check consent/argument behavior. The app smoke entry exits before opening a window. Thus actual networking, Apple installation, GUI behavior, accessibility, the full OS matrix and Windows/game compatibility remain separate tests. No results in the table above are pre-filled from CI.

## Cache and removal

The preview cache is `~/Library/Caches/io.github.mixutin.Mallow.setup`, separate from the future bottle/application data directory. It contains a marker, lock and any verified runtime archive. There is no automatic deletion of foreign directories. Move the preview app to Trash to remove the app; its downloaded archive remains in the cache until you remove it. Do not treat the cache as an installed runtime or manually merge it into unrelated Wine installations.

## Next step toward Windows execution

The [roadmap](roadmap.md) still requires safe runtime activation and dependency installation, complete models/stores, bottle creation, launch planning and a tested kernel sandbox. A future preview will expose each new capability with its own test checklist rather than silently enabling unfinished behavior.
