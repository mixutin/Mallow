<!-- SPDX-License-Identifier: 0BSD -->

# Contributing to Mallow

Mallow now has a native development setup preview, a limited CLI and the initial MallowKit library. Windows execution, runtime activation, complete bottle models and sandbox enforcement remain unfinished. Begin with the [current roadmap](https://github.com/mixutin/Mallow/blob/main/ROADMAP.md), [design](https://github.com/mixutin/Mallow/blob/main/docs/DESIGN.md), [bootstrap addendum](https://github.com/mixutin/Mallow/blob/main/docs/BOOTSTRAP.md) and [security model](https://github.com/mixutin/Mallow/blob/main/docs/SECURITY_MODEL.md).

## The short version

Be kind, follow the [Code of Conduct](https://github.com/mixutin/Mallow/blob/main/CODE_OF_CONDUCT.md), and discuss substantial changes in an issue or Discussion before writing them. Make one logical, reviewable change at a time. Add tests and update documentation, changelog, roadmap and affected website pages together. Use the contribution licences and DCO rules below. Do not copy GPL frontend code or proprietary CrossOver files. Report vulnerabilities privately.

## Where help is needed now

The first priorities are actual-Mac preview testing in [#42](https://github.com/mixutin/Mallow/issues/42), complete WF0 models/fixtures in [#9](https://github.com/mixutin/Mallow/issues/9), safe stores and verified runtime activation. Higher-level bottle/launch work must not invent incompatible persisted formats. The early app does not complete v0.3; its purpose is to expose implemented capabilities for testing.

## Ways to contribute without writing code

Test the preview and report the exact source revision, Mac and observed outcome; review an unverified design assumption; improve accessibility or documentation; triage issues; or help review licensing and release requirements. Do not describe a CI build as evidence that a game works.

## Development setup

With Swift 6.2 or newer:

```sh
swift build
scripts/test.sh
scripts/test.sh -c release
scripts/test.sh --filter SetupServiceTests
swift run mallow doctor --json
```

On Apple Silicon macOS, `scripts/build-app.sh` produces `dist/Mallow-macos-arm64.zip`; `scripts/verify-app-bundle.sh dist/Mallow-macos-arm64.zip` checks it. The app target is macOS-only. Unit tests need neither Wine nor Rosetta. The full design targets Swift 6.3 and CLT-only development; the complete CLT/Xcode matrix remains acceptance work, not an assumed result of a single CI runner.

The current package has no third-party Swift dependencies. `fake-wine`, the full CLI, schema tools and `scripts/lint.sh` are not implemented yet. Report unavailable checks honestly. The [development setup page](https://mixutin.github.io/Mallow/contributing/dev-setup/) lists working commands and the [preview guide](https://mixutin.github.io/Mallow/development-preview/) covers real setup effects.

## Repository layout

MallowKit remains one SwiftPM target with layered folders:

```text
Support → Bottles → Runtime → Wine → Programs → Graphics → Launch → Operations → Recipes → Diagnostics → Composition
```

A layer can use only earlier layers. Shared protocols and identifiers belong at the lowest layer that needs them. The current setup service is in Operations, compiled pins in Runtime, and transport/host/locking primitives in Support. MallowApp and MallowCLI use the library rather than duplicating effects. New files or temporary APIs not listed in the original design must be documented in the same PR; the initial additions are recorded in BOOTSTRAP.md.

## Workflow

Open or reference an issue for substantial work. Branch from current main, using `feat/`, `fix/`, `docs/`, `ci/` or `design/` with a short topic. Prefer small changes; separate generated-fixture changes where practical. Use a conventional commit title and explain validation, risks, documentation impact and remaining work in the PR.

### Sign off your commits (DCO)

Human contributors sign off their contributions with `git commit -s`, certifying the [Developer Certificate of Origin](https://developercertificate.org/) under the relevant file licence. Use your own identity and only certify what you can truthfully certify. AI assistance or permission to use a GitHub account is not an independent reviewer or a fabricated human certification. Owner-directed exceptions and outstanding sign-off/process work must be recorded, not silently presented as fulfilled.

## Coding standards

Use Swift concurrency deliberately. Planning should be pure; effects use injectable protocols. Heavy work must not run on the main actor. Use swift-testing (`import Testing`, `@Test`, `#expect`), not XCTest. Persisted formats follow the normative design or a documented staging addendum, not accidental synthesized encodings.

Tests are offline and hermetic by default: temporary paths, injected clocks/IDs/host facts/transports, synthetic inputs and explicit opt-in for real external effects. A bug fix needs a failing regression test. Security-relevant code needs negative tests. Wire fixtures are regenerated only intentionally with `MALLOW_UPDATE_GOLDENS=1 scripts/test.sh`; review and explain every changed value.

Run Swift formatting when available and shell syntax/shellcheck for scripts. Scripts use bash 3.2-compatible constructs, `set -euo pipefail`, quoted paths and fixed system tool paths where appropriate. Do not introduce sudo or pipe downloaded content into a shell. No local cleanup script may delete unrelated user data.

New Swift files start with `// SPDX-License-Identifier: 0BSD`, after the tools-version line in Package.swift. Shell/Python/YAML use `# SPDX-License-Identifier: 0BSD`, after a shebang where present. Root Markdown uses an HTML SPDX comment; site pages use an SPDX comment in YAML front matter. JSON cannot contain comments and is covered by the appropriate directory licence.

## Clean-room and licensing rules

Mallow's frontend, library, CLI, app, tests, scripts and docs are 0BSD. Wine patches are LGPL-2.1-or-later. Recipe data and JSON schemas are CC0-1.0. Preserve upstream licences and notices for any permitted reused component; new dependencies require discussion and an explicit licence review.

Do not put GPL, LGPL or MPL implementation code into the 0BSD frontend. Never copy implementation from Whisky, Heroic, Bottles, Mythic or other copyleft frontends; ideas and behavior can inform an independently written design. Do not copy unlicensed code. If you recently read a GPL implementation of the same function, disclose that in the PR for a second review.

Never use proprietary content inside CrossOver.app: launcher logic, defaults/templates, compatibility data, comments, assets or bundled binaries. No Apple/Microsoft payloads or real malware may be committed. D3DMetal is never downloaded, bundled, mirrored or uploaded by Mallow. The separate LGPL runtime may use properly licensed Wine source under its own terms; it does not license copying that implementation into the frontend.

Every new environment variable, registry key or DLL rule needs an open source or reproducible test cited in a code comment. Do not implement rules derived only from proprietary files. Download URLs, sizes and hashes need recorded provenance and deliberate review. Fixes to upstream components should be sent upstream where possible. No anti-cheat bypasses or storefront/DRM circumvention are added.

## Security-sensitive changes

Sandbox/trust settings, process/environment construction, prefix hardening, downloads/signatures/installers, imports/provenance, recipes/hosts, diagnostics, URL routing, entitlements and CI/release controls are security-sensitive. `.github/CODEOWNERS` and [GOVERNANCE.md](https://github.com/mixutin/Mallow/blob/main/GOVERNANCE.md) describe the review rules.

The standing policy requires two independent approving reviews for security-sensitive changes and no same-day merge; the author's review does not count. Do not invent reviewers to satisfy it. The owner explicitly directed the initial foundation merge and early ad-hoc setup preview; that specific staging decision is recorded in BOOTSTRAP.md and the PR, not treated as evidence that independent review occurred or as blanket removal of production safeguards.

Explain risks and refusals in the PR; test negative paths; update security documentation when behavior changes. Never quietly weaken a default for compatibility. Undisclosed vulnerabilities are handled privately under [SECURITY.md](https://github.com/mixutin/Mallow/blob/main/SECURITY.md), not first fixed or described in a public issue.

## Changing the design

Normative changes to APIs, formats or ownership need a corresponding design update and a linked proposal. The full RFC, waiting-period and decision rules remain in GOVERNANCE.md. Tag new factual assumptions with confidence, cite primary evidence and put unverified items in the backlog. A temporary staging addendum must state its exact scope and what remains unimplemented; it must not quietly redefine release acceptance.

## Documentation and the devlog

**Documentation is part of every change.** Review and update `README.md`, `CHANGELOG.md`, `ROADMAP.md` and affected pages under `docs/` together. Explain genuine no-impact surfaces in the PR. The website roadmap embeds the root roadmap; do not maintain another status table by hand. Update the design/security model when contracts or protections change. Keep dated posts as history and add a new progress post for a meaningful milestone.

Write plain English and distinguish implemented, tested, published and planned. Never describe a setting type as an enforced security boundary. Do not claim a website is deployed just because a PR's docs build succeeded. The main deployment outcome is separate.

Preview with the pinned requirements:

```sh
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements-docs.txt
mkdocs build --strict
mkdocs serve
```

Add each new site page to navigation or its relevant parent. Root docs use absolute links because they may be embedded in the site. Site pages normally link to Markdown paths. Follow the [writing guide](https://mixutin.github.io/Mallow/contributing/writing-docs/) for front matter and devlog authors.

## Compatibility reports

Use the source revision in the app/test report, Mac chip/model, macOS version, exact action and observed result. Distinguish compile/bundle/startup checks from GUI, network, installer and game results. The current preview cannot run games, so game compatibility remains untested. Do not post private paths, credentials, vendor payloads or malware.

## Review process

Inspect the actual diff, tests and exact PR head. Run applicable checks, or state precisely which are unavailable. Resolve objections before merge. Follow the review rules and record any explicit owner decision; never claim independent approval that did not happen. Do not force-push or bypass branch protection to get a green result.

For owner-authorized merges, use the checked head SHA, verify main, then inspect development-release publication and Pages deployment separately. PR builds never publish public releases. Do not claim background implementation or maintenance was scheduled merely because repository instructions exist.

## Recognition

Credit contributors and upstream work truthfully. Record AI-assisted implementation when relevant, without representing it as an independent human review or a claim about the user's personal testing.

## Getting help

Use [Discussions](https://github.com/mixutin/Mallow/discussions) for questions and [issues](https://github.com/mixutin/Mallow/issues) for reproducible tasks. Read [SUPPORT.md](https://github.com/mixutin/Mallow/blob/main/SUPPORT.md). Security reports use the private channel described in SECURITY.md.
