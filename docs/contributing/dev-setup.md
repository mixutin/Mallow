---
# SPDX-License-Identifier: 0BSD
description: Build and test Mallow's current library, bootstrap CLI and native development app; preview documentation and report exact platform evidence.
---

# Development setup

The repository now contains buildable library, CLI and Mac app targets. The current app handles prerequisite setup only; it does not run Windows programs. [BOOTSTRAP.md](../BOOTSTRAP.md) distinguishes this slice from the full design.

## 1. Check your Mac

The app targets Apple Silicon and macOS 15 or later. The package uses Swift tools version 6.2; Swift 6.3 is the full design target. Current Apple Silicon CI has passed with Swift 6.3.3 on macOS 26.6.2. Report your actual toolchain when testing, rather than assuming all supported OS/CLT combinations have been verified.

Wine and Rosetta are not needed to build the native app or run its unit tests. Python and the pinned documentation requirements are needed only for the website. The portable setup/library subset also builds on Linux, but production Mac setup actions are not enabled there.

## 2. Install the Command Line Tools

```sh
xcode-select --install
swift --version
xcode-select -p
```

An existing Xcode toolchain is also usable. The full project is designed for Command Line Tools-only development, but a successful Xcode-backed CI runner is not independent proof of that complete matrix. Do not install Rosetta just to build or test this preview.

## 3. Get the code

```sh
git clone https://github.com/mixutin/Mallow.git
cd Mallow
```

Contributors can fork first and add the original repository as `upstream`. Set your own Git name/email for your contributions and sign-offs; do not invent another person's certification.

## 4. Build and test

```sh
swift build
scripts/test.sh
scripts/test.sh -c release
scripts/test.sh --filter SetupServiceTests
swift run mallow doctor --json
```

The package builds MallowKit and the bootstrap CLI; macOS additionally builds MallowApp. The test script uses swift-testing without XCTest. Tests use temporary directories and injected transports/hashes; no real Wine or dependency download is part of the unit suite. There are 37 tests on macOS, including the CryptoKit known-vector test; Linux omits that platform-only case.

The original wire fixtures can be regenerated intentionally with:

```sh
MALLOW_UPDATE_GOLDENS=1 scripts/test.sh
```

Review every changed fixture. This is not a shortcut for making an unexpected failure disappear. `fake-wine`, the complete CLI, schema validation, full layering linter and Windows launch integration tests are still planned; `scripts/lint.sh` does not yet exist. Use `swift format lint --strict --recursive Package.swift Sources Tests` when the tool is available and report the exact result, rather than claiming a missing script ran.

## 5. Try the CLI and the app safely

On Apple Silicon macOS:

```sh
scripts/build-app.sh
scripts/verify-app-bundle.sh dist/Mallow-macos-arm64.zip
```

The output is a ZIP containing the ad-hoc-signed `Mallow.app`, plus `dist/SHA256SUMS` and `dist/build-info.json`. Unzip it to try the native interface. The build script does not install the app, change Gatekeeper or install dependencies. The app's smoke-test option only proves executable startup, not that its GUI was exercised.

The bundled CLI lives at `Mallow.app/Contents/Helpers/mallow`. `doctor --json` is inspection only. The following operations have real setup effects and require reviewing their source/licence information first:

```sh
swift run mallow setup --download-runtime --accept-download
swift run mallow setup --install-rosetta --accept-apple-license
```

The download is the fixed Standard Wine archive; it remains unactivated in the separate setup cache. Rosetta uses Apple's installer. No command launches Wine. Use the [preview checklist](../development-preview.md) to record actual Mac behavior.

## 6. Preview the docs site

The repository pins MkDocs and Material dependencies in `requirements-docs.txt`:

```sh
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements-docs.txt
mkdocs serve
mkdocs build --strict
```

The local site is served under `http://127.0.0.1:8000/Mallow/`. Strict build warnings are failures. Do not claim a local preview ran when only CI built the site. Root-level documentation uses absolute links because it can be embedded in pages; site pages generally link to Markdown files.

## 7. Commit and open a pull request

Every change reviews README, CHANGELOG, ROADMAP and affected site pages in the same PR. Record genuinely unaffected surfaces as no-impact rather than adding meaningless edits. New or changed normative interfaces need a design update; the preview's temporary contracts are recorded in BOOTSTRAP.md.

```sh
git switch -c feat/short-topic
git add <reviewed-files>
git commit -s -m "feat: describe the change"
git push -u origin feat/short-topic
```

Follow [CONTRIBUTING.md](https://github.com/mixutin/Mallow/blob/main/CONTRIBUTING.md) for review, licensing and security-sensitive changes. New code must include tests and SPDX headers. Never turn a build-only result into a claim of game compatibility.

CI checks the Swift package, JSON/YAML/SPDX, strict docs and the development app bundle. PR artifacts cannot publish releases. Successful canonical-main app workflows publish commit-addressed development prereleases; relevant main documentation pushes build and deploy GitHub Pages. Check the exact commit and each outcome separately.

## 8. Saving disk space

`swift package clean` removes build products. The generated `.build/`, `dist/`, `.venv/` and `site/` directories are not source. Remove only directories you recognize and do not point cleanup commands at your real bottle or application data. Unit tests do not require a Wine runtime; a real acquisition creates the separate preview cache documented in the test guide.

## Troubleshooting

`no such module 'Testing'`
:   Try `scripts/test.sh`, record `swift --version` and `xcode-select -p`, and report the toolchain. Do not assume a CLT configuration was tested merely because Xcode CI passed.

`mallow run` or bottle commands are unknown
:   They are not implemented. This preview only exposes `doctor` and setup acquisition.

Setup cache is refused
:   Mallow does not adopt an unmarked or unsafe directory. Read the error and report the situation; do not delete unrelated files or weaken ownership checks.

App is blocked by macOS
:   Follow the [development preview guide](../development-preview.md#download-and-verify). Do not disable protections globally or ignore a malware warning.

`mkdocs build --strict` fails
:   Check the named page/link/anchor or navigation omission. Local filesystem paths are not website links. Every new documentation page must be reachable from navigation or its parent page.
