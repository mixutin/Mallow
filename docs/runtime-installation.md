---
# SPDX-License-Identifier: 0BSD
title: Runtime installation design
description: The pinned Wine installer's trust boundary, staged APIs, integrity receipt, performance decisions and test limits.
---

# Runtime installation design

**Staged implementation, 27 September 2026, owner-requested in [#44](https://github.com/mixutin/Mallow/issues/44), implemented by [PR #45](https://github.com/mixutin/Mallow/pull/45).** This extends the [bootstrap addendum](BOOTSTRAP.md). It implements installation of the one compiled Wine pin, not the full runtime manager, generic import, bottle creator or launch service from [DESIGN.md](DESIGN.md).

## Trust boundary and flow

The user approves runtime acquisition/installation; Apple licence consent remains separate. Setup reuses a cached archive only after checking its size and SHA-256. The installer takes a private snapshot of that archive, verifies the compiled pin again, and extracts only those checked bytes. It does not run Wine, invoke a downloaded shell script or require Homebrew.

A new owned application root contains `.mallow-root.json`, with bootstrap schema `io.github.mixutin.Mallow.root.v1`, creation date and creator. Existing roots must be ordinary, owned directories with the recognized marker; unmarked or symlink roots are not adopted. `Runtimes/.lock` stays held throughout installation/verification, including asynchronous work.

A private same-volume `.install-<uuid>/` holds the source snapshot and output tree. Extraction completes before the expected Wine entry points are checked and the file inventory is written. Only then is the complete payload moved to `Runtimes/standard-wine-stable-11.0_1/`. Error/cancellation cleanup removes the current staging directory, not an existing runtime. Abrupt process termination can leave staging behind; automatic stale-staging recovery remains future work.

An existing installation is fully verified when setup is explicitly repeated. A damaged installation is preserved and rejected, not overwritten. Repair, rollback and removal remain unimplemented. No installed state is treated as permission to launch Windows software.

## Archive policy

The OS libarchive reader decodes tar with built-in none/xz/gzip filters. Mallow performs file writes itself instead of trusting archive-supplied extraction metadata. Entry paths must be relative, contain no traversal/control characters or backslashes, and fit length limits. Duplicate normalized/case-insensitive paths, special files and setid/sticky modes are rejected. Maximums are 100,000 entries and 4 GiB expanded regular-file data.

Regular files are created exclusively without following a destination symlink. Directories and files are materialized first; hardlinks may target only known regular archive files, and symlinks are created last. All links must then resolve to existing paths within the installation tree. Archive owner IDs, ACLs and xattrs are not restored. This avoids importing untrusted metadata; it is not a generic archive extraction service.

The expected `Wine Stable.app/Contents/Resources/wine/bin/wine` and `wineserver` paths must resolve inside the tree to executable regular files. The upstream bundle stays in place. Path checks reject known Apple translation/CrossOver bundle names, but these checks do **not** claim to implement the future general-purpose provenance/signature scanner. The only accepted source bytes are the compiled pin.

The bridge uses public libarchive 3 declarations and links the operating system library. The tested macOS SDK omitted the headers, so the small bridge declares just the needed API; Linux additionally uses its system headers. No upstream library implementation is vendored. API references: [Apple's published archive headers](https://github.com/apple-oss-distributions/libarchive/tree/main/libarchive/libarchive) and [upstream reader documentation](https://github.com/libarchive/libarchive/blob/master/libarchive/archive_read.3). System-library compatibility is checked by the actual macOS build, not assumed from Linux compilation.

## Receipt and verification

`.mallow-install.json` is a bootstrap receipt with `schemaVersion: 1`, runtime ID, compiled archive SHA-256, installed time and a sorted inventory. Records distinguish directories, files (size/hash/executable bit) and symlinks (target). It is not the future signed runtime `manifest.json` format and must not be passed off as one. Unknown schema versions are refused without rewriting the receipt.

Full verification checks the inventory and reports missing, changed and unexpected paths, checked bytes/files and elapsed time. The receipt is a local corruption baseline: someone already able to modify both receipt and runtime under the same user can defeat it. It is not an authenticated catalog, antivirus scan or kernel sandbox.

## Performance contract

Startup uses bounded receipt/layout metadata checks; it never silently hashes all installed files. `runtimeArchiveCached` means a size-matching ordinary cached file is present, while `runtimeArchiveVerified` is true only when explicitly checked in that report. `runtimeActivated` means registered installation, not a fresh full integrity check. `readyToRunWindows` and `sandboxImplemented` remain false.

Hashing/extraction use 1 MiB buffers outside the UI's main actor. Download progress is capped near ten UI updates per second while all size/redirect checks still run. Expensive verification is explicit and cancellable between work units. The UI shows an indeterminate loader for phases without a meaningful byte total instead of pretending to know a percentage. The loader is mounted only while busy and pauses for Reduce Motion/inactive scenes.

Measurements of startup latency, RSS, throughput and UI responsiveness on end-user Macs remain to be collected. No game-FPS claim is made. A completed-tree rename prevents ordinary observers from seeing a half-installed tree; full power-loss durability is not established, and per-file fsync is not used as an unmeasured performance penalty.

## Staged file ownership and APIs

| Path | Responsibility |
|---|---|
| `Sources/CArchive/` | Public system-library ABI bridge, no copied archive implementation |
| `Support/ArchiveExtractor.swift` | Bounded parsing and confined extraction |
| `Support/MallowPaths.swift` | Bootstrap root ownership and runtime paths |
| `Runtime/StandardWineInstaller.swift` | Pinned install, receipt, metadata status and full integrity verification |
| `Operations/SetupService.swift` | Acquisition/installation orchestration shared by app and CLI |
| `Support/SetupPlan.swift`, `VerifiedDownload.swift` | Distinct state/progress values and throttled download notifications |
| `MallowApp/Views/MallowBrand.swift` | Original site flower geometry, palette and reduced-motion loader |
| `scripts/make-icns.swift` | AppKit rendering of original favicon geometry into icon sizes; iconutil packages it |
| `Tests/MallowKitTests/RuntimeInstallTests.swift` | Synthetic archive/receipt/ownership regression tests |
| `scripts/test-runtime-install.sh` | Separate real pinned-archive install/verify integration; never executes Wine |
| `docs-fi/`, `mkdocs.fi.yml`, `overrides/main.html` | Localized user site and real-navigation loading indicator |
| `scripts/build-docs.sh`, `check-site.py` | Combined English/Finnish artifact and generated-output checks |

CLI additions are `setup --install-runtime --accept-download`, `runtime verify [--json]` and `runtime path`. Cache-only `--download-runtime` remains available. `doctor --verify-archive` opts into archive hashing. `MALLOW_HOME` enables isolated absolute test roots. These temporary APIs do not assert full §3.4/§3.8 conformance.

## Evidence and unresolved work

Synthetic tests cover successful installation/reuse, changed/missing/extra files, unsupported receipts, consent, cancellation, foreign roots, traversal, hardlinks/symlinks, duplicate names and special entries. The macOS suite caught SDK-header and receipt-path portability issues during development; fixes were tested rather than bypassed. A separate pipeline step installs the real pinned archive, verifies it, repeats setup and confirms deliberate file alteration is detected. No Wine process is executed by that step.

Personal-Mac installation, GUI/accessibility, supported-OS coverage, multimedia dependencies and the entire sandboxed Windows-launch path remain acceptance work. Keep [the roadmap](roadmap.md) and [actual-Mac checklist](development-preview.md) distinct from implementation checkmarks.
