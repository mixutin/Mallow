---
# SPDX-License-Identifier: 0BSD
description: Build and test Mallow's library, runtime installer, CLI and pink native app, plus both website languages.
---

# Development setup

The package builds MallowKit, the bootstrap CLI and, on macOS, MallowApp. The current app installs and verifies Wine but does not run Windows programs. See [BOOTSTRAP.md](../BOOTSTRAP.md) and [runtime installation design](../runtime-installation.md).

## 1. Check your Mac

Apple Silicon/macOS 15+ is the product target. Package tools version is Swift 6.2; the full design targets Swift 6.3. The macOS pipeline has tested Swift 6.3.3/macOS 26.6.2, not the entire OS/CLT/Xcode matrix. Wine and Rosetta are not needed to compile or run synthetic unit tests.

The native installer links the OS libarchive library through `Sources/CArchive`. For SDKs without libarchive headers, the bridge declares the needed public API. No Homebrew library is bundled. Linux development needs its system libarchive development package; production Mac installation is not enabled there.

## 2. Install the Command Line Tools

```sh
xcode-select --install
swift --version
xcode-select -p
```

An Xcode toolchain also works. Record the exact active toolchain rather than treating a green Xcode-backed run as proof of CLT-only coverage.

## 3. Get the code

```sh
git clone https://github.com/mixutin/Mallow.git
cd Mallow
```

Contributors can fork first. Use your own Git identity and sign-off, never a fabricated certification for somebody else.

## 4. Build and test

```sh
swift build
scripts/test.sh
scripts/test.sh -c release
scripts/test.sh --filter RuntimeInstallTests
swift run mallow doctor --json
```

Tests use swift-testing, synthetic archives and injected transports/hashes. The unit suite is offline and never executes Wine. The installer adds 12 functions to the prior 37 macOS tests. See PR #45 for exact-head outcomes.

```sh
MALLOW_UPDATE_GOLDENS=1 scripts/test.sh
```

This intentionally regenerates wire fixtures. Review every difference; do not regenerate just to conceal a regression. Full WF0, fake-wine, schemas and the complete linter remain unfinished. `scripts/lint.sh` does not exist; do not claim it ran. `swift format lint --strict --recursive Package.swift Sources Tests` can be used when available, with its real result reported.

## 5. Try the CLI and app safely

```sh
scripts/build-app.sh
scripts/verify-app-bundle.sh dist/Mallow-macos-arm64.zip
```

The ZIP includes the ad-hoc-signed app, CLI, original flower icon and notices. Checksums/source metadata are separate files. The build does not install the app or its dependencies; `--smoke-test` exits before showing a window and is not a GUI test.

For a throwaway data root, choose an absolute directory that does not already hold unrelated files:

```sh
export MALLOW_HOME="$TMPDIR/mallow-install-test-$(date +%s)"
swift run mallow setup --install-runtime --accept-download
swift run mallow runtime verify --json
swift run mallow runtime path
```

Review source/licence terms before passing acceptance flags. `setup --download-runtime` remains cache-only. Rosetta's `--install-rosetta --accept-apple-license` is separately consented. No command launches Wine or creates a bottle.

The distinct **network integration test** is:

```sh
scripts/test-runtime-install.sh
```

Run after a release CLI build on Apple Silicon. It creates a temporary `MALLOW_HOME`, downloads/installs the actual pinned archive, verifies it, repeats setup, alters a temporary installed file and requires integrity failure. It cleans its temporary directory and does not execute Wine. This is not part of the offline unit suite.

## 6. Preview the docs site

```sh
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements-docs.txt
mkdocs serve
# Or preview the Finnish pages:
mkdocs serve --config-file mkdocs.fi.yml
# Build both language trees and validate the generated output:
scripts/build-docs.sh
```

English pages live in `docs/`; Finnish user pages in `docs-fi/`. The build produces English under `site/` and Finnish under `site/fi/`, then checks languages, navigation-loader output, shared assets and search output. There is one Pages artifact, not competing deployments.

Full technical documents and historical posts remain English. The Finnish roadmap is an explicit user summary; update it alongside the root English roadmap when progress changes. `docs/roadmap.md` embeds that root file. The new loader uses a local template/CSS, no external service and no artificial delay.

## 7. Commit and open a pull request

Each change reviews README, CHANGELOG, ROADMAP and affected English/Finnish pages. Record real no-impact cases. New staged API/file ownership goes in the installation/bootstrap addendum; full normative changes still follow DESIGN.md and the review process.

```sh
git switch -c feat/short-topic
git add <reviewed-files>
git commit -s -m "feat: describe the change"
git push -u origin feat/short-topic
```

Follow [CONTRIBUTING.md](https://github.com/mixutin/Mallow/blob/main/CONTRIBUTING.md), especially clean-room, licences and security-sensitive review. Performance changes need measurements or clearly stated implementation properties; security checks cannot be removed silently for speed. Main publication/Pages deployment and actual-Mac behavior are checked separately from a green PR build.

## 8. Saving disk space

`swift package clean` removes build output. `.build/`, `dist/`, `.venv/` and `site/` are generated directories. Do not apply cleanup commands to unrelated user data. The runtime-install test needs staging space and a network download; ordinary unit tests do not require the vendor archive.

## Troubleshooting

`no such module 'Testing'`
:   Use `scripts/test.sh` and record Swift/developer-directory details.

Unknown `mallow run` or bottle commands
:   Those are not implemented. Current additions are runtime installation, verification and path inspection.

Unrecognized data root or receipt
:   Mallow refuses foreign roots and newer/invalid receipts rather than silently overwriting. Report the situation without deleting unrelated files or weakening checks.

Integrity check fails
:   Existing data is preserved. Repair/rollback is still planned. Do not treat the runtime as verified.

macOS blocks the app
:   Use [the per-app preview instructions](../development-preview.md#download-and-verify), not global protection disabling.

Strict docs build fails
:   Inspect the named link, anchor or navigation entry in the appropriate language. Test both configurations before claiming the website is ready.


For optimized/debug bundle generation, matching dSYMs and client tests, read [Mac client testing](../mac-client-testing.md). `scripts/build-app.sh release` and `scripts/build-app.sh debug` build separately. `scripts/package-test-kit.sh` adds exact tracked sources and the helper kit. Both language builds remain required.
