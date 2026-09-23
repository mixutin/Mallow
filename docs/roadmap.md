---
# SPDX-License-Identifier: 0BSD
description: Mallow's planned milestones from Gate G0 to 1.0, the security track, open decisions and non-goals. Pre-alpha; nothing here is built yet.
---

# Roadmap

> **Status: pre-alpha, design phase.** No application code exists yet. Everything on this page is planned or in design. Nothing described here works today.

Mallow is an open-source way to run Windows games and apps on Apple Silicon Macs, using Wine, Rosetta 2 and DirectX-to-Metal translation. It aims to be an open-source alternative to CrossOver.

This page is the docs-site copy of [`ROADMAP.md`](https://github.com/mixutin/Mallow/blob/main/ROADMAP.md) in the repository root. It is a summary. The authoritative plan is in the [design document](DESIGN.md), especially [§8 Roadmap](DESIGN.md#8-roadmap), and in the [security model](SECURITY_MODEL.md), especially [§5 Hardening roadmap](SECURITY_MODEL.md#5-hardening-roadmap). If this page and those documents disagree, they are right and this page gets fixed.

The time estimates below assume two or three part-time contributors. They are rough guesses, not release dates.

## Vision

Running a Windows game on a Mac should be simple, open and safe.

- **Simple.** A native Mac app for everyday use, plus a `mallow` command-line tool that can do everything the app can. Programs live in *bottles* (separate Wine prefixes), which keep them apart from each other and from the rest of your Mac. Setting up Steam should take one click.
- **Open all the way down.** Mallow's own code, scripts and docs are [0BSD](https://github.com/mixutin/Mallow/blob/main/LICENSE): you can use them for anything, including commercial work, change them and redistribute them, with no attribution required. The Wine runtime that Mallow downloads is LGPL-2.1-or-later. It is built in public GitHub Actions from CodeWeavers' published LGPL Wine sources, and its source code is published next to every runtime release. Recipes and schemas are CC0-1.0. DXVK, DXMT and MoltenVK keep their own licences.
- **Safe by default.** Wine is a compatibility layer, not a sandbox. So Mallow plans to run every Windows program inside a macOS kernel sandbox (Seatbelt), create bottles that can't see your home folder, offer a disposable *Untrusted* mode for suspicious downloads, and verify every runtime download against a signed manifest. No sandbox is perfect, and we will always say so plainly.
- **Honest.** A feature is only offered when the installed runtime really supports it, and every greyed-out control says why. Every launch leaves a log.
- **A good neighbour.** Fixes go upstream to Wine, DXMT, MoltenVK and winetricks wherever possible. We acknowledge CodeWeavers' central role in Wine on macOS and never send our users to their support channels.

## Where we are now

| | |
|---|---|
| **Phase** | Gate G0: design sign-off |
| **What exists** | The [design document](DESIGN.md) (Draft 2), the [security model](SECURITY_MODEL.md) (draft), the 0BSD licence and the project documentation |
| **What doesn't exist yet** | Any library, CLI or app code, any runtime build, any release |
| **Next step** | Close G0, then start v0.1 with "WF0": the shared data formats and their test fixtures land before anything else is built |

## Milestones at a glance

| Milestone | Goal | Rough size |
|---|---|---|
| [G0: Design sign-off](#g0-design-sign-off) | Settle the name, identity, licence files and governance before any code is written | about 1 week |
| [v0.1: Foundations](#v01-foundations) | The core library and CLI can create a secure bottle and run a Windows program on a pinned Wine build | about 4 weeks |
| [v0.2: Own runtime](#v02-own-runtime) | Our own signed LGPL Wine runtime from public CI, per-program graphics backends, Untrusted mode | weeks 3–12, alongside the other milestones |
| [v0.3: Mac app](#v03-mac-app) | A native app that people can use without the terminal | about 4 weeks |
| [v0.4: Steam and dependencies](#v04-steam-and-dependencies) | One-click Steam, a recipe engine, and dependency installs that show their licence terms first | about 3 weeks |
| [v0.5: D3DMetal and upscalers](#v05-d3dmetal-and-upscalers) | Use your own copy of Apple's Game Porting Toolkit per game; a tighter sandbox | about 3 weeks |
| [v0.6: Polish](#v06-polish) | Shortcuts, diagnostics, localisation groundwork, accessibility | about 3 weeks |
| [v0.8: Distribution](#v08-distribution) | Notarised builds, automatic updates, Homebrew cask | about 2 weeks, plus Apple account lead time |
| [v0.9: Import and community](#v09-import-and-community) | Import existing Wine prefixes; open the community recipe repository | about 3 weeks |
| [v1.0: Stable release](#v10-stable-release) | Meet the release criteria, including an external security review | when the criteria are met |

There is no separate v0.7 milestone; the numbering follows the design document. Progress is tracked in [GitHub milestones](https://github.com/mixutin/Mallow/milestones).

## Milestones in detail

### G0: Design sign-off

**Goal.** Settle everything that would be expensive to change later, before any code is written. The design document calls this gate "Before any code".

**Key deliverables**

- **Name.** Formal trademark searches for "Mallow" (USPTO and EUIPO, classes 9 and 42) and a lawyer's opinion. If the name fails, switch to the pre-checked fallback "Mullion" and re-run the checks.
- **Identity.** ✅ Decided: the project lives at `github.com/mixutin/Mallow`, the docs at `mixutin.github.io/Mallow`, and the bundle identifier is `io.github.mixutin.Mallow`. Still to do: reserve the Homebrew tap name.
- **Licence files.** `LICENSE` stays the unmodified 0BSD text (already committed). Add `NOTICE` (copyright line and credits for the projects whose ideas shaped the design), `recipes/LICENSE` and `schemas/LICENSE` (CC0-1.0), and SPDX headers. Adopt the Developer Certificate of Origin (DCO).
- **Governance.** `GOVERNANCE.md` (at least two maintainers, custody of signing keys) and `SECURITY.md` (security and abuse contact).

Drafts of `NOTICE`, `CONTRIBUTING.md` (with the DCO and the clean-room rules), `GOVERNANCE.md` and `SECURITY.md` are already in the repository. What remains (the name clearance, the identity decision, the CC0 files, the DCO check in CI and a second maintainer) is tracked in the G0 milestone on GitHub, together with small fixes to the design documents found during review.

**Exit criteria** (from DESIGN.md §8)

- The name, identity, licence and governance items above are merged.

**How to help**

- Read the [design document](DESIGN.md) and the [security model](SECURITY_MODEL.md), and tell us in [Discussions](https://github.com/mixutin/Mallow/discussions) or an issue about anything that is wrong, unclear or risky.
- If you have experience with trademarks or open-source licensing, help review the name clearance and the licence files.
- The project wants at least two maintainers with release rights before anything is released. If you'd like to help run it, see [GOVERNANCE.md](https://github.com/mixutin/Mallow/blob/main/GOVERNANCE.md) and say so in a Discussion.

Design: [§2 Legal and licensing](DESIGN.md#2-legal-and-licensing-model) · [§2.6 Naming](DESIGN.md#26-trademarks-and-naming) · [§8 G0](DESIGN.md#gate-g0-before-any-code-about-1-week-blocks-v01) · [Open issues for G0](https://github.com/mixutin/Mallow/issues?q=is%3Aissue+is%3Aopen+milestone%3A%22G0%3A+Design+sign-off%22)

### v0.1: Foundations

**Goal.** A tested core library (MallowKit) and `mallow` CLI that can create a secure-by-default bottle and run a Windows program on a pinned, publicly available Wine build.

**Key deliverables**

- **WF0 first.** The shared wire-format helpers, all model types and their checked-in JSON fixtures land in week 1, before work is split between contributors.
- The SwiftPM package skeleton and the Support layer: data folders with an ownership marker, file locks, a file watcher, a provenance guard that refuses CrossOver and D3DMetal files, and code-signature checks.
- Bottles, runtime import, and a pinned "Standard Wine" build (a public WineHQ-based build) that can be installed from the CLI.
- A runtime capability probe, so features are offered only when the runtime supports them.
- The Wine layer (settings plans, staging files inside the prefix), launching in environment mode, and bottle creation with Windows version, Retina and key-mapping settings.
- Graphics backends: wined3d, and DXVK native mode if verification item V27 passes.
- CLI commands: `rosetta`, `runtime`, `bottle`, `run`, `wine`, `logs` and `doctor`, with JSON output and stable exit codes.
- Testing: `fake-wine` (a stand-in for Wine in tests), golden tests, `scripts/test.sh`, and CI. Everything builds and tests with Swift 6.3 and the Command Line Tools only; Xcode is not needed.

**Security goals**

- Prefix hardening on by default: no `Z:` drive, real folders instead of links into your home folder, and Windows programs can't create Mac menu entries or file associations.
- A first Seatbelt sandbox profile (a deny-list) that hides your home folder from every Wine process. Wrapping Wine in the sandbox changes how Mallow spawns processes, so the design document is revised first. The target is v0.1; DESIGN.md (open question Q12) allows it to land in v0.2 at the latest.
- The only download in v0.1 is the pinned Standard Wine build, checked against a sha256 compiled into Mallow.

**Exit criteria** (from DESIGN.md §8)

- `mallow runtime install standard-wine-stable-11.0_1 && mallow bottle create Test && mallow run --bottle Test --wait notepad` works on an Apple Silicon Mac.
- All tests pass with both the Command Line Tools and Xcode.
- The clean-room rules and the DCO are in [CONTRIBUTING.md](https://github.com/mixutin/Mallow/blob/main/CONTRIBUTING.md).

**How to help**

- Swift developers: once WF0 lands, many pieces are small, pure and well specified. Look for [good first issues](https://github.com/mixutin/Mallow/issues?q=is%3Aissue+is%3Aopen+label%3A%22good+first+issue%22).
- Mac owners: help close the verification items this milestone depends on (V7, V8, V12, V20, V27, V35, V40; see [Verification backlog](#verification-backlog)).
- Security people: help design and test the Seatbelt profile.

Design: [§3 Architecture](DESIGN.md#3-architecture) · [§3.7.0 Wire-format rules](DESIGN.md#370-wire-format-rules-normative) · [§3.8 CLI](DESIGN.md#38-the-mallow-cli) · [§7 Testing and CI](DESIGN.md#7-testing-strategy-and-ci) · [§8 v0.1](DESIGN.md#v01-foundations-about-4-weeks) · [Open issues for v0.1](https://github.com/mixutin/Mallow/issues?q=is%3Aissue+is%3Aopen+milestone%3A%22v0.1%3A+Foundations%22)

### v0.2: Own runtime

**Goal.** Build, verify, sign and publish our own Wine runtime ("Mallow Runtime", based on Wine 11.0 from CodeWeavers' LGPL source release) entirely in public CI, with per-program graphics backends. This work runs from about week 3 to week 12, alongside the frontend milestones.

**Key deliverables**

- The runtime's dependency libraries built from pinned source by our own scripts (`deps.yml`), so no GPL code is bundled and the complete source can be published.
- The runtime build pipeline and our three small LGPL patches: 0001 (a private DLL search path for graphics backends), 0002 (a per-program DLL path map, so games started by Steam get the right backend) and 0003 (the crash dialog points at Mallow's issue tracker, not CodeWeavers').
- A relocatable runtime that never relies on `DYLD_*` environment variables.
- Licence and vendor-string audits, smoke tests (a) to (k), and the LGPL source archives published next to every binary.
- Signing, a signed component catalog, and an installer that checks signatures and can repair or roll back.
- Graphics: per-program DLL path map mode, MSync, DXMT, DXVK builtin mode, and packaged backend components.

**Security goals**

- **Untrusted mode:** the program runs in a disposable APFS clone of a clean bottle, with no shared folders and the network off. The clone is deleted when the program exits, unless you choose to keep it.
- A per-bottle network toggle (also used by *Offline* mode).
- A trust check that looks at the macOS quarantine flag and the file's Authenticode signature, and suggests Untrusted mode for unsigned downloads.
- A log of sandbox denials, so "blocked by the sandbox" can be told apart from "the game is broken".
- Ed25519-signed catalog and runtime manifests, pinned keys, and anti-rollback checks. A hash or signature mismatch is always a hard failure.

Following the CLI-first principle, these land in MallowKit and the CLI first. The app's Security panel follows in v0.3.

**Exit criteria** (from DESIGN.md §8)

- `mallow-runtime-11.0-r1` is released with both source archives next to it.
- The smoke suite passes with no `DYLD_*` variables set.
- FFmpeg's `avcodec_license()` reports LGPL, and the vendor-string scan is clean.
- A DirectX 11 title renders through DXMT with MSync on.

**How to help**

- Build and CI engineers: autotools, meson, mingw-w64 and GitHub Actions experience is very welcome.
- Wine developers: patch 0002 needs a prototype to confirm it can read the program's image path early enough (V2).
- Licence auditors: help check the generated `licenses/` tree against the real sources.
- Weigh in on open questions Q7, Q10 and Q11 (see [Open decisions](#open-decisions)).

Design: [§3.11 Runtime build pipeline](DESIGN.md#311-runtime-build-pipeline-runtime-depsyml-runtimeyml) · [§3.11.4 Our Wine patches](DESIGN.md#3114-our-wine-patches-lgpl-21-or-later-written-by-us) · [§2.3 LGPL compliance](DESIGN.md#23-lgpl-compliance-procedure-for-every-runtime-or-backend-release) · [§3.13 Catalog and update security](DESIGN.md#313-catalog-and-update-security) · [§8 v0.2](DESIGN.md#v02-own-runtime-weeks-312-in-parallel) · [Open issues for v0.2](https://github.com/mixutin/Mallow/issues?q=is%3Aissue+is%3Aopen+milestone%3A%22v0.2%3A+Own+runtime%22)

### v0.3: Mac app

**Goal.** Someone who has never opened Terminal can install Mallow, create a bottle, and run an installer and a game.

**Key deliverables**

- The SwiftUI app: bottle list, program grid, settings, runtime manager, log viewer, and onboarding (Rosetta, runtime download, first bottle). Rosetta is only installed after you explicitly agree to Apple's licence.
- Screens for acknowledgements and third-party terms, and a banner when a setting needs a bottle restart.
- Program discovery from Start Menu shortcuts and program icons, and pinned programs.
- An app bundle assembled by script (no Xcode needed), an ad-hoc signed zip on GitHub Releases, and a Homebrew tap. Until notarisation arrives in v0.8, macOS will ask you to confirm the first launch, and we will document how.

**Security goals**

- The red-team suite runs in CI, including probes that make raw macOS system calls from Windows code.
- A watcher that lists autostart entries (`Run`, `RunOnce`, the Startup folder) and alerts when a new one appears.
- The app's per-bottle Security panel: trust mode, network, shared folders and recent sandbox denials.

**Exit criteria** (from DESIGN.md §8)

- A non-developer can install the app, create a bottle, and run an installer and a game without using the terminal.
- The release zip passes `verify-app-bundle.sh`.

**How to help**

- SwiftUI developers who don't mind working without Xcode previews.
- Designers and testers: onboarding, wording, accessibility and first-run experience.
- Decide telemetry (Q9): the proposal is none at all.

Design: [§3.9 The SwiftUI app](DESIGN.md#39-the-swiftui-app) · [§3.10 Building the app without Xcode](DESIGN.md#310-building-the-app-without-xcode) · [Red-team plan](SECURITY_MODEL.md#4-red-team-validation-plan) · [§8 v0.3](DESIGN.md#v03-mac-app-about-4-weeks)

### v0.4: Steam and dependencies

**Goal.** One click gives you a working Steam client, and common dependencies install through declarative recipes that show their licence terms and download hosts first.

**Key deliverables**

- The recipe engine: every recipe names its licence, its download hosts and whether they are the vendor or a third-party mirror, and Mallow shows the terms before downloading anything.
- The Steam recipe, Steam library indexing, and automatic per-game backend rules. The Steam installer comes from Valve's servers at run time; Mallow never hosts it.
- winetricks through a pinned download, and a native `vcrun2022` verb.
- Faster bottle creation from APFS-cloned templates, and a "Restart Steam web helper" action.

**Exit criteria** (from DESIGN.md §8)

- On a clean Mac, one click produces a Steam client that can log in and download a game. This is tested on every runtime release.
- A DirectX 11 game started by Steam uses DXMT, while Steam's own processes use Wine's DLLs.

**How to help**

- Test the Steam flow on as many Macs and macOS versions as you can.
- Write and review recipes (CC0-1.0).

Design: [§6 Steam installer flow](DESIGN.md#6-steam-installer-flow-and-known-workarounds) · [§2.5 Third-party content](DESIGN.md#25-other-third-party-content) · [§3.7.7 Recipes](DESIGN.md#377-recipes-recipesjson-cc0-10) · [§8 v0.4](DESIGN.md#v04-steam-and-dependencies-about-3-weeks)

### v0.5: D3DMetal and upscalers

**Goal.** People who have their own copy of Apple's Game Porting Toolkit can import D3DMetal and use it per game, including for games that Steam starts.

**Key deliverables**

- A GPTK importer that shows Apple's licence from your own disk image, requires you to accept it, and checks Apple's signatures. Mallow never downloads, bundles, mirrors or uploads D3DMetal.
- Per-game MetalFX and NVAPI rules, DXR, DXMT's NVEXT and spatial upscaling, the full `auto` backend policy, and shader-cache clearing.

**Security goals**

- Move from a deny-list sandbox profile (`allow default`) to an allow-list profile (`deny default`), with the smallest set of system services games need, measured by the compatibility suite.

**Exit criteria** (from DESIGN.md §8)

- A DirectX 12 title runs with an imported GPTK 3.0, both launched directly and started by Steam.
- MetalFX shows up in the Metal HUD.

**How to help**

- Test with your own GPTK copy and report which titles work with which backend.
- Help find the minimal sandbox allow-list for Metal, audio and game controllers.

Design: [§2.4 D3DMetal](DESIGN.md#24-d3dmetal-apple-game-porting-toolkit) · [§4 Graphics backend mechanics](DESIGN.md#4-graphics-backend-mechanics) · [§8 v0.5](DESIGN.md#v05-d3dmetal-and-upscalers-about-3-weeks)

### v0.6: Polish

**Goal.** Make everyday use smoother and easier to support.

**Key deliverables**

- Mac shortcuts for Windows programs and the `mallow://` URL scheme.
- A diagnostics bundle for bug reports (it never includes your D3DMetal copy or the contents of `drive_c`, and replaces your home path with `~`).
- Automatic program discovery and Steam-library re-indexing when files change.
- Localisation groundwork and an accessibility review.
- `mallow doctor` cleans up leftover native graphics DLLs in old prefixes.

**Exit criteria.** Not yet defined in the design document.

**How to help**

- Accessibility testing with VoiceOver and keyboard-only use.

Design: [§8 v0.6](DESIGN.md#v06-polish-about-3-weeks)

### v0.8: Distribution

**Goal.** Builds that install without Gatekeeper warnings and keep themselves up to date.

**Key deliverables**

- A project Developer ID. This needs a legal entity to hold the Apple developer account and signing keys (open question Q5).
- Notarised builds with a stapled ticket.
- Automatic app updates with Sparkle and an EdDSA-signed appcast.
- Runtime update channels (stable and preview).
- Submission to Homebrew's main cask repository once builds are notarised.

**Exit criteria.** Not yet defined in the design document.

**How to help**

- Help find a fiscal host or other legal entity for the developer account (Q5).

Design: [§8 v0.8](DESIGN.md#v08-distribution-about-2-weeks-plus-apple-account-lead-time)

### v0.9: Import and community

**Goal.** Bring existing Wine prefixes into Mallow safely, and open recipes to the community.

**Key deliverables**

- Import or adopt plain Wine prefixes, including ones made by other tools. Imports are checked for proprietary files, and Apple translation DLLs found in them are quarantined. Other tools' settings are not interpreted beyond the environment variables you can see.
- The community recipe repository, opened only once its rules are in place: CC0-1.0, DCO sign-off, an allowlist of download hosts, and a public takedown process.
- Review grades for recipes, and automation that watches upstream releases.
- Decide how the runtime follows future CodeWeavers LGPL source releases (Q6).

**Exit criteria.** Not yet defined in the design document.

**How to help**

- Write recipes for the games and apps you use.
- Help review recipes and download hosts.

Design: [§2.9 Community recipe repository](DESIGN.md#29-community-recipe-repository-v09) · [§8 v0.9](DESIGN.md#v09-import-and-community-about-3-weeks)

### v1.0: Stable release

**Goal.** A release people can rely on, with clean licensing and an independently reviewed sandbox.

**Release criteria** (from DESIGN.md §8)

1. At least two active maintainers with release rights and split custody of the signing keys.
2. The runtime is rebuilt on the latest CodeWeavers LGPL source release, and every low-confidence assumption that shipped features depend on has been verified.
3. The Steam recipe works with the current Steam client.
4. At least 30 titles are documented with their backend and result.
5. No open data-loss bugs.
6. The licence audit is complete: every component has its notice, and every binary has its source next to it.
7. Legal review of the Game Porting Toolkit import flow and of the name is complete.
8. User and contributor documentation is published.

**Security goals**

- An external security review.
- A published threat-model document.
- A security advisory process in `SECURITY.md`.

Design: [§8 v1.0 release criteria](DESIGN.md#v10-release-criteria)

## Security track

Security is a headline feature, so it has its own track through the milestones. The plan comes from the [hardening roadmap](SECURITY_MODEL.md#5-hardening-roadmap) and the [defence layers](SECURITY_MODEL.md#3-defense-layers) in the security model.

| Milestone | Planned security work |
|---|---|
| v0.1 | Prefix hardening on by default (no `Z:` drive, no links into your home folder, no Mac menu entries). A first Seatbelt deny-list profile that hides your home folder. Downloads checked against pinned hashes. |
| v0.2 | Untrusted mode with disposable APFS-clone bottles. Per-bottle network toggle. A trust check based on the quarantine flag and Authenticode. A sandbox denial log. Signed catalog and runtime manifests. |
| v0.3 | Red-team suite in CI, including raw-syscall probes from Windows code. Autostart watcher. Security panel in the app. |
| v0.5 | Allow-list (`deny default`) sandbox profiles. |
| v1.0 | External security review, published threat model, security advisory process. |

A few notes on sequencing:

- Putting Wine inside the sandbox changes how Mallow starts processes, so [DESIGN.md §3.14](DESIGN.md#314-relationship-to-docssecurity_modelmd) requires a design revision first. The security model targets v0.1; the design document allows v0.2 at the latest.
- Mallow's own runtime, and with it the signed runtime manifest, arrives in v0.2. Until then the only download is the pinned Standard Wine build, which is checked against a sha256 compiled into Mallow.
- Where the two documents differ on defaults, the security model wins: bottles are secure by default, and any relaxation for compatibility is per bottle, opt-in and visible.

What the sandbox will not do: Mallow is not an antivirus, bugs in the macOS kernel, GPU drivers or Rosetta can in principle break any sandbox, and anything you share into a bottle is reachable by the programs in it. See [SECURITY_MODEL.md §6](SECURITY_MODEL.md#6-honest-limitations).

## Open decisions

These questions are still open (from [DESIGN.md §10](DESIGN.md#10-open-questions-decisions-needed)). Comments are welcome in [Discussions](https://github.com/mixutin/Mallow/discussions) or the issue tracker.

| # | Question | Needed by |
|---|---|---|
| Q2 | Is the name "Mallow" clear to use? (Decided provisionally; fallback "Mullion".) | G0 |
| Q4 | The project's permanent GitHub home, Pages URL and bundle identifier | G0 |
| Q7 | Should we cooperate with other open runtime efforts, such as highball-engine? | v0.2 |
| Q10 | Media stack: our from-source GStreamer subset, or the official GStreamer framework? | v0.2 |
| Q11 | Is `winegstreamer` still needed next to Wine 11's FFmpeg-based `winedmo`? | v0.2 |
| Q12 | How the Seatbelt profile plugs into the launch path (the secure defaults themselves are decided) | v0.2 |
| Q9 | Telemetry: none (proposed), or opt-in only? | v0.3 |
| Q3 | Legal review of the GPTK import flow, the LGPL source procedure and codec patents | v0.5 / v1.0 |
| Q5 | Which legal entity holds the Apple Developer ID and the signing keys? | v0.8 |
| Q6 | Follow each CodeWeavers LGPL source release, or rebase onto upstream Wine? | v0.9 |

Already decided: the licences (Q1: 0BSD for Mallow's own code, scripts and docs; LGPL-2.1-or-later for the runtime; CC0-1.0 for recipes and schemas) and AVX advertisement off by default (Q8).

## Verification backlog

The design tags every assumption it depends on by confidence. Nothing may depend on a low-confidence item until someone has verified it ([DESIGN.md §11](DESIGN.md#11-verification-backlog-assumptions-register)). Each item says how to verify it, and many need only an Apple Silicon Mac and some patience, so they are a good way to start contributing.

| Blocks | Items |
|---|---|
| G0 | V31 (name clearance) |
| v0.1 | V7, V8, V12, V20, V27, V35, V40 |
| v0.2 | V1, V2, V3, V9, V11, V26, V29, V32, V33, V38, V39 |

## Future ideas and long term

These are directions, not commitments. Some depend on decisions by Apple or CodeWeavers that we don't control.

- **Native arm64 runtime (ARM64EC and FEX).** Research after 1.0, once CodeWeavers publishes LGPL source for its ARM64 work and the question of Apple's cross-architecture entitlement is settled.
- **Rosetta sunset plan for macOS 28.** Apple has said macOS 27 is the last release with full Rosetta, and that macOS 28 keeps a gaming-focused subset whose scope is not yet clear. The plan: follow Apple's wording closely, keep an experimental arm64 cross-build of the runtime working in CI (GitHub's Intel macOS runners are expected to go away around August 2027), push the native arm64 research above, and tell users early and clearly which macOS versions each release supports.
- **Community recipe repository.** Opens in v0.9. Longer term: grow it with review grades and upstream-watch automation.
- **Compatibility database.** v1.0 needs at least 30 documented titles. A larger, searchable database could grow out of the recipe repository after 1.0.
- **Controller support.** Make sure game controllers work through the runtime, including inside the sandbox, document tested controllers, and add per-bottle controller settings if they turn out to be needed.
- **Game Mode.** Not planned for v1, because macOS Game Mode reportedly does not apply to windows owned by child processes. We will revisit it if that changes.
- **Cloud saves?** An open idea, not a plan. Many storefronts already sync saves themselves, and any Mallow feature would have to respect the sandbox.
- **Localisation.** The groundwork lands in v0.6; translations of the app and the docs by the community after that.
- **Notarised builds and a Homebrew cask.** Scheduled for v0.8, but they depend on finding a legal entity for the Apple developer account (Q5), so they may move.
- **Storefronts.** Epic and GOG through open command-line clients (legendary, gogdl) instead of running their Windows launchers.
- **Graphics.** DXMT 1.0 and its DirectX 12 work, KosmicKrisp as a possible path to DXVK 2.x, and GPTK 4 once its licence has been checked.
- **Installer verification.** A built-in Authenticode check of the Steam installer's signature.

## Non-goals

Mallow will not do these things:

- **Anti-cheat workarounds.** Kernel-level anti-cheat drivers can't work under Wine on macOS, and we will not try to get around any anti-cheat system. Affected titles are marked "anti-cheat: unsupported".
- **Bundling D3DMetal.** Mallow never downloads, bundles, mirrors or hosts Apple's D3DMetal in any form. You import it from your own copy of Apple's Game Porting Toolkit.
- **Piracy tooling.** No cracks, no DRM circumvention, no storefront hacks, and no recipes that point at warez, abandonware or file-locker hosts.
- **Hosting other people's software.** No Microsoft redistributables, fonts or Steam client on our servers. Recipes download from the vendor (or a named, reviewed mirror) after showing you the terms.
- **Using CodeWeavers' proprietary work.** We never copy files from CrossOver, and we use the name "CrossOver" only to describe what Mallow is an alternative to. We also never copy code from GPL-licensed frontends into Mallow's 0BSD code; we learn from their ideas only.
- **Being an antivirus.** Mallow limits what a program can reach. It doesn't decide whether a program is malicious.
- **Intel Macs** as a supported host, **32-bit (win32) prefixes**, **Mac App Store distribution**, and **per-game app wrappers** (Mallow creates lightweight Mac shortcuts instead).

## How to help

- Start with the [contributing guide](https://github.com/mixutin/Mallow/blob/main/CONTRIBUTING.md). Every commit needs a DCO sign-off (`git commit -s`), and the clean-room rules apply: never copy CodeWeavers' proprietary files, and never copy GPL code into Mallow's 0BSD code.
- Browse [good first issues](https://github.com/mixutin/Mallow/issues?q=is%3Aissue+is%3Aopen+label%3A%22good+first+issue%22) and issues marked [help wanted](https://github.com/mixutin/Mallow/issues?q=is%3Aissue+is%3Aopen+label%3A%22help+wanted%22).
- Ask questions and discuss the design in [GitHub Discussions](https://github.com/mixutin/Mallow/discussions).
- Report security problems privately as described in [SECURITY.md](https://github.com/mixutin/Mallow/blob/main/SECURITY.md), not in public issues.

## How this roadmap changes

This roadmap changes through pull requests, like everything else. Changes to scope or behaviour go into the [design document](DESIGN.md) first, then into [`ROADMAP.md`](https://github.com/mixutin/Mallow/blob/main/ROADMAP.md), and this page follows. Big changes to the roadmap go through the RFC process described in [GOVERNANCE.md](https://github.com/mixutin/Mallow/blob/main/GOVERNANCE.md).
