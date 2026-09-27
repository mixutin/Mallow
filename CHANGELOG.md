<!-- SPDX-License-Identifier: 0BSD -->

# Changelog

Notable Mallow changes are recorded here. Development prereleases use commit-addressed `dev-<sha>` tags; they are not stable product releases. The planned Wine runtime is versioned separately. The long-term versioning policy remains Semantic Versioning, with breaking changes possible before 1.0.

## [Unreleased]

### Added — runtime installation and branded preview, 27 September 2026

- [PR #45](https://github.com/mixutin/Mallow/pull/45): Wine 11.0_1 installation from the compiled-in pin. Reuse a verified cache, check a private archive snapshot, extract into a bounded private staging tree, preserve the upstream bundle layout, and register only a complete installation.
- Ownership-marked application data root and a held runtime-install lock. Refuse foreign roots, unsupported receipts and silent replacement of damaged installations.
- `mallow setup --install-runtime --accept-download`, `mallow runtime verify [--json]` and `mallow runtime path`; matching native installation, verification and Finder controls.
- Per-file installation receipt and explicit integrity checks for modified, missing and unexpected files. A receipt is a local corruption baseline, not a signature or protection against an attacker who can change both it and the files.
- Twelve new extraction/installation test functions with synthetic inputs. The pipeline also performs a separate real pinned-archive install, repeat-install and altered-file detection check; it never executes Wine.
- System libarchive bridge with minimal public ABI declarations for SDKs without headers. No Homebrew installation or bundled third-party archive implementation.
- Dark-pink native interface, original website flower geometry, generated app icon and real-work loading indicator. Motion pauses for Reduce Motion and an inactive app; no artificial loading delay.
- Performance changes: metadata-only startup instead of rehashing the cached runtime, 1 MiB streaming buffers, download progress limited to approximately ten UI updates per second, and explicit verification elapsed-time reports. These are design/implementation properties, not measured game-performance claims.
- Finnish user-facing website pages, localized navigation/search, English/Finnish language selector and one combined Pages artifact. Long technical documents and historical posts remain English.
- Website loading spinner for real page navigation, with reduced-motion support, no content/focus blocking, no artificial wait and timeout cleanup.
- Updated README, roadmap, setup/testing guides and an installation design/security addendum. The roadmap separates completed subfeatures, automated evidence and pending tests on the owner's Mac.

**User evidence:** the owner reported successful Wine archive acquisition and SHA-256 verification in the preceding preview. This does not establish the new installer's behavior on that Mac. [Issue #44](https://github.com/mixutin/Mallow/issues/44) tracks new installation, theme, accessibility and performance checks. Exact CI and publication outcomes are linked from PR #45.

**Still unfinished:** GStreamer setup, generic runtime imports and capability probes, repair/rollback, full WF0/schema-safe stores, bottles, fake-wine, graphics translation, Windows launching and the kernel sandbox. No FPS, game compatibility, crash-durability or independent security-review claim is made. v0.1/v0.3 and production release gates remain open.

### Added — development setup preview, 26 September 2026

- Native SwiftUI onboarding app with host/prerequisite status, dependency selection, explicit consent, progress, cancellation, verified-archive reveal and a copyable build/status report.
- Bootstrap `mallow doctor [--json]` and `mallow setup` commands over the same MallowKit setup service; not the full CLI from DESIGN.md.
- Rosetta detection and an installation request through Apple's fixed `softwareupdate` command, only after explicit Apple-licence consent.
- Pinned Wine archive acquisition with HTTPS/redirect, size and SHA-256 checks, an ownership-marked cache, advisory lock, cancellation and verified-cache reuse. At this stage the archive was not extracted or activated.
- Fifteen setup tests on macOS, including a CryptoKit known-vector check; 37 total tests in four suites for PR #43. Linux ran 14 setup tests with injected transport/hash implementations.
- App assembly/verification scripts, licence texts, source revision, arm64 binaries, ad-hoc signatures, ZIP checksums and build metadata.
- `Development app` workflow: PR artifacts and canonical-main development prereleases. No project signing keys or Developer ID; already published previews are not overwritten.
- Bootstrap design addendum, real-Mac checklist, updated setup guides and progress devlog.
- Repository/PR-template documentation requirements and a single root roadmap embedded by the website.

**Historical evidence:** [PR #43](https://github.com/mixutin/Mallow/pull/43) passed 37 tests on macOS 26.6.2/Apple Silicon with Swift 6.3.3, release-mode app/CLI compilation, bundle checks and binary startup. GUI, actual network, Apple installation and broader OS coverage were not established by those checks. Subsequent testing is tracked in [#42](https://github.com/mixutin/Mallow/issues/42) and #44.

### Added — initial WF0 foundation, 26 September 2026

- [PR #41](https://github.com/mixutin/Mallow/pull/41): dependency-free MallowKit SwiftPM library and swift-testing target, tools version 6.2 and macOS 15 deployment target.
- `@Defaulted`, strict tagged-union and local-path helpers, bottle-settings values and `ProgramSource`. Complete bottle/program/runtime/launch model families remain unfinished.
- `JSONStore` deterministic dates/keys, missing/corrupt-file distinction and same-directory write/fsync/rename replacement. Owning stores must enforce schema guards and transaction locks.
- Nineteen generated wire fixtures, 22 initial tests and `scripts/test.sh`. Sandbox settings are configuration, not isolation.

### Existing design and project documentation

- Draft 2 DESIGN.md, draft security model, roadmap, contributor guide, governance, conduct and security policies.
- 0BSD LICENSE, NOTICE and third-party inventory. Recipes/schemas are designated CC0-1.0; separate runtime components retain upstream licences.
- Documentation site, dated devlog, issue/PR templates, CODEOWNERS and JSON/YAML/SPDX, Swift and strict-documentation workflows.

[Unreleased]: https://github.com/mixutin/Mallow/commits/main
