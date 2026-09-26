<!-- SPDX-License-Identifier: 0BSD -->

# Changelog

Notable Mallow changes are recorded here. Development prereleases use commit-addressed `dev-<sha>` tags; they are not stable product releases. The planned Wine runtime is versioned separately. The long-term versioning policy remains Semantic Versioning, with breaking changes possible before 1.0.

## [Unreleased]

### Added — development setup preview, 26 September 2026

- Native SwiftUI onboarding app with host/prerequisite status, dependency selection, explicit consent, progress, cancellation, verified-archive reveal and a copyable build/status report.
- Bootstrap `mallow doctor [--json]` and `mallow setup` commands over the same MallowKit setup service. This is not the full CLI from DESIGN.md.
- Rosetta detection and an installation request through Apple's fixed `softwareupdate` command, only after explicit Apple-licence consent. No shell, Homebrew or elevated helper is installed.
- Pinned Wine 11.0_1 archive acquisition: approved HTTPS sources/redirects, exact size and SHA-256 checks, private ownership-marked cache, advisory lock, cancellation, failure cleanup and verified-cache reuse. The archive is not extracted or activated.
- Fifteen additional setup tests on macOS, including a CryptoKit known-vector check; the full suite now has 37 tests in four suites. Linux runs 14 setup tests with injected transport/hash implementations.
- App bundle assembly and verification scripts; licence texts, source revision, arm64 binaries, ad-hoc signatures, ZIP checksum and build metadata.
- `Development app` CI: build/test artifacts on PRs; commit-addressed development prereleases only from successful canonical-main builds. No project signing keys or Developer ID are used. Published previews are not overwritten by the workflow.
- A bootstrap design addendum, real-Mac test checklist, current build/setup docs and a progress devlog.
- Repository maintenance instructions and PR-template checks requiring synchronized documentation, roadmap, changelog and affected website updates. The website now embeds the root roadmap instead of maintaining its own copy.

**Evidence:** the initial app revision in [PR #43](https://github.com/mixutin/Mallow/pull/43) passed 37 tests on macOS 26.6.2/Apple Silicon with Swift 6.3.3, release-mode app/CLI compilation, bundle checks and binary startup. Actual GUI usability, real network acquisition, Rosetta installation on an end-user Mac and the full macOS/CLT matrix are not established by those checks. Record results against the exact development revision in [#42](https://github.com/mixutin/Mallow/issues/42).

**Still not implemented:** runtime extraction/activation, GStreamer setup, complete WF0 and schema-safe stores, bottles, fake-wine, graphics translation, the kernel sandbox or Windows launching. No game-compatibility claim is made. G0 and production release gates remain open.

### Added — initial WF0 foundation, 26 September 2026

- [PR #41](https://github.com/mixutin/Mallow/pull/41): dependency-free MallowKit SwiftPM library and swift-testing target, tools version 6.2 and macOS 15 deployment target.
- `@Defaulted` providers, strict tagged-union helpers, local POSIX path coding, bottle-settings values and `ProgramSource`. Complete bottle/program/runtime/launch model families remain unfinished.
- `JSONStore` sorted-key JSON, ISO-8601 whole-second dates, missing/corrupt-file distinction and same-directory write/fsync/rename replacement. Owning stores must still enforce schema guards and transaction locking.
- Nineteen generated wire fixtures, 22 initial tests and executable `scripts/test.sh`. Sandbox settings are configuration, not isolation.

### Existing design and project documentation

- Draft 2 [DESIGN.md](https://github.com/mixutin/Mallow/blob/main/docs/DESIGN.md), the draft [security model](https://github.com/mixutin/Mallow/blob/main/docs/SECURITY_MODEL.md), roadmap, contributor guide, governance, conduct and security policies.
- 0BSD LICENSE, NOTICE and planned third-party licence inventory. Recipes/schemas are designated CC0-1.0 and the separate runtime retains its upstream licences.
- Documentation site and dated devlog, issue/PR templates, CODEOWNERS and starter JSON/YAML/SPDX, Swift and strict-documentation workflows.

[Unreleased]: https://github.com/mixutin/Mallow/commits/main
