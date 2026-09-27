<!-- SPDX-License-Identifier: 0BSD -->

# Contributing to Mallow

Mallow has a native runtime-installation/verification preview, a limited CLI and initial MallowKit models. Windows execution, full runtime lifecycle/capability checks, multimedia dependencies, complete bottle models and kernel-sandbox enforcement remain unfinished. Begin with the [roadmap](https://github.com/mixutin/Mallow/blob/main/ROADMAP.md), [design](https://github.com/mixutin/Mallow/blob/main/docs/DESIGN.md), [bootstrap addendum](https://github.com/mixutin/Mallow/blob/main/docs/BOOTSTRAP.md), [installer design](https://mixutin.github.io/Mallow/runtime-installation/) and [security model](https://github.com/mixutin/Mallow/blob/main/docs/SECURITY_MODEL.md).

## The short version

Be kind, follow the [Code of Conduct](https://github.com/mixutin/Mallow/blob/main/CODE_OF_CONDUCT.md), and reference substantial work in an issue/Discussion. Make reviewable changes with tests, README/changelog/roadmap and affected English/Finnish pages updated together. Follow DCO and licence rules. Do not copy GPL frontend implementations or proprietary CrossOver files. Report vulnerabilities privately.

## Where help is needed now

Actual-Mac installer/accessibility/performance testing is tracked in [#44](https://github.com/mixutin/Mallow/issues/44), with earlier preview results in [#42](https://github.com/mixutin/Mallow/issues/42). Complete WF0 in [#9](https://github.com/mixutin/Mallow/issues/9), then schema-safe stores, capability/dependency checks and the safe bottle/launch pipeline. Runtime installation is now implemented; it does not complete v0.1 or v0.3.

## Ways to contribute without writing code

Report an exact source revision, Mac and observed behavior; measure startup/RSS/verification time; check accessibility; verify a design assumption; improve both language versions; or review licensing/release requirements. CI compilation is not proof of personal-Mac usability or a working game.

## Development setup

With Swift 6.2 or newer:

```sh
swift build
scripts/test.sh
scripts/test.sh -c release
scripts/test.sh --filter RuntimeInstallTests
swift run mallow doctor --json
```

Apple Silicon macOS builds the app using `scripts/build-app.sh`, producing `dist/Mallow-macos-arm64.zip`; verify it with `scripts/verify-app-bundle.sh`. The app target is macOS-only. Unit tests need neither Wine nor Rosetta and do not use the network. The full design targets Swift 6.3/CLT-only development; the complete OS/CLT/Xcode matrix remains acceptance work.

There are no external Swift-package dependencies. CArchive links the OS libarchive and supplies minimal public declarations when headers are absent; Linux development needs its system headers. No upstream archive implementation is vendored. The separate `scripts/test-runtime-install.sh` installs/checks the actual pinned archive in a temporary root without executing Wine. It is not an offline unit test.

Full WF0, fake-wine, the complete CLI/schema tooling and `scripts/lint.sh` are still unfinished. Report unavailable checks honestly. See [developer setup](https://mixutin.github.io/Mallow/contributing/dev-setup/) and [Mac preview tests](https://mixutin.github.io/Mallow/development-preview/).

## Repository layout

```text
Support → Bottles → Runtime → Wine → Programs → Graphics → Launch → Operations → Recipes → Diagnostics → Composition
```

MallowKit is one layered target; a layer uses earlier layers only. Shared protocols live low in the graph. Support owns host/download/lock/path/archive helpers; Runtime owns pins/installation/verification; Operations orchestrates; UI and CLI call the same services. Document new file ownership and staged APIs in the same PR. BOOTSTRAP.md and runtime-installation.md record the early exceptions, not full normative completion.

## Workflow

Reference an issue for substantial work. Branch from current main with `feat/`, `fix/`, `docs/`, `ci/` or `design/`. Prefer small logical changes; keep generated fixtures distinct where practical. Use conventional commit titles and explain tests, risks, documentation changes and unfinished work.

### Sign off your commits (DCO)

Human contributors use `git commit -s` to certify the [Developer Certificate of Origin](https://developercertificate.org/) under the file's licence. Use your own identity and only certify truthfully. AI assistance or account authorization is not an independent reviewer or fabricated certification. Record owner-directed exceptions/outstanding process items explicitly.

## Coding standards

Planning is pure; effects use injectable protocols. Heavy work must stay off the UI's main actor. Use swift-testing rather than XCTest. Persisted formats follow normative design or explicit staging contracts, not accidental synthesized encoding.

Tests are offline/hermetic by default: temporary roots, injected facts/transports, synthetic inputs and explicit opt-in for external effects. Fixes need regression tests; security boundaries need rejection tests. Regenerate wire fixtures only intentionally with `MALLOW_UPDATE_GOLDENS=1 scripts/test.sh`, then inspect every change.

Run formatting and shell checks when available, recording actual results. Scripts must support system bash 3.2, quote paths, use `set -euo pipefail` and fixed system tools when appropriate. Never introduce sudo, execute downloaded shell content or delete unrelated user data.

Swift starts with `// SPDX-License-Identifier: 0BSD` after a tools-version line; shell/Python/YAML use `# SPDX-License-Identifier: 0BSD`; root Markdown uses an HTML SPDX comment; ordinary site pages use front matter. JSON uses directory licensing, not invalid comments.

### Performance and security

Each feature records bounded input/memory/I/O behavior, cancellation and UI impact. Startup must not silently rehash the entire runtime. Throttle progress rather than scheduling a UI task for every data chunk. Loaders track actual work, stop when idle and respect reduced motion. Record source/hardware/OS/workload before claiming performance results.

Do not gain speed by bypassing checksums, accepting unsafe archives, overwriting foreign data, hiding errors or weakening sandbox rules. Installation metadata is not a fresh full integrity check; a local receipt is not an authenticated trust root; installed Wine is not Windows-launch readiness. Keep these states explicit.

## Clean-room and licensing rules

Mallow's own frontend/library/CLI/app/tests/scripts/docs are 0BSD. Wine patches are LGPL-2.1-or-later; recipes/schemas are CC0-1.0. Reused permitted components keep their notices; new dependencies require discussion and licence review. The OS libarchive boundary and its public API provenance are recorded in Sources/CArchive/README.md and the installer design.

Do not copy GPL/LGPL/MPL implementation code into the 0BSD frontend, including Whisky, Heroic, Bottles or Mythic. Ideas may inform fresh work; disclose recent reading of a corresponding GPL implementation for second review. Do not copy unlicensed code or CrossOver's proprietary launcher logic, defaults, templates, compatibility data, comments, assets or binaries.

No Apple/Microsoft payloads or malware belong in this repository. D3DMetal is never downloaded, bundled, mirrored or uploaded. The separate runtime may use appropriately licensed Wine sources; that does not permit copying their implementation into the frontend. Cite an open source or reproducible test for every new environment variable, registry key and DLL rule; record input URL/size/hash provenance. Send upstream fixes upstream where appropriate. No anti-cheat bypass or DRM/storefront circumvention.

## Security-sensitive changes

Sandbox/trust controls, process/environment construction, prefix hardening, download/install/signature handling, imports/provenance, recipe hosts, diagnostics, URL routing, entitlements and CI/releases are sensitive. CODEOWNERS and [GOVERNANCE.md](https://github.com/mixutin/Mallow/blob/main/GOVERNANCE.md) retain the review rules.

The standing policy calls for two independent approving reviews and no same-day merge of security-sensitive changes; the author's review does not count. Never invent reviews. The owner explicitly requested these limited implementation/merge/testing slices; record each decision and its limits in the issue/PR, not as a blanket waiver or evidence that independent review occurred. Production signing and security gates remain outstanding.

Explain risks/refusals, test negative cases and update security documentation. Never weaken defaults quietly. Undisclosed vulnerabilities are handled privately under [SECURITY.md](https://github.com/mixutin/Mallow/blob/main/SECURITY.md).

## Changing the design

Normative API, format or ownership changes require corresponding design updates and linked proposals. GOVERNANCE.md contains the RFC/process rules. Source new assumptions and track uncertainty. A staging addendum must state its exact scope and cannot silently redefine release acceptance.

## Documentation and the devlog

Review README.md, CHANGELOG.md, ROADMAP.md and affected `docs/` **and** `docs-fi/` pages with every change. Record genuine no-impact cases. The English website roadmap embeds the root file; its Finnish counterpart is an explicit translated summary and must stay synchronized. Update design/security contracts when behavior changes. Preserve dated posts; add new progress posts rather than rewriting history.

Distinguish implemented, tested, published and planned. A settings type is not an enforced boundary. A passing PR docs build is not a Pages deployment. App strings, long technical documents and historical posts remain English until actually translated.

```sh
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements-docs.txt
scripts/build-docs.sh
mkdocs serve
```

Both language builds run in strict mode and produce one artifact. Add pages to navigation or their parent. Root files use absolute links for embedding; site pages normally link to Markdown. The Finnish site shares English-root assets: validate the combined output for a complete visual preview. See [the writing guide](https://mixutin.github.io/Mallow/contributing/writing-docs/).

## Compatibility reports

Provide source revision, chip/model, OS, exact action and observed result. Separate compilation/bundle/startup, installation/integrity, GUI/accessibility and later game results. This preview does not run games. Do not post private paths/credentials, vendor payloads or malware.

## Review process

Inspect the diff, regression tests and exact PR head; run checks or state what is unavailable. Resolve objections and record explicit owner decisions without claiming independent approvals. Do not force-push or bypass branch protection to get a passing result.

For authorized merges, use the checked SHA, verify main, then inspect release assets and Pages deployment separately. PR builds do not publish public releases. Repository instructions do not schedule unattended maintenance.

## Recognition

Credit contributors/upstream work truthfully. Record AI-assisted work when relevant without representing it as an independent human review or fabricated personal-Mac result.

## Getting help

Use [Discussions](https://github.com/mixutin/Mallow/discussions), reproducible [issues](https://github.com/mixutin/Mallow/issues) and [SUPPORT.md](https://github.com/mixutin/Mallow/blob/main/SUPPORT.md). Security issues use the private route in SECURITY.md.
