<!-- SPDX-License-Identifier: 0BSD -->

# Mallow

**Run Windows games and apps on your Apple Silicon Mac. Free, open source, and sandboxed by default.**

Mallow is an open-source alternative to CrossOver. It will combine Wine, Rosetta 2 and DirectX-to-Metal translation with a native Mac app, a scriptable command-line tool, and a kernel sandbox around every Windows program.

[![Status: pre-alpha, design phase](https://img.shields.io/badge/status-pre--alpha%20%C2%B7%20design%20phase-orange)](https://github.com/mixutin/Mallow/blob/main/ROADMAP.md)
[![Licence: 0BSD](https://img.shields.io/badge/licence-0BSD-blue)](https://github.com/mixutin/Mallow/blob/main/LICENSE)

> **🚧 Pre-alpha: design phase.** No application code exists yet, so there is nothing to download or run. Everything on this page describes what Mallow is **planned** to do, based on the [design document](https://github.com/mixutin/Mallow/blob/main/docs/DESIGN.md) and the [security model](https://github.com/mixutin/Mallow/blob/main/docs/SECURITY_MODEL.md). Plans may change. If you need to run Windows software on a Mac today, see the comparison further down this page for tools that work now.

## What Mallow will do

- Keep each game or app in its own **bottle**: a separate Windows environment with its own `C:` drive, registry and settings.
- Install Steam in one click and run the games it downloads.
- Choose a DirectX-to-Metal translator for each game, and keep that choice even when Steam starts the game.
- Download a signed, open-source Wine runtime that is built in public, and keep it up to date.
- Keep Windows programs away from your personal files unless you choose to share a folder.
- Do all of this from a native SwiftUI app, or from the `mallow` command-line tool.

## How it works

```text
  Windows game or app (.exe)
          │
          ▼
  Wine ...................... answers the program's Windows API calls using macOS
          │
          ▼
  DirectX → Metal ........... D3DMetal, DXMT, or DXVK + MoltenVK draws the graphics with Metal
          │
          ▼
  Rosetta 2 ................. runs all of this x86-64 code on Apple Silicon
          │
          ▼
  macOS ..................... Metal, Core Audio, windows, keyboard, mouse and controllers
```

Mallow's job is everything around this stack. It will create bottles, download and verify the runtime, pick a graphics backend for each program, build the environment, and start Wine inside a kernel sandbox. Mallow will start Wine as a separate program and never link to it.

## Planned features

### 🔒 Secure by default

Wine is a compatibility layer, not a sandbox. Out of the box, a Windows program running under Wine can read your whole home folder, including SSH keys, browser profiles and documents. Mallow's goal is that **running a suspicious `.exe` puts at risk only the bottle it runs in, never the rest of your Mac.**

- **Kernel sandbox.** Every Windows program runs inside a macOS Seatbelt sandbox profile that Mallow generates for each bottle. The kernel enforces it, so it still applies when a program skips Wine and makes raw system calls.
- **Locked-down bottles.** There is no `Z:` drive exposing your whole Mac. Documents, Desktop and Downloads are real folders inside the bottle, not links into your home folder. Windows programs cannot create Mac file associations or open Mac apps on their own.
- **Untrusted mode.** Run a suspicious download in a disposable copy of a clean bottle (an APFS clone), with no network and no shared folders. The copy is deleted when the program exits. Unsigned files downloaded from the internet start in this mode by default.
- **Explicit sharing.** You share folders with one bottle at a time, and shares are read-only by default. Each bottle has a Security panel showing its trust mode, network switch, shared folders and recently blocked actions.
- **Signed downloads.** Runtimes and graphics backends come from a signed catalog and are checked with Ed25519 signatures and SHA-256 hashes. A mismatch stops the install. There is no "install anyway" button.
- **Honest limits.** No sandbox is perfect. A bug in the macOS kernel, a GPU driver or Rosetta could in principle be used to escape, and Mallow is not an antivirus. The [security model](https://github.com/mixutin/Mallow/blob/main/docs/SECURITY_MODEL.md) explains the threat model, the limits and the red-team test plan.

### An open runtime, built in public

- The **Mallow Runtime** will be Wine 11.0, built from CodeWeavers' published LGPL Wine sources plus three small patches of our own.
- It will be compiled in public GitHub Actions, and every runtime release will come with its complete corresponding source.
- It will be a separate download from the app. New versions will install side by side, and a runtime can be verified, repaired and rolled back.
- Until the Mallow Runtime is ready, Mallow will install a pinned standard WineHQ build and offer only the features that build supports.

### 🎮 Games and graphics

- **Graphics backends per bottle and per program:** D3DMetal (Apple's translator, for DirectX 12 and 11), DXMT (open source, Direct3D 10 and 11 to Metal), DXVK with MoltenVK (Direct3D 10 and 11 through Vulkan), and Wine's built-in wined3d. An `auto` setting picks one for you.
- **Choices that survive Steam.** A small patch in our runtime lets each game get its own backend, even when Steam starts it.
- **D3DMetal is never bundled.** You import it from your own copy of Apple's Game Porting Toolkit and accept Apple's licence yourself.
- **Performance and display options:** MSync, Retina mode, the Metal performance HUD, MetalFX upscaling, DirectX ray tracing (with D3DMetal), and Command/Option key mapping.
- **One-click Steam,** recipes for common dependencies, and winetricks for everything else. Before anything is downloaded, Mallow shows you the licence terms and the real download hosts.

### A Mac app and a full command-line tool

- A native SwiftUI app with a bottle list, a program grid with icons, settings, a runtime manager, a log viewer and guided setup.
- A `mallow` CLI that can do everything the app can, with JSON output and stable exit codes for scripts. For example (planned, not working yet):

  ```sh
  mallow runtime install standard-wine-stable-11.0_1
  mallow bottle create Test
  mallow run --bottle Test --wait notepad
  ```

- A log file for every launch, `mallow doctor` for common problems, and a diagnostics bundle to attach to bug reports.

### Planned requirements and limits

- A Mac with Apple Silicon, running macOS 15 or later.
- Rosetta 2. Mallow will offer to install it, but only after you accept Apple's licence.
- **Not planned for 1.0:** Intel Macs, games that need anti-cheat (kernel-level and most user-mode anti-cheat cannot work under Wine on macOS, and Mallow will never try to get around it), and the Mac App Store.
- **Rosetta's future:** Apple has said macOS 27 is the last release with full Rosetta, and macOS 28 keeps a subset for games whose scope is not yet clear. Mallow depends on Rosetta, so we are following this closely.

## Mallow and other tools

A short, factual comparison, based on each project's public information as of September 2026. If anything here is wrong or out of date, please [open an issue](https://github.com/mixutin/Mallow/issues).

| | **Mallow** | **CrossOver** | **Whisky** | **Heroic Games Launcher** | **Plain Wine** |
|---|---|---|---|---|---|
| What it is | Mac app and CLI for Windows games and apps | Commercial app for Windows apps and games | Free Mac app for Windows games | Launcher for Epic, GOG and Amazon games | The compatibility layer itself, used from Terminal |
| Status | Pre-alpha, design phase | Mature, actively developed | Archived in 2025; community forks continue | Actively developed | Actively developed |
| Cost | Free | Paid, with a free trial | Free | Free | Free |
| Licence | 0BSD (runtime LGPL-2.1-or-later) | Proprietary; CodeWeavers publishes its Wine changes under the LGPL | GPL-3.0 | GPL-3.0 | LGPL-2.1-or-later |
| Runs on | Apple Silicon Macs | macOS and Linux | Apple Silicon Macs | Windows, macOS and Linux | macOS, Linux and more |
| DirectX 12 through D3DMetal | Planned; you import your own copy | Included | Included | Depends on the Wine build you choose | No |
| Kernel sandbox around Windows programs | Planned, on by default | Not advertised | Not advertised | Not advertised | No (Wine is not a sandbox) |
| Support | Community | Included with purchase | None (archived) | Community | Community |

**If you need to run Windows software on a Mac today, CrossOver is the most complete option,** and buying it funds much of the Wine development that every project in this table relies on. Mallow aims to become a free, open and security-focused choice once it is ready.

Other open-source projects in this space include [Mythic](https://github.com/MythicApp/Mythic), a macOS game launcher, and [Bottles](https://github.com/bottlesdevs/Bottles), a Wine manager for Linux. Apple's Game Porting Toolkit is a tool for developers evaluating their games, not an end-user app.

## 🗺️ Roadmap

Mallow will be built in small milestones. Every feature lands in the core library and the CLI before it gets a user interface.

| Milestone | Focus |
|---|---|
| G0: Design sign-off | Before any code: name clearance, governance, licence files, contribution rules |
| v0.1: Foundations | Bottles, the CLI, the launch pipeline, secure-by-default bottles, a pinned standard Wine build |
| v0.2: Own runtime | The Mallow Runtime built in public CI, signed catalog, DXMT, DXVK, MSync |
| v0.3: Mac app | The SwiftUI app, guided setup, log viewer, Homebrew tap |
| v0.4: Steam and dependencies | One-click Steam, recipes, winetricks |
| v0.5: D3DMetal and upscalers | Game Porting Toolkit import, MetalFX, ray tracing |
| v0.6: Polish | Mac shortcuts, diagnostics bundle, accessibility |
| v0.8: Distribution | Developer ID signing, notarisation, automatic updates |
| v0.9: Import and community | Importing existing Wine prefixes, a community recipe repository |
| v1.0 | Release criteria met, including at least two maintainers, a complete licence audit and legal review |

Security work runs alongside these milestones, from secure-by-default bottles in v0.1 to an external security review for 1.0. See [ROADMAP.md](https://github.com/mixutin/Mallow/blob/main/ROADMAP.md) for details and the security model's [hardening roadmap](https://github.com/mixutin/Mallow/blob/main/docs/SECURITY_MODEL.md) for the security milestones. There are no release dates yet.

## 🤝 Get involved

Mallow is at the best stage for shaping its design. Reviews, questions and ideas are all welcome.

- **Discuss the design.** Read the [design document](https://github.com/mixutin/Mallow/blob/main/docs/DESIGN.md) and the [security model](https://github.com/mixutin/Mallow/blob/main/docs/SECURITY_MODEL.md), then join [GitHub Discussions](https://github.com/mixutin/Mallow/discussions) or [open an issue](https://github.com/mixutin/Mallow/issues).
- **Follow progress.** The [devlog](https://mixutin.github.io/Mallow/blog/) shares decisions, research and progress, including the parts that don't go to plan. It also has an [RSS feed](https://mixutin.github.io/Mallow/feed_rss_created.xml).
- **Contribute.** Start with [CONTRIBUTING.md](https://github.com/mixutin/Mallow/blob/main/CONTRIBUTING.md), and please follow the [Code of Conduct](https://github.com/mixutin/Mallow/blob/main/CODE_OF_CONDUCT.md). In short:
  - Sign off every commit with the [Developer Certificate of Origin](https://developercertificate.org/) (`git commit -s`).
  - Follow the clean-room rules. Never copy files from CrossOver. Never copy code from GPL projects such as Whisky, Heroic, Bottles or Mythic into Mallow's 0BSD code. Learning from their ideas is fine; the code must be your own.
  - Send fixes upstream to Wine, DXMT, MoltenVK and winetricks where possible.
- **Report security problems privately.** Follow [SECURITY.md](https://github.com/mixutin/Mallow/blob/main/SECURITY.md) instead of opening a public issue.

**Planned toolchain.** Swift 6.3 with the Command Line Tools only (`xcode-select --install`), so Xcode is not needed. The project uses Swift Package Manager and swift-testing. A script assembles the `.app` bundle, and most tests run against a fake Wine, so day-to-day work needs neither Xcode nor a real Wine runtime. The Wine runtime itself will be built in public GitHub Actions from CodeWeavers' published LGPL Wine sources.

## Documentation

- [Documentation site](https://mixutin.github.io/Mallow/), including [How it works](https://mixutin.github.io/Mallow/how-it-works/), the [FAQ](https://mixutin.github.io/Mallow/faq/) and [Legal & licensing](https://mixutin.github.io/Mallow/legal/)
- [Devlog](https://mixutin.github.io/Mallow/blog/)
- [Design document](https://github.com/mixutin/Mallow/blob/main/docs/DESIGN.md): architecture, licensing, runtime build, graphics, launch pipeline, testing
- [Security model](https://github.com/mixutin/Mallow/blob/main/docs/SECURITY_MODEL.md): threat model, sandbox, trust modes, red-team plan
- [Roadmap](https://github.com/mixutin/Mallow/blob/main/ROADMAP.md)
- [Contributing](https://github.com/mixutin/Mallow/blob/main/CONTRIBUTING.md)
- [Code of Conduct](https://github.com/mixutin/Mallow/blob/main/CODE_OF_CONDUCT.md)
- [Governance](https://github.com/mixutin/Mallow/blob/main/GOVERNANCE.md)
- [Security policy](https://github.com/mixutin/Mallow/blob/main/SECURITY.md)
- [Getting help](https://github.com/mixutin/Mallow/blob/main/SUPPORT.md)
- [Changelog](https://github.com/mixutin/Mallow/blob/main/CHANGELOG.md)

## Licence

Mallow's own code, scripts and documentation are released under the [BSD Zero Clause License (0BSD)](https://github.com/mixutin/Mallow/blob/main/LICENSE). You may use, copy, modify, sell and redistribute them for any purpose, commercial use included. No attribution is required.

Other parts keep their own licences:

| Part | Licence | Notes |
|---|---|---|
| Mallow app, `mallow` CLI, MallowKit, scripts, docs | 0BSD | |
| Mallow Runtime (Wine) | LGPL-2.1-or-later | A separate download, not part of the app. Every runtime release comes with its complete source. |
| Our Wine patches (`runtime/patches/`) | LGPL-2.1-or-later | They modify Wine, so they share its licence. |
| Recipes and JSON schemas | CC0-1.0 | Free for any tool to reuse. |
| DXMT | MIT up to v0.80, LGPL-2.1-or-later after | Separate backend download, with its licence texts. |
| DXVK-macOS | zlib | Separate backend download, with its licence text. |
| MoltenVK | Apache-2.0 | Included in the runtime, with its licence texts. |
| swift-argument-parser; Sparkle (from v0.8) | Apache-2.0; MIT with extra notices | Listed in [THIRD_PARTY_LICENSES.md](https://github.com/mixutin/Mallow/blob/main/THIRD_PARTY_LICENSES.md). |
| D3DMetal (Apple Game Porting Toolkit) | Apple proprietary | Never bundled, downloaded or hosted by Mallow. You import your own copy and accept Apple's licence. |
| Steam, Microsoft redistributables, fonts | Each vendor's terms | Downloaded from the vendor, or from a named mirror, only after you have seen the terms. Never hosted by Mallow. |

Mallow is designed to start Wine as a separate program and never link to it, so Wine's LGPL does not extend to Mallow's 0BSD code. Credits for the projects that shaped Mallow's design are in [NOTICE](https://github.com/mixutin/Mallow/blob/main/NOTICE).

## Acknowledgements

Wine on the Mac exists in its current form thanks to the [Wine project](https://www.winehq.org/) and to CodeWeavers, which funds a large share of Wine development, especially on macOS, and publishes its Wine changes under the LGPL. The Mallow Runtime will be built from those sources. Mallow will send its fixes upstream wherever it can, and will point its users at its own issue tracker, never at CodeWeavers' support.

Mallow's design also learned from earlier open-source projects, including Whisky, Heroic, Bottles, Mythic, DXMT, DXVK-macOS, MoltenVK and Gcenx's Wine builds. See [NOTICE](https://github.com/mixutin/Mallow/blob/main/NOTICE).

## Trademarks

CrossOver is a registered trademark of CodeWeavers, Inc. Mallow is not affiliated with, endorsed by or sponsored by CodeWeavers, Inc. The name is used here only to describe what Mallow is an alternative to.

Apple, Mac, macOS and Metal are trademarks of Apple Inc., registered in the U.S. and other countries and regions. Windows and DirectX are trademarks of the Microsoft group of companies. Steam is a trademark of Valve Corporation. All other names belong to their owners and are used only to describe compatibility. Mallow is not affiliated with Apple, Microsoft, Valve or the Wine project.

---

Copyright (C) 2026 Mixutin and the Mallow contributors
