<!-- SPDX-License-Identifier: 0BSD -->

# Mallow Roadmap

> **Pre-alpha: development setup preview. Updated 26 September 2026.** Library foundations, a limited CLI, native onboarding and automatic development-app builds are implemented. Windows execution, runtime activation and sandbox enforcement are not. No milestone is complete merely because an app bundle builds.

This is the current progress summary of [DESIGN.md §8](https://github.com/mixutin/Mallow/blob/main/docs/DESIGN.md#8-roadmap) and the [security model](https://github.com/mixutin/Mallow/blob/main/docs/SECURITY_MODEL.md). Their detailed milestone criteria remain the long-term plan. The [bootstrap addendum](https://github.com/mixutin/Mallow/blob/main/docs/BOOTSTRAP.md) records the owner-directed early preview and its temporary interfaces. There are no promised release dates.

## Vision

A native Mac app and a full CLI will share MallowKit to run Windows software on Apple Silicon through Wine, Rosetta and graphics translation. Secure bottles, verified components, explicit sharing, honest capability checks and clear logs are product goals. They are not implied by a development download.

## Where we are now

| Track | Current state |
|---|---|
| G0 | Still open: outstanding naming, licensing/process and production-governance work |
| v0.1 foundations | Partial WF0; JSON persistence; setup acquisition and bootstrap CLI implemented |
| Early app testing surface | SwiftUI onboarding and source-addressed development prereleases implemented ahead of the full v0.3 app |
| Runtime | Pinned Wine archive can be acquired and verified; no extraction, activation or capability probe |
| Windows execution | Disabled; no working bottle/launch pipeline or kernel sandbox |
| Validation | CI compilation, 37 unit tests, bundle/signature/architecture checks and binary startup passed for PR #43; owner-Mac GUI/setup results remain to be recorded |

[PR #41](https://github.com/mixutin/Mallow/pull/41) established the library. [PR #43](https://github.com/mixutin/Mallow/pull/43) adds the setup preview. [Issue #9](https://github.com/mixutin/Mallow/issues/9) remains the WF0 tracker; [issue #42](https://github.com/mixutin/Mallow/issues/42) tracks preview testing and setup completion.

### Implemented

- [x] MallowKit SwiftPM target, `@Defaulted`, tagged-union/local-path helpers, bottle-settings values and `ProgramSource`.
- [x] Deterministic JSON coding, atomic replacement and 19 reference wire fixtures.
- [x] Owner-checked setup cache, advisory file locking and consent-gated pinned archive acquisition with size/SHA-256 checks.
- [x] Host/Rosetta detection and an explicit-consent request to Apple's Rosetta installer.
- [x] Bootstrap `doctor`/`setup` CLI and a native onboarding app using the same setup service.
- [x] App ZIP assembly, licence files, source revision, ad-hoc signatures, checksums and main-only development-prerelease workflow.
- [x] Documentation-update instructions and a single-source roadmap embedded by the website.

### Next work, in implementation order

- [ ] Record first-launch, consent, progress, cancellation, retry and offline-reopen results on actual Macs using the [preview checklist](https://mixutin.github.io/Mallow/development-preview/).
- [ ] Finish all WF0 model families, wire-table cases and schemas; keep #9 open until its complete acceptance criteria are met.
- [ ] Add application-data-root ownership, schema-version write guards and transaction-safe bottle/runtime/settings stores. The preview's separate cache is not those stores.
- [ ] Validate archive extraction before activation, preserve the Standard Wine bundle layout, add provenance checks and capability probing, and record runtime receipts.
- [ ] Implement GStreamer and other required dependency setup with pinned inputs, licence/privilege consent and successful installation checks. Do not equate a downloaded archive with an installed runtime.
- [ ] Add fake-wine and the complete CLI/launch planner, then secure bottle creation and tested Seatbelt enforcement before enabling Windows execution.
- [ ] Demonstrate the end-to-end Notepad milestone on Apple Silicon, with reproducible logs and the CLT/Xcode test matrix.

## Milestones at a glance

| Milestone | Intended outcome | Status |
|---|---|---|
| G0 | Naming, identity, licence/process and governance sign-off | Open |
| v0.1 | Verified runtime, secure bottle and CLI-launched Windows program | In progress; only a subset implemented |
| v0.2 | Publicly built own Wine runtime, signed catalog, per-image graphics and Untrusted mode | Planned |
| v0.3 | Complete native app: bottles, programs, settings, runtime manager, logs and onboarding | Onboarding preview only; milestone open |
| v0.4 | Steam, dependency recipes and winetricks | Planned |
| v0.5 | User-supplied D3DMetal, upscalers and tighter sandbox profiles | Planned |
| v0.6 | Shortcuts, diagnostics, accessibility and localization groundwork | Planned |
| v0.8 | Developer ID, notarisation, automatic updates and distribution | Planned; development prereleases do not satisfy it |
| v0.9 | Existing-prefix imports and community recipes | Planned |
| v1.0 | Release criteria and external security review met | Planned |

There is no separate v0.7 milestone in the design. See [GitHub milestones](https://github.com/mixutin/Mallow/milestones) for the issue breakdown.

## Milestones in detail

### G0: Design sign-off

The design originally placed G0 before code. The owner requested foundation work and development previews while unfinished G0 items remain open; this is a sequencing exception, not proof that they were completed. The repository identity and bundle identifier are decided. Remaining work includes formal name clearance, the CC0 licence files, DCO enforcement/process reconciliation and production release governance. Existing LICENSE, NOTICE, CONTRIBUTING, GOVERNANCE and SECURITY files remain the policy sources. No AI session counts as an additional independent maintainer or signing-key holder.

**Exit:** the naming, identity, licence and governance actions in DESIGN.md are actually satisfied. No development build certifies that legal review occurred.

### v0.1: Foundations

Complete WF0 before splitting dependent model work. Finish the Support layer, stores, runtime import/install/probe, Wine command/settings and staging layers, environment-mode launch planner, secure bottle creation, graphics capability gates and the full CLI. Add fake-wine, golden tests, schema checks and the CLT/Xcode matrix. The preview downloader is only the acquisition portion of the runtime installer.

Security work includes prefix hardening, no host-root drive or home-folder links by default, a tested sandbox around every Wine process, and a pinned interim runtime. Sandbox integration requires the design work described in DESIGN.md §3.14.

**Exit:** `mallow runtime install standard-wine-stable-11.0_1 && mallow bottle create Test && mallow run --bottle Test --wait notepad` works on an Apple Silicon Mac, with the required tests and contribution rules. These commands are **not implemented** in the preview.

### v0.2: Own runtime

Build Wine and dependencies from pinned, redistributable source in public CI. Implement the three planned Wine patches, relocatable library layout without `DYLD_*` dependence, licence/vendor audits, binary/source packages, signatures and the signed catalog. Add runtime repair/rollback, DXMT/DXVK components, MSync and per-image graphics rules. Security additions include disposable Untrusted bottles, network controls, quarantine/Authenticode assessment, denial logs and anti-rollback checks.

**Exit:** the own-runtime release includes its source assets, passes the smoke suite, satisfies licence/vendor checks, and renders a DirectX 11 title through DXMT with MSync.

### v0.3: Mac app

The early preview supplies only onboarding and prerequisite acquisition. The full milestone still needs bottle/program views, settings, runtime lifecycle controls, logs, program discovery/icons, restart notices, security controls and the complete onboarding-to-game flow. Add app distribution, the planned Homebrew tap, accessibility work appropriate to these views, autostart monitoring and the harmless sandbox validation suite.

**Exit:** a non-developer installs the app, creates a bottle and runs an installer and game without Terminal; the release bundle passes its checks. No such end-to-end result is claimed yet.

### v0.4: Steam and dependencies

Implement the declarative recipe engine, per-download host/licence disclosure, Steam installation and library indexing, pinned winetricks, native dependency verbs and APFS template acceleration. Download vendor installers rather than hosting them.

**Exit:** Steam can log in and download a game on a clean Mac; a DirectX 11 game launched by Steam gets its own graphics backend while Steam uses the intended Wine DLLs.

### v0.5: D3DMetal and upscalers

Implement user-supplied GPTK import, consent and signature/provenance checks, per-game graphics options, MetalFX/DXR/NVAPI behavior and shader-cache management. Never download or bundle D3DMetal. Move toward measured allow-list sandbox profiles.

**Exit:** a tested DirectX 12 title works through an imported toolkit, including when Steam starts it, with the requested upscaling behavior verified rather than inferred from settings.

### v0.6: Polish

Add Mac shortcuts and URL routing, privacy-preserving diagnostics, automatic discovery/reindexing, accessibility and localization groundwork. Diagnostics must exclude proprietary payloads and user program data. Finish any still-undefined exit criteria through design review before calling this milestone complete.

### v0.8: Distribution

Establish the Developer ID/account arrangements, notarisation and stapling, application updates, runtime channels and the planned Homebrew cask. The current ad-hoc development ZIP is not a substitute for these controls. Production signing/key-custody rules stay in GOVERNANCE.md.

### v0.9: Import and community

Safely import existing Wine prefixes with provenance and prefix audits. Open community recipes only with CC0/DCO, download-host review, versioning, review grades and a takedown process. Decide the runtime upstream/rebase policy.

### v1.0: Stable release

The design requires at least two active release maintainers with split key custody; an up-to-date runtime with verified assumptions; working Steam; at least 30 documented title/backend results; no open data-loss bugs; complete licence/source compliance and legal review; and published user/contributor docs. The security track additionally requires external review and a functioning advisory process. These criteria are not waived by development prereleases.

## Security track

| Stage | Remaining security outcome |
|---|---|
| v0.1 | Hardened prefixes, a tested kernel sandbox, verified interim-runtime installation |
| v0.2 | Untrusted/offline modes, explicit sharing/network controls, signed catalogs, anti-rollback and denial logs |
| v0.3 | Harmless validation suite in CI, autostart monitoring and security UI |
| v0.5 | Compatibility-tested allow-list sandbox profiles |
| v1.0 | External review and published security evidence |

The preview enforces its download/consent/cache rules, but it does not enforce the future Windows-program sandbox. Checksums identify bytes; they do not establish that a program is safe. Mallow is not an antivirus.

## Open decisions

Naming clearance, production signing/account arrangements, the media dependency stack, sandbox launch integration, telemetry policy and the long-term runtime upstream policy remain as tracked in [DESIGN.md §10](https://github.com/mixutin/Mallow/blob/main/docs/DESIGN.md#10-open-questions-decisions-needed). The fixed repository/Pages/bundle identity is already decided. New external dependencies and download hosts need explicit review, not silent setup-script additions.

## Verification backlog

Use [DESIGN.md §11](https://github.com/mixutin/Mallow/blob/main/docs/DESIGN.md#11-verification-backlog-assumptions-register) to track assumptions. No feature may depend on an unverified low-confidence item. For this preview, record actual Mac GUI, Rosetta and real-download results separately from CI's tests with injected transports. A successful build is not a successful game test.

## Future ideas and long term

Native ARM runtime research, future Rosetta compatibility, additional storefronts, controller testing, broader compatibility data and cloud-save ideas remain research or later work, not commitments. Follow upstream changes and update the design with evidence before building against them.

## Non-goals

No anti-cheat bypasses, piracy/DRM-circumvention tools, proprietary CrossOver code, bundled D3DMetal, hosted Microsoft redistributables/fonts/Steam client, or antivirus claims. Intel hosts, 32-bit prefixes and Mac App Store distribution are not in the v1 support plan.

## How to help

Test the preview on your Mac, finish a WF0 issue, verify a documented assumption, or improve tests and documentation. Read [CONTRIBUTING.md](https://github.com/mixutin/Mallow/blob/main/CONTRIBUTING.md). Security reports go privately through [SECURITY.md](https://github.com/mixutin/Mallow/blob/main/SECURITY.md).

## How this roadmap changes

Every implementation change reviews README, CHANGELOG, this roadmap and affected website pages together. Update progress only with evidence; record unaffected surfaces in the PR. The website's `docs/roadmap.md` embeds this file. Normative design changes require the corresponding design update. Dated devlog posts remain history; new milestones get new posts. CI results, release publication, Pages deployment and actual Mac results are separate checks.
