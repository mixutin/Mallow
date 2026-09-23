<!-- SPDX-License-Identifier: 0BSD -->

# Changelog

All notable changes to Mallow are recorded in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Once releases begin, Mallow will use [Semantic Versioning](https://semver.org/spec/v2.0.0.html). Before 1.0, a minor release (0.x) may include breaking changes. The Mallow Runtime is versioned separately (for example `mallow-runtime-11.0-r1`) and will have its own release notes.

## [Unreleased]

Mallow is in the design phase. No application code exists yet, and nothing has been released.

### Added

- Design document ([`docs/DESIGN.md`](https://github.com/mixutin/Mallow/blob/main/docs/DESIGN.md), Draft 2): architecture, licensing model, runtime build pipeline, graphics backends, launch pipeline, testing strategy, and the roadmap to 1.0.
- Security model ([`docs/SECURITY_MODEL.md`](https://github.com/mixutin/Mallow/blob/main/docs/SECURITY_MODEL.md)): threat model, a kernel sandbox around every Windows program, secure-by-default bottles, Untrusted mode with disposable bottles, signed runtime downloads, and a red-team test plan.
- 0BSD licence ([`LICENSE`](https://github.com/mixutin/Mallow/blob/main/LICENSE)) for Mallow's own code, scripts and documentation. The Wine runtime stays LGPL-2.1-or-later, and recipes and schemas are CC0-1.0.
- [`NOTICE`](https://github.com/mixutin/Mallow/blob/main/NOTICE) with courtesy credits for the prior art that shaped the design, and a placeholder [`THIRD_PARTY_LICENSES.md`](https://github.com/mixutin/Mallow/blob/main/THIRD_PARTY_LICENSES.md) listing the planned third-party components and their licences.
- Contributor guide ([`CONTRIBUTING.md`](https://github.com/mixutin/Mallow/blob/main/CONTRIBUTING.md)) with the clean-room rules and DCO sign-off (`git commit -s`), and a [Code of Conduct](https://github.com/mixutin/Mallow/blob/main/CODE_OF_CONDUCT.md).
- Governance ([`GOVERNANCE.md`](https://github.com/mixutin/Mallow/blob/main/GOVERNANCE.md)), a security policy ([`SECURITY.md`](https://github.com/mixutin/Mallow/blob/main/SECURITY.md)) for private vulnerability reports, and a support guide ([`SUPPORT.md`](https://github.com/mixutin/Mallow/blob/main/SUPPORT.md)).
- Issue forms (bug report, compatibility report, feature request), a pull request template, `CODEOWNERS` and a label set.
- Project [README](https://github.com/mixutin/Mallow/blob/main/README.md), the [roadmap](https://github.com/mixutin/Mallow/blob/main/ROADMAP.md) and this changelog.
- Documentation site and devlog at [mixutin.github.io/Mallow](https://mixutin.github.io/Mallow/), built and published by a GitHub Actions workflow, and a starter CI workflow that checks JSON, YAML and licence headers.

[Unreleased]: https://github.com/mixutin/Mallow/commits/main
