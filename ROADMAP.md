<!-- SPDX-License-Identifier: 0BSD -->

# Mallow Roadmap

> **Pre-alpha: runtime installation preview. Updated 27 September 2026.** Wine installation, installed-file verification, ownership-protected storage, native pink onboarding and automatic Mac builds are implemented. Windows launching and its kernel sandbox are not. Performance and security are acceptance requirements, not optional polish.

This is the progress summary of [DESIGN.md §8](https://github.com/mixutin/Mallow/blob/main/docs/DESIGN.md#8-roadmap) and the [security model](https://github.com/mixutin/Mallow/blob/main/docs/SECURITY_MODEL.md). Detailed milestone criteria remain the long-term plan. The [bootstrap addendum](https://github.com/mixutin/Mallow/blob/main/docs/BOOTSTRAP.md) and [runtime installation design](https://mixutin.github.io/Mallow/runtime-installation/) record the early preview's staged interfaces. No release dates are promised.

## Vision

A native Mac app and full CLI will share MallowKit to run Windows software through Wine, Rosetta and graphics translation. Secure bottles, verified components, explicit sharing, honest capability checks and responsive operation are requirements. A development download does not imply any unfinished feature works.

## Where we are now

| Track | Current state |
|---|---|
| G0 | Outstanding naming, licensing/process and production-governance work remains open |
| v0.1 foundations | Partial WF0, JSON persistence, owned setup/data directories, archive installation and bootstrap CLI |
| Early app surface | Dark-pink SwiftUI onboarding, flower branding, loaders and runtime verification; not the full v0.3 app |
| Runtime | Pinned archive acquisition, confined extraction, completed-tree registration and per-file integrity checks implemented |
| Windows execution | Disabled; bottle/launch pipeline and kernel sandbox missing |
| Website | English and Finnish principal user pages, localized search/navigation, non-blocking loader |
| Evidence | Exact-head automated results are on PR #45; real-Mac tests are separately recorded in #44 |

[PR #41](https://github.com/mixutin/Mallow/pull/41) established the library; [#43](https://github.com/mixutin/Mallow/pull/43) added acquisition/onboarding. [#45](https://github.com/mixutin/Mallow/pull/45) adds runtime installation and the branded preview. [#9](https://github.com/mixutin/Mallow/issues/9) still tracks full WF0. [#44](https://github.com/mixutin/Mallow/issues/44) tracks actual-Mac verification of this slice.

### Implemented

A checked item means the named implementation exists with its scoped tests. It does not imply that all devices, game compatibility or the enclosing milestone passed.

- [x] MallowKit SwiftPM target, `@Defaulted`, tagged-union/local-path helpers, bottle-settings values and `ProgramSource`.
- [x] Deterministic JSON coding, atomic replacement and 19 reference wire fixtures.
- [x] Owner-checked setup cache, advisory locking and consent-gated pinned HTTPS acquisition with size/SHA-256 checks.
- [x] Host/Rosetta detection and an explicit-consent request to Apple's installer.
- [x] Bootstrap `doctor`/`setup` CLI and native onboarding over the same setup service.
- [x] **Application-root ownership:** versioned root marker and refusal to adopt foreign/symlink roots. This is not every planned store.
- [x] **Pinned runtime installation:** private snapshot verification, bounded tar extraction, deferred/confined links, expected entry points, preserved Wine bundle and final directory registration.
- [x] **Integrity verification:** installation receipts, missing/changed/unexpected-file checks, elapsed-time reporting, UI/CLI access and no silent overwrite of a damaged runtime.
- [x] **Repeat setup:** reuse a verified cached archive, or verify the already installed runtime rather than fetching it again.
- [x] **Responsive setup foundation:** streaming buffers, off-main-actor file work, metadata-only startup and throttled UI progress.
- [x] **Native visual update:** dark-pink theme, original flower geometry, generated app icon and reduced-motion-aware real-work loader.
- [x] App ZIP assembly, notices, source revision, ad-hoc signatures, checksums and main-only development prereleases.
- [x] Separate real-archive integration check before app publication: install, verify, repeat and altered-file rejection. No Wine execution in that check.
- [x] **Finnish user website:** home, setup, preview tests, explanation, roadmap summary, FAQ, security and contributing; localized navigation/search.
- [x] Non-blocking website navigation spinner and a combined bilingual Pages build.
- [x] Documentation-update instructions and one root English roadmap embedded by the site; the Finnish summary is updated alongside it.

### Evidence still to collect on the owner's Mac

The owner reported successful Wine acquisition and SHA-256 verification in the preceding preview. The following remain unverified for the new installer until a corresponding test report is submitted:

- [ ] First installation and subsequent offline reopen on the owner's actual Mac.
- [ ] Full integrity-check result and measured elapsed time on that Mac.
- [ ] UI responsiveness, peak memory and startup latency during setup and verification.
- [ ] Cancellation/retry, unavailable network, low disk space and existing-cache behavior.
- [ ] Logo/icon appearance, keyboard navigation, VoiceOver and Reduce Motion behavior.
- [ ] macOS 15 and a separate Command Line Tools-only/Xcode coverage matrix.

Use the [preview checklist](https://mixutin.github.io/Mallow/development-preview/). Do not fill this list from a successful CI compile.

### Next work toward the first working Windows version

- [ ] Finish all WF0 model families, wire-table cases and JSON schemas; #9 remains open.
- [ ] Add schema-version guards and transaction-safe bottle/runtime/settings stores. Root ownership is only one completed subtask.
- [ ] Add runtime capability probing, generic import/provenance/signature checks and multimedia dependency detection.
- [ ] Implement pinned, consent-aware GStreamer and other required dependency installation with post-install verification.
- [ ] Add runtime repair/rollback and safe removal. Damaged installations are currently preserved and rejected.
- [ ] Add fake-wine and a pure launch planner with deterministic golden tests and bounded process/log handling.
- [ ] Implement secure bottle creation and tested kernel sandbox enforcement before enabling Windows execution.
- [ ] Demonstrate the end-to-end Notepad milestone on Apple Silicon with reproducible logs and documented limits.

## Performance and security acceptance track

Neither priority is traded away silently for the other. Each feature must describe its I/O/CPU cost, failure behavior and trust boundary.

| Area | Implemented requirement | Remaining measurement or protection |
|---|---|---|
| Startup | Metadata/receipt checks only; no automatic full archive/runtime hash | Actual-Mac cold/warm startup time and memory budget |
| Large files | 1 MiB streaming buffers and off-main-actor hashing/extraction | Peak RSS and throughput measurements across supported Macs |
| Progress | Download UI updates capped near 10/sec; no artificial waiting; loader absent when idle | Real accessibility/UI responsiveness tests |
| Download trust | Compiled-in source, exact size/SHA-256, approved HTTPS redirects | Signed catalogs, anti-rollback and component lifecycle |
| Installation | Private staging, entry/expanded-size limits, no archive ACL/xattr/owner restoration, confined links, final completed-tree move | Power-loss durability study and broader filesystem coverage |
| Runtime integrity | Explicit file inventory comparison; damaged trees not overwritten | Authenticated receipts, repair/rollback, hostile same-user threat analysis |
| Windows processes | No unfinished launch feature enabled | Measured launch performance and kernel-enforced isolation |
| Game performance | No FPS or compatibility claims | Reproducible title/backend benchmarks after launching works |
| Website | Static bilingual pages, shared assets, CSS spinner that never blocks content | Browser/device accessibility checks and measured page budgets |

Any optimization that skips a required checksum, accepts an unsafe archive, silently relaxes a sandbox rule or reports false readiness fails acceptance. Conversely, security checks must have bounded input sizes, useful progress and cancellation where feasible instead of freezing the UI.

## Milestones at a glance

| Milestone | Intended outcome | Status |
|---|---|---|
| G0 | Naming, identity, licence/process and governance sign-off | Open |
| v0.1 | Verified runtime, secure bottle and CLI-launched Windows program | In progress; runtime installation is only one part |
| v0.2 | Public own Wine runtime, signed catalog, per-image graphics and Untrusted mode | Planned |
| v0.3 | Complete native app: bottles, programs, settings, runtime manager, logs and onboarding | Setup/verification preview only |
| v0.4 | Steam, dependency recipes and winetricks | Planned |
| v0.5 | User-supplied D3DMetal, upscalers and tighter sandbox profiles | Planned |
| v0.6 | Shortcuts, diagnostics, accessibility and localization | Initial visual/accessibility work and Finnish website only |
| v0.8 | Developer ID, notarisation, automatic updates and distribution | Planned; ad-hoc previews do not satisfy it |
| v0.9 | Existing-prefix imports and community recipes | Planned |
| v1.0 | Release criteria and external security review met | Planned |

There is no separate v0.7 milestone. See [GitHub milestones](https://github.com/mixutin/Mallow/milestones) for issue breakdowns.

## Milestones in detail

### G0: Design sign-off

The design originally put G0 before code. The owner requested foundation work and development previews while G0 items remain open; this is a sequencing exception, not proof of completion. Repository and bundle identity are decided. Remaining work includes formal name clearance, CC0 licence files, DCO enforcement/process reconciliation and production release governance. LICENSE, NOTICE, CONTRIBUTING, GOVERNANCE and SECURITY remain the policy sources. An AI session does not create an independent maintainer or key custodian.

**Exit:** naming, identity, licence and governance actions are actually satisfied; no development build certifies legal review.

### v0.1: Foundations

Complete WF0, Support, stores, runtime import/install/probe, Wine commands/settings/staging, environment-mode launch planning, secure bottle creation, graphics capability gates and the full CLI. The pinned installer now covers acquisition, extraction and registration, not generic import or capability probing. Add fake-wine, golden tests, schemas and the CLT/Xcode matrix.

Security includes no host-root drive/home symlinks by default and a tested sandbox around every Wine process. Sandbox integration requires the design revision described in DESIGN.md §3.14.

**Exit:** `mallow runtime install standard-wine-stable-11.0_1 && mallow bottle create Test && mallow run --bottle Test --wait notepad` succeeds on Apple Silicon with the required tests. The complete command sequence is **not implemented**; the interim installer uses `mallow setup --install-runtime`.

### v0.2: Own runtime

Build Wine/dependencies from pinned redistributable source in public CI. Implement the three Wine patches, relocatable libraries without `DYLD_*` reliance, licence/vendor audits, binary/source packages, signatures/catalog, lifecycle repair/rollback, backend components, MSync and per-image graphics. Add disposable Untrusted bottles, network controls, quarantine/Authenticode assessment, denial logs and anti-rollback.

**Exit:** own-runtime release with sources and passing smoke/licence audits, plus a DirectX 11 title rendered through DXMT with MSync.

### v0.3: Mac app

The early UI now handles setup and verification. The full milestone still needs bottles/programs, settings, complete runtime lifecycle, logs, discovery/icons, restart notices and security controls. Add planned distribution/Homebrew support, accessibility validation, autostart monitoring and harmless sandbox tests.

**Exit:** a non-developer installs, creates a bottle and runs an installer/game without Terminal; release bundle checks pass. No end-to-end result is claimed yet.

### v0.4: Steam and dependencies

Implement declarative recipes, download-host/licence disclosure, Steam installation/indexing, pinned winetricks, native verbs and APFS templates. Download vendor installers rather than hosting them.

**Exit:** Steam logs in and downloads a game on a clean Mac; a DirectX 11 game it starts gets its own backend while Steam gets Wine's intended DLLs.

### v0.5: D3DMetal and upscalers

User-supplied GPTK import with consent and signature/provenance checks, per-game MetalFX/DXR/NVAPI behavior, shader caches and measured allow-list sandbox profiles. Never download or bundle D3DMetal.

**Exit:** a tested DirectX 12 title works through imported GPTK, directly and via Steam, with requested upscaling verified.

### v0.6: Polish

Mac shortcuts/URL routing, privacy-preserving diagnostics, discovery/reindexing, accessibility and application localization. The Finnish website and reduced-motion loader are initial work, not full app localization or a completed accessibility audit. Diagnostics must exclude proprietary payloads and user program data. Define remaining exit criteria before completion.

### v0.8: Distribution

Developer ID/account arrangements, notarisation/stapling, automatic app updates, runtime channels and the planned Homebrew cask. Current ad-hoc ZIPs are not substitutes. Production key-custody rules remain in GOVERNANCE.md.

### v0.9: Import and community

Safely import existing prefixes with provenance/prefix audits. Community recipes require CC0/DCO, host review, versioning, review grades and takedown procedures. Decide upstream/rebase policy.

### v1.0: Stable release

At least two active release maintainers with split key custody; an up-to-date runtime with verified assumptions; working Steam; 30 documented title/backend results; no open data-loss bugs; complete licence/source compliance and legal review; published docs; external security review and advisory process. Development prereleases do not waive these criteria.

## Security track

| Stage | Remaining security outcome |
|---|---|
| v0.1 | Hardened prefixes, tested kernel sandbox and broader runtime validation |
| v0.2 | Untrusted/offline modes, sharing/network controls, signed catalogs, anti-rollback and denial logs |
| v0.3 | Harmless validation suite, autostart monitoring and security UI |
| v0.5 | Compatibility-tested allow-list sandbox profiles |
| v1.0 | External review and published security evidence |

The installer enforces its input/consent/staging rules. It does not protect launched Windows programs because launching is still absent. Checksums identify bytes; Mallow is not an antivirus. A local unsigned receipt is not protection against malware already able to modify the same user's files.

## Open decisions

Naming, production signing/accounts, the media stack, sandbox integration, telemetry and long-term upstream policy remain tracked in [DESIGN.md §10](https://github.com/mixutin/Mallow/blob/main/docs/DESIGN.md#10-open-questions-decisions-needed). Repository/Pages/bundle identity is decided. New dependencies and hosts require explicit review. The system libarchive interface introduced for this installer is documented in the installation addendum; no new network download host was added.

## Verification backlog

Use [DESIGN.md §11](https://github.com/mixutin/Mallow/blob/main/docs/DESIGN.md#11-verification-backlog-assumptions-register). No feature may depend on an unverified low-confidence assumption. Keep synthetic tests, actual pinned-archive integration, published artifacts and personal-Mac reports separate. A build is not a game test.

## Future ideas and long term

Native ARM research, future Rosetta support, storefronts, controllers, broader compatibility data and cloud saves remain later research, not commitments. Follow upstream evidence before changing the design.

## Non-goals

No anti-cheat bypass, piracy/DRM-circumvention tooling, proprietary CrossOver implementation, bundled D3DMetal, hosted Microsoft redistributables/fonts/Steam, or antivirus claims. Intel hosts, 32-bit prefixes and Mac App Store distribution are outside v1.

## How to help

Test a development preview, implement a WF0 task, verify an assumption or improve tests/docs. Read [CONTRIBUTING.md](https://github.com/mixutin/Mallow/blob/main/CONTRIBUTING.md). Security reports go privately through [SECURITY.md](https://github.com/mixutin/Mallow/blob/main/SECURITY.md).

## How this roadmap changes

Every change reviews README, CHANGELOG, this roadmap and affected English/Finnish website pages. Check off only implemented/tested scope; retain actual-Mac acceptance separately. `docs/roadmap.md` embeds this English file. The Finnish summary lives in `docs-fi/roadmap.md` and must stay synchronized. Preserve dated posts and add new progress entries. CI success, prerelease publication, Pages deployment and real-device validation are distinct checks.
