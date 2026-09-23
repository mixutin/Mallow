# Mallow: Design Document

| | |
|---|---|
| Status | Draft 2, for review by the founding maintainers. It resolves the Draft 1 review (§13). |
| Date | 2026-09-23 |
| Scope | Gate G0 (before any code), then v0.1 (MVP) through v1.0 |
| Product | Mallow, an open-source (0BSD) way to run Windows games and apps on Apple Silicon Macs using Wine, Rosetta 2 and DirectX-to-Metal translation |
| Companion | `docs/SECURITY_MODEL.md` (sandboxing and trust modes). Where the two differ, see §3.14. |

## How to read this document

**Confidence tags.** Every factual claim this design depends on carries a tag:

| Tag | Meaning |
|---|---|
| **[H]** | Verified against a primary source (upstream source code, the vendor's own documentation, the local `man` pages, a registry API), or tested on the design host. |
| **[M]** | Taken from a credible secondary source, or only partly verified. Safe to design against, but a test must confirm it. |
| **[L]** | A single third-party report, an inference, or unverified. No code may depend on an [L] item until it has been verified. Every [L] item is listed in §11 (verification backlog). |

**Other conventions.**

- "Design host" means the Apple M4 machine this was written on: 16 GB RAM, macOS 26.5, Swift 6.3.2 with Command Line Tools only (no Xcode), about 1.6 GB of free disk.
- Reference numbers such as [R8] point to §12.
- "CX source" means the LGPL source tarball CodeWeavers publishes for CrossOver 26.3.0. We use it only under its LGPL terms (§2.7).
- **Naming.** Draft 1 used the working name "Decanter", which belongs to another active project (§2.6). The product is now **Mallow**. Every product-visible identifier is listed once, in §2.6.1. On the design host the working directory is still called `Decanter/`. It is renamed `mallow/` when the repository is published. All paths in this document are relative to the repository root.
- "Normative" means that engineers who implement modules in parallel must follow the text exactly. §3.4 (Swift API) and §3.7 (wire formats) are normative.

---

## 0. Summary

Mallow is a native Mac app plus a scriptable CLI. It manages **bottles** (isolated Wine prefixes) and runs Windows programs in them under Rosetta 2. It has three layers:

1. **MallowKit**, a Swift library that does all the work: bottles, runtimes, graphics backends, launch planning and process management, registry and settings, program discovery, recipes, and diagnostics.
2. **`mallow`**, a CLI that exposes all of MallowKit. Everything the app can do, the CLI can do.
3. **The Mallow app**, a SwiftUI frontend over the same library.

The Wine **runtime** is not shipped inside the app. It is a separately versioned, signed download that we build in public CI. It uses the LGPL Wine sources in CodeWeavers' CrossOver 26.3.0 source drop, three small patches we write ourselves, and dependency libraries that we build from pinned source with our own scripts. Graphics backends (DXMT, DXVK-macOS) are separate signed components that sit on top of one base runtime. D3DMetal is **never** distributed by us. Users import it from their own copy of Apple's Game Porting Toolkit.

### Key decisions

1. **The licence is 0BSD** for the frontend (MallowKit, CLI, app, scripts, docs), chosen by the project owner. Anyone may use, modify, sell and redistribute Mallow for any purpose, without attribution. The runtime stays LGPL-2.1-or-later, recipe data is CC0-1.0, and no copyleft code may enter the 0BSD parts (§2.1).
2. **The runtime is our own build, from CX-source Wine 11.0.** Only a CrossOver-derived Wine offers MSync, the `macdrv_functions` export that DXMT needs, and the `CX_APPLEGPTK_LIBD3DSHARED_PATH` hook that D3DMetal needs. The hook is verified in the LGPL source **[H]** [R32]. Until our runtime exists, a sha256-pinned "Standard Wine" build (Gcenx's WineHQ packages) can be installed from inside the app, limited to the capabilities it really has (§3.11.6).
3. **Backends are chosen per process image, inside Wine.** Steam starts games with its own environment, so a choice made only when Mallow launches something cannot reach those games. Our patch 0002 makes ntdll read a per-bottle **DLL path map** file. The file says which backend directories each executable image gets. It also says whether that image may load Apple's `libd3dshared` (§3.11.4, §4.5). Translation-DLL load orders live in the registry, not in `WINEDLLOVERRIDES`, because the environment variable would override every per-program rule **[H]** [R48].
4. **The runtime must not rely on `DYLD_*` variables.** SIP strips them whenever a process passes through a protected binary such as `/bin/sh` **[H]** (tested). `dlopen` of a bare leaf name checks the caller's `LC_RPATH` before any fallback path **[H]** [R33]. So the runtime gets rewritten install names and `LC_RPATH`s, and the launcher execs `bin/wine` directly with a fully specified environment.
5. **The core is a pure launch planner.** `LaunchPlanner` turns a bottle, a runtime, the installed backends, host facts and a request into a `LaunchPlan` value. The plan holds any pre-launch prefix work, the executable, argv, the complete environment, cwd and the log file. Planning has no side effects, so it can be golden-tested without Wine.
6. **One writer per piece of state.** Every Wine process for a bottle is spawned through `LaunchService`, and `LaunchService` alone writes `AppliedState`. Bottle files are edited under an advisory `flock` (§3.5).
7. **The toolchain is SwiftPM only.** swift-testing is the only test framework, because XCTest does not exist under Command Line Tools **[H]**. The `.app` bundle is assembled by a shell script. Anything that needs Xcode (Icon Composer assets, notarization with a Developer ID) is optional and runs in CI.
8. **Nothing is hosted that we may not redistribute.** No D3DMetal, no Microsoft redistributables, no fonts, no Steam client. Recipes tell the user where each download comes from, including third-party mirrors, and show the vendor's terms first (§2.5).

---

## 1. Goals and non-goals

### 1.1 Goals for v1.0

| ID | Goal |
|---|---|
| G1 | Run 64-bit and 32-bit Windows programs on Apple Silicon with macOS 15 or later, through an x86_64 Wine under Rosetta 2. Bottles use new WoW64 only. |
| G2 | Bottles: create (from templates), rename, delete (to the Trash), open in Finder, stop, force-stop. Settings can be set per bottle and per program. |
| G3 | A `mallow` CLI with the full feature set, JSON output, and stable exit codes, so it can be used in scripts and tests. |
| G4 | A native SwiftUI app with bottle list, program grid, settings, runtime manager, log viewer and onboarding. |
| G5 | A runtime manager that installs, verifies, rolls back and removes signed runtimes and backends from a signed catalog, and can import a Standard Wine build. |
| G6 | Per-bottle and per-program graphics backends: D3DMetal (user-supplied), DXMT, DXVK-macOS over MoltenVK, and wined3d, plus an `auto` policy. |
| G7 | Performance and display toggles: MSync, Rosetta AVX advertisement, Retina/DPI, Command/Option key mapping, Metal HUD, DXR, DLSS→MetalFX (D3DMetal), and DXMT NVEXT and MetalFX spatial upscaling. |
| G8 | A one-click Steam recipe, a declarative recipe engine, native verbs, and winetricks for everything else. |
| G9 | A log file for every launch with a reproducible header, a diagnostics bundle, and `mallow doctor`. |
| G10 | Clean licensing: every shipped component is openly licensed, corresponding source is published, and no CodeWeavers-proprietary or Apple-proprietary material is included (§2). |
| G11 | The frontend can be developed and tested on a machine that has only Command Line Tools (§7). |

### 1.2 Non-goals for v1

- **Anti-cheat.** Kernel-level and most user-mode anti-cheat cannot work under Wine on macOS. We show an "anti-cheat: unsupported" badge from recipe metadata, and we never attempt to work around anti-cheat **[M]** [R39].
- **Intel Macs** as hosts. Probably workable, but not supported.
- **An ARM64-native Wine** (ARM64EC plus FEX). Post-1.0 research only (§8.3).
- **32-bit (`win32`) prefixes.** They are deprecated in Wine 11 **[H]** [R7].
- **Storefront integrations** (Epic via legendary, GOG via gogdl). Planned post-1.0.
- **A large curated compatibility database.** v1 ships a handful of recipes. A community recipe repository follows later.
- **macOS Game Mode for Wine windows.** Apple DTS says it does not carry over to windows owned by child processes **[L]** [R44].
- **Mac App Store distribution.** The App Store sandbox and spawning Wine are incompatible.
- **Wineskin-style per-game app wrappers.** We only create lightweight Mac shortcuts.
- **Hosting or mirroring Microsoft redistributables or fonts**, or bundling D3DMetal in any form.

### 1.3 Design principles

1. **CLI first.** Every feature lands in MallowKit and the CLI before it gets UI.
2. **Planning is separate from effects.** Planning is pure. Effects go through injectable protocols: `ProcessSpawner`, `HTTPClient` and `CodeSignatureChecker`.
3. **Data drives behaviour.** The catalog, backend manifests and recipes are JSON, so they can change without an app release.
4. **Capabilities are gated honestly.** The UI offers a feature only when the runtime manifest or a probe says the runtime supports it. Every greyed-out control says why.
5. **Registry files are never edited directly.** All registry writes go through a Wine process (`regedit /S`), which talks to the running `wineserver`. The server flushes its registry every 30 seconds and when it exits **[H]** [R9].
6. **Every write is atomic and serialised.** Write to a temp file, fsync, then rename, as Bottles does **[H]** [R40]. The whole read-modify-write happens under an advisory `flock` on a sidecar lock file. `revision` numbers only detect stale UI state (§3.5).
7. **The main thread never does heavy work.** Every MallowKit API that hashes, extracts, scans or parses large files runs off the main actor (§3.5).
8. **Upstream first.** Fixes go to Wine, DXMT, MoltenVK and winetricks wherever possible (§2.8).

---

## 2. Legal and licensing model

> This section records engineering decisions and the facts they rest on. It is **not legal advice**. A lawyer must review §2.4 (Apple GPTK), §2.3 (the LGPL source procedure) and §2.6 (the name) before v1.0. The name review must happen before gate G0 closes.

### 2.1 Licences (decided)

| Part | Licence | Notes |
|---|---|---|
| MallowKit, `mallow` CLI, Mallow app, `fake-wine`, repository scripts (`scripts/`, `runtime/**/*.sh`, `*.py`) | **0BSD** | Chosen by the project owner (2026-09-23): any use, including commercial use, modification and redistribution, with no attribution required. Every source file starts with `// SPDX-License-Identifier: 0BSD` (or `#` for scripts). |
| Wine patches in `runtime/patches/` | **LGPL-2.1-or-later** | Derivatives of Wine. Header: `SPDX-License-Identifier: LGPL-2.1-or-later`. |
| Recipe data (`recipes/**`, the future community recipe repository) | **CC0-1.0** | Lets third parties reuse the data and lets us compile contributed recipes into the app. CC0 and 0BSD are both public-domain-equivalent, so recipe data and code mix freely (§2.9). |
| JSON Schemas (`schemas/`) | **CC0-1.0** | So other tools can adopt the formats. |
| Documentation (`docs/`) | 0BSD (same as the code) | Keeps doc snippets and code snippets freely interchangeable. |

**Repository state and the G0 actions.** The committed `LICENSE` (commit `dfd8365`) is the unmodified 0BSD text and names "Mixutin and the Mallow contributors". It is final. Gate G0 (§8) requires:

1. Keep `LICENSE` as the unmodified 0BSD text.
2. Add the line "Copyright (C) 2026 Mixutin and the Mallow contributors" to `README.md` and `NOTICE`.
3. Add SPDX headers to every file.
4. Write `NOTICE`. 0BSD does not require it, but it credits, as a courtesy, the prior art whose *ideas* shaped this design: Whisky [R20], frankea/Whisky [R18][R19], Heroic [R42], Bottles [R40], Mythic [R41], and Gcenx's WINEDLLPATH_PREPEND idea [R22]. It also points to `THIRD_PARTY_LICENSES.md`.
5. Add `recipes/LICENSE` and `schemas/LICENSE` (CC0-1.0 text) [R87].
6. Adopt DCO sign-off (`Signed-off-by:`) for all contributions [R86]. Contributors certify they have the right to submit their code under 0BSD.

**No code from copyleft frontends.** The frontend is 0BSD, so it must never contain code copied from GPL-licensed frontends such as Whisky, frankea/Whisky, Heroic, Bottles or Mythic. GPL code would force the combined frontend to be GPL, which defeats the licence choice. We may study those projects for ideas, behaviours and file formats, which copyright does not protect, and we credit them in `NOTICE`. Every line of Mallow's frontend is written fresh:

- Some type names match frankea/Whisky's: `WineEnvironment`, `DLLOverrides`, `GPTKImporter`, `BottleSettings` and the backend resolver. Some behaviours follow it too: the D3D12-hiding preset (§4.3), the per-program NVAPI rule, and the user-supplied GPTK import model. Names and behaviours are fine; the implementations must be our own.
- Reviewers reject pull requests that look transcribed from a GPL project. A contributor who has just read a GPL implementation of the same function says so in the PR, and a second maintainer reviews it.
- Copyleft code *is* allowed in the separately distributed LGPL runtime (`runtime/patches/`, LGPL-2.1-or-later), because the runtime is a separate program (see below).

**Direct Swift dependencies:** swift-argument-parser 1.8.2 (Apache-2.0) **[H]** [R34], and from v0.8 Sparkle 2.10.0. Sparkle's licence is MIT/Expat for the core plus notices for bsdiff (BSD-2), sais-lite and ed25519 **[H]** [R35][R70]. All of these are permissive. They keep their own licences, and their notices ship in `THIRD_PARTY_LICENSES.md`. 0BSD puts no conditions on combining with them.

**The frontend and the runtime are separate programs.** The frontend only `exec`s Wine binaries and never links them. That makes the two a mere aggregate, so the runtime's LGPL does not reach the 0BSD frontend. This is the standard FSF reading **[M]** [R45].

### 2.2 How each component reaches the user

| Component | Licence | How it is obtained | Where it lives | Our obligations |
|---|---|---|---|---|
| Mallow app and `mallow` CLI | 0BSD | Built from this repo | `Mallow.app` | `LICENSE`, `NOTICE` and `THIRD_PARTY_LICENSES.md` inside the bundle; a link to the source of the exact release tag (§3.10) |
| swift-argument-parser 1.8.2 | Apache-2.0 | SwiftPM | Linked into the CLI | Its licence text in `THIRD_PARTY_LICENSES.md` (Apache-2.0 §4(a)) |
| Sparkle 2.10.0 (v0.8+) | MIT plus BSD-2 (bsdiff), sais-lite and ed25519 notices | SwiftPM binary target | `Contents/Frameworks` | Sparkle's whole `LICENSE` file in `THIRD_PARTY_LICENSES.md` |
| **Mallow Runtime** (Wine 11.0 from the CX 26.3.0 LGPL source, plus our patches) | LGPL-2.1-or-later | **Downloaded** from our GitHub Releases through the signed catalog | `Runtimes/<id>/` | Corresponding source beside every binary (§2.3); runtime stays relinkable |
| Wine's own statically built third-party code (`libs/*`: capstone, jxr, ldap, tiff, png, jpeg, gsm, lcms2, musl, xml2, xslt, compiler-rt, faudio, tomcrypt, and others) | Mixed permissive (BSD-2/3, OpenLDAP, IJG, libpng, MIT, …) | Inside Wine's PE DLLs | `lib/wine/*-windows/` | Their notices in `licenses/wine-bundled/<lib>/`, generated mechanically; the IJG sentence in `THIRD_PARTY_LICENSES.md` (§2.3) **[H]** [R85] |
| MoltenVK 1.4.2 | Apache-2.0, plus embedded SPIRV-Cross, SPIRV-Tools, cereal (BSD-3), Vulkan-Headers | Inside the runtime | `lib/` | Licence texts for MoltenVK and each `ExternalRevisions` component **[M]** [R69] |
| FreeType | FTL (chosen over GPLv2) | Built from source by `runtime/deps/` | `lib/` | Credit line |
| GnuTLS, Nettle, GMP, libtasn1, libidn2, libunistring | LGPL-2.1+ / LGPL-3+ / dual | Built from source by `runtime/deps/` | `lib/` | Source beside the binary; dynamically linked and replaceable |
| GLib, libffi, PCRE2, ORC, GStreamer core, base and a subset of good, gst-libav | LGPL-2.1+ (libffi MIT, PCRE2 BSD-3, ORC BSD-2) | Built from source by `runtime/deps/` with `-Dgpl=disabled`; ugly and bad are **not** built | `lib/`, `lib/gstreamer-1.0/` | Source beside the binary; licence audit (§2.3) |
| FFmpeg (decoders, demuxers and parsers only) | **LGPL-2.1-or-later** | Built from pinned source: `--disable-gpl --disable-nonfree --disable-version3 --disable-encoders --disable-programs` | `lib/` | Source beside the binary; `avcodec_license()` must report LGPL (§3.11.2); codec patents in §9 |
| SDL2 2.32.x (real SDL2, not sdl2-compat) | zlib | Built from source | `lib/` | Notice |
| zlib, libpng, brotli, bzip2 | zlib, libpng, MIT, bzip2 | Built from source | `lib/` | Notices |
| wine-mono 10.4.1, wine-gecko 2.47.4 (the versions `addons.c` in Wine 11.0 expects) **[H]** | MIT and mixed; MPL-2.0 (Gecko) | Inside the runtime | `share/wine/{mono,gecko}` | Source beside the binary (MPL requires telling users where the source is) |
| DXMT v0.80 | MIT up to v0.80, LGPL-2.1+ afterwards **[H]** [R12]. `winemetal.so` statically links LLVM 15 (Apache-2.0 WITH LLVM-exception, plus the legacy NCSA section) **[H]** [R13]. It also vendors Microsoft DXBCParser (MIT), NVIDIA nvapi headers (MIT) and mingw DirectX headers | **Downloaded** backend component, repackaged from the upstream release | `Backends/dxmt-0.80/` | All of those licence texts in the component's `licenses/`; `staticComponents` in `backend.json` (§3.7.5); source beside the binary once we move past v0.80 |
| DXVK-macOS 1.10.3-20230507-repack | zlib | **Downloaded** backend component | `Backends/dxvk-macos-1.10.3-20230507/` | Notice, and a `staticComponents` list (may be empty, but must be present) |
| winetricks 20260125 | LGPL-2.1+ | **Downloaded on first use** through a catalog tool entry (`format: "file"`), sha256-pinned | `Tools/winetricks-20260125/` | It is source code; keep its licence header |
| cabextract | GPL-2.0+ | v0.x: user installs it with Homebrew. v1.0: we build and ship it with its source | `Tools/` | Source beside the binary once we ship it |
| **D3DMetal / Game Porting Toolkit** | Apple proprietary, non-commercial (EA18380) **[H]** [R16] | **User-supplied import only** (§2.4) | `UserSupplied/D3DMetal/<ver>/` | Never redistribute it, never upload it, keep it out of diagnostics bundles |
| Steam client | Proprietary (Steam Subscriber Agreement) | Downloaded at run time from Valve's CDN after an explicit user action | Inside the bottle | Never host or mirror it |
| Microsoft redistributables and fonts | Proprietary, with per-package terms | Downloaded at run time after the terms are shown (§2.5). **Not all come from Microsoft:** `corefonts` comes from the third-party GitHub mirror `github.com/pushcx/corefonts`, and `d3dcompiler_47` from `raw.githubusercontent.com/mozilla/fxc2` **[H]** [R66] | Inside the bottle | Never host or mirror them; name the real download host |
| Anything from CrossOver.app | Proprietary | **Never**. Import paths refuse it (§2.4, §3.4.3) | none | none |

### 2.3 LGPL compliance procedure (for every runtime or backend release)

**Which clauses apply.** A runtime binary is object code of the Library itself, a work based on the Library. So LGPL-2.1 **§1** (keep the notices and give a copy of the licence) and **§4** (object code must be accompanied by the source, or the source must be offered as equivalent access "from the same place") apply **[H]** [R45]. §6, which is about works that *use* the Library, does not. §4 has **no written-offer option**. For the LGPL-3 components (GMP, Nettle, libunistring), LGPL-3 incorporates GPL-3, and we rely on GPL-3 §6(d), "equivalent access … through the same place" **[H]** [R57].

**Hard rule (applies to every mirror, CDN or cache we ever operate or endorse).** No runtime, dependency or backend binary may be served from any host that does not serve the matching source assets beside it. A new download host (for example an R2 bucket) is only allowed after it carries both the binaries and the source assets.

Each GitHub Release that carries a runtime binary also carries:

1. `mallow-runtime-<ver>-source.tar.xz`. It holds `sources/wine` exactly as extracted from `crossover-sources-26.3.0.tar.gz`, our patches, the `runtime/` scripts at the tagged commit, and `inputs.json`. The GitHub-generated source zip is **not** enough on its own, because it lacks the CX tree.
2. `mallow-deps-<depsHash>-sources.tar.xz`. It holds every dependency's upstream source tarball, every patch we apply to it, and **our own build scripts** (`runtime/deps/**`, which are "the scripts used to control compilation and installation"). The same file is published beside the dependency artifact in the `deps-<depsHash>` release (§3.11.2). Because we build dependencies ourselves, no Homebrew formula, patch or bottle ever becomes part of the corresponding source (§13, L4).
3. Inside the runtime archive: `licenses/`, generated mechanically by `runtime/scripts/gen-licenses.py`:
   - `licenses/COPYING.LIB` and `licenses/AUTHORS` from Wine (unmodified);
   - `licenses/wine-bundled/<lib>/…`, a copy of every `LICENSE*`, `COPYING*`, `COPYRIGHT*` and `README*`-with-licence file under the Wine tree's `libs/*`;
   - `licenses/deps/<name>/…` for every dependency built by `runtime/deps/`;
   - `licenses/moltenvk/…` for MoltenVK and each `ExternalRevisions` component (SPIRV-Cross, SPIRV-Tools, cereal, Vulkan-Headers);
   - `licenses/THIRD_PARTY_LICENSES.md`, which includes the IJG sentence "this software is based in part on the work of the Independent JPEG Group" **[H]** [R71];
   - `licenses/SOURCE.md`, which gives the exact release URLs of items 1 and 2.
4. **Source retention.** Source assets stay available for as long as any copy of the matching binary is offered by us. Runtime releases are never deleted. If one must be withdrawn, its binary assets are removed first. As an extra precaution for the LGPL-3 components, we keep the source assets for at least 3 more years after that.
5. **Relinkability.** The runtime is ad-hoc signed without hardened runtime and without library validation. This keeps users' ability to swap LGPL libraries, as LGPL-3 §4(d) requires for GMP and Nettle. Do not enable library validation on Wine binaries.
6. **CI gates** (`verify-runtime.sh`, §3.11.2):
   - every `libs/*` directory in the Wine source has a `licenses/wine-bundled/<lib>` entry;
   - every bundled dylib has a `licenses/deps/<name>` entry and a licence on the SPDX allowlist in `runtime/deps/inputs.json`;
   - `manifest.components[].license` is generated from this audit, never written by hand.
7. **Where users see it.** The runtime installer and the Runtimes window show the source URL from `licenses/SOURCE.md`, and the Acknowledgements window links to it.

Backends follow the same procedure. `backends.yml` fails when a backend has no `staticComponents` list (§3.7.5).

### 2.4 D3DMetal (Apple Game Porting Toolkit)

**Facts.**

- The same licence text (EA18380, dated 8/17/2023) ships with GPTK 1.1, 2.x and 3.0 **[H]** [R16].
- Clause 2A(i) limits use to "developing, testing, or evaluating video games".
- Clause 2A(iii) allows distribution "solely for non-commercial purposes".
- Clause 2D forbids reverse engineering, modification and derivative works.
- The GPTK 4 licence has not been checked **[L]**.
- Payload layout comes from Apple's own GPTK 3.0 Read Me, which names `redist/lib/wine/x86_64-{unix,windows}/…` and the MetalFX files `wine/x86_64-{unix,windows}/nvngx-on-metalfx.*` **[H]** [R17]. The Read Me documents only x86_64 directories, so we treat the payload as x86_64-only. The importer confirms the layout on the user's own disk image (V19).

**Rules.**

1. Mallow **never downloads, bundles, mirrors or hosts** D3DMetal. The catalog has no entry for it. CI rejects any archive that contains `D3DMetal.framework` or `libd3dshared.dylib`.
2. **Import sources.** Users import either:
   - (a) Apple's "Evaluation environment for Windows games" disk image, which they downloaded with their own Apple ID, or
   - (b) a folder that has the same `redist/lib` layout.

   `GPTKImporter` refuses a source that `ProvenanceGuard` rejects (inside a `com.codeweavers.*` bundle, §3.4.1). It then checks the signatures of **both** `D3DMetal.framework` and `libd3dshared.dylib`. It accepts `anchor apple`, or `anchor apple generic` with a leaf-certificate team ID on `TrustedAppleTeams.gptk`. Which of the two Apple actually uses is unverified **[L]** (V24). `import.json` records the requirement observed on the user's copy. We do not take Apple binaries out of other vendors' products. This is the same user-supplied model used by frankea/Whisky and wyn **[H]** [R18].
3. **Licence acceptance.** The importer shows Apple's licence (`License.pdf` or `.rtf`) **from the user's own disk image** and requires an explicit "I accept" before copying. We store the acceptance time and the licence file's sha256 in `import.json`. The CLI needs `--accept-license`, or it asks interactively.
4. The payload is copied **verbatim** with `ditto`, which preserves symlinks and signatures, into `UserSupplied/D3DMetal/<version>/payload/`. We never modify or re-sign it. Renaming and arranging are done only with **symlink views** (§4.6). The quarantine attribute is removed only if it is present.
5. Only the D3DM variables Apple documents appear in the UI: `D3DM_SUPPORT_DXR`, `D3DM_ENABLE_METALFX`, `D3DM_DXIL_PROCESS_DEBUG_INFORMATION` **[H]** [R17]. Undocumented `D3DM_*` names can only be set through the generic "custom environment" field. We do not inspect the binary beyond reading `version.plist`, because clause 2D forbids it.
6. **Legal risk.** Clause 2A(i) arguably does not cover end-user gaming. The import model puts the use decision with the user, who has accepted Apple's licence directly. This must go to legal review (§10, Q3).
7. **Other import paths never bring D3DMetal in by the back door.** Runtime imports, Standard Wine imports and bottle imports all run `ProvenanceGuard` (§3.4.1). It refuses trees that contain D3DMetal or CrossOver files, and it quarantines Apple translation DLLs found in an imported prefix. The only way in is the GPTK import, with its licence screen.

### 2.5 Other third-party content

- **Every recipe states where its downloads come from.** The recipe schema (§3.7.7) requires `license` (name and URL of the vendor's terms), `sourceHosts` (every host a download may come from) and `sourceKind` (`vendor` or `thirdPartyMirror`). The runner shows the terms and the real hosts before downloading anything. The CLI needs `--yes`.
- **Built-in recipes and verbs in v1:**

  | Recipe | Downloads from | Kind | Terms shown |
  |---|---|---|---|
  | `steam` | `cdn.akamai.steamstatic.com` | vendor | Steam Subscriber Agreement |
  | `vcrun2022` (native steps) | `aka.ms`, `download.visualstudio.microsoft.com` | vendor | Microsoft Visual C++ Redistributable licence terms |
  | `corefonts` (through winetricks) | `github.com/pushcx/corefonts` | **third-party mirror**; Microsoft stopped distributing the fonts in 2002 | Microsoft Core Fonts EULA |
  | `d3dcompiler_47` (through winetricks) | `raw.githubusercontent.com/mozilla/fxc2` | **third-party mirror** | Windows SDK redistributable terms |

  The exact terms URLs are pinned when each recipe is written **[M]**.
- **`dotnet48` is not a built-in recipe.** Microsoft's .NET Framework supplemental terms allow its use only by people licensed to use Windows **[M]** [R67]. Most Mac users are not, so a one-click install would invite a breach. Bottles use wine-mono by default. `mallow winetricks dotnet48` still works, but it prints that the licence requires a Windows licence and needs `--yes`.
- **Winetricks runs unattended (`-q`),** which accepts installers' EULAs without showing them. So Mallow shows the terms from `TermsCatalog` (§3.4.9) **before** it starts winetricks. That covers recipe steps, `mallow verb install` and the `mallow winetricks` passthrough, which also needs `--yes`. Verbs missing from `TermsCatalog` get a generic notice ("this downloads third-party software under its own licence").
- **Winetricks downloads** go straight from the verb's own sources into `~/Library/Caches/Mallow/winetricks` (`W_CACHE`). We never re-host them. Link rot is a known risk (§9).
- **Rosetta 2.** Installing Rosetta means accepting Apple's software licence agreement. Mallow never passes `--agree-to-license` without the user's recorded consent (§3.9, §3.4.1) **[H]** [R64].

### 2.6 Trademarks and naming

- The product is **"Mallow"**. The runtime is **"Mallow Runtime"**, described as "based on Wine 11.0".
- "CrossOver", "CX", "CodeWeavers", "Whisky" and "WineHQ" never appear in product names, runtime IDs, bundle identifiers, UI labels or marketing.
- Factual attribution is allowed only where it is needed for provenance or licence compliance. For example, `manifest.baseSource.description` reads "Wine sources from CodeWeavers' LGPL source release 26.3.0".
- **User-visible strings inherited from the CX source are audited.** The CX tree's `programs/winedbg/winedbg.rc` sends crash-dialog users to codeweavers.com support pages **[H]** [R58]. Patch 0003 points it at our tracker instead, and CI audits the whole tree (§3.11.3, §3.11.4). Copyright headers and `AUTHORS` are never altered.
- Whether the name "Wine" is a trademark, and who holds it, is unverified **[L]**. We use "Wine" only descriptively.

**Why the name changed.** Draft 1's "Decanter" is already used by an active GPL-3.0 project with the same purpose: github.com/ricardothesillyllama/Decanter, "Run Windows games on Apple Silicon macOS. A maintained alternative to Whisky", created 2026-08-25, v0.9.1 released 2026-09-22 **[H]** [R53]. Its `Package.swift` declares `DecanterKit`, `decanter` and `DecanterApp` **[H]** [R53], the same names as Draft 1. The reviewer also reports that it uses the same data folder, which would have made both apps share bottles and runtimes; we did not re-check that part. "Decanter" is also a wine-magazine brand.

**Clearance done so far for "Mallow" (2026-09-23).** "Mallow" is the name already used in this repository's `LICENSE` and `docs/SECURITY_MODEL.md`.

| Check | Result | Tag |
|---|---|---|
| GitHub repositories named "mallow" that relate to wine, macOS or Windows games | none | **[H]** [R77] |
| Homebrew formula or cask `mallow` | none (HTTP 404) | **[H]** [R82] |
| Mac App Store "mallow" | no app of that name | **[H]** [R76] |
| iOS App Store "mallow" | several unrelated apps, including "mallow - no buy tracker" (getmallow.app). These are class 9 goods, but not in our category | **[H]** [R74][R76] |
| Software-services company | Mallow Technologies Pvt Ltd (custom app development, India), which is class 42 services, not our category | **[H]** [R75] |
| GitHub org `mallow-project` | free (not yet registered by us) | **[H]** [R77] |
| USPTO and EUIPO searches in classes 9 and 42 | **not done** | **[L]** V31 |

**Decision.** "Mallow" is adopted, with the formal USPTO and EUIPO searches (and a lawyer's opinion) as a **G0 exit criterion**. If they fail, the fallback name is "Mullion". Its quick check (GitHub, Homebrew, both App Stores) found no conflict in our category **[H]** [R76][R77]. Every identifier comes from `ProductIdentity` (§3.4.1) and the table below, so a rename before G0 closes is mechanical.

#### 2.6.1 Product identifiers (authoritative list)

| Identifier | Value |
|---|---|
| Product name | `Mallow` |
| SwiftPM package / library / CLI / app targets | `Mallow` / `MallowKit` / `mallow` (target `MallowCLI`) / `MallowApp` |
| Bundle identifier | `io.github.mallow-project.Mallow`. This needs no purchased domain; we control it once the `mallow-project` GitHub org exists (Q4) |
| URL scheme | `mallow://` |
| Environment variable prefix | `MALLOW_` (`MALLOW_HOME`, `MALLOW_FAKE_WINE`, `MALLOW_CLI`, `MALLOW_UPDATE_GOLDENS`, `MALLOW_REAL_RUNTIME`) |
| Data folders | `~/Library/Application Support/Mallow`, `~/Library/Caches/Mallow`, `~/Library/Logs/Mallow` |
| Data-root marker | `.mallow-root.json` with `"schema": "io.github.mallow-project.data-root/v1"` (§3.4.1) |
| Per-bottle metadata folder | `<bottle>/.mallow/` |
| Mac shortcuts folder | `~/Applications/Mallow/` |
| Runtime ID prefix | `mallow-runtime-` (e.g. `mallow-runtime-11.0-r1`) |
| Signature file format tag | `mallow-sig-v1` |
| GitHub org / repo / Pages | `mallow-project` / `mallow-project/mallow` / `https://mallow-project.github.io/mallow/` |
| Catalog URL | `https://mallow-project.github.io/mallow/catalog/v1/catalog.json` |
| Homebrew tap | `mallow-project/homebrew-tap` (`brew install --cask mallow-project/tap/mallow`) |
| CLI symlink | `~/.local/bin/mallow` |

**Data-root safeguard.** `MallowPaths.ensureDirectories()` refuses to adopt an existing, non-empty data root that lacks a valid `.mallow-root.json`, and fails with `MallowError.foreignDataRoot`. So even another app that happens to use the same folder name can never have its prefixes or runtimes read or written by Mallow.

### 2.7 Clean-room and contribution rules (to be copied into `CONTRIBUTING.md`)

**Allowed inputs:**

- **In the 0BSD frontend:** only code under permissive licences (0BSD, MIT, BSD, ISC, Apache-2.0, zlib, CC0), used under its licence, with original headers kept and the reuse recorded in `NOTICE` and `THIRD_PARTY_LICENSES.md`. Copyleft code (GPL, LGPL, MPL) never goes into MallowKit, the CLI, the app or the scripts (§2.1).
- **In the LGPL runtime (`runtime/patches/`):** upstream Wine, the CX source tarball (LGPL files only), and other LGPL-2.1-compatible code, used under its licence.
- **As ideas and facts only:** GPL frontends (Whisky, frankea/Whisky, Heroic, Bottles, Mythic) and winetricks (LGPL). Download URLs, hashes and registry keys are facts and may appear in CC0 recipes, but script logic is never transcribed.
- Public vendor documentation: Apple Developer docs and GPTK Read Me files, Microsoft specifications such as MS-SHLLINK and the PE format.
- Our own experiments, including inspection of **the user's own** copy of Apple's GPTK disk image.

**Forbidden inputs:**

- Anything inside `/Applications/CrossOver.app` beyond licence texts and version strings. In particular:
  - the `bin/wine` launcher script logic, including its environment defaults,
  - the bottle templates (`share/crossover/bottle_templates/*`),
  - the compatibility database (`crossover.tie`),
  - `cxbottle.conf` comments,
  - UI assets, strings and icons,
  - the D3DMetal copy under `lib64/apple_gptk`, and the file names or PE headers of CrossOver's binaries.
- Unlicensed repositories (for example frankea/winecx-gptk's scripts) may be read for ideas but not copied. Credit them in `NOTICE`.

**Provenance rule:** every environment variable, registry key or DLL rule we implement must cite an open source for it in a code comment. For example:

- `CX_APPLEGPTK_LIBD3DSHARED_PATH`: read by `getenv` in the CX-source `dlls/ntdll/unix/loader.c` (LGPL) **[H]** [R32].
- `ROSETTA_ADVERTISE_AVX`: Apple's GPTK 3.0 Read Me, which documents it as "Defaults to 0 (OFF)" **[H]** [R17].

Anything whose only source is an observation of CrossOver's proprietary files is not implemented.

**Draft 1 correction.** Draft 1 cited three facts from local inspection of CrossOver.app: the D3DMetal payload architecture, the payload's `.so` names, and the toolchain in CX's PE headers. It also defaulted AVX advertising to on, which matches CrossOver's launcher rather than Apple's documentation. All four are now re-sourced from open material (§2.4, §4.6, §3.11.1) or changed (§4.7), and the "(local inspection)" citations are gone.

### 2.8 Community stance

Whisky's maintainer archived the project in 2025. He cited burnout and called free CrossOver-derived frontends "parasitic" on CodeWeavers' funding of Wine on macOS **[H]** [R21]. Mallow responds in five ways:

1. At least two maintainers with release rights from day one (`GOVERNANCE.md`).
2. Fixes are sent upstream to Wine, DXMT, MoltenVK and winetricks. Each release's notes include an "upstream contributions" section.
3. The README acknowledges CodeWeavers' role in Wine on macOS.
4. There are no storefront or anti-cheat hacks.
5. **No support load is pushed onto CodeWeavers.** Our runtime's crash dialog and every user-facing link point at our own tracker (§2.6, patch 0003).

### 2.9 Community recipe repository (v0.9)

Before `mallow-project/recipes` opens:

1. **Licence and sign-off.** Recipe data is CC0-1.0 (`LICENSE` in the repo root). Every commit needs DCO sign-off, checked by CI [R86].
2. **Download-host allowlist.** CI validates every recipe against `recipe.schema.json`. A recipe needs a `license` block, `sourceHosts` and `sourceKind`. Each host in `sourceHosts` must be on `allowed-hosts.json`. Adding a host needs approval from a maintainer listed in `CODEOWNERS`. Warez, abandonware and file-locker hosts are never approved.
3. **Takedown process.** `GOVERNANCE.md` and `SECURITY.md` publish an abuse and DMCA contact (a project address, not a personal one) and a removal procedure. The procedure is: acknowledge within 7 days, disable the recipe pending review, and record the outcome in a public log.
4. **Compiled-in recipes** are reviewed again before they enter `recipes/` in this repository.

---

## 3. Architecture

### 3.1 Overview

```
 ┌──────────────────────────────┐        ┌────────────────────────────┐
 │ Mallow.app (SwiftUI)         │        │ mallow (CLI)               │
 │ AppModel @Observable         │        │ swift-argument-parser      │
 └──────────────┬───────────────┘        └──────────────┬─────────────┘
                │ both link MallowKit and build it with MallowServices │
 ┌──────────────▼────────────────────────────────────────▼─────────────┐
 │ MallowKit                                                            │
 │  Support   ─ identity, paths, locks, FSEvents, JSON/wire coding,     │
 │              hashing, Ed25519, HTTP, spawn, code signing, provenance │
 │  Bottles   ─ bottle.json model, AppliedState, store, templates, DLLs │
 │  Runtime   ─ catalog, builtin pins, installer, manifest, probe,      │
 │              Mach-O exports, Standard Wine importer, usage checks    │
 │  Wine      ─ env builder, commands, path mapper, .reg writer,        │
 │              SettingsPlan (pure), prefix staging, wineserver probe   │
 │  Programs  ─ .lnk + PE parsing, icons, discovery, Steam libraries,   │
 │              image index, prefix audit, Mac shortcuts                │
 │  Graphics  ─ backend manifests/store, resolver, configurator,        │
 │              GraphicsPlanner, DLL path map, managed files, GPTK      │
 │  Launch    ─ LaunchPlanner (pure) → LaunchService (all Wine spawns,  │
 │              sole writer of AppliedState), logs                      │
 │  Operations─ create bottle, apply settings, templates, import        │
 │  Recipes   ─ recipe schema/runner/validator, terms, winetricks       │
 │  Diagnostics ─ doctor, diagnostics bundle                            │
 │  Composition ─ MallowServices (the one object graph)                 │
 └──────────────┬───────────────────────────────────────────────────────┘
                │ posix_spawn (explicit env, new process group, log fd)
 ┌──────────────▼──────────────┐  per-image  ┌─────────────────────────────┐
 │ Runtimes/<id>/bin/wine       │  DLL path  │ Backends/dxmt-0.80           │
 │ (x86_64 → Rosetta 2)         │◄── map ────│ Backends/dxvk-macos-1.10.3…  │
 │ wineserver per WINEPREFIX    │ (patch 0002)│ UserSupplied/D3DMetal/3.0/… │
 └──────────────┬──────────────┘             └─────────────────────────────┘
                ▼
        Bottles/<slug>/  (plain Wine prefix + bottle.json + .mallow/dllpath-map)
```

### 3.2 Repository layout

This is the authoritative list of files. The module plan returned with this document uses exactly these paths. A file not listed here needs a design change first.

```
mallow/
├── .github/
│   ├── CODEOWNERS                    # maintainers who approve recipe hosts, patches, signing
│   └── workflows/
│       ├── ci.yml                    # lint, build, test (Xcode and CLT modes), schemas, generated files, ad-hoc .app + bundle check
│       ├── deps.yml                  # build the x86_64 dependency artifact from pinned source (cached by inputs hash)
│       ├── runtime.yml               # build, verify, smoke-test, sign and release the Wine runtime
│       ├── backends.yml              # repackage DXMT / DXVK-macOS as signed components (+ licence checks)
│       ├── catalog.yml               # validate, sign, publish catalog.json to GitHub Pages
│       ├── release-app.yml           # tagged app release (ad-hoc now, Developer ID later)
│       └── upstream-watch.yml        # weekly: open issues when pinned inputs fall behind
├── .gitignore
├── .swift-format
├── CONTRIBUTING.md                   # clean-room rules (§2.7), DCO, dev setup, CLT test flags
├── GOVERNANCE.md                     # ≥2 maintainers, key custody, release process, takedown procedure (§2.9)
├── LICENSE                           # 0BSD text (committed)
├── NOTICE                            # copyright line, prior-art credits, reused-code records (§2.1)
├── Package.swift
├── README.md
├── SECURITY.md                       # security and abuse/DMCA contact (§2.9)
├── THIRD_PARTY_LICENSES.md           # generated by scripts/gen-third-party-licenses.sh; CI checks it is fresh
├── Resources/                        # app-bundle inputs (NOT SwiftPM resources)
│   ├── AppIcon-1024.png
│   ├── Info.plist
│   └── Mallow.entitlements
├── Sources/
│   ├── MallowKit/
│   │   ├── Support/
│   │   │   ├── ArchiveExtractor.swift
│   │   │   ├── CodeSignatureChecker.swift     # protocol, SigningInfo, SecCodeSignatureChecker
│   │   │   ├── EventBus.swift                 # MallowEvent + shared identifiers
│   │   │   ├── FileLock.swift                 # flock(2) wrapper
│   │   │   ├── FileWatcher.swift              # FSEventStream wrapper
│   │   │   ├── GlobalSettings.swift           # GlobalSettings, ConsentRecord, GlobalSettingsStore
│   │   │   ├── Hashing.swift
│   │   │   ├── HostInfo.swift
│   │   │   ├── HTTPClient.swift
│   │   │   ├── JSONStore.swift
│   │   │   ├── MallowError.swift
│   │   │   ├── MallowPaths.swift              # + DataRootMarker
│   │   │   ├── PosixSpawner.swift
│   │   │   ├── ProcessSpawner.swift
│   │   │   ├── ProductIdentity.swift          # every product-visible identifier (§2.6.1)
│   │   │   ├── ProvenanceGuard.swift
│   │   │   ├── Quarantine.swift
│   │   │   ├── Rosetta.swift
│   │   │   ├── SignatureVerifier.swift
│   │   │   ├── ThreadProbe.swift              # internal test hook (§3.5)
│   │   │   ├── TrustedKeys.swift              # TrustedKeys, TrustedAppleTeams
│   │   │   └── WireCoding.swift               # @Defaulted, tagged-union and path coding helpers (§3.7.0)
│   │   ├── Bottles/
│   │   │   ├── AppliedState.swift
│   │   │   ├── BottleConfig.swift
│   │   │   ├── BottleMigrations.swift
│   │   │   ├── BottleSettings.swift
│   │   │   ├── BottleStore.swift
│   │   │   ├── BottleTemplate.swift
│   │   │   ├── DLLOverrides.swift             # + TranslationDLLs
│   │   │   ├── ManagedFileRecord.swift
│   │   │   ├── ProgramConfig.swift
│   │   │   └── WindowsVersion.swift
│   │   ├── Runtime/
│   │   │   ├── BuiltinComponents.swift        # compiled-in pinned entries (Standard Wine, winetricks)
│   │   │   ├── CatalogClient.swift
│   │   │   ├── ComponentCatalog.swift         # CatalogEntry, VersionKey, ReleaseChannel
│   │   │   ├── ComponentInstaller.swift
│   │   │   ├── InstalledRuntime.swift
│   │   │   ├── MachOExports.swift
│   │   │   ├── RuntimeCapabilityProbe.swift
│   │   │   ├── RuntimeManager.swift
│   │   │   ├── RuntimeManifest.swift
│   │   │   ├── RuntimeUsage.swift             # protocol only
│   │   │   └── StandardWineImporter.swift
│   │   ├── Wine/
│   │   │   ├── PrefixStaging.swift
│   │   │   ├── PrefixUpdateCheck.swift
│   │   │   ├── RegistryFile.swift
│   │   │   ├── SettingsPlan.swift
│   │   │   ├── WineCommand.swift
│   │   │   ├── WineContext.swift
│   │   │   ├── WineEnvironment.swift
│   │   │   ├── WinePathMapper.swift
│   │   │   └── WineserverController.swift
│   │   ├── Programs/
│   │   │   ├── IconExtractor.swift
│   │   │   ├── ImageIndex.swift
│   │   │   ├── MacShortcutBuilder.swift
│   │   │   ├── PEFile.swift                   # + ImageTraits, D3DAPI, version strings
│   │   │   ├── PrefixAudit.swift
│   │   │   ├── ProgramDiscovery.swift
│   │   │   ├── ShellLink.swift
│   │   │   └── SteamLibrary.swift             # text-VDF parser + library scan
│   │   ├── Graphics/
│   │   │   ├── BackendConfigurator.swift
│   │   │   ├── BackendManifest.swift
│   │   │   ├── BackendResolver.swift
│   │   │   ├── BackendStore.swift
│   │   │   ├── GPTKImporter.swift
│   │   │   ├── GraphicsPlanner.swift
│   │   │   ├── ImageBackendMap.swift
│   │   │   ├── ManagedFiles.swift             # ManagedFileSpec, ManagedFilesReconciler
│   │   │   └── ShaderCaches.swift
│   │   ├── Launch/
│   │   │   ├── BottleRuntimeUsage.swift       # RuntimeUsage implementation
│   │   │   ├── LaunchPlan.swift               # LaunchPlan, PreLaunchStep, PrefixApplyPlan, LaunchContext
│   │   │   ├── LaunchPlanner.swift
│   │   │   ├── LaunchService.swift
│   │   │   └── LogSession.swift
│   │   ├── Operations/
│   │   │   ├── BottleCreator.swift
│   │   │   ├── BottleImporter.swift
│   │   │   ├── BottleSettingsApplier.swift
│   │   │   └── PrefixTemplateCache.swift
│   │   ├── Recipes/
│   │   │   ├── BuiltinRecipes.generated.swift # generated from recipes/ by scripts/gen-builtin-recipes.sh
│   │   │   ├── Recipe.swift
│   │   │   ├── RecipeRegistry.swift
│   │   │   ├── RecipeRunner.swift
│   │   │   ├── RecipeValidator.swift
│   │   │   ├── TermsCatalog.swift
│   │   │   └── WinetricksRunner.swift
│   │   ├── Diagnostics/
│   │   │   ├── DiagnosticsBundle.swift
│   │   │   └── Doctor.swift
│   │   └── Composition/
│   │       └── MallowServices.swift
│   ├── MallowCLI/                    # product: `mallow`
│   │   ├── BackendCommand.swift
│   │   ├── BottleCommand.swift
│   │   ├── DiagnosticsCommand.swift
│   │   ├── DoctorCommand.swift
│   │   ├── GlobalOptions.swift
│   │   ├── InstallCommand.swift
│   │   ├── LogsCommand.swift
│   │   ├── MallowCommand.swift       # @main AsyncParsableCommand
│   │   ├── OutputFormatter.swift
│   │   ├── ProgramCommand.swift
│   │   ├── RecipeCommand.swift
│   │   ├── RosettaCommand.swift
│   │   ├── RunCommand.swift
│   │   ├── RuntimeCommand.swift
│   │   ├── VerbCommand.swift
│   │   ├── WinePassthroughCommand.swift
│   │   └── WinetricksCommand.swift
│   ├── MallowApp/                    # product: `MallowApp` (renamed to Mallow in the bundle)
│   │   ├── AppModel.swift
│   │   ├── AppUpdater.swift          # Sparkle wrapper, whole file inside `#if canImport(Sparkle)` (v0.8)
│   │   ├── EnvironmentKeys.swift     # manual EnvironmentKey (no @Entry under CLT)
│   │   ├── MallowApp.swift
│   │   ├── URLRouter.swift           # mallow:// URL scheme
│   │   └── Views/
│   │       ├── AcknowledgementsView.swift
│   │       ├── BottleDetailView.swift
│   │       ├── BottleSettingsView.swift
│   │       ├── GPTKImportSheet.swift
│   │       ├── GraphicsSettingsView.swift
│   │       ├── LogViewer.swift
│   │       ├── NewBottleSheet.swift
│   │       ├── OnboardingView.swift
│   │       ├── ProgramGridView.swift
│   │       ├── RosettaConsentSheet.swift
│   │       ├── RuntimesView.swift
│   │       ├── SidebarView.swift
│   │       ├── TaskProgressView.swift
│   │       └── TermsSheet.swift
│   └── FakeWine/                     # product: `fake-wine` (test double for bin/wine & bin/wineserver)
│       └── main.swift
├── Tests/
│   ├── MallowKitTests/
│   │   ├── BackendConfiguratorTests.swift
│   │   ├── BackendResolverTests.swift
│   │   ├── BottleConfigTests.swift
│   │   ├── BottleCreatorIntegrationTests.swift
│   │   ├── BottleMigrationTests.swift
│   │   ├── BottleSettingsApplierTests.swift
│   │   ├── BottleStoreTests.swift
│   │   ├── CatalogClientTests.swift
│   │   ├── ComponentInstallerTests.swift
│   │   ├── ConcurrencyIsolationTests.swift
│   │   ├── DiagnosticsBundleTests.swift
│   │   ├── DLLOverridesTests.swift
│   │   ├── GPTKImporterTests.swift
│   │   ├── GraphicsPlannerTests.swift
│   │   ├── ImageBackendMapTests.swift
│   │   ├── LaunchPlannerGoldenTests.swift
│   │   ├── LaunchServiceIntegrationTests.swift
│   │   ├── MachOExportsTests.swift
│   │   ├── MallowPathsTests.swift
│   │   ├── ManagedFilesTests.swift
│   │   ├── PEFileTests.swift
│   │   ├── PrefixAuditTests.swift
│   │   ├── PrefixStagingTests.swift
│   │   ├── ProvenanceGuardTests.swift
│   │   ├── RecipeRunnerTests.swift
│   │   ├── RecipeValidatorTests.swift
│   │   ├── RegistryFileTests.swift
│   │   ├── RuntimeCapabilityProbeTests.swift
│   │   ├── RuntimeManagerTests.swift
│   │   ├── RuntimeManifestTests.swift
│   │   ├── SchemaConformanceTests.swift
│   │   ├── SettingsPlanTests.swift
│   │   ├── ShellLinkTests.swift
│   │   ├── SignatureVerifierTests.swift
│   │   ├── StandardWineImporterTests.swift
│   │   ├── SteamLibraryTests.swift
│   │   ├── WineEnvironmentTests.swift
│   │   ├── WinePathMapperTests.swift
│   │   ├── WineserverControllerTests.swift
│   │   ├── WinetricksRunnerTests.swift
│   │   ├── WireFormatTests.swift
│   │   ├── Fixtures/
│   │   │   └── wire/                        # one <Type>.json per persisted/serialised type (§3.7.0, WF0)
│   │   ├── Golden/
│   │   │   ├── create-bottle-commands.json        # used by BottleCreatorIntegrationTests
│   │   │   ├── graphics-plan-steam.json           # used by GraphicsPlannerTests
│   │   │   ├── launch-bat.json                    # the 11 launch-*.json files are used by LaunchPlannerGoldenTests
│   │   │   ├── launch-exe-d3dmetal-metalfx.json
│   │   │   ├── launch-exe-d3dmetal.json
│   │   │   ├── launch-exe-dxmt.json
│   │   │   ├── launch-exe-dxvk-envmode.json
│   │   │   ├── launch-exe-dxvk-native-envmode.json
│   │   │   ├── launch-exe-wined3d.json
│   │   │   ├── launch-lnk-advertised.json
│   │   │   ├── launch-msi.json
│   │   │   ├── launch-steam.json
│   │   │   └── launch-transient-override.json
│   │   └── TestSupport/
│   │       ├── FakeRuntime.swift
│   │       ├── FakeSignatureChecker.swift
│   │       ├── FakeWineServer.swift       # spawns `fake-wine --hold-lock` and reads its pid file
│   │       ├── Golden.swift
│   │       ├── RecordingSpawner.swift
│   │       ├── StubHTTPClient.swift
│   │       ├── SyntheticMachO.swift       # minimal Mach-O with an export trie
│   │       ├── SyntheticPE.swift
│   │       ├── SyntheticShellLink.swift
│   │       └── TempDirectory.swift
│   └── MallowCLITests/
│       ├── CLIEndToEndTests.swift
│       └── ConcurrentEditTests.swift      # two-process lost-update test (§3.5)
├── catalog/
│   └── catalog.json                  # unsigned source of truth; CI signs and publishes it
├── docs/
│   ├── DESIGN.md
│   └── SECURITY_MODEL.md
├── recipes/                          # CC0-1.0
│   ├── LICENSE
│   ├── allowed-hosts.json            # download-host allowlist (§2.9)
│   ├── steam.json
│   └── verbs/
│       ├── corefonts.json
│       ├── d3dcompiler_47.json
│       └── vcrun2022.json
├── runtime/
│   ├── README.md
│   ├── inputs.json                   # Wine (CX tarball), MoltenVK, mono, gecko, build-tool pins
│   ├── licenses-map.json             # libs/* directories whose licence lives in an unusual file (§3.11.3)
│   ├── vendor-strings.allow          # reviewed source-tree hits of the vendor-string audit (§3.11.2)
│   ├── backends/
│   │   ├── inputs.json
│   │   ├── package-dxmt.sh
│   │   └── package-dxvk-macos.sh
│   ├── deps/
│   │   ├── inputs.json               # every dependency: url, sha256, version, SPDX licence, allowlist
│   │   ├── build-deps.sh             # builds all recipes in order into $DEPS_PREFIX (x86_64, minos 14.0)
│   │   ├── denylist.txt              # dylib leaf names that must never be bundled (libx264, libx265, …)
│   │   ├── ffmpeg-components.txt     # the decoders, demuxers and parsers we enable
│   │   └── recipes/
│   │       ├── brotli.sh
│   │       ├── bzip2.sh
│   │       ├── ffmpeg.sh
│   │       ├── freetype.sh
│   │       ├── glib.sh
│   │       ├── gmp.sh
│   │       ├── gnutls.sh
│   │       ├── gst-libav.sh
│   │       ├── gst-plugins-base.sh
│   │       ├── gst-plugins-good.sh
│   │       ├── gstreamer.sh
│   │       ├── libffi.sh
│   │       ├── libidn2.sh
│   │       ├── libpng.sh
│   │       ├── libtasn1.sh
│   │       ├── libunistring.sh
│   │       ├── nettle.sh
│   │       ├── orc.sh
│   │       ├── pcre2.sh
│   │       ├── sdl2.sh
│   │       └── zlib.sh
│   ├── patches/
│   │   ├── 0001-ntdll-add-WINEDLLPATH_PREPEND.patch
│   │   ├── 0002-ntdll-per-image-dll-path-map.patch
│   │   └── 0003-winedbg-point-crash-dialog-at-mallow-tracker.patch
│   ├── scripts/
│   │   ├── audit-vendor-strings.sh
│   │   ├── build-wine.sh
│   │   ├── bundle-dylibs.sh
│   │   ├── configure-wine.sh
│   │   ├── fetch-sources.sh
│   │   ├── gen-licenses.py
│   │   ├── gen-manifest.py
│   │   ├── install-addons.sh
│   │   ├── install-build-tools.sh    # build TOOLS only (bison, mingw-w64, ccache, meson, ninja); never bundled libraries
│   │   ├── package-runtime.sh
│   │   ├── package-sources.sh
│   │   ├── sign-manifest.sh
│   │   ├── smoke-test.sh
│   │   ├── strip-and-sign.sh
│   │   └── verify-runtime.sh
│   └── tests/
│       ├── dllmap_probe.c            # Windows test exe: prints which d3d11.dll it loaded (smoke tests h, i)
│       ├── dlopen_all.c              # x86_64 host tool: dlopen every bundled dylib/.so with DYLD_* unset; FFmpeg licence check
│       ├── mfprobe.c                 # Windows test exe: Media Foundation finds an H.264 decoder
│       ├── vkprobe.c                 # Windows test exe: creates a Vulkan instance (smoke k, Standard Wine CI)
│       └── wndtest.c                 # Windows test exe: creates a window and renders text (catches the nodrv fallback)
├── schemas/                          # CC0-1.0
│   ├── LICENSE
│   ├── backend-manifest.schema.json
│   ├── bottle.schema.json
│   ├── catalog.schema.json
│   ├── image-index.schema.json
│   ├── recipe.schema.json
│   ├── runtime-manifest.schema.json
│   └── settings.schema.json
└── scripts/
    ├── build-app.sh
    ├── check-recipes.py              # schema + licence block + host allowlist (CI and community repo)
    ├── dev-clean.sh
    ├── gen-builtin-recipes.sh
    ├── gen-third-party-licenses.sh
    ├── install-cli.sh
    ├── lint.sh
    ├── make-icns.sh
    ├── test.sh
    └── verify-app-bundle.sh          # unzips a release artifact; fails if licence files are missing
```

**Why the layout looks like this:**

- **Product names differ by more than case.** The CLI product is `mallow` and the app product is `MallowApp`. macOS volumes are case-insensitive by default, so products named `mallow` and `Mallow` would collide in `.build/release/`. For the same reason the CLI ships at `Mallow.app/Contents/Helpers/mallow`, not in `Contents/MacOS/`.
- **No SwiftPM `resources:`.** SwiftPM's `Bundle.module` looks for its `.bundle` at the `.app` root, and codesign rejects that location as "unsealed contents" **[H]** (tested). Built-in recipes are compiled in as generated Swift string literals. App assets and licence texts are copied into `Contents/Resources` by `build-app.sh` and loaded through `Bundle.main`.
- **MallowKit is one SwiftPM target.** Its folders are layered without cycles: `Support → Bottles → Runtime → Wine → Programs → Graphics → Launch → Operations → Recipes → Diagnostics → Composition`. Each folder may use only the folders to its left. `scripts/lint.sh` enforces the rule with a grep of type names per folder. Identifiers shared by every layer (`BottleID`, `ProgramID`, `InstallPhase`, `RunningProgramInfo`) live in `Support/EventBus.swift`.
- **Protocols sit at the lowest layer that needs them.** `CodeSignatureChecker` is in Support, because `ProvenanceGuard` needs it. `RuntimeUsage` is declared in Runtime and implemented in Launch.

### 3.3 `Package.swift`

```swift
// swift-tools-version: 6.2
// SPDX-License-Identifier: 0BSD
import PackageDescription

// No target enables NonisolatedNonsendingByDefault (SE-0461). With it on, a nonisolated async function
// runs on the CALLER's actor, so heavy MallowKit work called from the app would run on the main thread.
// Verified on the design host with Swift 6.3.2 [H]; see §3.5.
let common: [SwiftSetting] = [
    .enableUpcomingFeature("InferIsolatedConformances"),        // SE-0470 [H]
]

let package = Package(
    name: "Mallow",
    platforms: [.macOS(.v15)],        // Synchronization.Mutex; GPTK 3 requires macOS 15 [H]
    products: [
        .library(name: "MallowKit", targets: ["MallowKit"]),
        .executable(name: "mallow", targets: ["MallowCLI"]),
        .executable(name: "MallowApp", targets: ["MallowApp"]),
        .executable(name: "fake-wine", targets: ["FakeWine"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.8.2"),
        // v0.8: .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.10.0"),
    ],
    targets: [
        .target(name: "MallowKit", swiftSettings: common),
        .executableTarget(
            name: "MallowCLI",
            dependencies: ["MallowKit", .product(name: "ArgumentParser", package: "swift-argument-parser")],
            swiftSettings: common),
        .executableTarget(
            name: "MallowApp",
            dependencies: ["MallowKit"],   // v0.8: + .product(name: "Sparkle", package: "Sparkle")
            swiftSettings: common + [.defaultIsolation(MainActor.self)]),   // SE-0466 [H]
        .executableTarget(name: "FakeWine", swiftSettings: common),
        .testTarget(name: "MallowKitTests", dependencies: ["MallowKit", "FakeWine"], swiftSettings: common),
        .testTarget(name: "MallowCLITests", dependencies: ["MallowCLI", "FakeWine"], swiftSettings: common),
    ]
)
```

A test target that depends on an executable target makes SwiftPM build that executable first **[M]**. `scripts/test.sh` still builds `fake-wine` and `mallow` explicitly and exports their paths (`MALLOW_FAKE_WINE`, `MALLOW_CLI`), so tests do not depend on this behaviour. `AppUpdater.swift` compiles to nothing until Sparkle is added, because its whole body is inside `#if canImport(Sparkle)`.

### 3.4 MallowKit public API

Signatures are **normative**. Implementations may add internal helpers, but must not change a public signature without updating this section. Wire formats of every `Codable` type are fixed by §3.7.0, not by Swift's synthesised coding. `@concurrent` marks work that must never run on the caller's actor (§3.5).

#### 3.4.1 Support

```swift
// ProductIdentity.swift — the only place product-visible strings are spelled out (§2.6.1)
public enum ProductIdentity {
    public static let name = "Mallow"
    public static let bundleIdentifier = "io.github.mallow-project.Mallow"
    public static let urlScheme = "mallow"
    public static let cliName = "mallow"
    public static let environmentPrefix = "MALLOW_"
    public static let dataFolderName = "Mallow"
    public static let bottleMetadataFolder = ".mallow"
    public static let rootMarkerFileName = ".mallow-root.json"
    public static let rootMarkerSchema = "io.github.mallow-project.data-root/v1"
    public static let runtimeIDPrefix = "mallow-runtime-"
    public static let signatureFormatTag = "mallow-sig-v1"
    public static let defaultCatalogURL: URL    // https://mallow-project.github.io/mallow/catalog/v1/catalog.json
    public static let sourceRepositoryURL: URL  // https://github.com/mallow-project/mallow
    public static let issueTrackerURL: URL      // https://github.com/mallow-project/mallow/issues
}

// MallowPaths.swift
public struct DataRootMarker: Codable, Sendable, Equatable {
    public var schema: String       // == ProductIdentity.rootMarkerSchema
    public var createdAt: Date
    public var createdBy: String    // "mallow 0.1.0"
}
public struct MallowPaths: Sendable, Equatable {
    public let root: URL      // ~/Library/Application Support/Mallow
    public let caches: URL    // ~/Library/Caches/Mallow
    public let logs: URL      // ~/Library/Logs/Mallow
    public var rootMarker: URL { get }     // root/.mallow-root.json
    public var settingsFile: URL { get }   // root/settings.json
    public var settingsLock: URL { get }   // root/settings.json.lock
    public var bottles: URL { get }        // root/Bottles
    public var runtimes: URL { get }       // root/Runtimes
    public var backends: URL { get }       // root/Backends
    public var userSupplied: URL { get }   // root/UserSupplied
    public var templates: URL { get }      // root/Templates
    public var tools: URL { get }          // root/Tools
    public var userRecipes: URL { get }    // root/Recipes
    public var downloads: URL { get }      // caches/Downloads
    public var bottleLogs: URL { get }     // logs/Bottles
    public init(root: URL, caches: URL, logs: URL)
    /// Honors MALLOW_HOME (then caches = $MALLOW_HOME/Caches, logs = $MALLOW_HOME/Logs).
    public static func standard(environment: [String: String] = ProcessInfo.processInfo.environment) -> MallowPaths
    /// root absent → create it and write the marker; root present and empty (ignoring .DS_Store) → write the marker;
    /// root with a marker whose schema == rootMarkerSchema → OK; anything else → throw .foreignDataRoot(root.path).
    /// Then create missing subdirectories. Never deletes or rewrites anything it did not create.
    public func ensureDirectories() throws
}

public struct OSVersion: Sendable, Codable, Comparable { public var major, minor, patch: Int }  // wire: "26.5.0"

public struct HostInfo: Sendable, Codable, Equatable {
    public var macOS: OSVersion
    public var chip: String                 // sysctl machdep.cpu.brand_string, e.g. "Apple M4"
    public var isAppleSilicon: Bool         // sysctl hw.optional.arm64
    public var rosettaInstalled: Bool
    public var physicalMemoryBytes: UInt64
    public var userID: UInt32
    public var darwinUserCacheDir: URL      // confstr(_CS_DARWIN_USER_CACHE_DIR)
    public static func current() -> HostInfo
}

public enum JSONStore {
    public static let encoder: JSONEncoder  // prettyPrinted, sortedKeys, withoutEscapingSlashes, ISO-8601 dates (UTC, whole seconds)
    public static let decoder: JSONDecoder
    public static func read<T: Decodable>(_ type: T.Type, from url: URL) throws -> T
    public static func readIfPresent<T: Decodable>(_ type: T.Type, from url: URL) throws -> T?
    /// temp file in the same directory → write → fsync → rename(2). Read-modify-write callers hold a FileLock.
    public static func writeAtomically<T: Encodable>(_ value: T, to url: URL) throws
}

// FileLock.swift
public enum FileLock {
    /// open(url, O_RDWR|O_CREAT|O_CLOEXEC, 0644) → flock(LOCK_EX|LOCK_NB), retried every 20 ms until `timeout`
    /// → body → close (which releases the lock). flock locks belong to the open file description, so two
    /// FileLocks on one path exclude each other even inside one process [M]. Throws .lockTimeout(path).
    /// Blocking: call only from an actor or an @concurrent function, never on the main actor.
    public static func withExclusiveLock<T>(_ url: URL, timeout: Duration = .seconds(10), _ body: () throws -> T) throws -> T
}

// FileWatcher.swift
public final class FileWatcher: Sendable {
    /// FSEventStreamCreate(flags: FileEvents | NoDefer | WatchRoot) on a private serial queue. `handler` receives
    /// the changed file URLs of one batch, deduplicated. Directory-level DispatchSources are NOT used: they do not
    /// fire when a file inside a subdirectory is atomically replaced [H] (reviewed).
    public init(paths: [URL], latency: Duration = .milliseconds(250), handler: @escaping @Sendable ([URL]) -> Void)
    public func start()
    public func stop()
}

public enum Hashing {
    @concurrent public static func sha256Hex(of url: URL, chunkSize: Int = 1 << 20) async throws -> String  // CryptoKit, streaming
    public static func sha256Hex(of data: Data) -> String
}

public struct TrustedKey: Sendable, Hashable { public let id: String; public let rawPublicKey: Data } // 32-byte Ed25519
public enum TrustedKeys { public static let release: [TrustedKey] }      // current + next (rotation)
public enum TrustedAppleTeams { public static let gptk: Set<String> }     // empty until V24 is verified (§2.4)

public struct SignatureVerifier: Sendable {
    public init(keys: [TrustedKey])
    /// Signature file format: "mallow-sig-v1 <keyID> <base64 of 64-byte Ed25519 signature>\n"
    /// Verified with CryptoKit Curve25519.Signing.PublicKey.isValidSignature [H] [R47].
    public func verify(_ data: Data, signatureFile: Data) throws -> TrustedKey
}

public protocol HTTPClient: Sendable {
    func data(from url: URL) async throws -> Data
    /// Returns the final URL after redirects, so callers can check it against a host allowlist.
    func download(from url: URL, to destination: URL,
                  progress: @escaping @Sendable (_ received: Int64, _ expected: Int64?) -> Void) async throws -> URL
}
public struct URLSessionHTTPClient: HTTPClient { public init(session: URLSession = .shared) }  // rejects non-https, incl. redirects

public struct ArchiveExtractor: Sendable {
    public init(spawner: any ProcessSpawner)
    /// /usr/bin/tar -xf <archive> -C <dir> --no-same-owner  (bsdtar 3.5.3 auto-detects xz/gz [H]; no zstd)
    @concurrent public func extract(_ archive: URL, into directory: URL) async throws
    /// Rejects symlinks resolving outside `root`, device files, FIFOs, setuid bits.
    @concurrent public static func validateTree(at root: URL) async throws
}

public enum Quarantine {
    public static let attribute = "com.apple.quarantine"
    public static func isQuarantined(_ url: URL) -> Bool
    @concurrent public static func removeRecursively(at root: URL) async throws   // removexattr(…, XATTR_NOFOLLOW) per entry
}

public enum Rosetta {
    public static let marker = URL(filePath: "/Library/Apple/usr/libexec/oah/libRosettaRuntime")   // [H]
    public static let licenseURL = URL(string: "https://www.apple.com/legal/sla/")!
    public static func isInstalled() -> Bool
    /// For the user to run in Terminal. Without --agree-to-license, softwareupdate asks for agreement itself [M].
    public static let interactiveCommand = ["/usr/sbin/softwareupdate", "--install-rosetta"]
    /// Adds "--agree-to-license" [H] (man softwareupdate). Requires a ConsentRecord of kind
    /// .appleSoftwareLicense; otherwise throws .precondition(.consentRequired("appleSoftwareLicense")).
    public static func nonInteractiveInstallArguments(consent: ConsentRecord?) throws -> [String]
}

// CodeSignatureChecker.swift (Security.framework; no subprocess)
public struct SigningInfo: Sendable, Equatable, Codable {
    public var isSigned: Bool
    public var isValid: Bool                      // SecStaticCodeCheckValidity(kSecCSStrictValidate) == errSecSuccess
    public var satisfiesAnchorApple: Bool         // requirement "anchor apple" (Apple's own signing)
    public var satisfiesAnchorAppleGeneric: Bool  // any Apple-issued chain, e.g. Developer ID
    public var teamIdentifier: String?
    public var designatedRequirement: String?     // text form; recorded in import.json
}
public protocol CodeSignatureChecker: Sendable { func signingInfo(_ url: URL) throws -> SigningInfo }
public struct SecCodeSignatureChecker: CodeSignatureChecker { public init() }

// ProvenanceGuard.swift — keeps CrossOver files and Apple GPTK payloads out of every non-GPTK import (§2.4 rule 7)
public struct ProvenanceFinding: Sendable, Equatable, Codable {
    public enum Rule: String, Sendable, Codable {
        case codeweaversBundle   // source is inside a bundle whose CFBundleIdentifier starts with "com.codeweavers."
        case cxTool              // an executable named cx* in any bin/ directory
        case gptkPayload         // lib64/apple_gptk, D3DMetal.framework or libd3dshared.dylib anywhere in the tree
        case appleSignedMachO    // a Mach-O (by magic) that satisfies "anchor apple"
    }
    public var rule: Rule
    public var relativePath: String
}
public struct ProvenanceGuard: Sendable {
    public init(signatures: any CodeSignatureChecker)
    /// Walks from `url` up to "/", reading Contents/Info.plist of every enclosing *.app/*.bundle/*.framework.
    public func foreignEnclosingBundle(of url: URL) -> String?
    @concurrent public func scan(tree root: URL) async throws -> [ProvenanceFinding]
    /// foreignEnclosingBundle + scan; throws .provenanceRejected(path:findings:) if anything is found.
    @concurrent public func requireClean(_ root: URL) async throws
}

// ProcessSpawner.swift
public enum StdioTarget: Sendable, Equatable, Codable { case null, file(path: URL, append: Bool), sameAsStdout }   // wire §3.7.0
public enum DetachMode: String, Sendable, Codable, Equatable { case none, processGroup, session }
public struct SpawnRequest: Sendable, Codable, Equatable {        // hand-written Codable (paths, §3.7.0)
    public var executable: URL
    public var arguments: [String]             // argv[1...]; argv[0] = executable.path
    public var environment: [String: String]   // COMPLETE environment; never merged with the parent's
    public var workingDirectory: URL
    public var stdin: StdioTarget = .null
    public var stdout: StdioTarget
    public var stderr: StdioTarget
    public var detach: DetachMode = .processGroup
}
public struct ExitStatus: Sendable, Codable, Equatable {
    public enum Kind: String, Sendable, Codable { case exited, signaled }
    public var kind: Kind; public var code: Int32
    public var shellStyleCode: Int32 { get }   // exited → code, signaled → 128 + signal
}
public protocol RunningProcess: Sendable {
    var pid: Int32 { get }
    func waitForExit() async -> ExitStatus
    func signal(_ sig: Int32) throws
    func signalGroup(_ sig: Int32) throws
}
public protocol ProcessSpawner: Sendable {
    func spawn(_ request: SpawnRequest) throws -> any RunningProcess
}
extension ProcessSpawner {
    /// For short helper commands. stdout goes to a temp FILE, never a pipe: wineserver can inherit
    /// the write end and hold EOF open [L]. The file is read after the process exits.
    public func runToCompletion(_ request: SpawnRequest, timeout: Duration?) async throws -> (status: ExitStatus, stdout: Data)
}
public struct PosixSpawner: ProcessSpawner { public init() }   // §5.4

// EventBus.swift also defines the shared identifiers used across folders, so Support depends on nothing.
public typealias BottleID = UUID
public typealias ProgramID = String        // first 16 hex of sha256(lowercased Windows path)
public enum InstallPhase: String, Codable, Sendable { case downloading, verifying, extracting, validating, activating }
public enum RestartReason: String, Codable, Sendable, CaseIterable {
    case syncChanged, runtimeChanged, serverStartedOutsideMallow   // blocking: a new process would mismatch the server
    case retinaChanged, dpiChanged                                 // non-blocking: take effect after the next restart
    public var blocksLaunch: Bool { get }
}
public struct RunningProgramInfo: Sendable, Codable, Equatable, Identifiable {   // hand-written Codable (logURL path)
    public var id: UUID                      // == LaunchPlan.launchID
    public var pid: Int32; public var bottleID: BottleID
    public var programID: ProgramID?; public var name: String; public var logURL: URL?; public var startedAt: Date
}
public enum MallowEvent: Sendable {
    case bottlesChanged
    case bottleUpdated(BottleID)
    case settingsPending(BottleID, [RestartReason])
    case programStarted(RunningProgramInfo)
    case programExited(RunningProgramInfo, ExitStatus)
    case bottleIdle(BottleID)
    case componentProgress(id: String, phase: InstallPhase, fraction: Double?)
    case componentInstalled(id: String)
}
public final class EventBus: Sendable {
    public init()
    public func stream(bufferingNewest limit: Int = 256) -> AsyncStream<MallowEvent>   // unsubscribes on termination
    /// Nonisolated and synchronous: yields to every subscriber while holding a Mutex over the continuations,
    /// so events posted from one thread arrive in posting order (no unstructured Task hop).
    public func post(_ event: MallowEvent)
}

// MallowError.swift
public enum PreconditionFailure: Sendable, Equatable {
    case rosettaMissing, runtimeMissing(String), runtimeFeatureMissing(String)
    case backendUnavailable(kind: String, reasons: [String])     // GraphicsBackendKind.rawValue
    case bottleRunning(BottleID)
    case restartRequired(BottleID, [RestartReason])
    case runtimeInUse(runtimeID: String, bottles: [String])
    case insufficientDisk(neededBytes: Int64), pathNotReachable(String)
    case consentRequired(String)   // "appleSoftwareLicense" | "gptkLicense" | "recipeTerms:<id>" | "winetricksTerms:<verb>"
}
public enum MallowError: Error, Sendable, Equatable {
    case notFound(String)
    case conflict(expectedRevision: Int, actualRevision: Int)
    case unsupportedSchema(file: String, version: Int, supported: Int)
    case invalidConfiguration(String)
    case precondition(PreconditionFailure)
    case verificationFailed(String)
    case provenanceRejected(path: String, findings: [String])
    case foreignDataRoot(String)
    case lockTimeout(String)
    case processFailed(command: String, status: ExitStatus, log: URL?)
    case cancelled
    public var exitCode: Int32 { get }   // §3.8.3
}

// GlobalSettings.swift
public enum ConsentKind: String, Codable, Sendable { case appleSoftwareLicense }
public struct ConsentRecord: Codable, Sendable, Equatable {
    public var kind: ConsentKind; public var acceptedAt: Date
    public var via: String            // "app" | "cli"
    public var documentURL: URL       // the licence the user was shown a link to
}
public struct GlobalSettings: Codable, Sendable, Equatable { /* §3.7.1; every field @Defaulted or optional */ }
public actor GlobalSettingsStore {
    public init(paths: MallowPaths)
    public func load() throws -> GlobalSettings
    /// FileLock(paths.settingsLock) → reload → mutate → writeAtomically.
    public func update(_ mutate: @Sendable (inout GlobalSettings) throws -> Void) throws -> GlobalSettings
}

// ThreadProbe.swift — internal; lets ConcurrencyIsolationTests assert where heavy work ran (§3.5)
enum ThreadProbe { static func mark(_ label: StaticString) }   // records (label, pthread_main_np()) when enabled
```

#### 3.4.2 Bottles

```swift
// BottleID and ProgramID are defined in Support/EventBus.swift. @Defaulted is defined in Support/WireCoding.swift.
public enum GraphicsBackendKind: String, Codable, Sendable, CaseIterable { case auto, d3dmetal, dxmt, dxvk, wined3d }
public enum SyncMode: String, Codable, Sendable { case msync, esync, none }
public enum WineDebugPreset: String, Codable, Sendable { case off, normal, crash, custom }
public enum WindowsVersion: String, Codable, Sendable, CaseIterable { case win11, win10, win81, win8, win7, winxp64 }

// BottleSettings.swift — every non-optional field is @Defaulted, so a file missing any key still decodes (§3.7.0)
public struct DXVKOptions: Codable, Sendable, Equatable { @Defaulted<True> public var async: Bool; public var hud: String? }
public struct DXMTOptions: Codable, Sendable, Equatable {
    @Defaulted<False> public var metalFXSpatial: Bool; public var spatialUpscaleFactor: Double?
    @Defaulted<False> public var nvext: Bool
}
public struct D3DMetalOptions: Codable, Sendable, Equatable {
    public var dxr: Bool?                        // nil = Apple's per-chip default (unset)
    @Defaulted<False> public var metalFX: Bool   // bottle default; per-program override exists
    @Defaulted<False> public var nvapi: Bool
}
public struct WineD3DOptions: Codable, Sendable, Equatable {
    public enum Renderer: String, Codable, Sendable { case gl, vulkan }
    @Defaulted<RendererGL> public var renderer: Renderer; @Defaulted<True> public var csmt: Bool
}
public struct ImageOverride: Codable, Sendable, Equatable {
    public var match: String                   // exe basename ("steamwebhelper.exe") or full Windows path; case-insensitive
    public var backend: GraphicsBackendKind    // .wined3d = Wine's own DLLs only: no prepend, no libd3dshared
}
public struct GraphicsSettings: Codable, Sendable, Equatable {
    @Defaulted<BackendAuto> public var backend: GraphicsBackendKind
    @Defaulted<False> public var preferD3DMetalForD3D11: Bool
    @Defaulted<False> public var metalHUD: Bool
    public var hideD3D12: Bool?                // nil = backend preset default (§4.3)
    @Defaulted<Init<DXVKOptions>> public var dxvk: DXVKOptions
    @Defaulted<Init<DXMTOptions>> public var dxmt: DXMTOptions
    @Defaulted<Init<D3DMetalOptions>> public var d3dmetal: D3DMetalOptions
    @Defaulted<Init<WineD3DOptions>> public var wined3d: WineD3DOptions
    @Defaulted<EmptyArray<ImageOverride>> public var imageOverrides: [ImageOverride]
    @Defaulted<True> public var autoImageRules: Bool   // per-image rules for indexed images (Steam libraries), §4.5
}
public struct WindowsSettings: Codable, Sendable, Equatable {
    @Defaulted<WinVersion10> public var version: WindowsVersion; @Defaulted<UserNameMallow> public var userName: String  // "mallow"
}
public struct CPUSettings: Codable, Sendable, Equatable { @Defaulted<False> public var advertiseAVX: Bool }  // Apple default is OFF [H] [R17]
public struct DisplaySettings: Codable, Sendable, Equatable { @Defaulted<False> public var retina: Bool; public var dpi: Int? } // nil → 96, or 192 with retina
public struct InputSettings: Codable, Sendable, Equatable {
    @Defaulted<False> public var leftCommandIsCtrl: Bool;  @Defaulted<False> public var rightCommandIsCtrl: Bool
    @Defaulted<False> public var leftOptionIsAlt: Bool;    @Defaulted<False> public var rightOptionIsAlt: Bool
}
public struct DebugSettings: Codable, Sendable, Equatable { @Defaulted<DebugNormal> public var preset: WineDebugPreset; public var custom: String? }
public struct SandboxSettings: Codable, Sendable, Equatable { @Defaulted<False> public var linkHomeFolders: Bool; @Defaulted<True> public var hideHostRoot: Bool }   // secure by default (SECURITY_MODEL.md, Q12)
public struct RuntimeSelection: Codable, Sendable, Equatable {
    public var id: String?                     // required when pinned; ignored otherwise (§3.11.7)
    @Defaulted<False> public var pinned: Bool  // false: follow settings.defaultRuntimeID at the next cold start
}

// DLLOverrides.swift
public enum DLLLoadOrder: String, Codable, Sendable { case native = "n", builtin = "b", nativeBuiltin = "n,b", builtinNative = "b,n", disabled = "" }
public struct DLLOverrideSet: Codable, Sendable, Equatable {   // wire: JSON object {"name": "<raw value>"}
    public var entries: [String: DLLLoadOrder]            // keys lowercased, ".dll" stripped; "*d3d11" allowed
    public init(_ entries: [String: DLLLoadOrder] = [:])
    public init(parsing winedlloverrides: String) throws  // accepts "=d" as disabled too [H] (loadorder.c)
    public func merging(_ higher: DLLOverrideSet) -> DLLOverrideSet
    public func filter(_ isIncluded: (String) -> Bool) -> DLLOverrideSet
    /// Deterministic: group by mode (b, n, n,b, b,n, disabled), names sorted, groups joined by ";".
    public var environmentValue: String { get }
    /// Registry value strings for …\DllOverrides: "builtin", "native", "native,builtin", "builtin,native", "".
    public var registryValues: [String: String] { get }
}
public enum TranslationDLLs {
    /// T = {d3d8, d3d9, d3d10, d3d10_1, d3d10core, d3d11, d3d12, d3d12core, dxgi}
    public static let all: Set<String>
    /// Exposed only per image, never bottle-wide: {nvapi, nvapi64, nvngx}
    public static let perImageOnly: Set<String>
}

// ManagedFileRecord.swift — files Mallow placed inside the prefix (so they can be removed later)
public struct ManagedFileRecord: Codable, Sendable, Equatable {
    public var relativePath: String        // "drive_c/windows/system32/winemetal.dll"
    public var owner: String               // "backend:<backendID>" — the only owner form in v1
    public var sha256: String
    public var backupRelativePath: String? // ".mallow/backup/<relativePath>" (original file, if any)
}

// ProgramConfig.swift
public enum ProgramSource: Sendable, Equatable, Codable {   // wire §3.7.0
    case startMenu(lnkPath: String), desktop(lnkPath: String), manual, recipe(id: String), steamLibrary(appID: String)
}
public struct ProgramConfig: Codable, Sendable, Equatable, Identifiable { /* §3.7.2 */ }

// AppliedState.swift — written ONLY by LaunchService (§3.5, §5.6)
public struct ServerState: Codable, Sendable, Equatable {
    public var runtimeID: String
    public var sync: SyncMode
    public var startedAt: Date
    public var pid: Int32?                 // filled in once the lock probe first reports the server
}
public struct PrefixState: Codable, Sendable, Equatable {
    public var runtimeID: String           // runtime whose `wineboot -u` last updated the prefix
    public var windowsVersion: WindowsVersion
    public var retina: Bool
    public var dpi: Int                    // effective LogPixels value
    public var registryDigest: String      // sha256 of the last RegistryFile applied (settings + graphics)
    public var managedAppDefaults: [String]// exe basenames whose AppDefaults\…\DllOverrides values we own (sorted)
    public var imageMapDigest: String?     // sha256 of the dllpath-map last written; nil = none
    public var appliedAt: Date
}
public struct AppliedState: Codable, Sendable, Equatable {
    public var server: ServerState?        // the wineserver Mallow last started for this prefix
    public var prefix: PrefixState?        // what the prefix and registry were last configured with
    public init()
}

public enum BottleState: String, Codable, Sendable { case creating, ready, broken }
public struct BottleConfig: Codable, Sendable, Equatable { /* §3.7.2 */ }

public struct Bottle: Sendable, Identifiable, Equatable {
    public let url: URL                    // bottle dir == WINEPREFIX
    public var config: BottleConfig
    public var id: BottleID { config.id }
    public var configURL: URL { get }      // url/bottle.json
    public var lockURL: URL { get }        // url/.mallow/config.lock
    public var metadataDir: URL { get }    // url/.mallow (icons, backup, quarantine)
    public var imageMapURL: URL { get }    // url/.mallow/dllpath-map
    public var imageIndexURL: URL { get }  // url/.mallow/image-index.json
    public var driveC: URL { get }
    public var stagingRoot: URL { get }    // url/drive_c/windows/temp/mallow
}

public enum BottleMigrations {
    public static let current = 1
    /// Ordered dictionary-level migrations (n → n+1). Never silently resets values; returns warnings.
    public static func migrate(_ json: inout [String: Any]) throws -> [String]
}

public actor BottleStore {
    public init(paths: MallowPaths, settings: GlobalSettingsStore, bus: EventBus)
    public func list() throws -> [Bottle]                       // Bottles/*/bottle.json + settings.externalBottles
    public func resolve(_ reference: String) throws -> Bottle   // UUID | name (case-insensitive) | absolute path
    public func reload(_ id: BottleID) throws -> Bottle
    /// Under FileLock(bottle.lockURL): reload; disk revision != bottle.config.revision → .conflict (stale UI);
    /// else revision += 1 and writeAtomically.
    @discardableResult public func save(_ bottle: Bottle) throws -> Bottle
    /// Under FileLock(bottle.lockURL): reload → mutate → validate → revision += 1 → writeAtomically.
    /// Cannot lose an update: every writer, in any process, holds the lock for the whole sequence.
    public func update(_ id: BottleID, _ mutate: @Sendable (inout BottleConfig) throws -> Void) throws -> Bottle
    public func reserveDirectory(forName name: String) throws -> URL        // slug, unique
    public func rename(_ id: BottleID, to name: String) throws -> Bottle    // display name; dir renamed only when stopped
    public func moveToTrash(_ id: BottleID) throws                          // FileManager.trashItem (recoverable)
    /// Typed JSON sidecars in <bottle>/.mallow/ (e.g. "image-index.json"), read and written under the bottle lock.
    /// Generic so that Bottles does not depend on Programs (layering, §3.2).
    public func readSidecar<T: Decodable & Sendable>(_ type: T.Type, named name: String, for id: BottleID) throws -> T?
    public func writeSidecar<T: Encodable & Sendable>(_ value: T, named name: String, for id: BottleID) throws
    /// FileWatcher over Bottles/ and each external bottle: posts .bottleUpdated(id) per changed bottle.json and
    /// .bottlesChanged when bottles appear or disappear (debounced 250 ms). Reloads only the changed file.
    public func startWatching()
    public func stopWatching()
}

public struct BottleTemplate: Sendable, Identifiable {
    public let id: String                // "standard" | "gaming" | "steam"
    public let displayName: String
    public let configure: @Sendable (inout BottleConfig) -> Void
    public static let standard: BottleTemplate, gaming: BottleTemplate, steam: BottleTemplate
    public static var all: [BottleTemplate] { get }
}
```

#### 3.4.3 Runtime

```swift
public enum GStreamerSource: String, Codable, Sendable { case bundled, system, none }
public enum VulkanProvider: String, Codable, Sendable { case moltenvk, loader, none }  // loader = Khronos loader + ICD json
public struct RuntimeFeatures: Codable, Sendable, Equatable {
    public var wow64: Bool
    public var msync: Bool
    public var esync: Bool
    public var dllPathPrepend: Bool           // WINEDLLPATH_PREPEND (our patch 0001, or Gcenx's equivalent)
    public var dllPathMap: Bool               // our patch 0002: per-image DLL path map + per-image libd3dshared
    public var macdrvFunctions: Bool          // winemac.so EXPORTS _macdrv_functions (DXMT)
    public var d3dmetalHooks: Bool            // ntdll reads CX_APPLEGPTK_LIBD3DSHARED_PATH
    public var activeBackendHint: Bool        // source reads CX_ACTIVE_GRAPHICS_BACKEND (V6)
    public var vulkan: VulkanProvider
    public var gstreamer: GStreamerSource
    public var ffmpeg: Bool
    public var monoVersion: String?
    public var geckoVersion: String?
}
public struct RuntimeManifest: Codable, Sendable, Equatable { /* §3.7.3 */ }
public struct InstalledRuntime: Sendable, Identifiable, Equatable {
    public let id: String; public let root: URL; public let manifest: RuntimeManifest
    public var wineRoot: URL { get }          // root/<entryPoints.wineRoot>, "." for our runtime
    public var wine: URL { get }; public var wineserver: URL { get }
    public var wineInf: URL { get }           // wineRoot/share/wine/wine.inf
    public var features: RuntimeFeatures { get }
}

// ComponentCatalog.swift
public struct ArchiveRef: Codable, Sendable, Equatable {
    public enum Format: String, Codable, Sendable { case tarXZ = "tar.xz", file }
    public var url: URL; public var sha256: String; public var size: Int64
    @Defaulted<FormatTarXZ> public var format: Format
    public var installName: String?           // required when format == .file (e.g. "winetricks")
    @Defaulted<False> public var executable: Bool
}
public enum ComponentKind: String, Codable, Sendable { case runtime, backend, tool }
public enum ReleaseChannel: String, Codable, Sendable, Comparable { case stable, preview, nightly }   // stable < preview < nightly
public struct VersionKey: Codable, Sendable, Hashable, Comparable {   // wire: JSON array of non-negative ints
    public var components: [Int]              // lexicographic; missing trailing components compare as 0
}
public struct CatalogEntry: Codable, Sendable, Equatable, Identifiable { /* §3.7.4 */ }
public struct ComponentCatalog: Codable, Sendable, Equatable {
    public var schemaVersion: Int; public var sequence: Int; public var generatedAt: Date; public var entries: [CatalogEntry]
    /// Per family: the entry with the highest versionKey whose channel <= `channel`, minMacOS <= host and
    /// minAppVersion <= appVersion.
    public func latest(channel: ReleaseChannel, host: HostInfo, appVersion: VersionKey) -> [CatalogEntry]
}
public enum BuiltinComponents {
    /// Pinned entries compiled into the signed app, so the app is the root of trust (§3.11.6):
    /// "standard-wine-stable-11.0_1" (runtime, flavor standard) and "winetricks-20260125" (tool, format .file).
    public static let entries: [CatalogEntry]
    public static func entry(id: String) -> CatalogEntry?
}

public struct CatalogClient: Sendable {
    public init(url: URL, http: any HTTPClient, verifier: SignatureVerifier, settings: GlobalSettingsStore)
    /// Fetch catalog.json + .sig; verify signature; refuse sequence < lastCatalogSequence (anti-rollback).
    public func fetch() async throws -> ComponentCatalog
}

public struct ComponentInstaller: Sendable {
    public init(paths: MallowPaths, http: any HTTPClient, extractor: ArchiveExtractor, verifier: SignatureVerifier)
    /// download → sha256 → tar.xz: extract into <parent>/.staging-<uuid>, validateTree, runtime manifest sha256 ==
    /// signed manifest sha256 │ file: place as <staging>/<installName> (+x if executable) → strip quarantine →
    /// activate: target absent → rename(2); target present (same-ID repair) → renamex_np(staging, target,
    /// RENAME_SWAP), then rename the swapped-out tree to "<id>.previous", replacing an older one [M] (V38).
    @concurrent public func install(_ entry: CatalogEntry, into parent: URL,
                                    progress: @escaping @Sendable (InstallPhase, Double?) -> Void) async throws -> URL
}

// RuntimeUsage.swift — implemented in Launch/BottleRuntimeUsage.swift, injected by MallowServices
public struct RuntimeUse: Sendable, Equatable {
    public var bottleID: BottleID; public var bottleName: String
    public var serverRunning: Bool            // lock probe
    public var followsDefault: Bool           // runtime.pinned == false
}
public protocol RuntimeUsage: Sendable {
    func uses(of runtimeID: String) async throws -> [RuntimeUse]
}

public actor RuntimeManager {
    public init(paths: MallowPaths, settings: GlobalSettingsStore, catalog: CatalogClient, installer: ComponentInstaller,
                extractor: ArchiveExtractor, provenance: ProvenanceGuard, usage: any RuntimeUsage, bus: EventBus)
    public func installed() throws -> [InstalledRuntime]
    public func runtime(id: String) throws -> InstalledRuntime
    public func defaultRuntime() throws -> InstalledRuntime
    public func setDefault(id: String) async throws
    /// A new ID installs side by side. An already-installed ID is a same-ID repair, refused while any bottle
    /// using it has a live server (.precondition(.runtimeInUse)). Looks in the catalog, then BuiltinComponents.
    public func install(id: String) async throws -> InstalledRuntime
    public func importStandardWine(archive: URL, expectedSHA256: String?) async throws -> InstalledRuntime
    /// Dev/tests. Copies. ProvenanceGuard.requireClean first.
    public func importDirectory(_ directory: URL, id: String?) async throws -> InstalledRuntime
    nonisolated @concurrent public func verify(id: String) async throws -> [String]   // files.sha256 mismatches
    /// Restores "<id>.previous" over "<id>" (undo of a same-ID repair). Refused while in use by a live server.
    public func rollback(id: String) async throws -> InstalledRuntime
    /// Refused if any bottle references it; with force, still refused while any such bottle has a live server.
    public func remove(id: String, force: Bool) async throws
}

public enum RuntimeCapabilityProbe {
    /// Reads <wineRoot>/lib/wine/x86_64-unix/{ntdll.so,winemac.so,winevulkan.so}. Markers are matched as
    /// NUL-terminated C strings, so "WINEDLLPATH_PREPEND\0" never matches inside "WINEDLLPATH_PREPEND_MAPFILE":
    ///   msync "WINEMSYNC\0" · esync "WINEESYNC\0" · dllPathPrepend "WINEDLLPATH_PREPEND\0"
    ///   dllPathMap "WINEDLLPATH_PREPEND_MAPFILE\0" and "wine-dllpath-map 1\0"
    ///   d3dmetalHooks "CX_APPLEGPTK_LIBD3DSHARED_PATH\0" · activeBackendHint "CX_ACTIVE_GRAPHICS_BACKEND\0"
    /// macdrvFunctions = MachOExports.exports("_macdrv_functions", in: winemac.so) — never a byte search.
    /// vulkan: lib/libMoltenVK.dylib or "libMoltenVK" SONAME string in winevulkan.so → .moltenvk;
    ///         lib/libvulkan*.dylib (+ an ICD json) → .loader; else .none. wow64: i386-windows has > 500 PE files.
    @concurrent public static func probe(wineRoot: URL) async throws -> RuntimeFeatures
}
public enum MachOExports {
    /// Thin or fat (x86_64 slice) Mach-O; walks the LC_DYLD_EXPORTS_TRIE or LC_DYLD_INFO(_ONLY) export trie.
    /// Pure Swift: /usr/bin/nm is only a stub on Macs without the Command Line Tools [H] (reviewed).
    public static func exportedSymbols(of url: URL) throws -> Set<String>
    public static func exports(_ symbol: String, in url: URL) throws -> Bool
}

public struct StandardWineImporter: Sendable {
    public init(extractor: ArchiveExtractor, provenance: ProvenanceGuard)
    /// Accepts the Gcenx .tar.xz ("Wine Stable.app/Contents/Resources/wine/…"). Extracts into Runtimes/.staging-<uuid>
    /// and keeps the `Wine *.app` tree INTACT; ProvenanceGuard.requireClean; probe; writes a local, unsigned manifest
    /// (flavor "standard") whose entryPoints point into the .app, and, for vulkan == .loader, VK_DRIVER_FILES and
    /// VK_ICD_FILENAMES = the bundled MoltenVK ICD json (§3.11.6).
    @concurrent public func importArchive(_ archive: URL, into runtimes: URL, id: String,
                                          expectedSHA256: String?) async throws -> InstalledRuntime
}
```

#### 3.4.4 Wine

```swift
public struct WineContext: Sendable {
    public var bottle: Bottle; public var runtime: InstalledRuntime
    public var host: HostInfo; public var paths: MallowPaths
}

public struct EnvironmentLayer: Sendable, Equatable, Codable {   // hand-written Codable (paths, sorted sets)
    public var name: String                  // "host" | "runtime" | "wine" | "backend" | "bottle" | "recipe:<id>" | "program" | "cli"
    public var set: [String: String] = [:]
    public var unset: Set<String> = []
    public var dllOverrides = DLLOverrideSet()
    public var dllPathPrepend: [URL] = []    // environment mode only (§4.5)
}

public enum WineEnvironment {
    /// Only the "host", "runtime", "wine" and "backend" layers may set these.
    public static let protectedKeys: Set<String>   // WINEPREFIX WINEMSYNC WINEESYNC WINESERVER WINELOADER WINEDLLOVERRIDES
                                                   // WINEDLLPATH WINEDLLPATH_PREPEND WINEDLLPATH_PREPEND_MAPFILE
                                                   // CX_APPLEGPTK_LIBD3DSHARED_PATH LANG LC_ALL
    public static let forbiddenPrefixes = ["DYLD_"]  // exception: the "runtime" layer of a flavor-"standard" runtime (§3.11.6)
    public static func effectiveSync(_ config: BottleConfig, _ features: RuntimeFeatures) -> SyncMode
    /// host + runtime + wine layers, used by EVERY wine/wineserver invocation for this bottle, so the sync
    /// variables always match the server. With includeImageMap (default) and features.dllPathMap, the wine layer
    /// sets WINEDLLPATH_PREPEND_MAPFILE=<bottle>/.mallow/dllpath-map. Never sets a prepend or a translation-DLL override.
    public static func baseLayers(_ ctx: WineContext, includeImageMap: Bool = true) -> [EnvironmentLayer]
    /// Later layers win. Returns the final environment including WINEDLLOVERRIDES (and WINEDLLPATH_PREPEND in env mode).
    public static func resolve(_ layers: [EnvironmentLayer]) throws -> [String: String]
}

public enum WinebootAction: Sendable, Equatable, Codable { case initialize, update, endSession(force: Bool, kill: Bool) }
public enum WineCommand: Sendable, Equatable, Codable {   // wire §3.7.0
    case wineboot(WinebootAction)
    case regImport(windowsPath: String)                        // regedit /S
    case regQuery(key: String, value: String?)
    case winecfgSetVersion(WindowsVersion)                     // winecfg /v win10
    case msiexecInstall(windowsPath: String, quiet: Bool)
    case start(unixPath: String, wait: Bool)                   // start [/wait] /unix <path>
    case cmd(windowsPath: String, arguments: [String])         // cmd /c <bat> args
    case exe(windowsPath: String, arguments: [String])
    case builtin(program: String, arguments: [String])         // winecfg, regedit, taskmgr, explorer, control, uninstaller, notepad
    case taskkill(imageName: String, force: Bool)
    public var arguments: [String] { get }                     // argv after bin/wine
}
public enum WineserverCommand: Sendable, Equatable { case kill, wait
    public var arguments: [String] { get }                     // ["-k"] / ["-w"]
}

public struct WinePathMapper: Sendable {
    public init(prefix: URL) throws                            // reads dosdevices/<letter>: symlinks
    public func windowsPath(for url: URL) throws -> String     // realpath-normalized (/tmp → /private/tmp)
    public func unixURL(forWindowsPath path: String) throws -> URL
}

public struct RegistryFile: Sendable, Equatable, Codable {     // wire: the UTF-8 .reg text as one JSON string
    public enum Value: Sendable, Equatable {
        case string(String), dword(UInt32), expandString(String), multiString([String]), binary([UInt8]), delete
    }
    public init()
    public mutating func set(_ key: String, _ name: String?, _ value: Value)   // key "HKEY_CURRENT_USER\\Software\\Wine\\Mac Driver"
    public mutating func deleteKey(_ key: String)
    public mutating func merge(_ other: RegistryFile)          // other wins per (key, name)
    public var isEmpty: Bool { get }
    public var text: String { get }                            // "Windows Registry Editor Version 5.00", keys sorted, CRLF
    public var digest: String { get }                          // sha256 of `text`
    public func encoded() -> Data                              // UTF-16LE with BOM of `text`
    public static func parse(_ text: String) throws -> RegistryFile   // inverse of `text` for our subset
}

// SettingsPlan.swift — pure; shared by LaunchPlanner and BottleSettingsApplier
public struct SettingsPlan: Sendable, Equatable, Codable {
    public var registry: RegistryFile          // desired non-graphics keys: Mac Driver, LogPixels, WineDbg, recipe AppDefaults
    public var windowsVersion: WindowsVersion
    public var retina: Bool                    // what the plan WRITES (the old value while a server runs)
    public var dpi: Int
    public var commands: [WineCommand]         // e.g. winecfgSetVersion when windowsVersion != applied
    public var filesystem: [FilesystemChange]
    public var restartReasons: [RestartReason] // only when `server != nil`
    /// `server` = the live server's recorded state (nil = no server running). While a server runs, Retina/DPI keep
    /// their applied values and are reported as non-blocking reasons; sync/runtime differences are blocking reasons.
    /// LaunchPlanner itself adds .serverStartedOutsideMallow when a server runs but LiveServer.state is nil.
    public static func compute(applied: AppliedState, config: BottleConfig, runtime: InstalledRuntime,
                               host: HostInfo, server: ServerState?) -> SettingsPlan
}
public enum FilesystemChange: Sendable, Equatable, Codable {   // wire §3.7.0
    case replaceSymlinkWithDirectory(relativePath: String)     // sandbox: unlink a home folder
    case removeDriveLink(letter: String)                       // sandbox: drop dosdevices/z:
    case addDriveLink(letter: String, target: URL)             // "Map this folder as a drive letter"
}

// PrefixStaging.swift — every file a Wine process must open is staged INSIDE drive_c (§5.7)
public struct StagingArea: Sendable, Equatable {
    public let unixURL: URL                    // <bottle>/drive_c/windows/temp/mallow/<uuid>
    public let windowsPath: String             // C:\windows\temp\mallow\<uuid>
    /// APFS clone (copyfile COPYFILE_CLONE), falling back to a copy on other volumes.
    public func stage(_ file: URL, as name: String) throws -> (unix: URL, windows: String)
    public func write(_ data: Data, as name: String) throws -> (unix: URL, windows: String)
    public func remove() throws
}
public struct PrefixStaging: Sendable {
    public init(bottle: Bottle)
    public func makeArea(id: UUID) throws -> StagingArea
    public func sweep(olderThan: Duration = .seconds(86_400)) throws   // leftovers from crashes
}

public enum PrefixUpdateCheck {
    /// Mirrors Wine's own prefix-update check: <prefix>/.update-timestamp holds the mtime of runtime.wineInf
    /// ("disable" = never). True when it is missing or older, or applied.prefix?.runtimeID != runtime.id [M] (V29).
    public static func needsUpdate(prefix: URL, runtime: InstalledRuntime, applied: AppliedState) -> Bool
}

public actor WineserverController {
    public init(spawner: any ProcessSpawner, serverBase: URL = URL(filePath: "/tmp/.wine-\(getuid())"),
                pollInterval: Duration = .milliseconds(100))
    /// <serverBase>/server-<st_dev %llx>-<st_ino %llx>/lock [H] (server/request.c).
    public nonisolated func lockFile(for prefix: URL) throws -> URL
    /// open(O_RDONLY) → fcntl(F_GETLK, {F_WRLCK, SEEK_SET, 0, 1}) → close. Returns l_pid of a conflicting lock.
    /// NEVER takes a lock: fcntl locks are per process, so holding one would make every later wineserver start
    /// in this prefix fail, and closing any fd to the file would silently drop it [H] (§5.6).
    public nonisolated func serverPID(prefix: URL) -> Int32?
    public nonisolated func isRunning(prefix: URL) -> Bool
    /// Polls serverPID every pollInterval; honors Task cancellation.
    public func waitUntilStopped(prefix: URL, timeout: Duration) async -> Bool
    /// Returns when serverPID(prefix) == nil AND kill(pid, 0) fails with ESRCH; polls every 500 ms; cancellable.
    public func waitForIdle(prefix: URL, serverPID pid: Int32) async
    public func kill(_ ctx: WineContext) async throws                 // bin/wineserver -k (base env)
    public func stop(_ ctx: WineContext, grace: Duration = .seconds(10)) async throws   // §5.6; no-op when not running
}
```

#### 3.4.5 Programs

```swift
public struct ShellLink: Sendable, Equatable {       // MS-SHLLINK, parsed natively [H] [R26]
    public var targetPath: String?; public var arguments: String?; public var workingDirectory: String?
    public var iconLocation: String?; public var iconIndex: Int32; public var showCommand: UInt32
    public var name: String?; public var environmentTarget: String?; public var darwinDescriptor: String?
    public var isAdvertised: Bool { darwinDescriptor != nil }
    public static func parse(_ data: Data) throws -> ShellLink
}

public struct PEFile: Sendable, Equatable {
    public enum Machine: UInt16, Sendable, Codable { case i386 = 0x014c, amd64 = 0x8664, arm64 = 0xaa64, unknown = 0 }
    public struct IconGroupRef: Sendable, Equatable { public var id: UInt32?; public var name: String? }
    public var machine: Machine
    public var subsystem: UInt16
    public var importedDLLs: [String]           // lowercased, incl. delay-load
    public var isWineBuiltin: Bool              // "Wine builtin DLL" marker at 0x40
    public var iconGroups: [IconGroupRef]
    public var versionStrings: [String: String] // first StringFileInfo table of RT_VERSION (CompanyName, …)
    @concurrent public static func load(contentsOf url: URL, maxBytes: Int = 64 << 20) async throws -> PEFile
    public static func parse(_ data: Data) throws -> PEFile
}
public enum D3DAPI: String, Codable, Sendable, CaseIterable { case ddraw, d3d8, d3d9, d3d10, d3d11, d3d12, dxgi }
public struct ImageTraits: Codable, Sendable, Equatable {  // what BackendResolver needs; cached in the image index
    public var machine: PEFile.Machine
    public var d3dImports: Set<D3DAPI>                     // wire: sorted array
    public init(machine: PEFile.Machine, d3dImports: Set<D3DAPI>)
    public init(_ pe: PEFile)
}

public enum IconExtractor {
    /// RT_GROUP_ICON(14) → rebuild ICO (ICONDIR + 16-byte entries + RT_ICON(3) blobs) [M] [R27]
    @concurrent public static func icoData(fromPE url: URL, iconIndex: Int32 = 0) async throws -> Data?
    @concurrent public static func writePNG(icoData: Data, to url: URL, preferredSize: Int = 256) async throws   // ImageIO
    @concurrent public static func writeICNS(icoData: Data, to url: URL) async throws                           // "com.apple.icns"
}

public struct IconRef: Sendable, Equatable { public var path: String; public var index: Int32 }
public struct DiscoveredProgram: Sendable, Equatable {
    public var windowsPath: String; public var name: String; public var source: ProgramSource
    public var arguments: String?; public var workingDirectory: String?
    public var icon: IconRef?; public var isAdvertised: Bool
}
public struct ProgramDiscovery: Sendable {
    public init()
    /// Roots: ProgramData/…/Start Menu/Programs, users/<user>/AppData/Roaming/…/Start Menu/Programs,
    /// users/<user>/Desktop, users/Public/Desktop. Skips "Administrative Tools" and "StartUp".
    @concurrent public func scan(_ bottle: Bottle) async throws -> [DiscoveredProgram]
}

// SteamLibrary.swift
public struct VDFEntry: Sendable, Equatable { public var key: String; public var value: VDFNode }
public indirect enum VDFNode: Sendable, Equatable { case string(String), object([VDFEntry]) }
public enum VDF { public static func parse(_ text: String) throws -> VDFNode }   // text KeyValues only
public struct SteamApp: Sendable, Equatable { public var appID: String; public var name: String; public var installDir: URL }
public enum SteamLibrary {
    /// Images of the Steam client itself; the steam template pins them to Wine's own DLLs (§4.5).
    public static let clientImages: [String]  // steam.exe steamwebhelper.exe steamservice.exe steamerrorreporter.exe
                                              // steamerrorreporter64.exe gldriverquery.exe gldriverquery64.exe
                                              // vulkandriverquery.exe vulkandriverquery64.exe
    /// Reads steamapps/libraryfolders.vdf under drive_c/Program Files (x86)/Steam and drive_c/Program Files/Steam,
    /// then every library's appmanifest_*.acf; library paths are mapped through WinePathMapper.
    public static func apps(in bottle: Bottle) throws -> [SteamApp]
    /// *.exe up to depth 4 under installDir, skipping _CommonRedist, DirectX, vcredist, Redist, Support,
    /// EasyAntiCheat and BattlEye directories.
    public static func candidateExecutables(of app: SteamApp) throws -> [URL]
}

// ImageIndex.swift
public struct IndexedImage: Codable, Sendable, Equatable {
    public var windowsPath: String; public var traits: ImageTraits
    public var size: Int64; public var modified: Date; public var steamAppID: String?
}
public struct ImageIndex: Codable, Sendable, Equatable {   // <bottle>/.mallow/image-index.json; schema image-index.schema.json
    @Defaulted<SchemaV1> public var schemaVersion: Int
    public var scannedAt: Date
    @Defaulted<EmptyArray<IndexedImage>> public var images: [IndexedImage]
}
public struct ImageIndexer: Sendable {
    public init()
    /// Steam library executables + pinned programs; reuses entries whose size and mtime are unchanged.
    @concurrent public func refresh(_ bottle: Bottle, previous: ImageIndex?) async throws -> ImageIndex
}

// PrefixAudit.swift
public struct PrefixAuditFinding: Sendable, Equatable, Codable {
    public enum Kind: String, Codable, Sendable { case nativeTranslationDLL, appleTranslationDLL, metalFXBridge }
    public var kind: Kind; public var relativePath: String; public var companyName: String?
}
public enum PrefixAudit {
    /// system32/syswow64 PE files named in TranslationDLLs.all ∪ perImageOnly ∪ {atidxx64} that lack the Wine
    /// builtin marker. CompanyName containing "Apple" → .appleTranslationDLL. Any nvngx-on-metalfx.* → .metalFXBridge.
    @concurrent public static func scan(prefix: URL) async throws -> [PrefixAuditFinding]
    /// Moves findings to <prefix>/.mallow/quarantine/<timestamp>/ (reversible); returns the moved paths.
    public static func quarantine(_ findings: [PrefixAuditFinding], in prefix: URL) throws -> [String]
}

public struct MacShortcutBuilder: Sendable {
    public init(bundleIdentifier: String = ProductIdentity.bundleIdentifier)
    /// ~/Applications/Mallow/<Name>.app: Info.plist + icns + executable script
    /// `exec /usr/bin/open "mallow://launch?bottle=<uuid>&program=<id>"`; ad-hoc signed.
    public func createShortcut(for program: ProgramConfig, in bottle: Bottle, at directory: URL) throws -> URL
}
```

#### 3.4.6 Graphics

```swift
public struct BackendManifest: Codable, Sendable, Equatable { /* §3.7.5 */ }
public struct InstalledBackend: Sendable, Equatable, Identifiable {
    public let id: String; public let root: URL; public let manifest: BackendManifest
    public func prependRoot(_ variant: String = "default") -> URL?
    public var d3dshared: URL? { get }         // d3dmetal: <root>/payload/external/libd3dshared.dylib
}
public actor BackendStore {
    public init(paths: MallowPaths, installer: ComponentInstaller, bus: EventBus)
    public func installed() throws -> [InstalledBackend]           // Backends/* + UserSupplied/D3DMetal/*
    public func install(_ entry: CatalogEntry) async throws -> InstalledBackend
    public func remove(id: String) async throws
}

public enum BackendMode: String, Codable, Sendable { case builtinPrepend, nativeCopy, none }
public struct BackendResolution: Codable, Sendable, Equatable {
    public var requested: GraphicsBackendKind
    public var kind: GraphicsBackendKind          // never .auto
    public var backendID: String?
    public var mode: BackendMode
    public var reasons: [String]                  // why this choice (shown in UI + log header)
    public var warnings: [String]
}
public enum BackendAvailability: Sendable, Equatable { case available(backendID: String?), unavailable(reasons: [String]) }
public struct BackendResolver: Sendable {
    public init(host: HostInfo, runtime: RuntimeFeatures, installed: [InstalledBackend], preferD3DMetalForD3D11: Bool)
    public func availability(_ kind: GraphicsBackendKind) -> BackendAvailability
    /// §4.4. `image == nil` means an unknown image (the map's "*" rule, or a target without a readable PE).
    public func resolve(_ requested: GraphicsBackendKind, image: ImageTraits?) -> BackendResolution
}

public struct BackendOptions: Sendable, Equatable {   // bottle GraphicsSettings with one program's overrides applied
    public var hideD3D12: Bool?; public var metalHUD: Bool
    public var dxvk: DXVKOptions; public var dxmt: DXMTOptions; public var d3dmetal: D3DMetalOptions; public var wined3d: WineD3DOptions
    public init(bottle: GraphicsSettings, program: ProgramConfig?)
}
public struct BackendContribution: Sendable, Equatable {
    public var environment: [String: String]        // DXMT_*, DXVK_*, D3DM_*, WINE_D3D_CONFIG, MTL_HUD_ENABLED
    public var translationOverrides: DLLOverrideSet // members of T and perImageOnly this backend wants
    public var prepend: [URL]                       // backend directories/views in search order
    public var d3dshared: URL?                      // d3dmetal only
    public var managedFiles: [ManagedFileSpec]      // winemetal.dll (dxmt); native copies (dxvk native mode)
}
public struct BackendConfigurator: Sendable {
    public init(host: HostInfo, paths: MallowPaths)
    public func contribution(for resolution: BackendResolution, backend: InstalledBackend?, options: BackendOptions,
                             bottleID: BottleID, logDirectory: URL) throws -> BackendContribution   // §4.3
}

// ImageBackendMap.swift — the per-image DLL path map read by patch 0002 (§3.11.4)
public struct ImageRule: Sendable, Equatable, Codable {       // hand-written Codable (paths)
    public enum Match: Sendable, Hashable, Codable { case any, basename(String), windowsPath(String) }   // wire §3.7.0
    public var match: Match
    public var prepend: [URL]          // [] = Wine's own DLLs only
    public var d3dshared: URL?         // nil = this image never loads libd3dshared
    public var origin: String          // "default" | "override" | "program:<id>" | "auto:<windowsPath>" | "transient:<launchID>"
}
public struct ImageBackendMap: Sendable, Equatable, Codable {
    public private(set) var rules: [ImageRule]
    /// Exactly one .any rule; absolute paths only; no ':', TAB or LF inside a path; ≤ 1 MiB rendered.
    public init(rules: [ImageRule]) throws
    /// "wine-dllpath-map 1" header, then windowsPath rules, basename rules (each sorted), then "*". LF endings.
    public func rendered() -> String
    public var digest: String { get }  // sha256 of rendered()
    public func adding(_ transient: [ImageRule]) throws -> ImageBackendMap
}

// GraphicsPlanner.swift
public enum GraphicsMode: String, Codable, Sendable { case imageMap, environment }
public struct GraphicsPlan: Sendable, Equatable, Codable {
    public var mode: GraphicsMode
    public var defaultResolution: BackendResolution   // the "*" rule (imageMap) or the launch (environment)
    public var map: ImageBackendMap?                  // imageMap mode only
    /// imageMap mode: HKCU\Software\Wine\DllOverrides (every T member = builtin) + per-exe AppDefaults deltas
    /// (hidden d3d12, nvngx/nvapi64 = builtin) + deletion of AppDefaults values we owned but no longer need.
    public var registry: RegistryFile
    public var managedAppDefaults: [String]
    public var environment: EnvironmentLayer          // name "backend": env vars of every referenced backend;
                                                      // environment mode also: T overrides + dllPathPrepend
    public var managedFiles: [ManagedFileSpec]        // union over every backend the plan references
    public var warnings: [String]                     // e.g. basename collisions (§4.5)
}
public struct GraphicsPlanner: Sendable {
    public init(host: HostInfo, paths: MallowPaths)
    /// imageMap mode when runtime.features.dllPathMap, else environment mode. Rules, in precedence order (§4.5):
    /// transient, program (by full Windows path), graphics.imageOverrides (the steam template puts Steam's own
    /// images here), auto rules from `images` (only where the resolution differs from "*"), "*".
    public func plan(bottle: Bottle, runtime: InstalledRuntime, backends: [InstalledBackend],
                     images: ImageIndex?, applied: PrefixState?, transient: [ImageRule]) throws -> GraphicsPlan
    /// Resolution + contribution for one image (launch planning and the UI "effective backend" label).
    public func resolveImage(windowsPath: String, traits: ImageTraits?, program: ProgramConfig?,
                             backendOverride: GraphicsBackendKind?, bottle: Bottle, runtime: InstalledRuntime,
                             backends: [InstalledBackend]) throws -> (BackendResolution, BackendContribution)
}

// ManagedFiles.swift
public struct ManagedFileSpec: Codable, Sendable, Equatable, Hashable {   // hand-written Codable (source path)
    public var relativePath: String   // inside prefix
    public var source: URL
    public var owner: String          // "backend:<backendID>"
}
public struct ReconcileResult: Sendable, Equatable {
    public var records: [ManagedFileRecord]
    public var deferredRemovals: [String]      // relative paths still needed by a running server
}
public struct ManagedFilesReconciler: Sendable {
    public init()
    /// Adds or updates every desired file (backing up an original once). Removes and restores files that are no
    /// longer desired only when serverRunning == false; otherwise lists them in deferredRemovals (§4.5).
    @concurrent public func reconcile(_ bottle: Bottle, current: [ManagedFileRecord], desired: [ManagedFileSpec],
                                      serverRunning: Bool) async throws -> ReconcileResult
}

public struct GPTKPayload: Sendable, Equatable {
    public var sourceRoot: URL; public var version: String      // version.plist CFBundleShortVersionString
    public var licenseFile: URL; public var hasMetalFXBridge: Bool
    public var signing: [String: SigningInfo]                  // "D3DMetal.framework", "libd3dshared.dylib"
}
public struct GPTKImporter: Sendable {
    public init(paths: MallowPaths, signatures: any CodeSignatureChecker, provenance: ProvenanceGuard,
                spawner: any ProcessSpawner)
    public func mount(diskImage: URL) async throws -> URL       // hdiutil attach -readonly -nobrowse -noautoopen
    /// Layout (Apple's Read Me), foreignEnclosingBundle, and the signature policy of §2.4 rule 2 for BOTH files.
    @concurrent public func inspect(_ source: URL) async throws -> GPTKPayload
    @concurrent public func importPayload(_ payload: GPTKPayload, licenseAcceptedAt: Date) async throws -> InstalledBackend  // §4.6
}

public struct ShaderCache: Sendable, Equatable { public var name: String; public var url: URL; public var perBottle: Bool }
public enum ShaderCaches {
    public static func locations(host: HostInfo, paths: MallowPaths, bottle: BottleID?) -> [ShaderCache]
    @concurrent public static func clear(_ cache: ShaderCache) async throws
}
```

#### 3.4.7 Launch

```swift
public enum LaunchTarget: Sendable, Codable, Equatable {   // wire §3.7.0
    case file(URL)               // .exe .msi .bat .cmd .lnk (by extension, case-insensitive)
    case windowsPath(String)     // e.g. from ProgramConfig
    case builtin(String)         // winecfg, regedit, taskmgr, explorer, control, uninstaller, notepad
}
public enum TargetKind: String, Codable, Sendable { case exe, msi, batch, shortcut, builtin }

public struct LaunchRequest: Sendable, Equatable {
    public var bottleID: BottleID
    public var target: LaunchTarget
    public var programID: ProgramID? = nil
    public var arguments: [String] = []
    public var backendOverride: GraphicsBackendKind? = nil   // one-off: becomes a transient map rule (§4.5)
    public var extraEnvironment: [String: String] = [:]
    public var debugOverride: DebugSettings? = nil
    public var detach: DetachMode = .processGroup
}

public struct LiveServer: Sendable, Equatable {
    public var pid: Int32
    public var state: ServerState?   // applied.server if its pid matches (or its pid is unrecorded and it started < 10 s ago)
}
public struct LaunchContext: Sendable {
    public var bottle: Bottle
    public var runtime: InstalledRuntime
    public var backends: [InstalledBackend]
    public var images: ImageIndex?
    public var server: LiveServer?                    // nil = no wineserver for this prefix
    public var transientRules: [ImageRule]            // rules of launches that are still running
    public var runningManagedFiles: [ManagedFileSpec] // environment mode: files needed by running programs
}

public struct PrefixApplyPlan: Sendable, Equatable, Codable {
    public var registry: RegistryFile          // settings + graphics; imported only if registry.digest != applied
    public var commands: [WineCommand]
    public var filesystem: [FilesystemChange]
    public var imageMap: ImageBackendMap?      // written atomically when its digest differs
    public var managedFiles: [ManagedFileSpec] // the complete desired set
    public var resulting: PrefixState          // becomes applied.prefix on success
}
public enum PreLaunchStep: Sendable, Equatable, Codable {   // wire §3.7.0
    case updatePrefix(reason: String)          // wine wineboot -u with baseLayers(includeImageMap: false); wait for exit
    case applyPrefix(PrefixApplyPlan)
}

public struct LaunchPlan: Sendable, Codable, Equatable {
    public var launchID: UUID
    public var bottleID: BottleID
    public var programID: ProgramID?
    public var targetKind: TargetKind
    public var graphicsMode: GraphicsMode
    public var backend: BackendResolution
    public var preflight: [PreLaunchStep]
    public var transientRule: ImageRule?        // added to the map while this launch runs
    public var spawn: SpawnRequest
    public var serverStart: ServerState?        // non-nil when no server is running: recorded by LaunchService
    public var logURL: URL?                     // nil when debug preset is .off
    public var tracksProcessLifetime: Bool      // false for `start /unix` (.lnk fallback)
    public var requiresWineserverRestart: [RestartReason]   // blocking; LaunchService refuses while the server runs
    public var pendingUntilRestart: [RestartReason]         // non-blocking (retina, dpi)
    public var warnings: [String]
}

public struct LaunchPlanner: Sendable {
    public init(paths: MallowPaths, host: HostInfo,
                now: @escaping @Sendable () -> Date = Date.init,
                makeID: @escaping @Sendable () -> UUID = UUID.init,
                inspectImage: @escaping @Sendable (URL) async -> ImageTraits? = { url in
                    (try? await PEFile.load(contentsOf: url)).map(ImageTraits.init) })
    /// Pure apart from `inspectImage` and reading dosdevices through WinePathMapper (§5.1).
    @concurrent public func plan(_ request: LaunchRequest, context: LaunchContext) async throws -> LaunchPlan
}

// RunningProgramInfo is defined in Support/EventBus.swift.
/// Every Wine process for a bottle is spawned here, and this actor is the ONLY writer of AppliedState.
public actor LaunchService {
    public init(spawner: any ProcessSpawner, wineserver: WineserverController, store: BottleStore,
                reconciler: ManagedFilesReconciler, bus: EventBus, paths: MallowPaths, host: HostInfo)
    /// Fills LaunchContext.server (lock probe + applied.server), transientRules and runningManagedFiles.
    public func context(bottle: Bottle, runtime: InstalledRuntime, backends: [InstalledBackend],
                        images: ImageIndex?) async throws -> LaunchContext
    /// a) re-probe; refuse blocking reasons while the server runs  b) preflight steps in order
    /// c) no server → record plan.serverStart in applied.server  d) log header  e) spawn
    /// f) register; waitpid thread; record server pid; idle watcher. On exit: rewrite the map without the
    ///    transientRule and update applied.prefix.imageMapDigest (registry deltas it needed are removed by the next apply).
    public func launch(_ plan: LaunchPlan) async throws -> RunningProgramInfo
    /// Short Wine helpers (regedit, winecfg, wineboot, msiexec, winetricks) with the same server bookkeeping.
    public func runHelper(_ request: SpawnRequest, bottle: Bottle, runtime: InstalledRuntime,
                          timeout: Duration?) async throws -> (status: ExitStatus, stdout: Data)
    /// Staging area → .reg → regedit /S (only if the digest changed) → commands → filesystem → map → managed
    /// files (removals deferred while the server runs) → writes applied.prefix = plan.resulting (under the bottle lock).
    public func applyPrefix(_ plan: PrefixApplyPlan, bottle: Bottle, runtime: InstalledRuntime) async throws -> Bottle
    /// wine wineboot -u with baseLayers(includeImageMap: false), waits for it to exit, sets applied.prefix.runtimeID.
    public func updatePrefix(bottle: Bottle, runtime: InstalledRuntime, reason: String) async throws -> Bottle
    public func running(in bottle: BottleID?) -> [RunningProgramInfo]
    public func waitForExit(_ id: UUID) async -> ExitStatus
    public func stopBottle(_ ctx: WineContext) async throws
    public func killBottle(_ ctx: WineContext) async throws
}

public struct BottleRuntimeUsage: RuntimeUsage {
    public init(store: BottleStore, wineserver: WineserverController, settings: GlobalSettingsStore)
}

public enum LogSession {
    public static func logURL(paths: MallowPaths, bottle: Bottle, programName: String, at date: Date) -> URL
    public static func writeHeader(to url: URL, plan: LaunchPlan, host: HostInfo, appVersion: String) throws
    public static func prune(directory: URL, keep: Int) throws
}
```

#### 3.4.8 Operations

```swift
public struct ApplyOutcome: Sendable, Equatable {
    public var bottle: Bottle
    public var appliedNow: Bool                // false only when nothing could be applied
    public var pending: [RestartReason]        // shown as "Restart bottle to apply …"
}
public struct BottleSettingsApplier: Sendable {
    public init(launch: LaunchService, store: BottleStore, runtimes: RuntimeManager, backends: BackendStore,
                graphics: GraphicsPlanner, wineserver: WineserverController, host: HostInfo)
    /// Pure: SettingsPlan + GraphicsPlan → PrefixApplyPlan, plus blocking and pending reasons.
    public func plan(bottle: Bottle, runtime: InstalledRuntime, backends: [InstalledBackend], images: ImageIndex?,
                     server: ServerState?) throws -> (plan: PrefixApplyPlan, blocking: [RestartReason], pending: [RestartReason])
    /// `mallow bottle set`, `bottle unset`, `program set` and every UI edit go through here: store.update(mutate), then
    /// server stopped → apply everything now; server running → apply the hot parts now (registry except Retina/DPI,
    /// map, added managed files) and return the rest as `pending`. Never stops a running server by itself.
    public func edit(_ id: BottleID, _ mutate: @Sendable (inout BottleConfig) throws -> Void) async throws -> ApplyOutcome
    public func apply(_ id: BottleID) async throws -> ApplyOutcome     // `mallow bottle apply`
    /// ImageIndexer.refresh → store.writeSidecar(…, named: "image-index.json") → apply (hot: map + AppDefaults). Runs when a bottle is opened,
    /// before steam.exe is launched, on `mallow program list --scan`, and (v0.6) on FSEvents in Steam libraries.
    public func refreshImages(_ id: BottleID) async throws -> ApplyOutcome
}

public struct CreateBottleOptions: Sendable {
    public var name: String; public var template: BottleTemplate
    public var runtimeID: String?; public var windowsVersion: WindowsVersion?; public var location: URL?
}
public struct BottleCreator: Sendable {
    public init(store: BottleStore, runtimes: RuntimeManager, launch: LaunchService,
                wineserver: WineserverController, applier: BottleSettingsApplier, templates: PrefixTemplateCache?)
    @concurrent public func create(_ options: CreateBottleOptions,
                                   progress: @escaping @Sendable (String) -> Void) async throws -> Bottle   // §5.8
}
public struct PrefixTemplateCache: Sendable {   // v0.4
    public init(paths: MallowPaths)
    public func template(runtimeID: String, windowsVersion: WindowsVersion) -> URL?
    public func store(prefix: URL, runtimeID: String, windowsVersion: WindowsVersion) throws
    @concurrent public func clone(_ template: URL, to destination: URL) async throws   // copyfile(COPYFILE_CLONE | COPYFILE_RECURSIVE)
}
public struct BottleImporter: Sendable {        // v0.9
    public enum Mode: String, Sendable { case copy, adopt }
    public init(store: BottleStore, provenance: ProvenanceGuard)
    /// Refuses sources inside com.codeweavers.* bundles; runs PrefixAudit and quarantines Apple translation DLLs
    /// and MetalFX bridges (reported to the user, reversible).
    public func importPrefix(at source: URL, name: String, mode: Mode) async throws -> (bottle: Bottle, findings: [PrefixAuditFinding])
}
```

#### 3.4.9 Recipes, Diagnostics, Composition

```swift
public struct Recipe: Codable, Sendable, Identifiable { /* §3.7.7 */ }
public enum SourceKind: String, Codable, Sendable { case vendor, thirdPartyMirror }
public struct Terms: Codable, Sendable, Equatable {
    public var name: String; public var url: URL?; public var summary: String
    public var sourceHosts: [String]; public var sourceKind: SourceKind
    public var requiresWindowsLicense: Bool
}
public enum TermsCatalog {
    public static func terms(forVerb verb: String) -> Terms?   // corefonts, d3dcompiler_47, vcrun*, dotnet*, …
    public static func genericTerms(forVerb verb: String) -> Terms
}
public struct RecipeRegistry: Sendable {
    public init(paths: MallowPaths)             // builtin (generated) + Recipes/*.json (user/community)
    public func all() throws -> [Recipe]
    public func recipe(id: String) throws -> Recipe
}
public struct RecipeValidator: Sendable {
    public init(allowedHosts: Set<String>)      // recipes/allowed-hosts.json, compiled in
    /// license block present; sourceHosts ⊆ allowedHosts; every download URL is https and its host ∈ sourceHosts.
    public func validate(_ recipe: Recipe) -> [String]
}
public struct RecipeOptions: Sendable { public var acceptTerms = false; public var createBottleIfMissing = true }
public enum RecipeProgress: Sendable { case step(index: Int, of: Int, title: String), download(Double), log(URL) }
public actor RecipeRunner {
    public init(store: BottleStore, creator: BottleCreator, applier: BottleSettingsApplier, launch: LaunchService,
                planner: LaunchPlanner, winetricks: WinetricksRunner, http: any HTTPClient, paths: MallowPaths,
                validator: RecipeValidator)
    /// Throws .precondition(.consentRequired("recipeTerms:<id>")) unless options.acceptTerms. Downloads land in
    /// Caches/Downloads and are staged into the prefix only for the step that runs them (§5.7).
    public func run(_ recipe: Recipe, bottle: BottleID?, options: RecipeOptions,
                    progress: @escaping @Sendable (RecipeProgress) -> Void) async throws -> Bottle
}
public struct WinetricksRunner: Sendable {
    public static let componentID = "winetricks-20260125"      // one pin, in BuiltinComponents and the catalog
    public init(paths: MallowPaths, launch: LaunchService)
    /// Tools/<componentID>/winetricks. Throws .precondition(.runtimeMissing(componentID)) if absent; callers
    /// install it first through MallowServices.ensureTool (ComponentInstaller). No second download path exists.
    public func installedPath() throws -> URL
    /// Throws .precondition(.consentRequired("winetricksTerms:<verb>")) unless acceptTerms (§2.5).
    public func run(verbs: [String], bottle: Bottle, runtime: InstalledRuntime, acceptTerms: Bool,
                    logURL: URL) async throws -> ExitStatus
}

public struct DoctorCheck: Codable, Sendable, Equatable {
    public enum Status: String, Codable, Sendable { case ok, warning, error }
    public var id: String; public var status: Status; public var summary: String; public var remedy: String?
}
public struct Doctor: Sendable {
    public init(paths: MallowPaths, host: HostInfo, runtimes: RuntimeManager, wineserver: WineserverController)
    public func run(bottle: Bottle?) async -> [DoctorCheck]
}
public struct DiagnosticsBundle: Sendable {
    public init(paths: MallowPaths, host: HostInfo, spawner: any ProcessSpawner)
    /// Zip (ditto) of bottle.json, last 5 logs, Mac Driver/DllOverrides registry excerpts, dllpath-map, doctor output,
    /// runtime manifest. Redacts $HOME → "~". NEVER includes UserSupplied payloads or drive_c contents.
    @concurrent public func write(for bottle: Bottle, to destination: URL) async throws -> URL
}

// Composition/MallowServices.swift — the one object graph, shared by the CLI and the app
public final class MallowServices: Sendable {
    public let paths: MallowPaths; public let host: HostInfo; public let bus: EventBus
    public let settings: GlobalSettingsStore; public let store: BottleStore
    public let runtimes: RuntimeManager; public let backends: BackendStore; public let wineserver: WineserverController
    public let launch: LaunchService; public let planner: LaunchPlanner; public let graphics: GraphicsPlanner
    public let applier: BottleSettingsApplier; public let creator: BottleCreator
    public let recipes: RecipeRegistry; public let recipeRunner: RecipeRunner; public let winetricks: WinetricksRunner
    public let gptk: GPTKImporter; public let doctor: Doctor; public let diagnostics: DiagnosticsBundle
    /// Production wiring: PosixSpawner, URLSessionHTTPClient, SecCodeSignatureChecker, TrustedKeys.release,
    /// settings.catalogURL. Calls paths.ensureDirectories() (and so refuses a foreign data root).
    public static func live(paths: MallowPaths = .standard()) async throws -> MallowServices
    /// Test wiring.
    public init(paths: MallowPaths, host: HostInfo, spawner: any ProcessSpawner, http: any HTTPClient,
                signatures: any CodeSignatureChecker, keys: [TrustedKey], catalogURL: URL) async throws
    /// Installs a tool component (catalog first, then BuiltinComponents) if it is missing; returns its path.
    public func ensureTool(_ id: String) async throws -> URL
}
```

#### 3.4.10 Type-to-file ownership (normative)

Each public type is defined in exactly one file, so engineers working in parallel never edit the same file for different types. `@Defaulted` providers for an enum live next to that enum, because Support cannot see higher layers.

| File (under `Sources/MallowKit/`) | Defines |
|---|---|
| `Support/ProductIdentity.swift` | `ProductIdentity` |
| `Support/MallowPaths.swift` | `MallowPaths`, `DataRootMarker` |
| `Support/HostInfo.swift` | `HostInfo`, `OSVersion` |
| `Support/JSONStore.swift` | `JSONStore` |
| `Support/WireCoding.swift` | `Defaulted`, `DefaultValue`, `DefaultConstructible`, providers `True`, `False`, `Init`, `EmptyArray`, `EmptyDictionary`, `SchemaV1`; `KeyedDecodingContainer`/`KeyedEncodingContainer` path and tagged-union helpers |
| `Support/FileLock.swift` · `FileWatcher.swift` · `Hashing.swift` · `Quarantine.swift` · `Rosetta.swift` | `FileLock` · `FileWatcher` · `Hashing` · `Quarantine` · `Rosetta` |
| `Support/TrustedKeys.swift` | `TrustedKey`, `TrustedKeys`, `TrustedAppleTeams` |
| `Support/SignatureVerifier.swift` | `SignatureVerifier` |
| `Support/HTTPClient.swift` | `HTTPClient`, `URLSessionHTTPClient` |
| `Support/ArchiveExtractor.swift` | `ArchiveExtractor` |
| `Support/CodeSignatureChecker.swift` | `SigningInfo`, `CodeSignatureChecker`, `SecCodeSignatureChecker` |
| `Support/ProvenanceGuard.swift` | `ProvenanceFinding`, `ProvenanceGuard` |
| `Support/ProcessSpawner.swift` | `StdioTarget`, `DetachMode`, `SpawnRequest`, `ExitStatus`, `RunningProcess`, `ProcessSpawner` (+ `runToCompletion`) |
| `Support/PosixSpawner.swift` | `PosixSpawner` |
| `Support/EventBus.swift` | `BottleID`, `ProgramID`, `InstallPhase`, `RestartReason`, `RunningProgramInfo`, `MallowEvent`, `EventBus` |
| `Support/MallowError.swift` | `PreconditionFailure`, `MallowError` |
| `Support/GlobalSettings.swift` | `ConsentKind`, `ConsentRecord`, `GlobalSettings`, `GlobalSettingsStore` |
| `Support/ThreadProbe.swift` | `ThreadProbe` (internal) |
| `Bottles/WindowsVersion.swift` | `WindowsVersion`, `WinVersion10` |
| `Bottles/BottleSettings.swift` | `GraphicsBackendKind`, `SyncMode`, `WineDebugPreset`, `DXVKOptions`, `DXMTOptions`, `D3DMetalOptions`, `WineD3DOptions`, `ImageOverride`, `GraphicsSettings`, `WindowsSettings`, `CPUSettings`, `DisplaySettings`, `InputSettings`, `DebugSettings`, `SandboxSettings`, `RuntimeSelection`; providers `BackendAuto`, `RendererGL`, `DebugNormal`, `UserNameMallow` |
| `Bottles/DLLOverrides.swift` | `DLLLoadOrder`, `DLLOverrideSet`, `TranslationDLLs` |
| `Bottles/ManagedFileRecord.swift` | `ManagedFileRecord` |
| `Bottles/ProgramConfig.swift` | `ProgramSource`, `ProgramConfig` |
| `Bottles/AppliedState.swift` | `ServerState`, `PrefixState`, `AppliedState` |
| `Bottles/BottleConfig.swift` | `BottleState`, `BottleConfig`, `Bottle` |
| `Bottles/BottleMigrations.swift` · `BottleStore.swift` · `BottleTemplate.swift` | `BottleMigrations` · `BottleStore` · `BottleTemplate` |
| `Runtime/RuntimeManifest.swift` | `GStreamerSource`, `VulkanProvider`, `RuntimeFeatures`, `RuntimeManifest` (and its nested component/source types) |
| `Runtime/InstalledRuntime.swift` | `InstalledRuntime` |
| `Runtime/ComponentCatalog.swift` | `ArchiveRef`, `FormatTarXZ`, `ComponentKind`, `ReleaseChannel`, `VersionKey`, `CatalogEntry`, `ComponentCatalog` |
| `Runtime/BuiltinComponents.swift` · `CatalogClient.swift` · `ComponentInstaller.swift` | `BuiltinComponents` · `CatalogClient` · `ComponentInstaller` |
| `Runtime/RuntimeUsage.swift` | `RuntimeUse`, `RuntimeUsage` |
| `Runtime/RuntimeManager.swift` | `RuntimeManager` (+ `effectiveRuntime`) |
| `Runtime/RuntimeCapabilityProbe.swift` · `MachOExports.swift` · `StandardWineImporter.swift` | `RuntimeCapabilityProbe` · `MachOExports` · `StandardWineImporter` |
| `Wine/WineContext.swift` | `WineContext` |
| `Wine/WineEnvironment.swift` | `EnvironmentLayer`, `WineEnvironment` |
| `Wine/WineCommand.swift` | `WinebootAction`, `WineCommand`, `WineserverCommand` |
| `Wine/WinePathMapper.swift` · `RegistryFile.swift` | `WinePathMapper` · `RegistryFile` |
| `Wine/SettingsPlan.swift` | `SettingsPlan`, `FilesystemChange` |
| `Wine/PrefixStaging.swift` · `PrefixUpdateCheck.swift` · `WineserverController.swift` | `PrefixStaging`, `StagingArea` · `PrefixUpdateCheck` · `WineserverController` |
| `Programs/ShellLink.swift` | `ShellLink` |
| `Programs/PEFile.swift` | `PEFile`, `D3DAPI`, `ImageTraits` |
| `Programs/IconExtractor.swift` | `IconExtractor` |
| `Programs/ProgramDiscovery.swift` | `IconRef`, `DiscoveredProgram`, `ProgramDiscovery` |
| `Programs/SteamLibrary.swift` | `VDFEntry`, `VDFNode`, `VDF`, `SteamApp`, `SteamLibrary` |
| `Programs/ImageIndex.swift` | `IndexedImage`, `ImageIndex`, `ImageIndexer` |
| `Programs/PrefixAudit.swift` · `MacShortcutBuilder.swift` | `PrefixAuditFinding`, `PrefixAudit` · `MacShortcutBuilder` |
| `Graphics/BackendManifest.swift` | `BackendManifest` (and nested types), `InstalledBackend` |
| `Graphics/BackendStore.swift` | `BackendStore` |
| `Graphics/BackendResolver.swift` | `BackendMode`, `BackendResolution`, `BackendAvailability`, `BackendResolver` |
| `Graphics/BackendConfigurator.swift` | `BackendOptions`, `BackendContribution`, `BackendConfigurator` |
| `Graphics/ImageBackendMap.swift` | `ImageRule`, `ImageBackendMap` |
| `Graphics/GraphicsPlanner.swift` | `GraphicsMode`, `GraphicsPlan`, `GraphicsPlanner` |
| `Graphics/ManagedFiles.swift` | `ManagedFileSpec`, `ReconcileResult`, `ManagedFilesReconciler` |
| `Graphics/GPTKImporter.swift` · `ShaderCaches.swift` | `GPTKPayload`, `GPTKImporter` · `ShaderCache`, `ShaderCaches` |
| `Launch/LaunchPlan.swift` | `LaunchTarget`, `TargetKind`, `LaunchRequest`, `LiveServer`, `LaunchContext`, `PrefixApplyPlan`, `PreLaunchStep`, `LaunchPlan` |
| `Launch/LaunchPlanner.swift` · `LaunchService.swift` · `LogSession.swift` · `BottleRuntimeUsage.swift` | `LaunchPlanner` · `LaunchService` · `LogSession` · `BottleRuntimeUsage` |
| `Operations/BottleSettingsApplier.swift` | `ApplyOutcome`, `BottleSettingsApplier` |
| `Operations/BottleCreator.swift` | `CreateBottleOptions`, `BottleCreator` |
| `Operations/PrefixTemplateCache.swift` · `BottleImporter.swift` | `PrefixTemplateCache` · `BottleImporter` |
| `Recipes/Recipe.swift` | `Recipe` (and nested step types) |
| `Recipes/TermsCatalog.swift` | `SourceKind`, `Terms`, `TermsCatalog` |
| `Recipes/RecipeRegistry.swift` · `RecipeValidator.swift` | `RecipeRegistry` · `RecipeValidator` |
| `Recipes/RecipeRunner.swift` | `RecipeOptions`, `RecipeProgress`, `RecipeRunner` |
| `Recipes/WinetricksRunner.swift` · `BuiltinRecipes.generated.swift` | `WinetricksRunner` · `BuiltinRecipes` (internal, generated) |
| `Diagnostics/Doctor.swift` · `DiagnosticsBundle.swift` | `DoctorCheck`, `Doctor` · `DiagnosticsBundle` |
| `Composition/MallowServices.swift` | `MallowServices` |

### 3.5 Concurrency, state ownership and error model

**Language mode.** Swift 6 language mode everywhere.

**Isolation.**

- **MallowKit is `nonisolated` by default, and no target enables `NonisolatedNonsendingByDefault` (SE-0461).** With that feature on, a nonisolated `async` function runs on the *caller's* actor. So a MallowKit function called from the app would run its synchronous parts on the main thread. The reviewer verified this, and we re-checked it on the design host with Swift 6.3.2. Without the feature, the same function called from a `@MainActor` context ran off the main thread (`pthread_main_np() == 0`). `@concurrent` compiles without the feature flag **[H]** (tested) [R73].
- **Heavy-work rule (normative).** Every public MallowKit API whose cost grows with its input (hashing, extracting, tree walks, parsing large files, spawning and waiting) is either `@concurrent` or an actor method. The main actor is never used for such work. `@concurrent` is written explicitly even though it is the default without SE-0461, so that turning the feature on later cannot silently move work onto the main thread. The list:

  | API | Form |
  |---|---|
  | `Hashing.sha256Hex(of: URL)` | `@concurrent` |
  | `ArchiveExtractor.extract`, `.validateTree` | `@concurrent` |
  | `Quarantine.removeRecursively` | `@concurrent` |
  | `ComponentInstaller.install` | `@concurrent` |
  | `RuntimeManager.verify` | `nonisolated @concurrent` |
  | `RuntimeCapabilityProbe.probe`, `StandardWineImporter.importArchive` | `@concurrent` |
  | `ProvenanceGuard.scan`, `.requireClean` | `@concurrent` |
  | `GPTKImporter.inspect`, `.importPayload` | `@concurrent` |
  | `BottleCreator.create`, `PrefixTemplateCache.clone` | `@concurrent` |
  | `ManagedFilesReconciler.reconcile` | `@concurrent` |
  | `ProgramDiscovery.scan`, `ImageIndexer.refresh`, `PrefixAudit.scan`, `IconExtractor.*`, `PEFile.load` | `@concurrent` |
  | `LaunchPlanner.plan` | `async @concurrent` (it reads up to 64 MB of PE) |
  | `DiagnosticsBundle.write`, `ShaderCaches.clear` | `@concurrent` |
  | everything on `BottleStore`, `GlobalSettingsStore`, `RuntimeManager`, `BackendStore`, `LaunchService`, `WineserverController`, `RecipeRunner` | actor methods (not the main actor) |

  Synchronous APIs that stay callable from the main actor are the pure, small-input ones: `DLLOverrideSet`, `RegistryFile`, `SettingsPlan.compute`, `GraphicsPlanner.plan`, `BackendResolver`, `ImageBackendMap`, and the single-syscall probes `WineserverController.serverPID` and `isRunning`.
- **Test.** `ConcurrencyIsolationTests` calls each API in the table from a `@MainActor` test with `ThreadProbe` enabled. Each implementation calls `ThreadProbe.mark(#function)` inside its heavy section. The test asserts that every mark was recorded with `pthread_main_np() == 0`. `scripts/lint.sh` fails if `Package.swift` enables `NonisolatedNonsendingByDefault`.
- **Stateful services are actors:** `BottleStore`, `RuntimeManager`, `BackendStore`, `LaunchService`, `WineserverController`, `RecipeRunner`, `GlobalSettingsStore`. `EventBus` is deliberately a `final class` with a `Mutex`, so `post` is synchronous and keeps order (§3.4.1). All model types are `Sendable` value types.
- **The app target** uses `.defaultIsolation(MainActor.self)`. Its `AppModel` is an `@Observable @MainActor final class` that consumes `EventBus.stream()`. `@Observable` works under Command Line Tools; `@Entry` and `#Preview` do not **[H]**.
- **CLI entry point.** `MallowCommand` is an `AsyncParsableCommand`. `main.swift`-style top-level code is never used together with semaphores, because that deadlocks on the main actor **[H]** (tested).
- **Cancellation.** Every long operation is an `async` function that honours `Task` cancellation. The CLI maps SIGINT to task cancellation. Spawned Wine programs are *not* killed on cancellation unless the user runs `bottle kill`.

**Cross-process edits.** The app, the CLI and a recipe run may all edit the same bottle at once.

- A check of the on-disk revision followed by a rename is **not** atomic across processes: two writers can both pass the check and one update is lost. So `BottleStore.save` and `update` hold an advisory `flock(LOCK_EX)` on `<bottle>/.mallow/config.lock` for the whole reload → check → mutate → write → rename sequence. `GlobalSettingsStore.update` holds `settings.json.lock` the same way. `revision` is kept only so the UI can detect that what it shows is stale.
- `Runtimes/.lock` and `Backends/.lock` serialise installs across processes. A second installer of the same ID waits, then finds the ID installed and returns it.
- **Change notification** uses FSEvents with file-level events (`FileWatcher`) over `Bottles/` and each external bottle, debounced to 250 ms. Only the `bottle.json` that changed is reloaded. A `DispatchSource` on the `Bottles/` directory fd is **not** used: an atomic rename of `Bottles/<slug>/bottle.json` changes the subdirectory, not `Bottles/`, so such a watch never fires for it.
- `ConcurrentEditTests` starts 8 `mallow bottle set` processes at once, each setting a different `env.K<i>`, and asserts that all 8 keys are present afterwards.

**State ownership (normative).** Each piece of persistent state has exactly one writer:

| State | Sole writer | Serialised by |
|---|---|---|
| `bottle.json` user settings (everything except the rows below) | `BottleStore.update`/`save`, called by `BottleSettingsApplier.edit`, `BottleCreator`, `RecipeRunner` | `.mallow/config.lock` |
| `bottle.json` `applied` (`server`, `prefix`) | `LaunchService`, through `BottleStore.update` | same lock |
| `bottle.json` `managedFiles` | `LaunchService` (reconcile results) | same lock |
| `bottle.json` `installed` | `RecipeRunner` | same lock |
| `<bottle>/.mallow/dllpath-map` | `LaunchService` (`applyPrefix`, and adding or removing transient rules) | same lock, then atomic rename |
| `<bottle>/.mallow/image-index.json` | `BottleSettingsApplier.refreshImages` via `BottleStore.writeSidecar` | same lock |
| Prefix registry | Wine processes spawned by `LaunchService` (`regedit /S`, `winecfg`) | wineserver |
| `settings.json` | `GlobalSettingsStore` | `settings.json.lock` |
| `Runtimes/*`, `Backends/*`, `Tools/*` | `ComponentInstaller`, via `RuntimeManager`, `BackendStore` or `MallowServices.ensureTool` | `Runtimes/.lock`, `Backends/.lock` |
| `UserSupplied/D3DMetal/*` | `GPTKImporter` | `Backends/.lock` |

Every Wine process for a bottle is spawned through `LaunchService`, whether it is a program launch or a helper such as `regedit`, `winecfg`, `wineboot`, `msiexec` or winetricks. So the one component that can start a `wineserver` is also the one that records `applied.server`. The only exception is `WineserverController.stop`/`kill`, which only shut a server down and never start one.

**Errors.** `MallowError` (§3.4.1) is the only error type that crosses the public API. Each case maps to a CLI exit code (§3.8.3).

### 3.6 On-disk layout

```
~/Library/Application Support/Mallow/            ($MALLOW_HOME overrides)
├── .mallow-root.json                              # data-root marker (§2.6.1); written on creation
├── settings.json   settings.json.lock             # GlobalSettings (§3.7.1)
├── Bottles/
│   └── <slug>/                                    # == WINEPREFIX (plain Wine prefix)
│       ├── bottle.json                            # BottleConfig (§3.7.2)
│       ├── bottle.json.v<N>.bak                   # written before a schema migration
│       ├── .mallow/
│       │   ├── config.lock                        # flock for bottle.json read-modify-write
│       │   ├── dllpath-map                        # per-image backend map read by patch 0002 (§3.11.4)
│       │   ├── image-index.json                   # scanned executables and their PE traits (§3.7.6)
│       │   ├── icons/   backup/   quarantine/
│       ├── drive_c/                               # drive_c/windows/temp/mallow/<uuid>/ = staging areas (§5.7)
│       ├── dosdevices/  system.reg  user.reg  userdef.reg  .update-timestamp
├── Runtimes/
│   ├── .lock
│   ├── mallow-runtime-11.0-r1/                    # §3.11.5 layout; manifest.json at root
│   ├── mallow-runtime-11.0-r2/                    # updates install SIDE BY SIDE under new IDs
│   ├── mallow-runtime-11.0-r1.previous/           # only after a same-ID repair (§3.11.7)
│   └── standard-wine-stable-11.0_1/               # manifest.json + "Wine Stable.app/" kept intact (§3.11.6)
├── Backends/
│   ├── .lock
│   ├── dxmt-0.80/                                 # §3.12 layout; backend.json at root
│   └── dxvk-macos-1.10.3-20230507/
├── UserSupplied/
│   └── D3DMetal/<version>/                        # §4.6; NEVER uploaded, NEVER in diagnostics
├── Templates/<runtimeID>-<winver>/                # pristine prefixes for APFS clone (v0.4)
├── Tools/winetricks-20260125/winetricks           # a catalog/builtin "tool" component (format "file")
└── Recipes/*.json                                 # user/community recipes

~/Library/Caches/Mallow/
├── Downloads/                                     # component archives, SteamSetup.exe, … (staged into prefixes, never run from here)
├── winetricks/                                    # W_CACHE
├── dxvk/<bottleID>/                               # DXVK_STATE_CACHE_PATH
└── gstreamer/<runtimeID>.bin                      # GST_REGISTRY_1_0

~/Library/Logs/Mallow/
├── mallow.log                                     # app/CLI diagnostics (rotated at 5 MB × 3)
└── Bottles/<slug>/<yyyyMMdd-HHmmss>-<program>.log # one per launch (§5.5)

~/Applications/Mallow/<Program>.app                 # Mac shortcuts (optional, per program)
```

**Bottle directory naming.** At creation the directory is named with a slug of the display name (lowercase, `[a-z0-9-]`, made unique with `-2`, `-3` and so on). A bottle's identity is the `id` UUID in `bottle.json`, so shortcuts and URLs reference the UUID. Directories are renamed only while the bottle is stopped.

**External bottles** (`settings.externalBottles`) may live on other volumes. `flock` on exFAT or SMB volumes is unverified **[M]** (V30). If `flock` returns `ENOTSUP`, the bottle opens read-only with an explanation.

### 3.7 File formats

Every format has a JSON Schema in `schemas/`. The Python `schemas` CI job validates every fixture, example and file under `recipes/` and `catalog/` against the schemas. `SchemaConformanceTests` (Swift) only **decodes** those files and checks round-trips. There is no Swift JSON Schema validator among our dependencies, and we do not add one.

**Unknown fields.** Readers ignore unknown fields. Writers refuse to write a file whose `schemaVersion` is newer than they support (`MallowError.unsupportedSchema`). This avoids silently dropping data written by a newer version.

#### 3.7.0 Wire-format rules (normative)

Swift's synthesised `Codable` does not produce the formats below. For example, it encodes `.file(url, append:)` as `{"file":{"_0":…}}`, and it throws `keyNotFound` for a missing key even when the property has a default value **[H]** (reviewed). So these rules are fixed by hand:

1. **Missing keys decode to defaults.** Every non-optional stored property of a persisted struct is declared with `@Defaulted<P>` (`Support/WireCoding.swift`), or its type hand-writes `init(from:)` with `decodeIfPresent(…) ?? default`. The pattern is a property wrapper whose `KeyedDecodingContainer.decode` overload falls back to `P.value`. It decodes `{}` to all defaults and encodes normally **[H]** (tested on the design host). Providers: `True`, `False`, `Init<T>` (for `T: DefaultConstructible`), `EmptyArray<T>`, `EmptyDictionary<K,V>`, `SchemaV1`, and one named provider per enum default (`BackendAuto`, `RendererGL`, `WinVersion10`, `DebugNormal`, `FormatTarXZ`, `UserNameMallow`). `WireFormatTests` decodes `{}` for every persisted struct.
2. **`nil` is never written.** An absent key means `nil`. Examples in this document never show `null`.
3. **Local file URLs are absolute POSIX path strings** (`url.path(percentEncoded: false)`, decoded with `URL(filePath:)`). Remote URLs are absolute `https://` strings. Types that hold local URLs hand-write `Codable` using `encodePath`/`decodePath` from `WireCoding.swift`. They are `SpawnRequest`, `StdioTarget`, `EnvironmentLayer`, `ManagedFileSpec`, `ImageRule`, `LaunchTarget`, `FilesystemChange`, `RunningProgramInfo`, `LaunchPlan` and `HostInfo`.
4. **Dates** are ISO-8601 UTC with whole seconds. **Sets** are sorted arrays. Output uses sorted keys.
5. **Enums without payloads** are their raw string. **Enums with payloads** are a tagged union with exactly one key:
   - a case with no payload → `"caseName"`;
   - a case with one payload, labelled or not → `{"caseName": <payload>}`;
   - a case with several payloads (all labelled) → `{"caseName": {"<label>": …}}`.
6. **Wire forms of every non-trivial type:**

| Type | JSON |
|---|---|
| `StdioTarget` | `"null"` · `"sameAsStdout"` · `{"file": {"path": "/abs/x.log", "append": true}}` |
| `ProgramSource` | `{"startMenu": "C:\\ProgramData\\…\\Foo.lnk"}` · `{"desktop": "…"}` · `"manual"` · `{"recipe": "steam"}` · `{"steamLibrary": "620"}` |
| `LaunchTarget` | `{"file": "/abs/Foo.exe"}` · `{"windowsPath": "C:\\Games\\Foo.exe"}` · `{"builtin": "winecfg"}` |
| `FilesystemChange` | `{"replaceSymlinkWithDirectory": "drive_c/users/mallow/Documents"}` · `{"removeDriveLink": "z"}` · `{"addDriveLink": {"letter": "s", "target": "/Volumes/Games"}}` |
| `ImageRule.Match` | `"any"` · `{"basename": "steam.exe"}` · `{"windowsPath": "C:\\…\\Foo.exe"}` |
| `WinebootAction` | `"initialize"` · `"update"` · `{"endSession": {"force": true, "kill": false}}` |
| `WineCommand` | `{"wineboot": "update"}` · `{"regImport": "C:\\windows\\temp\\mallow\\<uuid>\\apply.reg"}` · `{"winecfgSetVersion": "win10"}` · `{"regQuery": {"key": "…", "value": "…"}}` · `{"msiexecInstall": {"windowsPath": "…", "quiet": true}}` · `{"start": {"unixPath": "…", "wait": false}}` · `{"cmd": {"windowsPath": "…", "arguments": []}}` · `{"exe": {…}}` · `{"builtin": {"program": "winecfg", "arguments": []}}` · `{"taskkill": {"imageName": "…", "force": true}}` |
| `PreLaunchStep` | `{"updatePrefix": "runtime changed …"}` · `{"applyPrefix": {…PrefixApplyPlan…}}` |
| `PEFile.Machine` | `"i386"` · `"amd64"` · `"arm64"` · `"unknown"` |
| `OSVersion` | `"26.5.0"` |
| `VersionKey` | `[11, 0, 1]` |
| `DLLOverrideSet` | `{"d3d11": "b", "gameoverlayrenderer": ""}` |
| `RegistryFile` | one string holding the `.reg` text (LF-normalised) |
| `ExitStatus` | `{"kind": "exited", "code": 0}` |

7. **WF0, the fixtures come first.** In week 1 of v0.1, before modules are split among engineers, `Support/WireCoding.swift`, every model type in §3.4 and `WireFormatTests` land together. The test writes `Tests/MallowKitTests/Fixtures/wire/<Type>.json` when `MALLOW_UPDATE_GOLDENS=1`, and otherwise compares against the checked-in fixtures. These fixtures, not hand-written examples, are the reference for every engineer. The examples below were written to match them and are regenerated from them when WF0 lands.

#### 3.7.1 `settings.json`

```json
{
  "schemaVersion": 1,
  "defaultRuntimeID": "mallow-runtime-11.0-r1",
  "catalogURL": "https://mallow-project.github.io/mallow/catalog/v1/catalog.json",
  "channel": "stable",
  "lastCatalogSequence": 42,
  "externalBottles": ["/Volumes/Games/Mallow Bottles/rpg"],
  "logRetentionPerBottle": 30,
  "preferD3DMetalForD3D11": false,
  "shortcutDirectory": "~/Applications/Mallow",
  "consents": [
    { "kind": "appleSoftwareLicense", "acceptedAt": "2026-10-01T11:58:00Z", "via": "app", "documentURL": "https://www.apple.com/legal/sla/" }
  ]
}
```

#### 3.7.2 `bottle.json` (schema v1)

A bottle made from the `steam` template, with one directly pinned game that uses D3DMetal:

```json
{
  "schemaVersion": 1,
  "id": "6F1C2B0E-3D0A-4F55-9A57-3B8E7B2A9C10",
  "name": "Steam",
  "revision": 7,
  "state": "ready",
  "createdAt": "2026-10-01T12:00:00Z",
  "createdBy": "mallow 0.4.0",
  "runtime": { "pinned": false },
  "windows": { "version": "win10", "userName": "mallow" },
  "graphics": {
    "backend": "dxmt",
    "preferD3DMetalForD3D11": false,
    "metalHUD": false,
    "hideD3D12": false,
    "dxvk": { "async": true },
    "dxmt": { "metalFXSpatial": false, "nvext": false },
    "d3dmetal": { "metalFX": false, "nvapi": false },
    "wined3d": { "renderer": "gl", "csmt": true },
    "imageOverrides": [
      { "match": "steam.exe", "backend": "wined3d" },
      { "match": "steamwebhelper.exe", "backend": "wined3d" },
      { "match": "steamservice.exe", "backend": "wined3d" }
    ],
    "autoImageRules": true
  },
  "sync": "msync",
  "cpu": { "advertiseAVX": false },
  "display": { "retina": false },
  "input": { "leftCommandIsCtrl": false, "rightCommandIsCtrl": false, "leftOptionIsAlt": false, "rightOptionIsAlt": false },
  "debug": { "preset": "normal" },
  "environment": {},
  "dllOverrides": { "gameoverlayrenderer": "", "gameoverlayrenderer64": "" },
  "sandbox": { "linkHomeFolders": false, "hideHostRoot": true },
  "programs": [
    {
      "id": "a3f09c1d77e2b410",
      "windowsPath": "C:\\Program Files (x86)\\Steam\\steam.exe",
      "name": "Steam",
      "pinned": true,
      "arguments": [],
      "environment": {},
      "dllOverrides": {},
      "source": { "recipe": "steam" }
    },
    {
      "id": "0c55e1a2b3c4d5e6",
      "windowsPath": "C:\\Program Files (x86)\\Steam\\steamapps\\common\\Foo\\Foo.exe",
      "name": "Foo",
      "pinned": true,
      "arguments": [],
      "environment": {},
      "dllOverrides": {},
      "backend": "d3dmetal",
      "d3dmetalMetalFX": true,
      "source": { "steamLibrary": "123450" }
    }
  ],
  "installed": {
    "verbs": [ { "id": "corefonts", "via": "winetricks@20260125", "at": "2026-10-01T12:05:00Z" } ],
    "recipes": [ { "id": "steam", "version": 1, "at": "2026-10-01T12:03:00Z" } ]
  },
  "managedFiles": [
    { "relativePath": "drive_c/windows/system32/winemetal.dll", "owner": "backend:dxmt-0.80", "sha256": "…" },
    { "relativePath": "drive_c/windows/syswow64/winemetal.dll", "owner": "backend:dxmt-0.80", "sha256": "…" }
  ],
  "applied": {
    "server": { "runtimeID": "mallow-runtime-11.0-r1", "sync": "msync", "startedAt": "2026-10-01T12:10:00Z", "pid": 4242 },
    "prefix": {
      "runtimeID": "mallow-runtime-11.0-r1", "windowsVersion": "win10", "retina": false, "dpi": 96,
      "registryDigest": "5d1e…", "managedAppDefaults": ["foo.exe"], "imageMapDigest": "9ab0…",
      "appliedAt": "2026-10-01T12:09:58Z"
    }
  }
}
```

**Rules.**

- `ProgramConfig.id` is the first 16 hex digits of `sha256(lowercased windowsPath)`. It is stable and does not collide for two different `launcher.exe` files. Whisky keyed programs by bare file name, which is a bug we avoid **[H]** [R20].
- `ProgramConfig` fields: `id`, `windowsPath`, `name`, `pinned`, `arguments`, `workingDirectory?`, `environment`, `dllOverrides`, `locale?`, `backend?`, `metalHUD?`, `dxmtNVExt?`, `d3dmetalMetalFX?`, `d3dmetalNVAPI?`, `hideD3D12?`, `debug?`, `source`. An absent optional means "inherit from the bottle".
- `BottleConfig` fields: `schemaVersion`, `id`, `name`, `revision`, `state`, `createdAt`, `createdBy`, `runtime`, `windows`, `graphics`, `sync`, `cpu`, `display`, `input`, `debug`, `locale?`, `environment`, `dllOverrides`, `sandbox`, `programs`, `installed`, `managedFiles`, `applied`. All but `id` and `name` are `@Defaulted` or optional.
- `runtime.id` is required when `runtime.pinned` is true and ignored otherwise. An unpinned bottle follows `settings.defaultRuntimeID` at its next cold start. The runtime it last used is `applied.prefix.runtimeID` (§3.11.7).
- `locale` is **absent by default**, meaning Mallow sets neither `LANG` nor `LC_ALL`. Wine then derives the Windows locale from the Mac's settings (§5.2). An explicit value (per bottle or per program, for example `ja_JP.UTF-8`) sets both.
- `dllOverrides` values use `DLLLoadOrder` raw values. `""` means disabled. Where each entry ends up (environment or registry) is decided in §4.5.
- `environment` keys may not be in `WineEnvironment.protectedKeys` or start with `DYLD_`. This is a validation error at save time.
- `applied` is written only by `LaunchService` (§3.5). Pending changes are **derived**, never stored: `SettingsPlan.compute` against `applied` gives them at any time, so they cannot go stale.
- **Migrations.** When `schemaVersion` is below the current version, the file is copied to `bottle.json.v<old>.bak`, then `BottleMigrations.migrate` runs and the result is saved. When it is above the current version, the bottle opens **read-only** in the UI with a "made by a newer Mallow" banner. A version mismatch is never allowed to wipe settings, which was a Whisky bug **[H]** [R20]. Because every field is `@Defaulted`, adding a field needs no migration.

#### 3.7.3 Runtime `manifest.json`

The manifest sits at the runtime root. It is also published as a separate release asset `<id>.manifest.json` with `<id>.manifest.json.sig`.

```json
{
  "schemaVersion": 1,
  "runtimeID": "mallow-runtime-11.0-r1",
  "displayName": "Mallow Runtime 11.0 (r1)",
  "flavor": "mallow",
  "version": "11.0-r1",
  "versionKey": [11, 0, 1],
  "wineVersion": "11.0",
  "baseSource": {
    "description": "Wine sources from CodeWeavers' LGPL source release 26.3.0 (sources/wine)",
    "url": "https://media.codeweavers.com/pub/crossover/source/crossover-sources-26.3.0.tar.gz",
    "sha256": "ac99c8ca4b3848f3e81784135f023df266b61c2345726ea55a50b3e030dd6872",
    "subdir": "sources/wine"
  },
  "patches": [
    { "name": "0001-ntdll-add-WINEDLLPATH_PREPEND.patch", "sha256": "…" },
    { "name": "0002-ntdll-per-image-dll-path-map.patch", "sha256": "…" },
    { "name": "0003-winedbg-point-crash-dialog-at-mallow-tracker.patch", "sha256": "…" }
  ],
  "arch": "x86_64",
  "peArchs": ["i386", "x86_64"],
  "minMacOS": "14.0",
  "requiresRosetta": true,
  "entryPoints": { "wineRoot": ".", "wine": "bin/wine", "wineserver": "bin/wineserver" },
  "features": {
    "wow64": true, "msync": true, "esync": false,
    "dllPathPrepend": true, "dllPathMap": true,
    "macdrvFunctions": true, "d3dmetalHooks": true, "activeBackendHint": false,
    "vulkan": "moltenvk", "gstreamer": "bundled", "ffmpeg": true,
    "monoVersion": "10.4.1", "geckoVersion": "2.47.4"
  },
  "environment": {
    "GST_PLUGIN_SYSTEM_PATH_1_0": "${WINE_ROOT}/lib/gstreamer-1.0",
    "GST_PLUGIN_SCANNER_1_0": "${WINE_ROOT}/libexec/gstreamer-1.0/gst-plugin-scanner",
    "GST_REGISTRY_1_0": "${CACHES}/gstreamer/${RUNTIME_ID}.bin"
  },
  "components": [
    { "name": "wine", "version": "11.0", "license": "LGPL-2.1-or-later", "linkage": "self",
      "sourceAsset": "mallow-runtime-11.0-r1-source.tar.xz", "licenseFiles": ["licenses/COPYING.LIB", "licenses/AUTHORS"] },
    { "name": "wine-bundled/jpeg", "license": "IJG", "linkage": "static",
      "sourceAsset": "mallow-runtime-11.0-r1-source.tar.xz", "licenseFiles": ["licenses/wine-bundled/jpeg/README"] },
    { "name": "ffmpeg", "version": "…", "license": "LGPL-2.1-or-later", "linkage": "dynamic",
      "auditedLicense": "LGPL version 2.1 or later",
      "sourceAsset": "mallow-deps-<depsHash>-sources.tar.xz", "licenseFiles": ["licenses/deps/ffmpeg/COPYING.LGPLv2.1"] },
    { "name": "MoltenVK", "version": "1.4.2", "license": "Apache-2.0", "linkage": "dynamic",
      "embeds": ["SPIRV-Cross", "SPIRV-Tools", "cereal", "Vulkan-Headers"], "licenseFiles": ["licenses/moltenvk/…"] }
  ],
  "archive": { "name": "mallow-runtime-11.0-r1-x86_64.tar.xz", "size": 0, "sha256": "…" },
  "filesDigest": "sha256 of files.sha256",
  "licensesDigest": "sha256 of the sorted licenses/ listing",
  "sourceAssets": [
    { "name": "mallow-runtime-11.0-r1-source.tar.xz", "url": "https://github.com/mallow-project/mallow/releases/download/runtime-11.0-r1/mallow-runtime-11.0-r1-source.tar.xz" },
    { "name": "mallow-deps-<depsHash>-sources.tar.xz", "url": "https://github.com/mallow-project/mallow/releases/download/runtime-11.0-r1/mallow-deps-<depsHash>-sources.tar.xz" }
  ],
  "deps": { "hash": "<depsHash>", "release": "deps-<depsHash>" },
  "build": { "repo": "mallow-project/mallow", "commit": "…", "runID": "…", "runner": "macos-15-intel", "sdk": "MacOSX15.x", "peToolchain": "mingw-w64 GCC 13.x" }
}
```

**Rules.**

- The `baseSource.sha256` shown is the value highball-engine pins. **We must re-verify it ourselves** before release **[M]** [R2].
- `components[]` (including `license`, `linkage` and `licenseFiles`) is **generated** by `gen-licenses.py` from the licence audit (§2.3), never written by hand. `auditedLicense` records the string that `avcodec_license()` returned.
- `environment` may use only the placeholders `${RUNTIME}`, `${WINE_ROOT}`, `${RUNTIME_ID}` and `${CACHES}`. The schema rejects `DYLD_*` keys, with one exception: a locally generated manifest with `flavor: "standard"` and `"requiresDyldFallback": true`, allowed only if V27 proves it is needed (§3.11.6).
- **Imported Standard Wine** gets a locally generated manifest with `flavor: "standard"`, `features` from `RuntimeCapabilityProbe`, `entryPoints` into the intact `.app` (for example `"wineRoot": "Wine Stable.app/Contents/Resources/wine"`), and `archive.sha256` of the imported file.

#### 3.7.4 `catalog.json`

Published at `…/catalog/v1/catalog.json` with `catalog.json.sig`.

```json
{
  "schemaVersion": 1,
  "sequence": 42,
  "generatedAt": "2026-10-01T12:00:00Z",
  "entries": [
    {
      "id": "mallow-runtime-11.0-r1",
      "family": "mallow-runtime-11.0",
      "kind": "runtime",
      "flavor": "mallow",
      "channel": "stable",
      "version": "11.0-r1",
      "versionKey": [11, 0, 1],
      "displayName": "Mallow Runtime 11.0 (r1)",
      "archive": { "url": "https://github.com/mallow-project/mallow/releases/download/runtime-11.0-r1/mallow-runtime-11.0-r1-x86_64.tar.xz", "sha256": "…", "size": 340000000 },
      "manifest": { "url": "https://github.com/mallow-project/mallow/releases/download/runtime-11.0-r1/mallow-runtime-11.0-r1.manifest.json", "sha256": "…", "size": 4096, "format": "file", "installName": "manifest.json" },
      "minMacOS": "14.0",
      "minAppVersion": "0.2.0",
      "license": "LGPL-2.1-or-later",
      "sourceURL": "https://github.com/mallow-project/mallow/releases/tag/runtime-11.0-r1",
      "releaseNotesURL": "https://github.com/mallow-project/mallow/releases/tag/runtime-11.0-r1",
      "requiresRuntimeFeatures": []
    },
    {
      "id": "dxmt-0.80",
      "family": "dxmt",
      "kind": "backend",
      "backendKind": "dxmt",
      "channel": "stable",
      "version": "0.80",
      "versionKey": [0, 80],
      "displayName": "DXMT 0.80",
      "archive": { "url": "https://github.com/mallow-project/mallow/releases/download/backends-2026.10/dxmt-0.80-mallow1.tar.xz", "sha256": "…", "size": 19000000 },
      "minMacOS": "14.0",
      "minAppVersion": "0.2.0",
      "license": "MIT AND Apache-2.0 WITH LLVM-exception AND NCSA",
      "sourceURL": "https://github.com/3Shain/dxmt/releases/tag/v0.80",
      "requiresRuntimeFeatures": ["dllPathMap", "macdrvFunctions"]
    },
    {
      "id": "winetricks-20260125",
      "family": "winetricks",
      "kind": "tool",
      "channel": "stable",
      "version": "20260125",
      "versionKey": [20260125],
      "displayName": "winetricks 20260125",
      "archive": { "url": "https://raw.githubusercontent.com/Winetricks/winetricks/20260125/src/winetricks", "sha256": "…", "size": 0,
                   "format": "file", "installName": "winetricks", "executable": true },
      "license": "LGPL-2.1-or-later",
      "sourceURL": "https://github.com/Winetricks/winetricks/tree/20260125",
      "requiresRuntimeFeatures": []
    }
  ]
}
```

**Selection** (`ComponentCatalog.latest`). Per `family`, the client picks the entry with the highest `versionKey` whose `channel` is at or below the user's channel (`stable < preview < nightly`) and whose `minMacOS` and `minAppVersion` are satisfied. This follows Mythic's `UpdateCatalog` pattern **[H]** [R41]. `version` is for display only and is never compared. `size` is informational: the checksum is authoritative, and `0` means "unknown". A `format: "file"` archive is placed as `<id>/<installName>` without extraction.

#### 3.7.5 `backend.json`

This file sits at the root of each installed backend. For imported GPTK it is written by `GPTKImporter`.

```json
{
  "schemaVersion": 1,
  "backendID": "dxmt-0.80",
  "kind": "dxmt",
  "version": "0.80",
  "license": "MIT",
  "origin": "catalog",
  "prependRoots": { "default": ".", "nvext": "nvext" },
  "builtinDLLs": ["d3d10core", "d3d11", "dxgi", "winemetal"],
  "systemFiles": [
    { "source": "x86_64-windows/winemetal.dll", "destination": "system32", "variant": "default" },
    { "source": "i386-windows/winemetal.dll", "destination": "syswow64", "variant": "default" }
  ],
  "staticComponents": [
    { "name": "LLVM", "version": "15", "license": "Apache-2.0 WITH LLVM-exception AND NCSA", "in": ["x86_64-unix/winemetal.so"], "licenseFile": "licenses/LLVM-LICENSE.TXT" },
    { "name": "DXBCParser", "license": "MIT", "in": ["x86_64-windows/d3d11.dll", "i386-windows/d3d11.dll"], "licenseFile": "licenses/DXBCParser-LICENSE" },
    { "name": "nvapi", "license": "MIT", "in": ["nvext/x86_64-windows/nvapi64.dll"], "licenseFile": "licenses/nvapi-LICENSE" },
    { "name": "mingw-w64 DirectX headers", "license": "…", "in": [], "licenseFile": "licenses/mingw-directx-headers-LICENSE" }
  ],
  "licenseFiles": ["licenses/LICENSE"],
  "requires": { "runtimeFeatures": ["dllPathMap", "macdrvFunctions"], "minMacOS": "14.0", "peArchs": ["i386", "x86_64"] },
  "upstream": { "url": "https://github.com/3Shain/dxmt/releases/download/v0.80/dxmt-v0.80-builtin.tar.gz", "sha256": "…" }
}
```

- `staticComponents` is **required**, even when it is empty (`[]`). `backends.yml` fails when it is missing, or when a listed `licenseFile` is absent. The DXMT entries are **[H]** [R13] for LLVM 15 and **[M]** for the exact vendored components. The packaging script re-derives them from DXMT's source tree at the pinned tag.
- `nvapi64.dll` and `nvngx.dll` are **never** in `systemFiles`. They are reached only through the per-image map (§4.5).
- **GPTK imports** use `"origin": "userSupplied"`, `"prependRoots": {"default": "views/default", "nvext": "views/nvext", "metalfx": "views/metalfx"}`, `"d3dshared": "payload/external/libd3dshared.dylib"`, `"staticComponents": []`, and an `import` block. The `import` block records the licence file's sha256, the time the licence was accepted, the source volume name, and the observed `SigningInfo` of both Apple files.

#### 3.7.6 `image-index.json` and `dllpath-map`

`<bottle>/.mallow/image-index.json` (schema `image-index.schema.json`):

```json
{
  "schemaVersion": 1,
  "scannedAt": "2026-10-01T12:20:00Z",
  "images": [
    { "windowsPath": "C:\\Program Files (x86)\\Steam\\steamapps\\common\\Bar\\Bar.exe",
      "traits": { "machine": "amd64", "d3dImports": ["d3d12", "dxgi"] },
      "size": 81234567, "modified": "2026-09-30T08:00:00Z", "steamAppID": "678900" }
  ]
}
```

The `dllpath-map` text format is specified with patch 0002 in §3.11.4.

#### 3.7.7 Recipes (`recipes/*.json`, CC0-1.0)

```json
{
  "schemaVersion": 1,
  "id": "steam",
  "kind": "program",
  "version": 1,
  "name": "Steam",
  "description": "Valve's Steam client (Windows version).",
  "license": { "name": "Steam Subscriber Agreement", "url": "https://store.steampowered.com/subscriber_agreement/" },
  "sourceHosts": ["cdn.akamai.steamstatic.com"],
  "sourceKind": "vendor",
  "requires": { "runtimeFeatures": ["msync", "dllPathMap"], "backends": ["dxmt"], "minMacOS": "15.0", "freeDiskBytes": 2000000000 },
  "bottleTemplate": "steam",
  "steps": [
    { "download": { "id": "setup", "url": "https://cdn.akamai.steamstatic.com/client/installer/SteamSetup.exe", "fileName": "SteamSetup.exe", "sizeRange": [1000000, 20000000], "expectPE": true } },
    { "dllOverride": { "dll": "gameoverlayrenderer", "mode": "" } },
    { "dllOverride": { "dll": "gameoverlayrenderer64", "mode": "" } },
    { "registry": [ { "key": "HKEY_CURRENT_USER\\Software\\Wine\\WineDbg", "name": "ShowCrashDialog", "type": "dword", "data": 0 } ] },
    { "run": { "target": "$DOWNLOAD:setup", "arguments": ["/S"], "wait": true, "timeoutSeconds": 900, "acceptExitCodes": [0] } },
    { "waitForWineserver": {} },
    { "addProgram": { "windowsPathCandidates": ["C:\\Program Files (x86)\\Steam\\steam.exe", "C:\\Program Files\\Steam\\steam.exe"],
                      "name": "Steam", "pinned": true } },
    { "refreshImages": {} }
  ],
  "checks": [ { "anyFileExists": ["drive_c/Program Files (x86)/Steam/steam.exe", "drive_c/Program Files/Steam/steam.exe"] } ],
  "knownIssues": [ { "summary": "Black or blank Steam window", "workaround": "Program menu → Restart Steam web helper", "confidence": "M" } ],
  "testedWith": [ { "runtimeID": "mallow-runtime-11.0-r1", "result": "untested" } ]
}
```

**Required fields:** `license` (`name`, and `url` when one exists), `sourceHosts` and `sourceKind`. Verb recipes need them too. `RecipeValidator` and `scripts/check-recipes.py` reject a recipe whose download URLs are not `https`, whose hosts are not in `sourceHosts`, or whose `sourceHosts` are not all on `recipes/allowed-hosts.json`.

**Step types:** `download`, `run`, `verb`, `winetricks`, `registry`, `dllOverride`, `settings`, `addProgram`, `refreshImages` and `waitForWineserver`.

- **`download`** saves to `Caches/Downloads`. The final URL after redirects must still be on a `sourceHosts` host. A **`run`** step stages the file into the prefix (`drive_c/windows/temp/mallow/<uuid>/`), runs it through a `C:` path, and deletes the staging area afterwards (§5.7).
- **`dllOverride`** with `exe` absent goes into `bottle.dllOverrides`. With `exe` present it goes into the recipe's `HKCU\Software\Wine\AppDefaults\<exe>\DllOverrides` registry values, which `SettingsPlan` emits. Wine's precedence is `WINEDLLOVERRIDES` > `AppDefaults\<exe>\DllOverrides` > `DllOverrides` **[H]** [R48]. So the planner never puts a DLL named in any AppDefaults override into `WINEDLLOVERRIDES`. It moves that DLL's bottle-level value to the global registry key instead (§4.5).
- **`settings`** is a flat key-path patch, for example `{"display.retina": false, "sync": "msync"}`, using the same key paths as `mallow bottle set` and applied through `BottleSettingsApplier.edit`.
- **Verb recipes** (`kind: "verb"`) either list native steps (for example `vcrun2022` downloads `vc_redist.x64.exe` and `vc_redist.x86.exe` from Microsoft and runs them with `/install /quiet /norestart`) or delegate to winetricks, as in `{"winetricks": ["corefonts"]}`. A delegating recipe names the real download hosts of the winetricks verb, for example `"sourceHosts": ["github.com"], "sourceKind": "thirdPartyMirror"` for `corefonts` [R66].

**Idempotency.** Each recipe records itself in `bottle.installed`. Running it again re-applies the settings and re-runs only steps that are marked `always: true`.

**Winetricks execution** (`WinetricksRunner.run`):

- **Before running**, the terms from `TermsCatalog` are shown and must be accepted (the app's `TermsSheet`, or `--yes` in the CLI). For `dotnet*` verbs the notice says that Microsoft's terms require a Windows licence (§2.5).
- argv: `/bin/bash <Tools>/winetricks-20260125/winetricks -q <verbs…>`, spawned through `LaunchService.runHelper`.
- The environment is the bottle's base layers (so the sync variables match the server) plus:
  - `WINE=<wine>`
  - `WINESERVER=<wineserver>`
  - `W_CACHE=~/Library/Caches/Mallow/winetricks`
  - `WINETRICKS_LATEST_VERSION_CHECK=disabled`
  - `PATH=<wineRoot>/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin`

  These variables are **[H]** [R28].
- Output goes to a log file. It runs in-app with progress and cancellation, and never through Terminal or AppleScript.
- `/bin/bash` strips `DYLD_*`. That is harmless because our runtimes do not depend on `DYLD_*`. If V27 shows that a Standard Wine build needs a DYLD fallback, `WINE` points instead at a generated wrapper, `Tools/wine-wrapper-<runtimeID>.sh`. The wrapper sets the variable *after* the SIP boundary and then `exec`s wine (§3.11.6).
- The upstream winetricks `dxvk*` verbs are **blocked**: they install Linux DXVK 2.x, which MoltenVK cannot run **[M]** [R14].

#### 3.7.8 Log file header

See §5.5.

### 3.8 The `mallow` CLI

#### 3.8.1 Command tree

```
mallow [--home <dir>] [--json] [--quiet] [--verbose] <command>

  doctor [--bottle <b>]
  rosetta status
  rosetta install --accept-apple-license   # without the flag: prints the Terminal command; softwareupdate then asks
  runtime list [--available]
  runtime install <id>                     # catalog entry, or a builtin pin such as standard-wine-stable-11.0_1
  runtime import <archive.tar.xz | dir> [--sha256 <hex>] [--id <id>]
  runtime set-default <id>
  runtime verify <id>
  runtime rollback <id>                    # undo a same-ID repair (§3.11.7)
  runtime remove <id> [--force]
  runtime probe <dir>
  backend list [--available]
  backend install <id>
  backend import-gptk <dmg | dir> [--accept-license]
  backend remove <id>
  backend availability --bottle <b>
  bottle list
  bottle create <name> [--template standard|gaming|steam] [--runtime <id>] [--windows <ver>]
  bottle show <b> [--effective]            # --effective: resolved map rules, registry overrides, pending changes
  bottle set <b> <key>=<value>…            # graphics.backend, graphics.<backend>.<opt>, graphics.hideD3D12, sync,
                                           # cpu.advertiseAVX, display.retina, display.dpi, windows.version, input.*,
                                           # debug.preset, debug.custom, locale, env.<NAME>, dll.<name>, runtime.id,
                                           # runtime.pinned, image.<match>=<backend>
  bottle unset <b> env.<NAME>|dll.<name>|locale|image.<match>
  bottle apply <b>                         # re-apply registry/prefix settings
  bottle restart <b>                       # stop (§5.6), then apply pending changes
  bottle stop <b> [--grace 10]
  bottle kill <b>
  bottle rename <b> <new-name>
  bottle trash <b> [--yes]
  bottle path <b> [--drive-c]
  bottle clear-shader-cache <b> [--backend d3dmetal|dxmt|dxvk|all]
  program list <b> [--scan]                # --scan: discovery + image index refresh (BottleSettingsApplier.refreshImages)
  program add <b> <unix-path | windows-path> [--name <n>] [--pin]
  program set <b> <program> <key>=<value>… # backend, locale, env.<NAME>, dll.<name>, metalHUD, dxmtNVExt,
                                           # d3dmetalMetalFX, d3dmetalNVAPI, hideD3D12, debug.preset
  program pin|unpin <b> <program>
  program shortcut <b> <program> [--dir <dir>]
  run --bottle <b> <target> [--program <id>] [--backend <kind>] [--env K=V]… [--debug off|normal|crash|custom:<spec>]
      [--wait | --follow] [--restart] [--dry-run] [-- <args>…]
  wine --bottle <b> -- <wine args…>        # raw passthrough with base env (the bottle's map still applies)
  winetricks --bottle <b> <verb>… --yes    # prints each verb's terms and download hosts; refuses without --yes
  verb list | verb install --bottle <b> <verb>… [--yes]
  recipe list | recipe show <id>
  install <recipe-id> [--bottle <b>] [--yes]
  logs --bottle <b> [--list | --last | --follow] [--program <id>]
  diagnostics --bottle <b> [--output <file.zip>]
  licenses [--runtime <id>]                # licence notices and source URLs of the app and a runtime
```

- `<b>` accepts a UUID, a display name or a path.
- `<program>` accepts a program ID, a name, or a Windows path.
- `--home` sets `MALLOW_HOME`. All tests use it.
- `bottle set`, `bottle unset` and `program set` go through `BottleSettingsApplier.edit` (§3.4.8). They print what was applied now and what is pending until a restart (for example `display.retina (restart bottle to apply)`), and exit 0 in both cases.
- `run --restart` stops the bottle first if the plan has blocking restart reasons. Without it, such a plan fails with exit code 69.

#### 3.8.2 `run` semantics

| Flag | Behaviour |
|---|---|
| (default) | Detached. Spawns the program in a new process group, prints `{pid, logURL}`, and exits 0 immediately. |
| `--wait` | Waits for the spawned process and exits with its shell-style status. |
| `--follow` | Like `--wait`, and also streams the log file to stdout. |
| `--dry-run` | Prints the `LaunchPlan` as JSON (§3.7.0) and runs nothing, not even the preflight. The same code path serves as the golden-test oracle and as "show me the environment". |

#### 3.8.3 Exit codes

| Code | Meaning | `MallowError` cases |
|---|---|---|
| 0 | Success | |
| 64 | Usage error | (argument parsing) |
| 65 | Data or schema error | `unsupportedSchema`, `invalidConfiguration` |
| 66 | Not found | `notFound` |
| 69 | Precondition failed | `precondition(…)`: Rosetta missing, runtime missing, backend unavailable, bottle running, restart required, runtime in use, consent required |
| 70 | Internal error | `processFailed` for helpers, anything unexpected |
| 73 | Cannot create | `foreignDataRoot` |
| 75 | Temporary failure (retry) | `conflict`, `lockTimeout` |
| 77 | Verification failed | `verificationFailed`, `provenanceRejected` |
| 130 | Cancelled | `cancelled` |

`run --wait` returns the child's code instead.

### 3.9 The SwiftUI app

**Main window.** A `NavigationSplitView`:

- **Sidebar:** the bottle list with a running indicator, and a "+" button.
- **Detail:** a `ProgramGridView` showing pinned and discovered programs with extracted icons. The toolbar has Run… (open panel for `.exe`, `.msi`, `.bat`, `.lnk`), Stop, Force Stop, Open C: Drive, Winetricks…, Install… (recipes) and Settings.
- **Drag and drop.** Dropping an `.exe` or `.msi` on the window or the Dock icon opens a bottle picker.
- **Pending banner.** When `settingsPending` reports reasons, the bottle shows "Restart bottle to apply: Retina" with a Restart button.

**Settings sheet (`BottleSettingsView`) tabs:**

| Tab | Contents |
|---|---|
| General | Name, Windows version, runtime (with "Follow default runtime" = unpinned), locale ("Use Mac setting" by default) |
| Graphics (`GraphicsSettingsView`) | Backend picker. Each option shows `BackendResolver.availability` and the reasons when it is unavailable. Image rules list (Steam client images, per-program rules, auto rules from the image index, each with its effective backend). Metal HUD, DXR, MetalFX, DXVK async/HUD, DXMT NVEXT/spatial upscale, "Hide D3D12", "Clear shader cache" |
| Performance | Sync mode (MSync is shown only when the runtime supports it), advertise AVX (off by default) |
| Display & Input | Retina, DPI, Command/Option mapping |
| Advanced | Environment variables, DLL overrides, WINEDEBUG preset, sandbox options |

Every edit goes through `BottleSettingsApplier.edit`.

**Other windows and sheets:**

- **Per-program sheet:** arguments, working directory, environment, locale, backend override, HUD, NVEXT/MetalFX/NVAPI, "Create Mac shortcut". It shows "Also applies when Steam starts this game" for backend and MetalFX/NVAPI, because those are per-image map rules. For environment-only options it shows "Only when launched from Mallow" (§4.5).
- **Runtimes window:** installed and available runtimes and backends, install/remove/rollback, "Set as default", "Import Standard Wine…", "Import Game Porting Toolkit…" (`GPTKImportSheet`, with the licence text and an Accept button). Each runtime and backend shows its licence summary and a **"Source code" link** (from `licenses/SOURCE.md`, or `CatalogEntry.sourceURL`).
- **`TermsSheet`:** shown before any recipe, verb or winetricks run. It gives the terms name and link, the real download hosts, and a "third-party mirror" badge where it applies. Accept, or Cancel.
- **Acknowledgements (`AcknowledgementsView`, menu Mallow → Acknowledgements):** shows `LICENSE`, `NOTICE` and `THIRD_PARTY_LICENSES.md` from `Bundle.main`, and a link "Source code for this version" to the `MallowSourceURL` Info.plist value (`https://github.com/mallow-project/mallow/tree/v<version>`).
- **Onboarding:**
  1. **Rosetta** (`RosettaConsentSheet`). If Rosetta is missing, the sheet says: "Installing Rosetta 2 means you accept Apple's software licence agreement", with a link to https://www.apple.com/legal/sla/ and explicit **Agree and Install** and Cancel buttons. Agree records a `ConsentRecord` in `settings.json`, then runs `softwareupdate` with `Rosetta.nonInteractiveInstallArguments(consent:)`. If that fails without administrator rights, the sheet shows `Rosetta.interactiveCommand` (without `--agree-to-license`) to copy into Terminal, where `softwareupdate` asks for agreement itself **[M]** [R38] (V16).
  2. **Runtime download.** Before v0.2 this is the builtin Standard Wine pin; from v0.2 on it is the catalog's Mallow Runtime.
  3. **First bottle.**
- **Log viewer:** tails the log file (a `DispatchSource` on file writes, polling as fallback). It has filters for `err:`, `fixme:`, and `D3DM`/`DXMT`/`DXVK` lines, plus "Export diagnostics".
- **URL scheme `mallow://`:**
  - `launch?bottle=<uuid>&program=<id>` is used by Mac shortcuts.
  - `open?bottle=<uuid>` opens a bottle.
- **Quitting** with programs running asks: "Leave programs running" (the default) or "Stop all". Programs are independent process groups, so they survive the app quitting.

**Constraints under Command Line Tools:**

- No `#Preview`. No `@Entry`; write manual `EnvironmentKey` conformances in `EnvironmentKeys.swift`.
- No asset catalogs. The icon comes from `iconutil` via `make-icns.sh`, with an optional prebuilt `Assets.car` from CI **[H]**.

### 3.10 Building the `.app` without Xcode

**`scripts/build-app.sh`** (arm64 only). macOS runs it with `/bin/bash` 3.2, where `set -u` treats an empty array expansion as an unbound variable **[H]** (tested). So every array expansion uses the `${A[@]+"${A[@]}"}` form, and every variable has a default.

```bash
#!/bin/bash
# SPDX-License-Identifier: 0BSD
set -euo pipefail
CODESIGN=/usr/bin/codesign      # absolute path: on the design host a conda `codesign`/`clang` shadow PATH [H]
IDENTITY="${IDENTITY:--}"       # "-" = ad-hoc; "Developer ID Application: …" in release CI
VERSION="${VERSION:-0.0.0-dev}"
BUILD_NUMBER="${BUILD_NUMBER:-0}"
GIT_REF="${GIT_REF:-v$VERSION}"
swift build -c release --arch arm64 --product MallowApp
swift build -c release --arch arm64 --product mallow
BIN="$(swift build -c release --arch arm64 --show-bin-path)"
APP=dist/Mallow.app
rm -rf "$APP"; mkdir -p "$APP/Contents/"{MacOS,Helpers,Resources,Frameworks}
cp "$BIN/MallowApp" "$APP/Contents/MacOS/Mallow"
cp "$BIN/mallow"    "$APP/Contents/Helpers/mallow"
cp Resources/Info.plist "$APP/Contents/Info.plist"
/usr/bin/plutil -replace CFBundleShortVersionString -string "$VERSION" "$APP/Contents/Info.plist"
/usr/bin/plutil -replace CFBundleVersion -string "$BUILD_NUMBER" "$APP/Contents/Info.plist"
/usr/bin/plutil -replace MallowSourceURL -string "https://github.com/mallow-project/mallow/tree/$GIT_REF" "$APP/Contents/Info.plist"
scripts/gen-third-party-licenses.sh --check        # fails if THIRD_PARTY_LICENSES.md is stale vs Package.resolved
cp LICENSE NOTICE THIRD_PARTY_LICENSES.md "$APP/Contents/Resources/"
scripts/make-icns.sh Resources/AppIcon-1024.png "$APP/Contents/Resources/AppIcon.icns"
if [ -f dist/Assets.car ]; then cp dist/Assets.car "$APP/Contents/Resources/"; fi   # optional, built with Xcode in CI
/usr/bin/plutil -lint "$APP/Contents/Info.plist"
TS=(); if [ "$IDENTITY" != "-" ]; then TS=(--timestamp); fi
# (v0.8) Sparkle, BEFORE any signing (install_name_tool invalidates signatures):
#   ditto Sparkle.framework → Contents/Frameworks
#   install_name_tool -add_rpath @executable_path/../Frameworks "$APP/Contents/MacOS/Mallow"   # SwiftPM does not add it
#   then sign Autoupdate, Updater.app, Sparkle.framework (inside-out); XPC services removed (app is not sandboxed)
# inside-out; never --deep for signing
"$CODESIGN" --force --options runtime ${TS[@]+"${TS[@]}"} --sign "$IDENTITY" "$APP/Contents/Helpers/mallow"
"$CODESIGN" --force --options runtime ${TS[@]+"${TS[@]}"} --entitlements Resources/Mallow.entitlements \
            --sign "$IDENTITY" "$APP"
"$CODESIGN" --verify --strict --deep -vv "$APP"
/usr/bin/ditto -c -k --keepParent "$APP" "dist/Mallow-$VERSION.zip"
scripts/verify-app-bundle.sh "dist/Mallow-$VERSION.zip"
```

This is based on the research team's local test, where an assembled `.app` signed with hardened runtime verified cleanly **[H]**.

**`scripts/verify-app-bundle.sh`** unzips the artifact into a temp directory. It fails unless all of these hold:

- `Contents/Resources/LICENSE` exists and contains "GNU GENERAL PUBLIC LICENSE" and "Version 3".
- `NOTICE` and `THIRD_PARTY_LICENSES.md` exist.
- `THIRD_PARTY_LICENSES.md` names every package in `Package.resolved`, and from v0.8 includes Sparkle's bsdiff notice.
- `MallowSourceURL` is set.
- `codesign --verify --strict` passes.

`ci.yml` (bundle job) and `release-app.yml` both run it.

**`Resources/Info.plist` keys:**

| Key | Value |
|---|---|
| `CFBundleExecutable` | `Mallow` |
| `CFBundleIdentifier` | `io.github.mallow-project.Mallow` (§2.6.1) |
| `CFBundleName`, `CFBundleDisplayName` | `Mallow` |
| `CFBundlePackageType` | `APPL` |
| `CFBundleShortVersionString`, `CFBundleVersion` | set by the build script |
| `MallowSourceURL` | set by the build script; used by the Acknowledgements window |
| `NSHumanReadableCopyright` | "Copyright © 2026 Mixutin and the Mallow contributors. Licensed under 0BSD." |
| `LSMinimumSystemVersion` | `15.0` |
| `NSHighResolutionCapable` | true |
| `NSPrincipalClass` | `NSApplication` |
| `CFBundleIconFile` | `AppIcon` |
| `CFBundleIconName` | `AppIcon` (used only if `Assets.car` is present) |
| `LSApplicationCategoryType` | `public.app-category.games` |
| `NSMicrophoneUsageDescription`, `NSCameraUsageDescription` | Windows programs may request them |
| `NSLocalNetworkUsageDescription` | LAN games; whether it is needed for child processes is **[L]** |
| `CFBundleURLTypes` | scheme `mallow` |
| `CFBundleDocumentTypes` | `.exe`, `.msi`, `.lnk`, `.bat` as viewer, "Open with Mallow" |
| `SUFeedURL`, `SUPublicEDKey` | added in v0.8 |

**`Resources/Mallow.entitlements`:**

- `com.apple.security.device.audio-input` = true
- `com.apple.security.device.camera` = true
- No App Sandbox.
- No `cs.*` exceptions. The frontend loads no plugins, and a hardened parent can spawn unsigned x86_64 children under Rosetta without special entitlements **[H]** (tested).
- Whether TCC charges a child's microphone or camera access to the responsible app is **[L]**. Including both entitlements costs nothing.

**Other scripts** (all start with `#!/bin/bash`, `set -euo pipefail` and the SPDX header, and are checked by `shellcheck` in `lint.sh`):

| Script | What it does |
|---|---|
| `scripts/make-icns.sh` | `sips` resizes the 1024 px PNG to 16–1024 px (@1x and @2x) in an `.iconset`, then `iconutil -c icns` **[H]** |
| `scripts/install-cli.sh` | Symlinks `~/.local/bin/mallow`, or `/usr/local/bin/mallow` if that is writable, to `Mallow.app/Contents/Helpers/mallow`. Never uses sudo. It refuses to overwrite a `mallow` that is not a symlink into a `Mallow.app`. |
| `scripts/gen-builtin-recipes.sh` | Embeds `recipes/**/*.json` and `recipes/allowed-hosts.json` as raw string literals in `BuiltinRecipes.generated.swift`. The CI `generated` job fails if the checked-in file is stale. No Swift test does this. |
| `scripts/gen-third-party-licenses.sh` | Writes `THIRD_PARTY_LICENSES.md` from `Package.resolved`, taking each package's licence file from `.build/checkouts/<pkg>/` and Sparkle's full `LICENSE` from its artifact. `--check` compares instead of writing. |
| `scripts/check-recipes.py` | Schema + `license` block + `sourceHosts` ⊆ `allowed-hosts.json` + every URL `https` and on a listed host. Used by `ci.yml` and the community recipe repository (§2.9). |
| `scripts/dev-clean.sh` | Removes `.build/*/debug` and test products. The design host has about 1.6 GB free and one debug, release and test build uses about 250 MB **[H]**. |
| `scripts/lint.sh` | `swift format lint --recursive --strict Sources Tests`; `shellcheck` on every shell script; the layering grep (§3.2); fails if any target enables `NonisolatedNonsendingByDefault` (§3.5) |

### 3.11 Runtime build pipeline (`runtime/`, `deps.yml`, `runtime.yml`)

#### 3.11.1 Inputs

Git mirrors of the CX source exist ([R3]) and are useful for reading and diffing, but the build always starts from the official tarball. Every input has `url`, `sha256`, `license` and `role`, and the build refuses unpinned inputs.

**`runtime/inputs.json`:**

| Input | Pin |
|---|---|
| CX source | `crossover-sources-26.3.0.tar.gz`, 149,054,023 bytes **[H]** [R1]. sha256 must be re-verified (see §3.7.3). Only `sources/wine` is used. |
| MoltenVK | v1.4.2 `MoltenVK-macos.tar`. It is universal; thin it with `lipo -thin x86_64` **[M]** [R15]. Its `ExternalRevisions/` names the embedded components whose licences we ship [R69]. |
| wine-mono and wine-gecko | Versions read from `dlls/appwiz.cpl/addons.c` at build time. Expected to be 10.4.1 and 2.47.4 for this source **[H]** [R50]. Tarballs come from `dl.winehq.org`. |
| Dependency artifact | `deps-<depsHash>` from `deps.yml` (below). Referenced by hash, never rebuilt implicitly. |
| Build tools (not shipped) | mingw-w64 GCC, bison ≥ 3.0 (the system bison is 2.3 **[H]**), ccache, pkgconf, nasm, meson and ninja (pinned `pip` versions). |

**`runtime/deps/inputs.json`** lists every bundled dependency: `name`, `version`, `url`, `sha256`, `spdx` (its licence), the recipe script and its configure flags, and a top-level `allowedLicenses` SPDX allowlist. The allowlist is LGPL-2.0/2.1/3.0-or-later, `GPL-2.0-or-later OR LGPL-3.0-or-later` (GMP, Nettle), MIT, BSD-2-Clause, BSD-3-Clause, Zlib, FTL, bzip2-1.0.6, libpng-2.0 and Apache-2.0. `runtime/deps/denylist.txt` lists dylib leaf-name prefixes that must never be bundled: `libx264`, `libx265`, `libpostproc`, `libfdk-aac`, `libxvidcore`, `librubberband`, `libvidstab`, `libfrei0r`, `libgpl`.

**Toolchain.** mingw-w64 GCC, not llvm-mingw. Open community build reports for CX-source Wine use mingw-w64 GCC 13 **[M]** [R2][R6]. One report says an llvm-mingw-built `kernelbase.dll` stalls Steam login **[L]** [R6].

#### 3.11.2 Build pipeline

**Why dependencies are built from source.** Intel Homebrew no longer provides what we need. On 2026-09-23, glib 2.90.0, gstreamer 1.28.7, ffmpeg 9.0.2, sdl2-compat and gnu-tar had **no** x86_64 macOS bottle, the `sdl2` formula no longer existed, and mingw-w64 had only a `sonoma` Intel bottle **[H]** [R82]. Homebrew's `ffmpeg` is licensed GPL-3.0-or-later **[H]** [R54]. Its gstreamer is a single formula with GPL plugin sets, which pulls in ffmpeg, x264 and x265 [R55]; we checked the formula's licence field **[H]**, and the reviewer checked the rest. Building those formulae from source on a 4-vCPU Intel runner would not fit the time budget, would give minos 15.0, and would bundle GPL code. So our own scripts build a **minimal** dependency set once per change, and Homebrew supplies build *tools* only.

**A. `deps.yml`** (runner `macos-15-intel`; runs when `runtime/deps/**` changes; timeout 240 min; result cached as a GitHub Release `deps-<depsHash>`, where `depsHash` = sha256 of the sorted `runtime/deps/**` tree):

1. `install-build-tools.sh`: pkgconf and nasm (Homebrew if an Intel bottle exists, else from pinned source), meson and ninja from `pip`, cmake (preinstalled).
2. Environment for every recipe:
   - `MACOSX_DEPLOYMENT_TARGET=14.0`
   - `CC="clang -arch x86_64"`, `CFLAGS="-O2 -mmacosx-version-min=14.0"`
   - `LDFLAGS="-Wl,-headerpad_max_install_names"`
   - `PKG_CONFIG_LIBDIR=$DEPS_PREFIX/lib/pkgconfig`, so no Homebrew library can leak in
   - `--prefix=$DEPS_PREFIX`
3. `build-deps.sh` runs `runtime/deps/recipes/*.sh` in dependency order:
   - zlib, bzip2, brotli, libpng
   - freetype (`--with-png --with-brotli --with-bzip2 --with-zlib --without-harfbuzz`)
   - gmp, nettle, libtasn1, libunistring, libidn2
   - gnutls (`--without-p11-kit --without-tpm --without-tpm2 --disable-dane --disable-doc --disable-tools`)
   - SDL2 2.32.x (real SDL2, CMake, shared)
   - libffi, pcre2
   - glib (`-Dintrospection=disabled -Dtests=false -Dnls=disabled`; libintl via glib's proxy-libintl fallback **[M]** V33)
   - orc
   - gstreamer core (`-Dtests=disabled -Dexamples=disabled`; keeps `gst-plugin-scanner`)
   - gst-plugins-base (`-Dauto_features=disabled`, then `app`, `audioconvert`, `audioresample`, `videoconvertscale`, `typefind`, `playback`, `volume`)
   - gst-plugins-good (`-Dauto_features=disabled`, then `isomp4`, `matroska`, `wavparse`, `audioparsers`, `id3demux`)
   - FFmpeg
   - gst-libav

   The GStreamer "ugly" and "bad" sets are **not** built, and `-Dgpl=disabled` is passed wherever the option exists. FFmpeg is configured with `--disable-gpl --disable-nonfree --disable-version3 --enable-shared --disable-static --disable-programs --disable-doc --disable-encoders --disable-muxers --disable-devices --disable-filters --enable-filter=aresample,aformat,format,scale --disable-network --disable-autodetect --disable-everything`, then the components in `ffmpeg-components.txt` are enabled. The first list covers these decoders: h264, hevc, aac, mp3float, wmav1, wmav2, wmapro, wmv1, wmv2, wmv3, vc1, mpeg4, msmpeg4v3, mpeg1video, mpeg2video, vp8, vp9, theora, vorbis, opus, flac, pcm_s16le, adpcm_ms, bink and binkaudio. It also covers the matching demuxers (mov, matroska, asf, avi, mpegps, mpegts, ogg, wav, mp3, flac, bink) and parsers. The list is refined with `mfprobe` and title tests **[M]** (V32).
   - An **alternative for the media stack**, if the from-source GStreamer proves too costly, is the official universal GStreamer 1.28.x macOS package. It ships LGPL builds, and we would `lipo -thin x86_64` it [R81] **[M]**. It is not planned. If adopted, its GPL plugins must be excluded by the same audit.
4. **Audit** (fails the job):
   - every dylib's `otool -L` closure stays inside `$DEPS_PREFIX`, `/usr/lib` and `/System`;
   - `LC_BUILD_VERSION` minos ≤ 14.0 for every Mach-O;
   - no leaf name matches `denylist.txt`;
   - every library's `spdx` is on `allowedLicenses`;
   - a small x86_64 tool calls `avcodec_license()`, `avformat_license()` and `avutil_license()`, and all three must start with "LGPL".
5. **Package:**
   - `mallow-deps-<depsHash>-x86_64.tar.xz` (bsdtar, which keeps symlinks and modes);
   - `mallow-deps-<depsHash>-sources.tar.xz`, with every upstream tarball, `runtime/deps/**` (our build scripts) and `inputs.json`;
   - `deps-manifest.json` (name, version, spdx, files).

   No dependency patches exist today. The first one adds `runtime/deps/patches/`, and it goes into the sources tarball automatically.

**B. `runtime.yml`** (tag `runtime-*` or manual). Four jobs:

*Job `build`* (runner `macos-15-intel` or `macos-26-intel`; timeout 180 min):

1. **`fetch-sources.sh`.** Download the inputs, verify their sha256, extract `sources/wine`, and apply `patches/0001…0003` with `patch -p1`. Download and verify the `deps-<depsHash>` artifact into `$DEPS_PREFIX`.
2. **`install-build-tools.sh`.** mingw-w64 (Homebrew installs the `sonoma` bottle on macOS 15 **[M]**; otherwise from source, cached), bison and ccache. Homebrew is never a source of *bundled* libraries.
3. **`audit-vendor-strings.sh`** (source tree, §3.11.3).
4. **`configure-wine.sh`.**
   - Environment: `MACOSX_DEPLOYMENT_TARGET=14.0`, `BISON` pointing at Homebrew's bison, and `PKG_CONFIG_LIBDIR=$DEPS_PREFIX/lib/pkgconfig`.
   - Flags:
     ```
     --build=x86_64-apple-darwin --enable-archs=i386,x86_64 --with-mingw
     --without-x --without-wayland --with-coreaudio --with-freetype --with-gnutls
     --with-sdl --with-vulkan --with-gstreamer --with-ffmpeg --disable-tests
     ```
   - Soname pins, so that every leaf-name `dlopen` resolves through `LC_RPATH`:
     - `ac_cv_lib_soname_vulkan=` (cached as empty, so configure treats the Khronos loader as not found). Wine's `configure.ac` probes `libvulkan` first and falls back to MoltenVK only if it is absent **[H]** (reviewed, wine-11.0 L1932–1935). The empty-cache behaviour is **[M]** (V26).
     - `ac_cv_lib_soname_MoltenVK=@rpath/libMoltenVK.dylib`
     - `ac_cv_lib_soname_freetype=@rpath/libfreetype.6.dylib`
     - `ac_cv_lib_soname_gnutls=@rpath/libgnutls.30.dylib`
     - `ac_cv_lib_soname_SDL2=@rpath/libSDL2-2.0.0.dylib` (real SDL2 from `runtime/deps`, never sdl2-compat)
     - `dlopen("@rpath/…")` is documented in `dlopen(3)` **[H]** [R33]. Whether Wine's configure accepts `@rpath/` values unchanged is **[M]** (V3). Fallback: leaf names, which dyld still resolves through the calling image's `LC_RPATH` **[H]** [R33].
   - **Post-configure assertions** in `include/config.h`, each with a message that names the pin to fix:
     - `SONAME_LIBMOLTENVK` is defined, and `SONAME_LIBVULKAN` equals `"@rpath/libMoltenVK.dylib"`;
     - `SONAME_LIBSDL2` equals `"@rpath/libSDL2-2.0.0.dylib"`;
     - `HAVE_FFMPEG` is defined;
     - `GSTREAMER_LIBS` in the Makefile is non-empty.

     Configure otherwise drops `winedmo` and `winegstreamer` silently **[M]** [R6].
5. **`build-wine.sh`.** `make -j"$(sysctl -n hw.ncpu)"` with ccache (`CCACHE_COMPILERCHECK=content`, `CCACHE_SLOPPINESS=time_macros,include_file_mtime,include_file_ctime`, `CCACHE_BASEDIR`, `CCACHE_NOHASHDIR=1`). Then `make install-lib DESTDIR=$STAGE`, **not** `install`, which pulls in about 2,181 import libraries **[M]**. Expect about 80–90 min cold and about 15 min with a warm ccache **[H]** [R2].
6. **`bundle-dylibs.sh`.**
   - Walk the dependency closure of `bin/*` and `lib/wine/x86_64-unix/*.so` with `otool -L`. Copy the libraries from `$DEPS_PREFIX` (and MoltenVK) into `lib/`. Fail if anything resolves elsewhere outside `/usr/lib` and `/System`.
   - `install_name_tool -id @rpath/<leaf>` and `-change <abs> @rpath/<leaf>`.
   - Add `LC_RPATH @loader_path/../..` to every `lib/wine/x86_64-unix/*.so`, `@loader_path` to `lib/*.dylib`, and `@loader_path/../lib` to `bin/*`.
   - GStreamer plugins go to `lib/gstreamer-1.0` with `@loader_path/..`, and `gst-plugin-scanner` goes to `libexec/gstreamer-1.0/`.
7. **`install-addons.sh`.** Unpack wine-mono into `share/wine/mono/wine-mono-<v>/` and wine-gecko into `share/wine/gecko/wine-gecko-<v>-{x86,x86_64}/`. Wine finds them through `WINEDATADIR`, which ntdll computes from the runtime's own location **[H]** [R50]. So bottles never show the "install Mono?" prompt.
8. **`strip-and-sign.sh`.**
   - `x86_64-w64-mingw32-strip --strip-debug` over `lib/wine/x86_64-windows/*` and `i686-w64-mingw32-strip --strip-debug` over `i386-windows/*`. Unstripped DWARF is about 600 MB **[M]**.
   - `strip -S` on Mach-O files.
   - `/usr/bin/codesign -f -s -` on every Mach-O, **after** every `install_name_tool` edit.
9. **`gen-licenses.py`** builds `licenses/` and the `components[]` list (§2.3, §3.11.3).
10. **`gen-manifest.py`.** Writes `files.sha256` (sorted `sha256␠␠relative-path`, regular files only) and `manifest.json`. It takes `features` from source greps, for example `grep -r WINEMSYNC dlls/ntdll/unix`, and cross-checks them with `RuntimeCapabilityProbe` rules (NUL-terminated markers, export trie).
11. **`verify-runtime.sh`** (static checks; all must pass):
    - No absolute load commands outside `/usr/lib` and `/System` (`otool -L`/`-D`).
    - `LC_BUILD_VERSION` minos ≤ 14.0 on every Mach-O.
    - Undefined-symbol audit against the SDK `.tbd` files. A build that weak-linked `pipe2` from a newer SDK crashed older macOS versions **[M]** [R6].
    - `lib/wine/i386-windows` holds more than 500 files. `ntdll.dll` is under 1.5 MB, which proves stripping ran.
    - **Licences** (§3.11.3):
      - every `libs/*` in the source has `licenses/wine-bundled/<lib>`;
      - every `lib/*.dylib` has `licenses/deps/<name>`;
      - every licence is on the allowlist;
      - no leaf name is on the denylist;
      - `dlopen_all` (run natively on this Intel runner) reports `avcodec_license()` and `avutil_license()` starting with "LGPL".
    - **Vendor strings in binaries:** every PE and Mach-O file is searched for `codeweavers.com` in ASCII and UTF-16LE. Any hit fails.
    - **No Apple payload** anywhere in the tree: no `D3DMetal.framework`, no `libd3dshared.dylib`, no `apple_gptk`, and no Mach-O that satisfies `anchor apple`.
12. **Intermediate artifact:** `bsdtar -cJf stage.tar.xz`. `actions/upload-artifact` zips drop symlinks and modes **[M]**, so the tree is archived first.

*Job `package`* (runner `macos-26`, arm64, where Homebrew `gnu-tar` has bottles **[H]** [R82]):

- **`package-runtime.sh`.** Reproducible tar: GNU tar `--sort=name --mtime=@$SOURCE_DATE_EPOCH --owner=0 --group=0 --numeric-owner --format=posix`, then single-threaded `xz -6`. Output is `.tar.xz`, **not** zstd, because the system `tar` cannot extract zstd without an external `zstd` binary **[H]**.
- **`package-sources.sh`.** The source assets of §2.3.
- The cheap `verify-runtime.sh` checks run again on the repacked tree.

*Job `smoke`* (runner `macos-26`, arm64, after `sudo softwareupdate --install-rosetta --agree-to-license`; the runner image does not list Rosetta **[M]** [R36]; this is our CI accepting Apple's licence for our own machines). It runs under `env -i HOME=… PATH=/usr/bin:/bin`, with **no DYLD variables**:

- (a) `wine wineboot --init` in a temp prefix, then `wineserver -w`.
- (b) `wine cmd /c echo mallow-ok`.
- (c) `wndtest.exe`: creates a window and fails if the display driver fell back to nodrv. Whether the runner has a GUI session is **[M]** (V11).
- (d) `mfprobe.exe`: finds an H.264 decoder MFT.
- (e) `dlopen_all` (built with `clang -arch x86_64`): every bundled dylib and `.so` loads.
- (f) `WINEMSYNC=1 WINEESYNC=1 wine wineboot -u` succeeds.
- (g) **Prepend order:** with `WINEDLLPATH_PREPEND=<dir with a marked test d3d11.dll>`, `dllmap_probe.exe` reports the test DLL, not Wine's.
- (h) **No leak into the prefix:** with the same prepend set, `rm .update-timestamp; wine wineboot -u`. Afterwards `system32/d3d11.dll` and `syswow64/d3d11.dll` are byte-identical to Wine's own `lib/wine/*-windows/d3d11.dll`.
- (i) **Per-image map:** a map with `probe_a.exe → dirA` (d3dshared = a fake dylib whose constructor writes a marker file), `probe_b.exe → -` (d3dshared `-`), and `* → dirB`. `probe_a.exe` (a copy of `dllmap_probe.exe`) starts `probe_b.exe` and `probe_c.exe` with `CreateProcess`, so the children inherit its environment, as Steam's games do. Expected: A loads dirA's DLL and writes the marker; B loads Wine's own DLL and writes no marker; C loads dirB's DLL.
- (j) `winedbg.exe`'s resources contain the Mallow tracker URL and no `codeweavers.com`.
- (k) `vkprobe.exe` creates a Vulkan instance (MoltenVK).

*Job `release`* (`runtime-<ver>`): the archive, `manifest.json` with its `.sig`, `files.sha256`, **both source assets** (§2.3), and `THIRD_PARTY_LICENSES`. `sign-manifest.sh` runs `openssl pkeyutl -sign -rawin` with Homebrew **openssl@3** (the system LibreSSL has no Ed25519 **[H]**) and the `RELEASE_SIGNING_KEY` secret, and emits the `mallow-sig-v1` format. It also runs `actions/attest-build-provenance` on the archive **[M]** [R46]. After that, a PR updates `catalog/catalog.json` automatically.

An **experimental job** on arm64 `macos-26` cross-builds everything (deps and Wine) with `clang -arch x86_64` and native `--with-wine-tools`. It is `continue-on-error`, and exists to prove the arm64 path before x86_64 runners are retired (announced for about August 2027) **[M]** [R38-ci].

#### 3.11.3 Licence and vendor-string audits

**`gen-licenses.py`** (runs in `build`, re-checked in `verify-runtime.sh`):

1. For every directory `sources/wine/libs/<lib>`, copy each `LICENSE*`, `COPYING*`, `COPYRIGHT*`, `NOTICE*` and `README*` that contains a licence into `licenses/wine-bundled/<lib>/`. A `libs/` directory with no such file fails the build until a mapping is added to `runtime/licenses-map.json` (initially `{}`), which names the file in that library that carries its licence. Expected libraries include capstone, jxr, ldap (OpenLDAP licence: binary redistributions must reproduce the notice), tiff, png, jpeg, gsm, lcms2, musl, xml2, xslt, compiler-rt, faudio and tomcrypt **[H]** (reviewed) [R85].
2. `licenses/deps/<name>/`: the licence files from each dependency's source tarball.
3. `licenses/moltenvk/`: MoltenVK's `LICENSE` plus each component from `ExternalRevisions/` (SPIRV-Cross, SPIRV-Tools, cereal, Vulkan-Headers), taken from the tagged sources **[M]** [R69].
4. `licenses/THIRD_PARTY_LICENSES.md`: one section per component. The JPEG section contains the IJG sentence "this software is based in part on the work of the Independent JPEG Group" **[H]** [R71].
5. `licenses/COPYING.LIB`, `licenses/AUTHORS` and `licenses/SOURCE.md`.
6. The manifest's `components[]` and `licensesDigest`.

**`audit-vendor-strings.sh`** (source tree):

```
grep -rIn -E 'codeweavers\.com|CrossOver' sources/wine \
     --include='*.rc' --include='*.po' --include='*.c' --include='*.m' --include='*.in'
```

It drops hits inside C comments and copyright lines. Every remaining hit must appear in `runtime/vendor-strings.allow`, which records `path`, a hash of the line, and the reviewer's note (for example "log message, not user-visible"). A new hit fails the build until someone reviews it. After patch 0003, `programs/winedbg/winedbg.rc` must have no hits. The survey of other user-visible CX strings is not finished **[M]** (V39). Copyright headers and `AUTHORS` are never changed.

#### 3.11.4 Our Wine patches (LGPL-2.1-or-later, written by us)

**`0001-ntdll-add-WINEDLLPATH_PREPEND.patch`**

- In `dlls/ntdll/unix/loader.c:set_dll_path()`, read `getenv("WINEDLLPATH_PREPEND")` and split it on `:`. Store the entries in a **separate private array**, `prepend_paths[]`. **They are not inserted into `dll_paths`.**
- `find_builtin_dll` searches `prepend_paths` first, then `dll_paths` as before. For each entry it tries `<entry>/x86_64-windows/<dll>` (or `i386-windows`), and loads the unixlib from `<entry>/x86_64-unix/<dll>.so` **[H]** [R8]. This is exactly the backend directory layout.
- **Why separate:** `dlls/ntdll/unix/env.c` exports every `dll_paths` entry to the Windows environment as `WINEDLLDIR%u`. On every top-level start where the prefix needs an update, `build_initial_params` runs wineboot with that environment. `setupapi`'s `fakedll.c:create_wildcard_dlls` then copies DLLs from the `WINEDLLDIR%u` directories into `system32`/`syswow64`, and the first match wins **[H]** (reviewed, wine-11.0) [R61][R62]. If the prepend directories were in `dll_paths`, a backend's `d3d11`, `dxgi` and `winemetal` would be copied into the prefix, untracked. Smoke test (h) guards this.
- About 25 lines. Gcenx carries a patch with the same variable name for the same purpose **[H]** [R22]. We use the same name for compatibility with Standard Wine builds that already honour it, but we write our own implementation. Whether Gcenx's version exports to `WINEDLLDIR` is unknown **[L]** (V35). Environment-mode launches on such runtimes are protected by the base-environment `wineboot -u` preflight instead (§5.1).

**`0002-ntdll-per-image-dll-path-map.patch`** (replaces Draft 1's `WINEDLLPATH_PREPEND_EXCLUDE`)

- **Variable:** `WINEDLLPATH_PREPEND_MAPFILE=<absolute Unix path>`. If it is set and the file parses, `WINEDLLPATH_PREPEND` is ignored for that process.
- **When it is evaluated:** once per process, lazily. That is at the first builtin DLL search, or in CX's `init_non_native_support` before it would `dlopen` libd3dshared, whichever comes first. The key is the process image path from its process parameters (`ImagePathName`, with a `\??\` prefix removed). Whether that is available on the Unix side at the CX hook point is **[M]** (V2), so it needs a prototype.
- **Effect for the matched image:**
  - its `prepend` directories go into the private `prepend_paths[]` of patch 0001, and are never exported;
  - its `d3dshared` column replaces `getenv("CX_APPLEGPTK_LIBD3DSHARED_PATH")` in `init_non_native_support` (the CX hook **[H]** [R32]): `-` means libd3dshared is never loaded in this process, and a path means that file is loaded.
- **Why a file and not an environment value:** Steam passes its environment on to every game it starts, so the whole rule set has to travel with Steam's process tree. A file lets that set be long, and lets Mallow update it while Steam is running: each game reads the current file when it starts.
- **File format v1** (UTF-8, LF line endings, at most 1 MiB and 4096 lines):

  ```
  wine-dllpath-map 1
  # <match> TAB <prepend> TAB <d3dshared>
  C:\Program Files (x86)\Steam\steamapps\common\Bar\Bar.exe	/…/UserSupplied/D3DMetal/3.0/views/default	/…/UserSupplied/D3DMetal/3.0/payload/external/libd3dshared.dylib
  steam.exe	-	-
  steamwebhelper.exe	-	-
  *	/…/Backends/dxmt-0.80	-
  ```

  - `<match>`: a full DOS path (`X:\…`), a basename (no `\` or `/`), or `*`. Comparison is case-insensitive (`wcsicmp` after UTF-8 → UTF-16 conversion). A full path beats a basename, which beats `*`. Within one class, the first matching line wins.
  - `<prepend>`: `-` for none, or `:`-separated absolute directories.
  - `<d3dshared>`: `-`, or an absolute path.
  - A malformed file produces one `ERR` line and falls back to the process environment, the same as having no map.
- Probe markers: `"WINEDLLPATH_PREPEND_MAPFILE\0"` and `"wine-dllpath-map 1\0"`. Smoke test (i) is its regression test.
- **Fallback if V2 fails:** evaluate the map in `init_startup_info`, where the parent passes the image name. If neither works, Steam bottles fall back to one bottle-wide backend, and per-game backends apply only when the game is launched directly from Mallow.

**`0003-winedbg-point-crash-dialog-at-mallow-tracker.patch`**

- The CX tree's `programs/winedbg/winedbg.rc` links to `https://www.codeweavers.com/compatibility/` and to a codeweavers.com support-ticket page **[H]** [R58]. Upstream wine-11.0 links to the WineHQ AppDB and the WineHQ GitLab bugs page **[H]** [R59].
- We replace both links with `https://github.com/mallow-project/mallow/issues` and the matching text ("report it to the Mallow project"). We point at our own tracker, not back at WineHQ, because WineHQ asks for bug reports against unmodified Wine **[M]**, and a modified CX-based build is not that. Any `.po` translations that carry the URLs are updated the same way (the audit finds them). Copyright headers are untouched.

**Upstreaming.** Upstream Wine is unlikely to accept environment-variable hooks like 0001 and 0002, so we expect to maintain them downstream. 0003 is Mallow-specific by nature.

**Dock names.** CX-source Wine re-execs through a "descriptively-named link" for Dock icon names only when `WINEDLLPATH` is set (`CW HACK 22144`) **[H]** [R32]. We do not set `WINEDLLPATH`, so the Dock shows the loader name until we evaluate that behaviour (V21).

#### 3.11.5 Runtime layout (the extracted tree)

```
mallow-runtime-11.0-r1/
├── manifest.json   files.sha256
├── bin/{wine, wineserver, …}               # x86_64 Mach-O (+ Wine's helper links)
├── lib/*.dylib                              # bundled deps from runtime/deps; install names @rpath/<leaf>
├── lib/gstreamer-1.0/*.dylib
├── libexec/gstreamer-1.0/gst-plugin-scanner
├── lib/wine/{i386-windows, x86_64-windows, x86_64-unix}/   # new WoW64: no i386-unix [H]
├── share/wine/{nls, fonts, wine.inf, mono/wine-mono-10.4.1, gecko/wine-gecko-2.47.4-{x86,x86_64}}
└── licenses/
    ├── COPYING.LIB  AUTHORS  SOURCE.md  THIRD_PARTY_LICENSES.md
    ├── wine-bundled/<lib>/…                 # from sources/wine/libs/*
    ├── deps/<name>/…                        # from runtime/deps sources
    └── moltenvk/…                           # MoltenVK + ExternalRevisions components
```

#### 3.11.6 Standard Wine (interim and dev fallback)

- **What it is:** Gcenx's WineHQ macOS build `wine-stable-11.0_1-osx64.tar.xz` (185,303,032 bytes) **[H]** [R4].
- **In-app install (v0.1).** Its URL, sha256 and size are compiled into `BuiltinComponents` as `standard-wine-stable-11.0_1`, so the signed app is the root of trust. The exact release URL and sha256 are pinned when implemented **[M]**. `mallow runtime install standard-wine-stable-11.0_1` and the onboarding "Download runtime" button use it until the catalog exists (v0.2). `mallow runtime import <file>` still works for other builds, for example devel/staging 11.17.
- **Layout kept intact.** The extracted `Wine Stable.app` tree stays as it is under `Runtimes/standard-wine-stable-11.0_1/`. `manifest.entryPoints` points into it (`"wineRoot": "Wine Stable.app/Contents/Resources/wine"`). Moving `Resources/wine` out of its bundle might break library or ICD discovery **[L]**, so we never do it.
- **Vulkan.** Gcenx's README lists `vulkan-loader` and `moltenvk` as runtime dependencies **[H]** [R4]. So Vulkan on these builds probably goes through the Khronos loader and ICD-manifest discovery, not a direct MoltenVK `dlopen`. Whether the tarball bundles both is **[L]** (V27). The importer handles three cases:
  - it finds `libvulkan*.dylib` and a `MoltenVK_icd.json` → it sets `VK_DRIVER_FILES` and `VK_ICD_FILENAMES` to that json in the local manifest (`${WINE_ROOT}` placeholder);
  - it finds a loader and `libMoltenVK.dylib` but no json → it writes `<runtime>/mallow-icd/MoltenVK_icd.json` pointing at the bundled library;
  - it finds neither → `features.vulkan = none`, and DXVK is unavailable.
- **`DYLD_*`.** The launcher `posix_spawn`s `bin/wine` directly, and that keeps `DYLD_*` variables; only SIP-protected interpreters such as `/bin/sh` and `/bin/bash` strip them **[H]**. If V27 shows that a `DYLD_FALLBACK_LIBRARY_PATH` is needed:
  - it is allowed only for `flavor: "standard"`, through `requiresDyldFallback` in the local manifest and the runtime layer;
  - winetricks gets a generated `WINE=` wrapper script that sets the variable after the SIP boundary (§3.7.7).

  Our own runtime never uses this.
- **CI:** `runtime.yml`'s `real-runtime-tests` job also runs against the pinned Standard Wine: `wine cmd /c echo`, `wndtest.exe` (window + text rendering), and `vkprobe.exe` (Vulkan instance creation), all with `DYLD_*` unset.
- **Quarantine:** removed after the checksum passes. Unsigned x86_64 binaries run fine once quarantine is gone, but hang or are killed while it is present **[H]** (tested).
- **Missing capabilities:** MSync, `dllPathMap`, `macdrvFunctions` (so no DXMT) and `d3dmetalHooks` **[M]** [R51]. `dllPathPrepend` is decided by the probe. Gcenx says his builds honour `WINEDLLPATH_PREPEND` **[M]** [R22]. Bottles on Standard Wine use **environment mode** (§4.5).
- **GStreamer:** these builds need a system-wide GStreamer.framework, and `doctor` warns when it is missing **[H]** [R4].
- **Homebrew:** the `wine-*` casks were disabled on 2026-09-01, so we never tell users to `brew install` Wine **[H]** [R5].

#### 3.11.7 Runtime lifecycle

- **Updates install side by side.** Runtime IDs include the version (`mallow-runtime-11.0-r2`), so an update is a new directory and never replaces a runtime in place. `rename(2)` onto a non-empty directory fails with `ENOTEMPTY` **[H]**, which is another reason not to replace in place.
- **Same-ID repair** (reinstalling an ID whose files fail `verify`): the new tree is staged, then swapped in with `renamex_np(staging, target, RENAME_SWAP)`, and the old tree becomes `<id>.previous`. `runtime rollback <id>` swaps it back. Directory swaps on APFS are **[M]** (V38).
- **Which runtime a bottle uses:**
  - `runtime.pinned == true` → `runtime.id`.
  - `pinned == false` (the default) → while a server is running, the runtime that started it (`applied.server.runtimeID`). At a **cold start**, `settings.defaultRuntimeID`.
  - `RuntimeManager.effectiveRuntime(for:server:)` implements this.
  - When the effective runtime differs from `applied.prefix.runtimeID`, the planner adds the `updatePrefix` preflight (`wine wineboot -u` with base layers only). `LaunchService` then records the new `applied.prefix.runtimeID`.
  - An unpinned bottle never moves runtimes while its server is running.
- **Refusals.** Repair, rollback and remove are refused while any bottle using that runtime has a live server. Otherwise newly spawned clients would run new binaries against the old server and hit a protocol mismatch. `RuntimeManager` learns this through the injected `RuntimeUsage` (§3.4.3). A bottle "uses" a runtime if it is pinned to it, or its `applied.server`/`applied.prefix` names it, or it is unpinned and the runtime is the default.
- **Retention.** An old runtime stays installed until no bottle uses it and the user removes it. The Runtimes window marks it "unused".

```swift
extension RuntimeManager {
    /// pinned → runtime.id; else server running → server.runtimeID; else settings.defaultRuntimeID.
    public func effectiveRuntime(for bottle: Bottle, server: ServerState?) throws -> InstalledRuntime
}
```

### 3.12 Backend component packaging (`runtime/backends/`, `backends.yml`)

- **`package-dxmt.sh`** downloads `dxmt-v0.80-builtin.tar.gz`, which is pinned in `runtime/backends/inputs.json`.
  - Contents: `x86_64-windows/{d3d10core,d3d11,dxgi,winemetal,nvapi64,nvngx}.dll`, `i386-windows/{d3d10core,d3d11,dxgi,winemetal}.dll`, `x86_64-unix/winemetal.so` **[H]** [R12].
  - It **moves `nvapi64.dll` and `nvngx.dll` into `nvext/x86_64-windows/`**, so the default prepend root never exposes NVAPI (see the Steam/Chromium issue in §6).
  - **Licences:** it also fetches DXMT's source at the same tag (pinned). From that source it copies DXMT's `LICENSE` (MIT), LLVM 15's `LICENSE.TXT` including the legacy NCSA section (`winemetal.so` statically links LLVM 15 **[H]** [R13]), the vendored DXBCParser (MIT) and NVIDIA nvapi (MIT) licences, and the mingw DirectX headers' licence into `licenses/`. It then writes `staticComponents`. A vendored directory in the source (`external/`, submodules) without a licence file fails the job.
  - It then writes `backend.json`, packs `dxmt-0.80-mallow1.tar.xz`, and signs it.
- **`package-dxvk-macos.sh`** downloads the `v1.10.3-20230507-repack` release **[H]** [R14]:
  - The `-builtin` variant becomes `x86_64-windows/` and `i386-windows/` (`d3d10core`, `d3d11`).
  - The plain variant becomes `native/x64/` and `native/x32/`, used by runtimes that lack `dllPathPrepend`.
  - Plus `dxvk.conf.sample`, `licenses/LICENSE` (zlib), and `staticComponents` derived from the source tree at the tag (Khronos headers and similar) **[M]**.
- `backends.yml` fails if a backend has no `staticComponents` list, or if a listed licence file is missing.
- Backend releases carry their corresponding source (the upstream source archive at the tag) beside the binary, following the §2.3 hard rule. For DXMT after v0.80 (LGPL) this is required; for MIT and zlib components it is a courtesy.
- **No D3DMetal job exists, by design.**

### 3.13 Catalog and update security

| Threat | Mitigation |
|---|---|
| Tampered download | HTTPS only; sha256 from the **signed** catalog or the **compiled-in** builtin pins; runtime manifest signature; embedded manifest must match the signed one byte for byte (sha256) |
| Rollback or freeze | Monotonic `sequence`; client stores `lastCatalogSequence` |
| Path traversal or symlink escape in an archive | `ArchiveExtractor.validateTree` before activation; bsdtar strips `..` and absolute paths by default |
| Key compromise | Two keys in `TrustedKeys.release` (current and next); rotation announced by a catalog signed with both; keys held by two maintainers (`GOVERNANCE.md`) |
| Gatekeeper / quarantine hang | Quarantine removed recursively **only after** verification |
| Partial or concurrent install | Staging directory plus `rename(2)` (new IDs) or `RENAME_SWAP` (repair); `Runtimes/.lock` across processes |
| Recipe download redirected to another host | `HTTPClient.download` returns the final URL; `RecipeRunner` rejects it unless its host is in the recipe's `sourceHosts` |
| Proprietary files entering through an import | `ProvenanceGuard` on runtime, Standard Wine and bottle imports; `PrefixAudit` quarantine (§2.4 rule 7) |
| Another app's data folder with the same name | `.mallow-root.json` marker check (§2.6.1) |

URLSession downloads made by a non-sandboxed app may or may not get quarantine attributes **[L]**. We strip them regardless.

### 3.14 Relationship to `docs/SECURITY_MODEL.md`

The companion document proposes stricter defaults than this design:

- a Seatbelt profile around every Wine process (`sandbox-exec` or a `sandbox_init` launcher);
- `z:` removed by default;
- real folders instead of home-folder symlinks;
- `winebrowser` disabled;
- disposable APFS-clone bottles.

**Decision (project owner, 2026-09-23): secure by default.** Where the two documents differ, `SECURITY_MODEL.md` sets the defaults. Bottles are created with `hideHostRoot: true` (no `z:`) and `linkHomeFolders: false` (real folders instead of links into `$HOME`). Compatibility-driven relaxations are per-bottle, opt-in, and shown in the Security panel. Points already made compatible:

- Everything Wine must open is staged **inside** `drive_c` (§5.7), so settings and recipes work with `z:` removed.
- The Seatbelt profile's file-read allowance must also cover `Backends/`, `UserSupplied/D3DMetal/` and the bottle's `.mallow/dllpath-map`, not only `RUNTIME_DIR`. `SECURITY_MODEL.md` must be updated for that before its v0.1 profile ships.
- Wrapping the spawn in `sandbox-exec` changes `SpawnRequest.executable`. That change goes through `PosixSpawner` and `LaunchPlanner` and needs a DESIGN.md revision first.

---

## 4. Graphics backend mechanics

### 4.1 Why a prepend path is required (verified)

In upstream `wine-11.0` `dlls/ntdll/unix/loader.c`, `set_dll_path()` builds `dll_paths = [dll_dir, $WINEDLLPATH…]` in that order. The CX 26.3 LGPL source has the same code **[H]** [R8][R32].

`find_builtin_dll()` walks the search path in order. For each entry it tries:

1. `<entry>/<pe_dir>/<name>`, where `pe_dir` is `/x86_64-windows` or `/i386-windows`;
2. the unixlib `<entry>/<so_dir>/<name>.so`, where `so_dir` is always the *host* arch, `/x86_64-unix`. So i386 PE modules use the x86_64 unixlib under new WoW64;
3. then `<entry>/<name>` directly.

The consequence: a builtin `d3d11.dll` listed in `WINEDLLPATH` always loses to Wine's own. Patches 0001 and 0002 add a **private** list that is searched before `dll_dir` and is never exported as `WINEDLLDIR%u` (§3.11.4).

**Load-order syntax.** `WINEDLLOVERRIDES` values and registry `DllOverrides` values are parsed character by character:

- `n` and `b` are recognised, and so are the orders `n,b` and `b,n`, and the long forms `native`, `builtin`.
- An empty value means disabled. So does any value without `n` or `b`, which is why `=d` also works **[H]** [R48].

**Precedence.** `get_load_order` checks `WINEDLLOVERRIDES` first, then `HKCU\Software\Wine\AppDefaults\<exe>\DllOverrides`, then `HKCU\Software\Wine\DllOverrides` **[H]** (reviewed, wine-11.0 `loadorder.c`) [R48]. An environment value therefore beats every per-program registry rule. This is why translation-DLL load orders move to the registry (§4.5).

Mallow writes `name=` for disabled in the environment, and `""` in the registry.

### 4.2 Capability matrix

| Backend | Runtime features required | macOS | PE archs | Distribution |
|---|---|---|---|---|
| wined3d | none | 15+ (app floor) | i386, x86_64 | in Wine |
| dxvk (builtin mode) | `vulkan != none`, and `dllPathMap` (map mode) or `dllPathPrepend` (environment mode) | 15+ | i386, x86_64 | catalog backend |
| dxvk (native mode) | `vulkan != none` (environment mode only) | 15+ | i386, x86_64 | catalog backend (`native/`) |
| dxmt | `macdrvFunctions`, `dllPathMap` | 15+ (DXMT needs 14+, recommends 15) **[H]** [R12] | i386, x86_64 | catalog backend |
| d3dmetal | `d3dmetalHooks`, `dllPathMap`, and personality-routine unwinding for builtins (assumed present in CX source **[M]** [R52]) | 15+ (GPTK 3) **[H]** [R17] | x86_64 only | user-supplied import |

- DXMT and D3DMetal require `dllPathMap`, which only our runtime has. Otherwise Steam, and any launcher, would pass one process's backend on to every child (§4.5).
- MSync requires `features.msync`.
- DLSS→MetalFX requires d3dmetal, macOS 26 or later, and `GPTKPayload.hasMetalFXBridge` **[H]** [R17].

### 4.3 Per-backend configuration (`BackendConfigurator`)

**Translation DLL set** `T = {d3d8, d3d9, d3d10, d3d10_1, d3d10core, d3d11, d3d12, d3d12core, dxgi}`. Every configuration sets **every** member of `T` explicitly, so a stale native DLL in `system32` can never win. `d3d12core` exists in current Wine **[M]**. `perImageOnly = {nvapi, nvapi64, nvngx}` are never set bottle-wide.

`BackendConfigurator.contribution` returns environment variables, translation overrides, prepend directories, an optional libd3dshared path and managed files. **Where each part goes depends on the mode (§4.5)**: in map mode the overrides go to the registry and the directories and libd3dshared go into the map. In environment mode everything goes into the environment.

#### wined3d

| | |
|---|---|
| Prepend | none (Wine's own DLLs) |
| Overrides | all of `T` = `b` |
| libd3dshared | never |
| Env | `WINE_D3D_CONFIG=renderer=vulkan` only when `wined3d.renderer == .vulkan`; `csmt=0x0` only when `csmt == false` **[H]** [R48-wined3d] |
| Notes | D3D12 goes to Wine's vkd3d over MoltenVK. It is weak, so the UI warns. The steam template pins Steam's own images to this configuration (§4.5). |

#### dxvk (builtin mode)

| | |
|---|---|
| Prepend | `Backends/dxvk-macos-1.10.3-20230507` |
| Overrides | `d3d10core,d3d11=b`; `d3d8,d3d9,d3d10,d3d10_1,dxgi=b` (DXVK-macOS ships no `dxgi` or `d3d9` **[H]** [R14]); `d3d12,d3d12core=` (disabled) unless `hideD3D12 == false` |
| Env | `DXVK_ASYNC=1` (when `dxvk.async`), `DXVK_HUD=<hud>` (when set), `DXVK_STATE_CACHE_PATH=~/Library/Caches/Mallow/dxvk/<bottleID>`, `DXVK_LOG_PATH=<log dir>`, `DXVK_CONFIG_FILE=<bottle>/.mallow/dxvk.conf` (only if that file exists) |
| Notes | MoltenVK is found by winevulkan through `@rpath` inside our runtime (or through the ICD json on Standard Wine, §3.11.6). `MVK_CONFIG_*` values can only be set through custom env. |

Hiding `d3d12` follows frankea/Whisky's preset (credited in `NOTICE`, §2.1). The rationale, that games which probe D3D12 fall back to D3D11, is **[L]** (V9).

#### dxvk (native mode; environment mode on runtimes without `dllPathPrepend`)

- Managed files: `native/x64/{d3d10core,d3d11}.dll` go to `system32`, and `native/x32/*` go to `syswow64`.
- Overrides: `d3d10core,d3d11=n,b`. The rest of `T` = `b`.
- Existing files are backed up once into `.mallow/backup/` and restored when the backend changes. Whisky's copy-and-forget approach is the bug we avoid **[H]** [R20].

#### dxmt (needs `macdrvFunctions` and `dllPathMap`)

- **Prepend:** `Backends/dxmt-0.80`. When NVEXT is enabled for the image, also `Backends/dxmt-0.80/nvext`.
- **Overrides:** `d3d10core,d3d11,dxgi,winemetal=b`; `d3d8,d3d9,d3d10,d3d10_1=b`; `d3d12,d3d12core=` unless `hideD3D12 == false`. With NVEXT for the image: `nvapi64=b`.
- **Why d3d12 is hidden by default:** DXMT replaces `dxgi`, and Wine's vkd3d `d3d12` presumably needs Wine's own `dxgi`. That is inference **[L]**. The steam template sets `hideD3D12: false` (§6.1).
- **Never set** `d3d11`/`dxgi` to `n,b` for the builtin build **[H]** [R12].
- **Managed files:** `winemetal.dll` into `system32` and `syswow64`, as the DXMT wiki's builtin instructions say **[H]** [R12]. `nvapi64.dll` and `nvngx.dll` are **never** copied into the prefix. They are reached only through the image's map rule.
- **Env:**
  - `DXMT_LOG_PATH=<log dir>`
  - `DXMT_ENABLE_NVEXT=1` (NVEXT on)
  - `DXMT_METALFX_SPATIAL_SWAPCHAIN=1` (spatial upscaling on)
  - `DXMT_CONFIG=d3d11.metalSpatialUpscaleFactor=<f>` (factor set)

  All four are **[H]** [R13].
- **Shader cache:** left at DXMT's default, `$(DARWIN_USER_CACHE_DIR)/dxmt/<exe>`, so it is shared across bottles.
- Heroic forces `WINEMSYNC=1` for DXMT runtimes. Whether DXMT *requires* MSync is **[L]**. We default MSync on anyway (§4.7).

#### d3dmetal (needs `d3dmetalHooks` and `dllPathMap`; user-supplied)

- **Prepend:** `UserSupplied/D3DMetal/<v>/views/default`. Plus `views/metalfx` when MetalFX is enabled for the image, and `views/nvext` when NVAPI is enabled for the image. **Never** bottle-wide except through the image's own rule.
- **libd3dshared:** `<…>/payload/external/libd3dshared.dylib`, delivered through the map's `d3dshared` column. The patched loader reads it in place of `CX_APPLEGPTK_LIBD3DSHARED_PATH` and uses it on Sonoma or later **[H]** [R32]. Images whose rule has no D3DMetal (Steam, other games) never load it.
- **Overrides:** `d3d10,d3d10core,d3d11,d3d12,dxgi=b` (Apple's forwarders); `d3d8,d3d9,d3d10_1,d3d12core=b`. With MetalFX: `nvngx=b`. With NVAPI: `nvapi64=b`.
- **Env:**
  - `D3DM_SUPPORT_DXR=0|1` only when `d3dmetal.dxr != nil` **[H]** [R17].
  - `D3DM_ENABLE_METALFX=1` when MetalFX is on and the host is macOS 26 or later **[H]** [R17].
  - `CX_ACTIVE_GRAPHICS_BACKEND=d3dmetal` **only** if `features.activeBackendHint` (the variable has been found in the LGPL source). Its effect on DLSS frame generation is **[L]** [R19].
- **MetalFX and DLSS.** Apple's Read Me tells users to copy `nvngx-on-metalfx.dll` into `system32` as `nvngx.dll` **[H]** [R17]. **We deliberately deviate:** a file in `system32` is visible to every process in the bottle, and a visible `nvapi64` has been reported to crash Steam's Chromium helpers **[M]** [R6]. Instead, the image's rule adds `views/metalfx` (where `nvngx.dll` → `nvngx-on-metalfx.dll`), and its AppDefaults sets `nvngx=builtin`. A game that loads `nvngx.dll` by name then gets the builtin from the prepend. A game that loads `C:\windows\system32\nvngx.dll` by full path relies on Wine loading a missing system-directory DLL as a builtin by name. That is **[M]** (V25), and needs a DLSS title to verify.
  - If V25 fails, the fallback is a builtin-marked placeholder copy in `system32`, owned by `backend:<id>`. It is used only if the same test shows that images *without* the view fail to load it cleanly.
- **32-bit programs:** the payload has no i386 DLLs, so i386 lookups fall through to Wine's own builtins. The resolver steers 32-bit programs to DXMT instead (§4.4).

### 4.4 `auto` resolution policy (`BackendResolver.resolve`)

Resolution is **per image**. `PEFile` machine and imports are a heuristic, and games that load D3D dynamically from a launcher show no D3D imports.

| Signal from the image | D3DMetal imported and available | Result |
|---|---|---|
| imports `d3d12.dll` | yes | **d3dmetal** |
| imports `d3d12.dll` | no | **wined3d** (vkd3d), with warning "D3D12 titles generally need D3DMetal (import GPTK)" |
| amd64, imports `d3d11`/`d3d10*`/`dxgi` | any | **dxmt**, or **d3dmetal** if `preferD3DMetalForD3D11` |
| i386, imports `d3d10*`/`d3d11` | any | **dxmt** → dxvk → wined3d |
| imports only `d3d9`/`d3d8`/`ddraw` | any | **wined3d** |
| no D3D imports (launchers, dynamic loading), or unknown image (`image == nil`, the map's `*` rule) | any | **dxmt** (it replaces only d3d10core/d3d11/dxgi; D3D9 stays on wined3d) |

- **Fallback chain when the chosen backend is unavailable:** dxmt → dxvk → wined3d. Every step is recorded in `reasons`.
- **Where auto runs:** once for the map's `*` rule (unknown image), once per indexed image (auto rules are emitted only where the result differs from `*`), and once for each launch target that has no rule.
- **What the user sees:** the resolution appears in the log header, in `run --dry-run`, in `bottle show --effective`, and in the UI. An explicit choice (not `auto`) never falls back silently. It fails with `.precondition(.backendUnavailable)`.

### 4.5 Applying backends: image-map mode and environment mode

`GraphicsPlanner` picks the mode from the runtime:

| | **imageMap mode** (runtime has `dllPathMap`: our runtime) | **environment mode** (otherwise: Standard Wine) |
|---|---|---|
| Scope of a backend choice | **per process image**, including processes Steam or a launcher starts | per Mallow launch; inherited by every child process |
| Backend directories | rules in `<bottle>/.mallow/dllpath-map` (`WINEDLLPATH_PREPEND_MAPFILE`) | `WINEDLLPATH_PREPEND` in the launch environment |
| Load orders of `T` and `perImageOnly` | **registry**: `HKCU\Software\Wine\DllOverrides` + `AppDefaults\<exe>\DllOverrides` deltas | `WINEDLLOVERRIDES` |
| Other overrides (`winemenubuilder.exe`, `gameoverlayrenderer`, user entries outside T) | `WINEDLLOVERRIDES` | `WINEDLLOVERRIDES` |
| libd3dshared | map column | not available (no `d3dmetalHooks`) |
| Managed files (desired set) | union over **every backend the map references** | bottle backend ∪ backends of running programs ∪ the launching program's backend |
| Backends offered | all four | wined3d, dxvk (builtin if `dllPathPrepend`, else native) |

**Why.** Steam passes its own environment on to every game it starts, and `SteamAPI_RestartAppIfNecessary` relaunches directly started games through Steam **[M]** (reviewed). So a backend chosen only in the environment of Mallow's launch would give every Steam game the Steam process's backend, and a `WINEDLLOVERRIDES` value would override every per-program registry rule (§4.1). In imageMap mode, each process looks up its own image in the map inside Wine, and the registry holds the load orders. So a game gets its own rule whoever starts it.

**Rules and their precedence** (the planner resolves conflicts before writing; the patch then applies "full path > basename > `*`"):

1. **transient**: a one-off `run --backend` or "Run with…". Full path. `LaunchPlanner` passes the running launches' transient rules plus the new one to `GraphicsPlanner`, so the preflight `applyPrefix` writes a map (and any AppDefaults delta) that already contains it. When that launch exits, `LaunchService` rewrites the map without it, and the next apply removes its registry delta. Lost if the app quits, and dropped at the next apply.
2. **program**: `ProgramConfig.backend` and its MetalFX/NVAPI/NVEXT/hideD3D12 options. Full Windows path.
3. **override**: `graphics.imageOverrides`, by basename or full path. The steam template adds `SteamLibrary.clientImages` → `wined3d`.
4. **auto**: indexed images (`image-index.json`; Steam libraries and pinned programs), when `graphics.autoImageRules` is on. Full path, emitted only when the result differs from `*`. They are never emitted for an image whose basename a higher-precedence basename rule already covers, so the patch's "full path beats basename" cannot invert the precedence.
5. **`*`**: the bottle backend, resolved with `image == nil`.

**Registry written in imageMap mode** (part of `GraphicsPlan.registry`, applied by `LaunchService.applyPrefix`):

- `HKCU\Software\Wine\DllOverrides`: every `T` member = `"builtin"`. `d3d12` and `d3d12core` = `""` if the `*` rule hides D3D12. `winemetal` = `"builtin"` when any rule uses DXMT. The bottle's own `dllOverrides` entries for `T` members go here too, on top of these.
- `HKCU\Software\Wine\AppDefaults\<exe>\DllOverrides`, only for images whose rule differs from `*` in load orders: D3D12 hidden or visible, `nvngx="builtin"` (MetalFX), and `nvapi64="builtin"` (NVAPI/NVEXT). A program's own `dllOverrides` for `T` members go here too.
- Mallow owns exactly the `T` and `perImageOnly` values in the global key, and the AppDefaults values of the basenames in `applied.prefix.managedAppDefaults`. Values Mallow no longer needs are deleted at the next apply. Nothing else is touched.
- **Basename collisions.** AppDefaults is keyed by basename. Two rules with the same basename but different deltas (two different `launcher.exe` files) get a merged delta: the union of the `builtin` entries, with D3D12 left visible. The plan carries a warning that `bottle show --effective` and the UI display. Directories and libd3dshared are unaffected, because they are matched by full path in the map.
- `WineEnvironment.resolve` asserts that no `T` or `perImageOnly` member reaches `WINEDLLOVERRIDES` in imageMap mode.

**Environment variables of backends** (`DXMT_*`, `DXVK_*`, `D3DM_*`, `WINE_D3D_CONFIG`) are namespaced. In imageMap mode the planner sets the union for every referenced backend in the `backend` layer, from the **bottle's** options. Per-program options that exist only as environment variables (spatial upscaling factor, HUDs, DXR, `D3DM_ENABLE_METALFX`, `DXMT_ENABLE_NVEXT`) come from the program layer, so they apply only when Mallow launches the program. A game that Steam starts inherits Steam's environment, and so the bottle's values. The UI labels these options "Only when launched from Mallow". That `D3DM_ENABLE_METALFX=1` and `DXMT_ENABLE_NVEXT=1` do no harm in images whose rule lacks the matching view is **[L]** (V34). Until V34 is closed they are set bottle-wide only when the bottle-level option is on.

**Hot changes while the server runs.** Rewriting the map, running `regedit` (through the running server) and adding managed files all work while programs run. New processes see the change, and running processes keep what they already loaded. So changing a backend never needs a restart. Retina, DPI, sync and runtime changes do need one (§5.6).

**Managed files.**

- Only two kinds of file are ever placed in the prefix: DXMT's `winemetal.dll`, and DXVK native-mode copies (environment mode).
- **Desired set:** in imageMap mode, the files of every backend the current map references. This follows from the configuration, so Steam-started games are covered. In environment mode, it is the bottle backend, plus the backends of programs `LaunchService` is tracking as running, plus the program being launched.
- **Additions** happen immediately. **Removals** (restore the backup, or delete) happen only while the bottle's wineserver is stopped. Before that they are `deferredRemovals`, retried when `bottleIdle` fires. A file that a running process, or a game Steam starts later, depends on is never pulled away.
- `ManagedFilesTests` runs two programs with different backends at once and checks that neither loses its files.

**Legacy bottles.** For a bottle imported from elsewhere, `doctor` and `BottleImporter` run `PrefixAudit`. Native `d3d11.dll`, `dxgi.dll` or `d3d9.dll` files in `system32` (PE files without the Wine builtin marker) are offered for "Restore Wine DLLs": they move to `.mallow/quarantine/` and `wineboot -u` runs. Apple-made translation DLLs and MetalFX bridges are quarantined automatically on import and reported (§2.4 rule 7).

### 4.6 D3DMetal import layout

```
UserSupplied/D3DMetal/3.0/
├── import.json                    # source, version.plist values, licence sha256, acceptedAt, observed SigningInfo
├── License.pdf                    # the user's own copy, kept locally for reference
├── payload/                       # verbatim `ditto` of <GPTK>/redist/lib
│   ├── external/{D3DMetal.framework, libd3dshared.dylib}
│   └── wine/{x86_64-windows/*.dll, x86_64-unix/*.so}
└── views/                         # symlink farms we create; nothing of Apple's is modified
    ├── default/x86_64-{windows,unix}/<every payload name except nvapi64 and nvngx*> → ../../../payload/wine/…
    ├── nvext/x86_64-{windows,unix}/nvapi64.{dll,so} → …
    └── metalfx/x86_64-{windows,unix}/nvngx.{dll,so} → …/nvngx-on-metalfx.{dll,so}   (if present)
```

**Where the facts come from.** The directory names (`redist/lib`, `wine/x86_64-{unix,windows}`) and the MetalFX file names (`nvngx-on-metalfx.*`) come from Apple's GPTK 3.0 Read Me **[H]** [R17]. The importer **enumerates** the actual `.dll` and `.so` names from the user's disk image at import time. Our code carries no list of Apple's file names beyond those the Read Me documents. Draft 1's list from inspecting CrossOver's copy is withdrawn (§2.7).

**How the pieces resolve.**

- Wine loads the unixlib from `<view>/x86_64-unix/<name>.so` **[H]** [R8]. In the payload those `.so` files are symlinks to `../../external/libd3dshared.dylib`, as the unmodified Apple layout already has. The view's symlink chain ends at the real file.
- `libd3dshared.dylib` must be reached by its real path, because `@loader_path` must resolve to `payload/external`. The unmodified Apple layout already depends on dyld resolving symlinks for `@loader_path` **[M]** [R6] (V4).

### 4.7 Settings shared across backends, and their defaults

| Setting | Mechanism | Default | Source |
|---|---|---|---|
| Sync | `WINEMSYNC=1` **and** `WINEESYNC=1` for `msync` (MSync wins when both are set; D3DMetal reportedly checks for ESYNC). `WINEESYNC=1` for `esync`. Neither for `none`. | `msync` when the runtime supports it, else `none` | **[H]** [R31] (priority); **[M]** [R19] (D3DMetal detects ESYNC) |
| Advertise AVX | `ROSETTA_ADVERTISE_AVX=1` (changes cpuid only; macOS 15 or later). Unset when off. | **off**, as Apple documents: "Defaults to 0 (OFF)". Recipes opt in per title with a `settings` step | **[H]** [R17] |
| Locale | `LANG` and `LC_ALL` set only when `locale` is set (bottle or program) | **unset**: Wine derives the Windows locale from the Mac's settings (§5.2) | **[H]** (reviewed) [R61] |
| Metal HUD | `MTL_HUD_ENABLED=1`; optional `MTL_HUD_ELEMENTS`, `MTL_HUD_ALIGNMENT` through custom env | off | **[H]** [R23] |
| Retina | `HKCU\Software\Wine\Mac Driver\RetinaMode` = `"y"` (REG_SZ) plus `HKCU\Control Panel\Desktop\LogPixels` = dword 192; needs a `wineserver` restart | off | **[H]** [R11] |
| Key mapping | `Mac Driver\{Left,Right}CommandIsCtrl`, `{Left,Right}OptionIsAlt` = `"y"`/`"n"` (REG_SZ; a REG_DWORD 1 reads as **false**) | all `n` | **[H]** [R11] |
| Crash dialog | `HKCU\Software\Wine\WineDbg\ShowCrashDialog` = dword 0 (gaming and steam templates). When shown, its links point at the Mallow tracker (patch 0003) | on in "standard", off in the others | **[H]** [R28] |

**Shader caches.** "Clear shader cache" offers three locations:

- D3DMetal: `$(getconf DARWIN_USER_CACHE_DIR)/d3dm`, shared by all bottles **[M]** [R41].
- DXMT: `…/dxmt/`, shared **[M]** [R13].
- DXVK: `~/Library/Caches/Mallow/dxvk/<bottleID>`, per bottle.

---

## 5. Launch pipeline

### 5.1 Stages

```
LaunchRequest + LaunchContext  (bottle, effective runtime §3.11.7, backends, image index, live server, transient rules)
  │ 1 preconditions: Rosetta, runtime installed, bottle.state == ready
  │ 2 classify target (.exe/.msi/.bat/.cmd/.lnk/builtin) → Windows path via WinePathMapper
  │ 3 read PE header (exe, or the .lnk target) → ImageTraits
  │ 4 GraphicsPlanner.plan → map/registry/env/managed files; resolveImage for this target;
  │   imageMap mode: a transientRule when --backend is given or the image's rule resolves differently from auto
  │ 5 SettingsPlan.compute(applied, config, runtime, host, server) → blocking and pending restart reasons
  │ 6 preflight:
  │     no server:  updatePrefix  if PrefixUpdateCheck.needsUpdate (runtime changed or .update-timestamp stale)
  │                 applyPrefix   if registry digest, map digest, managed files or Windows version differ
  │     server up:  applyPrefix with hot parts only (Retina/DPI keep their applied values)
  │ 7 WineEnvironment.resolve(layers) → final env
  │ 8 LogSession.logURL; serverStart = (runtimeID, effective sync, now) when no server is running
  ▼
LaunchPlan  (pure value; golden-tested; `mallow run --dry-run` prints it)
  │ LaunchService.launch:
  │ a re-probe the lock; refuse if requiresWineserverRestart is non-empty and a server runs
  │   (UI: "Restart bottle?"; CLI: --restart)
  │ b run the preflight steps in order (updatePrefix waits for its wineboot to exit)
  │ c if no server runs: record plan.serverStart as applied.server
  │ d remember transientRule (it is already in the preflight's map); write the log header
  │ e PosixSpawner.spawn; post programStarted
  │ f waitpid thread; poll the lock ≤ 10 s to record the server pid; idle watcher;
  │   on exit: post programExited, remove transientRule, retry deferred managed-file removals when idle
  ▼
events: programStarted / programExited / bottleIdle / settingsPending
```

The `updatePrefix` step fixes a Draft 1 leak. A top-level `bin/wine` start whose prefix needs updating runs `wineboot` with the launch's environment. With a backend prepended, that copied the backend's DLLs into `system32` **[H]** (reviewed). So Mallow runs `wine wineboot -u` itself first, with `baseLayers(includeImageMap: false)` and no backend layer, and waits for it to exit before spawning the program. Patch 0001's private prepend list is the second line of defence (§3.11.4).

### 5.2 Environment construction

The environment is **never inherited** from the Mallow process. It is built from layers, and later layers win:

| # | Layer | Contents |
|---|---|---|
| 1 | `host` | `HOME` (real), `USER=<bottle.windows.userName>` (Wine names the profile folder after `$USER` **[H]** [R8]; a fixed name keeps prefixes portable), `TMPDIR` (inherited value), `PATH=<wineRoot>/bin:/usr/bin:/bin:/usr/sbin:/sbin`. `LANG` and `LC_ALL` = `program.locale ?? bottle.locale`, **only when one is set** |
| 2 | `runtime` | `manifest.environment` with placeholders expanded |
| 3 | `wine` | `WINEPREFIX=<bottle dir>`; `WINEDEBUG` from the preset; sync variables; `WINEDLLPATH_PREPEND_MAPFILE=<bottle>/.mallow/dllpath-map` (imageMap mode, except for `updatePrefix` and bottle creation); overrides `winemenubuilder.exe=` (disabled, so no host menus or file associations, as Heroic does **[H]** [R42]); `mscoree,mshtml=` only when the runtime has no bundled Mono/Gecko |
| 4 | `backend` | `GraphicsPlan.environment` (§4.5). Environment mode only: `T` overrides and `WINEDLLPATH_PREPEND` for this launch |
| 5 | `bottle` | `ROSETTA_ADVERTISE_AVX=1` (only when on), `MTL_HUD_ENABLED`, `bottle.environment`, `bottle.dllOverrides` (entries outside `T` in imageMap mode) |
| 6 | `recipe:<id>` | Environment declared by an installed recipe for this program |
| 7 | `program` | `ProgramConfig.environment`, `.dllOverrides` (entries outside `T` in imageMap mode), and per-program HUD/debug/backend-option variables |
| 8 | `cli` | `--env K=V` (validated) |

**Why no default locale.** Wine's `dlls/ntdll/unix/env.c` consults `setlocale(LC_ALL, "")` first. It uses `CFLocaleCopyCurrent` and `CFLocaleCopyPreferredLanguages` only when that gives no Windows locale **[H]** (reviewed) [R61]. Draft 1 forced `en_US.UTF-8` on every bottle, which made every user's bottle en-US with ANSI code page 1252. Non-Unicode Japanese, Chinese, Korean and Cyrillic programs showed garbled text. The app launched from Finder has no `LANG` at all, so leaving it unset gives the same Mac-derived result from the app and from the CLI.

**Validation (`WineEnvironment.resolve`):**

- Layers 5–8 may not set `protectedKeys` or any `DYLD_*` key.
- `WINEDLLOVERRIDES` is the rendered result of all layers' `DLLOverrideSet`s merged in order. In imageMap mode it must contain no `T` or `perImageOnly` member.
- `WINEDLLPATH_PREPEND` (environment mode only) is the `:`-joined concatenation of the layers' `dllPathPrepend` lists. Paths containing `:` are rejected.

**WINEDEBUG presets:**

| Preset | `WINEDEBUG` | stderr |
|---|---|---|
| off | `-all` | `/dev/null` (Wine skips all debug output when stderr is `/dev/null` **[H]** [R8-debug]) |
| normal | `fixme-all` | log file |
| crash | `+timestamp,+pid,+tid,+seh,+loaddll,err+all` | log file |
| custom | user string (UI warns that `+relay` produces huge logs) | log file |

**Golden example: `launch-exe-dxmt.json`.** An x86_64 game importing `d3d11.dll`, in a bottle with `auto` backend, msync and AVX off, whose prefix is already up to date and whose server is stopped. Placeholders are normalised by the test harness.

```json
{
  "launchID": "00000000-0000-0000-0000-000000000001",
  "bottleID": "$BOTTLE_ID",
  "targetKind": "exe",
  "graphicsMode": "imageMap",
  "backend": { "requested": "auto", "kind": "dxmt", "backendID": "dxmt-0.80", "mode": "builtinPrepend",
               "reasons": ["x86_64 PE imports d3d11.dll", "same as map rule \"*\" (dxmt-0.80); no transient rule needed"],
               "warnings": [] },
  "preflight": [],
  "spawn": {
    "executable": "$RUNTIME/bin/wine",
    "arguments": ["C:\\Games\\Foo\\Foo.exe", "-windowed"],
    "workingDirectory": "$BOTTLE/drive_c/Games/Foo",
    "environment": {
      "DXMT_LOG_PATH": "$LOGS/Bottles/games",
      "GST_PLUGIN_SCANNER_1_0": "$RUNTIME/libexec/gstreamer-1.0/gst-plugin-scanner",
      "GST_PLUGIN_SYSTEM_PATH_1_0": "$RUNTIME/lib/gstreamer-1.0",
      "GST_REGISTRY_1_0": "$CACHES/gstreamer/mallow-runtime-11.0-r1.bin",
      "HOME": "$HOME",
      "PATH": "$RUNTIME/bin:/usr/bin:/bin:/usr/sbin:/sbin",
      "TMPDIR": "$TMPDIR",
      "USER": "mallow",
      "WINEDEBUG": "fixme-all",
      "WINEDLLOVERRIDES": "winemenubuilder.exe=",
      "WINEDLLPATH_PREPEND_MAPFILE": "$BOTTLE/.mallow/dllpath-map",
      "WINEESYNC": "1",
      "WINEMSYNC": "1",
      "WINEPREFIX": "$BOTTLE"
    },
    "stdin": "null",
    "stdout": { "file": { "path": "$LOGS/Bottles/games/20261001-120000-foo.log", "append": true } },
    "stderr": "sameAsStdout",
    "detach": "processGroup"
  },
  "serverStart": { "runtimeID": "mallow-runtime-11.0-r1", "sync": "msync", "startedAt": "2026-10-01T12:00:00Z" },
  "logURL": "$LOGS/Bottles/games/20261001-120000-foo.log",
  "tracksProcessLifetime": true,
  "requiresWineserverRestart": [],
  "pendingUntilRestart": [],
  "warnings": []
}
```

The `dllpath-map` and registry that this bottle already has (from `graphics-plan` of the same fixture):

```
wine-dllpath-map 1
*	$BACKENDS/dxmt-0.80	-
```

```
[HKEY_CURRENT_USER\Software\Wine\DllOverrides]
"d3d10"="builtin"   "d3d10_1"="builtin"   "d3d10core"="builtin"   "d3d11"="builtin"   "d3d8"="builtin"
"d3d9"="builtin"    "dxgi"="builtin"      "winemetal"="builtin"   "d3d12"=""          "d3d12core"=""
```

(The registry excerpt is shown with several values per line for brevity. The real file has one value per line.)

### 5.3 argv by target type

`bin/wine` is x86_64-only, so exec'ing it from the arm64 app runs it under Rosetta automatically **[H]**. If Rosetta is missing, `posix_spawn` fails with `EBADARCH` (86), which maps to `.precondition(.rosettaMissing)`. Windows paths come from `WinePathMapper`: `C:` for paths inside `drive_c`, otherwise `Z:` (the `z:` link points at `/`).

| Target | argv after `<rt>/bin/wine` | cwd | Lifetime tracking |
|---|---|---|---|
| `.exe` | `<winpath> <args…>` | the exe's Unix directory (many games require it) | the spawned PID *is* the Windows process |
| `.msi` | `msiexec /i <winpath> <args…>` | the msi's directory | PID |
| `.bat` / `.cmd` | `cmd /c <winpath> <args…>` | its directory | PID |
| `.lnk`, target resolvable by `ShellLink` | treated as `.exe` using the lnk's target, arguments and working directory | the lnk's working directory, or the target's directory | PID |
| `.lnk`, advertised (Darwin ID) or unresolvable | `start /unix <unix-path-of-lnk>` | `drive_c` | **none**: `start` returns immediately; the wineserver idle watcher tracks it |
| builtin | `winecfg` / `regedit` / `taskmgr` / `explorer` / `control` / `uninstaller` / `notepad` | `drive_c` | PID |

`start` options, including `/unix` and `/wait`, are **[H]** [R24-start]. New WoW64 picks the right mode from the PE, so 32-bit programs launch the same way **[H]** [R7].

If `sandbox.hideHostRoot` removed `z:`, targets outside `drive_c` fail with `.precondition(.pathNotReachable)`. The UI then offers "Map this folder as a drive letter", which creates a new `dosdevices/<letter>:` symlink.

### 5.4 Spawning (`PosixSpawner`)

`posix_spawn` is used directly because Foundation `Process` cannot set a process group or a close-on-exec default:

| Setting | Purpose |
|---|---|
| `posix_spawn_file_actions_addchdir_np(cwd)` | Working directory (macOS 10.15+) |
| `addopen` `/dev/null` → fd 0 | stdin |
| `addopen(log, O_WRONLY \| O_CREAT \| O_APPEND, 0644)` → fd 1; `adddup2(1, 2)` | stdout and stderr to the log |
| `POSIX_SPAWN_CLOEXEC_DEFAULT` | Nothing of Mallow's (sockets, other files, lock fds) leaks into Wine |
| `POSIX_SPAWN_SETPGROUP` with pgid 0 | New process group. `.session` mode uses `POSIX_SPAWN_SETSID` for detached CLI launches **[M]** (V20) |
| `POSIX_SPAWN_SETSIGDEF` for all signals; `POSIX_SPAWN_SETSIGMASK` empty | Children do not inherit an ignored SIGPIPE or a blocked mask |
| `envp` = the plan's environment exactly; `argv[0]` = the executable path | Explicit, deterministic environment. A direct `posix_spawn` of an unprotected binary keeps any variables we pass; only SIP-protected interpreters strip `DYLD_*` **[H]** |

**Exit handling.** Each child gets one dedicated thread that blocks in `waitpid(pid, &status, 0)`, retrying on `EINTR`, and then resumes the waiting task with an `ExitStatus`. A kqueue or `DispatchSource` process-exit source that is registered after the child has already exited may never fire **[M]** (reviewed). That is why it is not used. The thread is cheap, because Mallow tracks tens of processes, not thousands.

**Event order.** `LaunchService` posts `programStarted` synchronously right after `spawn` returns, and only then starts the waitpid thread. `EventBus.post` is synchronous and ordered (§3.4.1), so `programExited` can never overtake `programStarted`, even for a program that exits at once.

**No pipes, ever**, for Wine processes. `wineserver` is started by the first client and inherits its file descriptors, so a pipe might never reach EOF **[L]**. Log files avoid the question entirely. Short helper commands capture to temp files (`runToCompletion`).

**Parent death does not kill children** **[H]** (tested). That is intended: games survive an app crash, and a restarted app re-discovers running bottles through the lock probe (§5.6).

### 5.5 Log capture

- **Path:** `~/Library/Logs/Mallow/Bottles/<slug>/<yyyyMMdd-HHmmss>-<program-slug>.log`.
- **Header**, written by Mallow before spawning; the child then appends:

```
# Mallow launch log
# mallow: 0.3.0 (git abc1234)
# time: 2026-10-01T12:00:00Z
# host: macOS 26.5, Apple M4, 16 GB, Rosetta installed
# bottle: Games (6F1C2B0E-…) runtime=mallow-runtime-11.0-r1 sync=msync
# backend: dxmt-0.80 (auto: x86_64 PE imports d3d11.dll)
# cwd: /Users/…/Bottles/games/drive_c/Games/Foo
# argv: /Users/…/Runtimes/mallow-runtime-11.0-r1/bin/wine 'C:\Games\Foo\Foo.exe' -windowed
# env: DXMT_LOG_PATH=…
# env: …                                   (sorted, one per line)
# ---- process output follows ----
```

- **Retention:** keep the newest `logRetentionPerBottle` files (default 30) per bottle. The size of a single log cannot be capped without a pipe, so the UI warns above 500 MB.
- **Backend logs:** DXMT and DXVK logs are pointed at the same directory. D3DMetal also logs to the unified log category `D3DMetal` **[H]** [R17]. `DiagnosticsBundle` includes `log show --predicate 'category == "D3DMetal"' --last 1h` output.
- **Early crash detection:** a non-zero exit within 10 s of launch triggers a "Program exited with code X — View log" banner. This replaces Wine's crash dialog when it is disabled.

### 5.6 Process lifecycle and `wineserver`

- **One `wineserver` per prefix.** It is started by the first client and persists for 3 s after the last client exits (default `-p` timeout) **[H]** [R9]. It flushes the registry every 30 s and when it exits **[H]** [R9].
- **The lock, precisely.** `wineserver` takes `F_SETLK` on `{F_WRLCK, SEEK_SET, start 0, len 1}` of `<serverBase>/server-<dev %llx>-<ino %llx>/lock` and exits with status 2 if it cannot. A client retries starting the server only 6 times, backing off 0.1, 0.4, 0.9, 1.6 and 2.5 s **[H]** (reviewed, wine-11.0 `server/request.c`, `dlls/ntdll/unix/server.c`) [R9].
- **Running check, done natively** (`WineserverController.serverPID`):
  1. `stat(prefix)` gives `st_dev` and `st_ino`.
  2. `open(lock, O_RDONLY)`, then `fcntl(F_GETLK, {F_WRLCK, SEEK_SET, 0, 1})`. `l_pid` is the holder.
  3. `close`.

  This mirrors `wineserver -w` and `-k` **[H]** [R9]. It needs no Rosetta process and works after the app restarts.
- **Mallow never takes this lock** (normative):
  - `fcntl` locks belong to the whole process. If the app or CLI held the lock, every later `wineserver` start in that bottle would fail after its retries.
  - `F_GETLK` never reports a lock the caller holds.
  - Closing *any* fd to the file drops the caller's locks.
  - A thread blocked in `F_SETLKW` cannot be cancelled cleanly, and it would grab the lock the instant the server exits.

  So there is no `F_SETLK`/`F_SETLKW` on the server lock anywhere in MallowKit.
- **Idle watcher.** After a spawn, `LaunchService` polls `serverPID` every 100 ms for up to 10 s until it reports a pid, and records it in `applied.server.pid`. It then runs `waitForIdle(prefix, pid)`, which polls `F_GETLK` every 500 ms on a cancellable `Task`. `bottleIdle` is posted only when no holder is reported **and** `kill(pid, 0)` fails with `ESRCH`. A server that has not yet taken its lock therefore never looks idle. On `bottleIdle`, `LaunchService` retries deferred managed-file removals and drops stale transient rules.
- **Consistency rule.** Every Wine invocation for a bottle (launch, `regedit`, `winecfg`, `wineboot`, winetricks, `wineserver`) is built from `WineEnvironment.baseLayers`, so `WINEMSYNC` always matches the running server. A mismatch produces "Server is running with WINEMSYNC but this process is not …" **[H]** [R31].
- **Server bookkeeping.** When the lock probe shows no server before a spawn, the spawn will start one. `LaunchService` then records `applied.server = {runtimeID, sync, startedAt}` before spawning, and the pid once it appears. If a server is running whose pid differs from `applied.server.pid`, it was started outside Mallow, and its sync mode is unknown.
- **Restart reasons** (`SettingsPlan.restartReasons`):

  | Reason | Blocks new launches while the server runs? |
  |---|---|
  | `syncChanged` (effective sync ≠ `applied.server.sync`) | yes |
  | `runtimeChanged` (effective runtime ≠ `applied.server.runtimeID`) | yes: a different `wineserver` build means a protocol mismatch |
  | `serverStartedOutsideMallow` | yes |
  | `retinaChanged`, `dpiChanged` | no: launches proceed with the old values; "Restart bottle to apply" is shown |

- **When edits apply** (`BottleSettingsApplier.edit`). With the server stopped, everything applies immediately. With it running, the hot parts apply immediately (§4.5), and the restart reasons are returned and posted as `settingsPending`. Nothing is ever silently dropped: pending reasons are derived from `applied` at any time, so they survive app restarts.
- **Stop sequence** (`WineserverController.stop`; a no-op when `isRunning` is false, so it never starts a server):
  1. `wine wineboot --end-session --shutdown`. Windows receive the end-session messages, so apps can save **[H]** [R24].
  2. `waitUntilStopped(grace)`, default 10 s.
  3. If the server is still running: `wine wineboot --end-session --force --kill --shutdown` **[H]** [R24].
  4. If the server is still running: `wineserver -k`. That sends SIGINT; the server kills all processes, flushes the registry and exits within 2 s. It escalates to SIGKILL after about 10.5 s **[H]** [R9][R10].
- **Force stop** is step 4 alone.
- **Registry safety:** `-k` still flushes the registry (SIGINT path). SIGKILL does not.

### 5.7 Applying settings (`LaunchService.applyPrefix`)

- **Planning is pure.** `SettingsPlan.compute` (Wine layer) covers the non-graphics part: Mac Driver keys, `LogPixels`, `WineDbg`, AppDefaults from recipes, `winecfg /v` when the Windows version changed (it writes the whole set of version keys **[H]** [R25]), and sandbox filesystem changes. `GraphicsPlanner.plan` (Graphics layer) covers the graphics part (§4.5). `BottleSettingsApplier.plan` and `LaunchPlanner` both combine them into one `PrefixApplyPlan`. Neither depends on a layer to its right.
- **Everything Wine opens is staged inside the prefix.** Draft 1 wrote the `.reg` file to `.mallow/tmp/` and ran installers from `~/Library/Caches`, both reached through `Z:`. With `sandbox.hideHostRoot` (and in the companion security model), `z:` does not exist, so `regedit /S` and every recipe `run` step would fail. Now every file a Wine process must open goes into `PrefixStaging.makeArea` → `drive_c/windows/temp/mallow/<uuid>/`, which is reachable as `C:\windows\temp\mallow\<uuid>\` in every configuration. The area is deleted after the operation, including on failure. `PrefixStaging.sweep` removes areas more than a day old that a crash left behind.
- **`applyPrefix` does the following**, in order:
  1. Make a staging area.
  2. If `registry.digest != applied.prefix.registryDigest`: write `apply.reg` (UTF-16LE with BOM) into the area, then `runHelper(wine regedit /S C:\windows\temp\mallow\<uuid>\apply.reg)`.
  3. Run the commands (for example `winecfg /v win10`).
  4. Apply the filesystem changes.
  5. If the map's digest differs, write `.mallow/dllpath-map` atomically.
  6. Reconcile managed files (removals deferred while the server runs).
  7. Remove the staging area.
  8. If the helpers above started the server (it was not running before), `waitUntilStopped(timeout: 15 s)`. The server exits by itself about 3 s after the last client, which flushes the registry. This avoids killing it.
  9. Write `applied.prefix = plan.resulting` (and `managedFiles`) under the bottle lock.
- **Never** edit `system.reg`/`user.reg` directly **[H]** [R9].
- `BottleSettingsApplierTests` and `RecipeRunnerTests` include a case with `dosdevices/z:` removed. `fake-wine`'s `regedit` fails on a `Z:` path whose drive link is missing, so a staging regression cannot pass.

### 5.8 Creating a bottle (`BottleCreator.create`)

1. Check preconditions: Rosetta, runtime installed, at least 500 MB free.
2. `reserveDirectory`, then write `bottle.json` with `state: "creating"`. The template sets the defaults.
3. **v0.4 fast path:** if `PrefixTemplateCache` has `(runtimeID, windowsVersion)`, APFS-clone it (`copyfile` with `COPYFILE_CLONE`), rename the profile if `userName` differs, and skip to step 6.
4. Run `wine wineboot --init` through `LaunchService.runHelper`, with `baseLayers(includeImageMap: false)` (overrides include `winemenubuilder.exe=`). **Do not set `WINEARCH`.** New WoW64 is the default for this runtime **[H]** [R7].
5. `waitUntilStopped(timeout: 120 s)`. `wineboot` can return before the `.reg` files are written, so we must wait for the server **[H]** [R24-wt].
6. `LaunchService.applyPrefix(plan)` with the plan from `BottleSettingsApplier.plan(…, server: nil)`. This writes `applied.prefix`.
7. If `sandbox.linkHomeFolders == false`, replace the `drive_c/users/<user>/{Documents,Downloads,Music,Pictures,Videos}` symlinks with real folders **[H]** [R8-shell].
8. Set `state: "ready"`. Store the template in the cache on the first successful creation per key.

**Golden test.** `create-bottle-commands.json` records the ordered sequence of `(executable, arguments, selected env keys)` from `RecordingSpawner`. `BottleCreatorIntegrationTests` owns it, not the launch goldens.

---

## 6. Steam installer flow and known workarounds

### 6.1 One-click flow (`mallow install steam`, or the "Install Steam" button)

1. **Preflight** (the recipe's `requires`):
   - Rosetta is installed.
   - The runtime has `msync` and `dllPathMap`. Standard Wine has neither, so the recipe is shown as unavailable there, with the reason.
   - The DXMT backend is installed. If it is missing, the recipe plan installs it from the signed catalog as its first step, and says so in the terms sheet.
   - At least 2 GB of free disk. The Steam client grows to about 1 GB after its first self-update **[L]** (V22).
   - The user accepts the terms (Steam Subscriber Agreement link and the download host `cdn.akamai.steamstatic.com`). `--yes` accepts in the CLI.
2. **Bottle.** Create one named "Steam" from the `steam` template, unless `--bottle` names an existing one. The template sets:

   | Setting | Value | Reason |
   |---|---|---|
   | Windows version | `win10` | |
   | sync | `msync` | |
   | Retina | **off** | CEF menus draw blank or at 2× with RetinaMode **[M]** [R11-retina] |
   | backend (`*` rule) | **`dxmt`**, explicit | Games Steam starts without a more specific rule get DXMT. `auto` is not used here, because Steam itself has no D3D imports **[H]** (reviewed) |
   | `hideD3D12` | **`false`** | Hiding D3D12 for every Steam-started game would break D3D12-only games (§13, F2) |
   | `imageOverrides` | every `SteamLibrary.clientImages` entry → `wined3d` | Steam's own processes get Wine's own DLLs and never load libd3dshared (§6.2) |
   | `autoImageRules` | `true` | Each installed game gets its own rule from its PE imports (§4.5) |
   | Crash dialog | off | |
   | locale | unset | §5.2 |

3. **Download** `SteamSetup.exe` from `https://cdn.akamai.steamstatic.com/client/installer/SteamSetup.exe` into `Caches/Downloads`. There is no pinned sha256, because Valve updates the file. Instead we check: HTTPS, a final URL (after redirects) on that exact host, size between 1 and 20 MB, and a file that starts with an `MZ`/`PE` header. Authenticode verification is not done (§9).
4. **Pre-install settings.**
   - Disable the `gameoverlayrenderer` and `gameoverlayrenderer64` DLL overrides. This comes from winetricks' `load_steam` (Wine bug 22053). Whether it is still needed with a 64-bit client is **[M]** [R28] (V15). They are outside `T`, so they stay in `WINEDLLOVERRIDES`.
   - `ShowCrashDialog=0`.
5. **Run.** The installer is staged into `drive_c/windows/temp/mallow/<uuid>/` and run as `wine C:\windows\temp\mallow\<uuid>\SteamSetup.exe /S`, with `wait` and a 15-minute timeout. Then `waitForWineserver`, then the staging area is deleted.
6. **Check** that `drive_c/Program Files (x86)/Steam/steam.exe` or `drive_c/Program Files/Steam/steam.exe` exists. Which path the 64-bit installer uses is **[L]** (V13), so both are accepted.
7. **Register the program**, pinned. Draft 1 added `LC_ALL=en_US.UTF-8` here. That fix was anecdotal **[L]** [R19-steam], and it is dropped unless V14 shows it helps.
8. **`refreshImages`.** Index the Steam libraries (none yet) and write the map. The index is refreshed again:
   - whenever the bottle is opened,
   - before every launch of `steam.exe`,
   - on `bottleIdle` after Steam exits,
   - from v0.6, on FSEvents in each library's `steamapps/common` while Steam runs. The map update is hot, so a newly installed game gets its rule on its first start.
9. **First launch** (optional, on by default in the UI). The client's bootstrapper downloads its update. The UI tails the log and shows "Steam is updating…".

**How games get their backend.** A game that Steam starts is matched in the map by its full path:

- the auto rule from its imports, for example a D3D12 game → D3DMetal when imported;
- or the user's per-program choice;
- or the `*` rule (DXMT).

This includes a directly launched game that `SteamAPI_RestartAppIfNecessary` relaunches through Steam. Steam's own rule never leaks into it, because the choice is made per image inside Wine (§4.5). `LaunchServiceIntegrationTests` checks the environment half of this with fake-wine (`FAKE_WINE_SPAWN_CHILD`). `GraphicsPlannerTests` checks the map and registry half (`graphics-plan-steam.json`), and smoke test (i) checks the patch itself.

### 6.2 Known issues and workarounds

| Symptom | Cause (as reported) | Mallow handling | Confidence |
|---|---|---|---|
| Black or blank Steam window, "steamwebhelper is not responding" | CEF GPU process draws across processes. Upstream winemac gained `CALayerHost` cross-process swapchains in 2026-06, but reports say more hosting fixes are needed. Upstream 11.17 builds show black Steam windows. | Our runtime is CX-source based (CrossOver 26.3 ships working Steam). Program menu action **"Restart Steam web helper"** kills only `steamwebhelper.exe` processes whose command line contains `--type=gpu-process`, falling back to `taskkill /IM steamwebhelper.exe /F`. **Test Steam on every runtime bump.** | [M] [R30][R6] |
| Steam UI breaks after enabling DXMT or D3DMetal for the bottle | Webhelper cross-process swapchains are refused by DXMT; a visible nvapi64 makes Chromium load D3DMetal | Steam's own images have `wined3d` rules (no prepend, no libd3dshared); nvapi64 is never in a default view, never in `system32`, and never set bottle-wide | [M] [R6] |
| Steam-started games all get Steam's backend, or D3D12 games fail under a bottle-wide DXMT preset | Draft 1 chose the backend from Steam's environment | Per-image map + registry load orders (§4.5); the steam template's `*` rule does not hide D3D12 | [H] (reviewed) |
| Login loop | Reported with an llvm-mingw-built `kernelbase.dll` | Runtime built with mingw-w64 GCC | [L] [R6] |
| Downloads stall with msync | Fixed in CrossOver 25.1 per its changelog | CX-source runtime; if seen, set sync to `none` for the Steam bottle | [M] |
| `-cef-force-32bit`, `-allosarches`, `-noreactlogin`, `-no-browser` | Obsolete: the client is 64-bit and 32-bit updates ended on 2026-01-01 | Never added | [M] [R29] |
| `-cef-disable-gpu` / `-cef-disable-gpu-compositing` | Reported to make the whole client black | Never added by default | [L] |
| Steam keeps running after the user quits | Tray background process | Stop action runs `steam.exe -shutdown`, waits 15 s, then the normal §5.6 stop | [M] (Whisky #680) |
| `WINE_FORCE_HTTP11`, `WINHTTP_CONNECT_TIMEOUT` and similar "fixes" from some guides | Do not exist in Wine (0 code-search hits) | Never added | [M] [R19-steam] |
| Anti-cheat games in the Steam library | Kernel anti-cheat is unsupported | Badge from recipe or game metadata only | [M] [R39] |

---

## 7. Testing strategy and CI

### 7.1 Principles

1. **Everything interesting is a pure function of injected inputs.** `LaunchPlanner` takes `HostInfo`, a `now` clock, `makeID` and `inspectImage`. `BottleSettingsApplier.plan`, `BackendResolver` and `BackendConfigurator` are pure. UUIDs are injected.
2. **Effects sit behind protocols:** `ProcessSpawner`, `HTTPClient`, `CodeSignatureChecker`. `WineserverController(serverBase:)` takes the lock-directory base as a parameter.
3. **No real Wine in unit tests.** Integration tests use **`fake-wine`**, a real Mach-O built from `Sources/FakeWine`.
   - A shell-script fake would not work. `#!/bin/sh` scripts run through a SIP-protected interpreter that strips `DYLD_*` **[H]**, so env-propagation tests would lie.
4. **Swift Testing only.** `import Testing`, `@Test`, `#expect`. XCTest is unavailable under Command Line Tools **[H]**.

### 7.2 `fake-wine` behaviour

`fake-wine` is a Swift executable. Swift on Darwin marks `fork()` unavailable ("Please use threads or posix_spawn*()") **[H]** (reviewed). So wherever a real wineserver would linger, `fake-wine` `posix_spawn`s **itself** in a hidden mode. It behaves according to `basename(argv[0])` and its arguments:

| Invocation | Behaviour |
|---|---|
| any | Appends `{"argv":…, "env":…, "cwd":…, "t":…}` as one JSON line to `$FAKE_WINE_LOG`. Honours `FAKE_WINE_EXIT_CODE`, `FAKE_WINE_STDERR`, `FAKE_WINE_SLEEP_MS`. Exits 130 on SIGINT. With `FAKE_WINE_SPAWN_CHILD=<winpath>`, it `posix_spawn`s `wine <winpath>` with **its own environment unchanged**, as Steam does for games. |
| `fake-wine --hold-lock <lockpath> <ms> [--pidfile <p>]` (hidden) | Creates the directory, opens the lock `O_RDWR\|O_CREAT`, and takes `F_SETLK {F_WRLCK, SEEK_SET, 0, 1}` (exits 2 if it cannot, like wineserver). Writes its pid to `<p>`, holds the lock for `<ms>` or until SIGINT (then exits 0, "flushed"), and exits. This is the stand-in wineserver. |
| `fake-wine --flock <path> <ms>` (hidden) | Holds a BSD `flock(LOCK_EX)` on `<path>` for `<ms>`. Used to prove that `BottleStore` waits for another process's lock. |
| `wine wineboot --init` / `-u` | Creates `drive_c/windows/{system32,syswow64,temp}`, `drive_c/users/$USER/{Desktop,Documents,…}` (Documents etc. as symlinks to `$HOME/…` stand-ins), `dosdevices/c:` → `../drive_c`, `z:` → `/`, `system.reg`/`user.reg`/`userdef.reg` with a `WINE REGISTRY Version 2` header, and `.update-timestamp`. Unless `FAKE_WINE_NO_SERVER=1`, it spawns `fake-wine --hold-lock $FAKE_WINE_SERVER_BASE/server-<dev>-<ino>/lock $FAKE_WINE_SERVER_LINGER_MS` (default 200 ms) and returns at once. |
| `wine regedit /S <X:\…>` | Maps the path through `dosdevices`. **Fails with exit 1 if the drive link is missing**, so a file staged outside the prefix fails as it would under real Wine. Decodes UTF-16LE and appends the parsed keys to `user.reg`/`system.reg` in a simple form that tests can assert on. |
| `wine winecfg /v <ver>` | Records `[Software\\Microsoft\\Windows NT\\CurrentVersion]` with a `CurrentBuild` marker. |
| `wineserver -k` | `F_GETLK` on the lock; sends SIGINT to the holder's pid. |
| `wineserver -w` | Polls `F_GETLK` every 50 ms until no holder remains, then exits. |
| `wine <anything else>` | Records the call and sleeps or exits as configured. |

`TestSupport/FakeRuntime.swift` builds a temporary runtime tree:

- `bin/wine` and `bin/wineserver` are hard links to `fake-wine`.
- `lib/wine/x86_64-unix/ntdll.so` is a file containing the **NUL-terminated** marker strings for the requested features, plus decoy strings (for example `WINEDLLPATH_PREPEND_MAPFILE` alone, to prove that 0001 is not inferred from it).
- `lib/wine/x86_64-unix/winemac.so` is a `SyntheticMachO` whose export trie contains `_macdrv_functions` when requested, or merely contains the string when testing that a string alone is not enough.
- `lib/wine/i386-windows/` holds 501 empty files, to satisfy the probe.
- `manifest.json` is included.

**Lock tests** never take a lock inside the test process. `F_GETLK` would not report it, and closing a descriptor would drop it. They use `FakeWineServer` (TestSupport), which spawns `fake-wine --hold-lock`, reads the pid file, and checks `serverPID == thatPid`.

The helpers find the binaries through `MALLOW_FAKE_WINE` and `MALLOW_CLI`, which `scripts/test.sh` sets. Otherwise they look next to the test bundle.

### 7.3 Test inventory (Tests/MallowKitTests)

| File | What it proves |
|---|---|
| `WireFormatTests` | WF0: every type in §3.7.0 encodes to its checked-in fixture; `{}` decodes to defaults for every persisted struct; `nil` is never written; paths are strings |
| `DLLOverridesTests` | parse/render round-trip; deterministic ordering; `=d` and empty both mean disabled; `*name` preserved; precedence of `merging`; `registryValues` long forms |
| `WineEnvironmentTests` | layer precedence; protected keys (incl. `LANG`/`LC_ALL`) rejected in user layers; `DYLD_*` rejected; no `LANG`/`LC_ALL` when locale is unset; imageMap mode: `T` members never reach `WINEDLLOVERRIDES`; prepend join and `:` rejection (environment mode) |
| `BackendResolverTests` | table-driven matrix: 5 kinds × feature sets × host macOS (14/15/26) × image (nil/i386/amd64, imports) → kind, mode, reasons; explicit choice never falls back |
| `BackendConfiguratorTests` | exact env, overrides, prepend, libd3dshared and managed files per backend; MetalFX gated on macOS 26; nvapi64/nvngx never in `managedFiles` |
| `ImageBackendMapTests` | rendering (header, ordering, tabs, `-`), digest stability, validation (one `*`, absolute paths, no `:`/TAB/LF), transient add/remove |
| `GraphicsPlannerTests` | rule precedence (transient > program > override > auto > `*`); auto rules only where they differ; no full-path rule shadows a higher basename rule; registry (global `T`, AppDefaults deltas, deletion of stale owned values); basename-collision warning; managed files = union over referenced backends; golden `graphics-plan-steam.json` |
| `SettingsPlanTests` | restart reasons (blocking vs non-blocking); Retina/DPI kept while a server runs; `winecfg /v` only on change; Mac Driver booleans as REG_SZ |
| `LaunchPlannerGoldenTests` | the **11** `Golden/launch-*.json` files. Run with `MALLOW_UPDATE_GOLDENS=1 scripts/test.sh` to regenerate them. Paths are normalised to `$RUNTIME`, `$BOTTLE`, `$BOTTLE_ID`, `$BACKENDS`, `$USER_SUPPLIED`, `$LOGS`, `$CACHES`, `$HOME`, `$TMPDIR`. Also: `updatePrefix` preflight when `.update-timestamp` is stale or the runtime changed; a transient rule for `--backend` |
| `WinePathMapperTests` | `C:`, `Z:`, `/tmp` → `/private/tmp` realpath, missing `z:`, case, spaces |
| `PrefixStagingTests` | area under `drive_c/windows/temp/mallow/<uuid>`, `C:` path, clone fallback on non-APFS, removal, `sweep` |
| `RegistryFileTests` | UTF-16LE BOM, CRLF, escaping of `\` and `"`, `dword:%08x`, delete markers, `parse(text)` round-trip, `merge` precedence |
| `BottleConfigTests` | defaults; `{}` and minimal files decode; unknown fields ignored; refusal of a newer schema; locale absent by default |
| `BottleMigrationTests` | fixture v0 → v1; `.bak` written; no value reset |
| `BottleStoreTests` | `save` detects stale revision; `update` waits while `fake-wine --flock` holds the lock, then applies; `lockTimeout`; slug uniqueness; trash; FileWatcher posts `bottleUpdated` for an atomic rename of `Bottles/<slug>/bottle.json` |
| `BottleSettingsApplierTests` | `edit` applies everything with no server; with a server (`FakeWineServer`) applies hot parts and returns Retina as pending; **works with `dosdevices/z:` removed** |
| `MallowPathsTests` | marker written for a new or empty root; refusal of a non-empty root without a marker or with an unknown schema; `MALLOW_HOME` |
| `ProvenanceGuardTests` | synthetic trees: `com.codeweavers.*` enclosing bundle; `bin/cxbottle`; `lib64/apple_gptk`; `D3DMetal.framework`; `libd3dshared.dylib`; a Mach-O the fake checker reports as `anchor apple`; a clean tree passes |
| `PrefixAuditTests` | native vs builtin-marked translation DLLs; Apple CompanyName → `appleTranslationDLL`; `nvngx-on-metalfx.dll`; reversible quarantine |
| `RuntimeManifestTests`, `SchemaConformanceTests` | every example in this doc, every fixture, `recipes/` and `catalog/` **decode** and round-trip (schema validation itself is the Python CI job) |
| `SignatureVerifierTests` | keypair generated at test time with `Curve25519.Signing.PrivateKey()`; valid, tampered, unknown key id, bad format |
| `CatalogClientTests` | signature required; anti-rollback (sequence < last → refused, and `lastCatalogSequence` not lowered); `latest` by `family` + `versionKey` + channel order + `minMacOS`/`minAppVersion` |
| `ComponentInstallerTests` | a `.tar.xz` built at test time with `/usr/bin/tar -cJf`; sha mismatch → no activation; escaping symlink rejected; quarantine xattr set by the test and removed; `format: file` placement with `+x`; same-ID repair via `RENAME_SWAP` and `.previous` |
| `RuntimeManagerTests` | side-by-side install; repair/rollback/remove refused while `RuntimeUsage` reports a live server; `effectiveRuntime` for pinned/unpinned/server-running; `importDirectory` rejected by `ProvenanceGuard` |
| `RuntimeCapabilityProbeTests` | NUL-terminated markers (a `…_MAPFILE` string alone does not imply `dllPathPrepend`); export-trie check vs string-only decoy; Vulkan provider detection |
| `MachOExportsTests` | `SyntheticMachO` with `LC_DYLD_EXPORTS_TRIE` and with `LC_DYLD_INFO_ONLY`; fat binary slice selection; truncated input never crashes |
| `StandardWineImporterTests` | a synthetic `Wine Stable.app/Contents/Resources/wine` tarball: tree kept intact; entryPoints into the `.app`; `VK_DRIVER_FILES`/`VK_ICD_FILENAMES` for loader + json; generated ICD json for loader + dylib; `vulkan: none` otherwise; provenance rejection |
| `GPTKImporterTests` | a synthetic payload tree with relative symlinks; fake `CodeSignatureChecker`; signature policy for both files (anchor apple; generic + trusted team; rejected otherwise); refuses CodeWeavers bundle paths; view symlink chains resolve; names enumerated from the payload; `import.json` contents |
| `ManagedFilesTests` | backup once, restore on switch, ownership isolation; **two programs with different backends running at once**: removals deferred while the server runs, applied after idle |
| `ShellLinkTests`, `PEFileTests` | synthetic `.lnk` and PE built from the specs by `SyntheticShellLink` and `SyntheticPE` (no binary fixtures, so no provenance questions); version strings; truncated and garbage inputs never crash |
| `SteamLibraryTests` | text-VDF parsing (quotes, escapes, nesting); `libraryfolders.vdf` → library paths through `WinePathMapper`; appmanifest parsing; skipped redist folders |
| `WineserverControllerTests` | `serverPID` returns the `FakeWineServer` pid; `waitUntilStopped` success and timeout; `waitForIdle` does not fire before the server takes its lock, and fires after it exits; cancellation |
| `ConcurrencyIsolationTests` | every API in the §3.5 table, called from `@MainActor`, records `ThreadProbe` marks with `pthread_main_np() == 0` |
| `BottleCreatorIntegrationTests` | fake-wine end to end: skeleton created, `.reg` applied from a staging area, `bottle.json` state `ready`, `applied.prefix` written, command sequence equals `Golden/create-bottle-commands.json` |
| `LaunchServiceIntegrationTests` | real `PosixSpawner` + fake-wine: header then child output in the log; env reaches the child exactly, **including a `DYLD_TEST` canary** set only by the test spawner; new process group; `programStarted` always before `programExited` for an immediately exiting child; `applied.server` recorded when no server ran; blocking restart refused; stop sequence escalation with `FAKE_WINE_SLEEP_MS`; `FAKE_WINE_SPAWN_CHILD` child sees `WINEDLLPATH_PREPEND_MAPFILE` and no `T` member in `WINEDLLOVERRIDES` |
| `RecipeRunnerTests` | Steam recipe against `StubHTTPClient` (a fake `SteamSetup.exe` with `MZ` header) + fake-wine; terms consent required; redirect to a non-listed host rejected; installer staged inside the prefix and removed; `z:` removed still works; idempotency |
| `RecipeValidatorTests` | missing `license`; host not in `sourceHosts`; `sourceHosts` not on the allowlist; non-https URL |
| `WinetricksRunnerTests` | argv and environment (base layers + `WINE`, `WINESERVER`, `W_CACHE`, `WINETRICKS_LATEST_VERSION_CHECK`, `PATH`); consent required; `dxvk*` verbs blocked; `dotnet*` notice; missing tool → `runtimeMissing` |
| `DiagnosticsBundleTests` | the zip never contains `UserSupplied/` or `drive_c/` content; `$HOME` redacted to `~` in every text file; `dllpath-map` included |
| `Tests/MallowCLITests/CLIEndToEndTests` | runs `$MALLOW_CLI` with `--home <tmp>`: `runtime import <fake>`, `bottle create`, `run --dry-run --json` equals the planner golden, `run --wait` exit code passthrough, exit codes 66/69/73/75/77, `winetricks` without `--yes` → 69, `rosetta install` without the flag prints the interactive command |
| `Tests/MallowCLITests/ConcurrentEditTests` | 8 concurrent `mallow bottle set` processes → no lost update (§3.5) |

**Opt-in real-runtime suite.** Tests tagged `.realRuntime` run only when `MALLOW_REAL_RUNTIME=/path/to/runtime` is set:

- `wineboot --init`, `cmd /c echo`, stop/kill, the lock probe against a real `wineserver`, the prepend patch, and the map patch.

They run on CI arm64 runners, against both our runtime and the pinned Standard Wine. They are not run on the design host, because of its disk space.

### 7.4 `scripts/test.sh` (works with Command Line Tools only)

```bash
#!/bin/bash
# SPDX-License-Identifier: 0BSD
set -euo pipefail
swift build --product fake-wine
swift build --product mallow
BIN="$(swift build --show-bin-path)"
export MALLOW_FAKE_WINE="$BIN/fake-wine"
export MALLOW_CLI="$BIN/mallow"
EXTRA=()
if [ "$(xcode-select -p)" = "/Library/Developer/CommandLineTools" ]; then
  F=/Library/Developer/CommandLineTools/Library/Developer/Frameworks
  EXTRA=(-Xswiftc -F -Xswiftc "$F" -Xlinker -F -Xlinker "$F"
         -Xlinker -rpath -Xlinker "$F"
         -Xlinker -rpath -Xlinker /Library/Developer/CommandLineTools/Library/Developer/usr/lib)
fi
swift test ${EXTRA[@]+"${EXTRA[@]}"} "$@"     # bash 3.2 + set -u: empty arrays need this form [H]
```

These flags are verified on CLT 26.5 / Swift 6.3.2 **[H]**. CLT 27 / Swift 6.4 reportedly needs `-plugin-path` instead **[L]** [R43], so the script will grow a version switch. The flags stay out of `Package.swift`, which keeps Xcode builds unaffected. `--build-system swiftbuild` is avoided because it passes a non-existent framework path **[H]** [R43].

### 7.5 CI (`.github/workflows/`)

| Workflow | Trigger | Runner | Jobs |
|---|---|---|---|
| `ci.yml` | push, PR | `macos-26` (arm64, Xcode 26.6) **[H]** [R36] | `lint` (`scripts/lint.sh`: swift-format, shellcheck, layering, SE-0461 guard); `test-xcode` (`scripts/test.sh` with Xcode selected); `test-clt` (`sudo xcode-select -s /Library/Developer/CommandLineTools && scripts/test.sh`; whether CLT is installed on the image is **[L]** (V12), and the job installs it if missing); `schemas` (Python `jsonschema` over `schemas/`, fixtures, `recipes/`, `catalog/`); `recipes` (`check-recipes.py`); `generated` (`gen-builtin-recipes.sh` and `gen-third-party-licenses.sh`, then `git diff --exit-code`); `dco` (sign-off check); `bundle` (`build-app.sh` ad-hoc → `verify-app-bundle.sh` → artifact); `.build` cached on `Package.resolved` + Swift version |
| `deps.yml` | change under `runtime/deps/**`, manual | `macos-15-intel` | §3.11.2 A; publishes release `deps-<depsHash>` |
| `runtime.yml` | tag `runtime-*`, manual | `macos-15-intel` (build), `macos-26` (package, smoke) | §3.11.2 B; then `real-runtime-tests` running the `.realRuntime` suite against the artifact and against the pinned Standard Wine |
| `backends.yml` | tag `backends-*`, manual | `macos-26` | §3.12; checks the pinned upstream sha256 values, `staticComponents` and licence files; signs |
| `catalog.yml` | push to `catalog/**` | `ubuntu-latest` | validate (every `sourceURL` resolves; every binary release also carries its source assets, per the §2.3 hard rule), sign with `RELEASE_SIGNING_KEY` (openssl@3), publish to GitHub Pages `catalog/v1/` |
| `release-app.yml` | tag `v*` | `macos-26` | `build-app.sh` (+ `verify-app-bundle.sh`). With Developer ID secrets: temporary keychain import (GitHub's documented recipe), `--timestamp`, `xcrun notarytool submit --wait`, `xcrun stapler staple` (all in CLT **[H]**). Otherwise ad-hoc. Uploads the zip; appcast from v0.8 |
| `upstream-watch.yml` | weekly cron | `ubuntu-latest` | Compare pins with the latest releases of Gcenx/macOS_Wine_builds, 3Shain/dxmt, Gcenx/DXVK-macOS, KhronosGroup/MoltenVK, Winetricks and every `runtime/deps` input, plus a HEAD check for new `crossover-sources-*.tar.gz`; open an issue for each drift |

---

## 8. Roadmap

This assumes 2–3 part-time contributors. Durations are rough estimates.

### Gate G0 "Before any code" (about 1 week; blocks v0.1)

- **Name.** Complete the clearance: formal USPTO and EUIPO searches in classes 9 and 42 for "Mallow", and a lawyer's opinion. If they fail, switch to "Mullion" and re-run the checks (§2.6) (Q2, V31).
- **Identity.** Register the GitHub org `mallow-project` and the repo, and reserve the Homebrew tap name (Q4). `ProductIdentity.swift` values are then final.
- **Licence.** `LICENSE` stays 0BSD (committed). Add `NOTICE`, `recipes/LICENSE` and `schemas/LICENSE` (CC0), and adopt the DCO (§2.1, Q1). This document is committed only in or after that commit.
- **Governance.** `GOVERNANCE.md` (≥ 2 maintainers, key custody) and `SECURITY.md` (security and abuse contact).
- **Exit criteria:** all of the above merged. `SECURITY_MODEL.md` needs no rename, because it already says "Mallow".

### v0.1 "Foundations" (about 4 weeks)

- **Week 1: WF0.** `Support/WireCoding.swift`, all §3.4 model types, `WireFormatTests` and fixtures (§3.7.0). Only then are modules split among engineers.
- **Scope:**
  - Package skeleton, `Support` (including `MallowPaths` marker, `FileLock`, `FileWatcher`, `ProvenanceGuard`, `CodeSignatureChecker`), `Bottles`, the `Runtime` import path.
  - `BuiltinComponents` with the pinned Standard Wine, installable in-app and through `mallow runtime install`.
  - `RuntimeCapabilityProbe` with `MachOExports`, `Wine` (including `SettingsPlan`, `PrefixStaging`), `Launch` in environment mode, and `BottleCreator`/`Applier` (Windows version, Retina, key mapping).
  - Backends: wined3d, and DXVK native mode if V27 passes.
  - CLI: `rosetta`, `runtime import|install|list|probe|set-default`, `bottle create|list|show|set|apply|restart|stop|kill|trash|path`, `run` (all flags), `wine`, `logs`, `doctor`.
  - `fake-wine` (with `--hold-lock`), the goldens, `test.sh`, `ci.yml`.
- **Exit criteria:**
  - `mallow runtime install standard-wine-stable-11.0_1 && mallow bottle create Test && mallow run --bottle Test --wait notepad` works on an Apple Silicon Mac.
  - All tests are green under both CLT and Xcode.
  - The clean-room rules and the DCO are in `CONTRIBUTING.md`.

### v0.2 "Own runtime" (weeks 3–12, in parallel)

- **Scope:**
  - `deps.yml` and `runtime/deps/` (the from-source dependency build, moved here from Draft 1's post-1.0 plan).
  - The `runtime/` pipeline; patches 0001 (private prepend list), 0002 (per-image map) and 0003 (winedbg); relocation.
  - The licence and vendor-string audits; verify and smoke tests (a)–(k); the LGPL source assets.
  - Signing, the catalog, and `ComponentInstaller` with signature checks and repair.
  - imageMap mode in `GraphicsPlanner`/`LaunchService`, MSync, DXMT, DXVK builtin mode, and the backend packaging with `staticComponents`.
- **Exit criteria:**
  - `mallow-runtime-11.0-r1` is released with both source assets beside it.
  - The smoke suite passes with no `DYLD_*` set.
  - `avcodec_license()` reports LGPL, and the vendor-string scan is clean.
  - A DX11 title renders through DXMT with MSync on.

### v0.3 "Mac app" (about 4 weeks)

- **Scope:**
  - The SwiftUI app with the §3.9 screens (except GPTK), including `RosettaConsentSheet`, `AcknowledgementsView`, `TermsSheet` and the pending-restart banner.
  - Program discovery (`.lnk` and PE icons), pinned programs, the log viewer, onboarding (Rosetta, runtime).
  - `build-app.sh` + `verify-app-bundle.sh`, an ad-hoc zip on GitHub Releases, and a Homebrew **tap** (not homebrew-cask) **[H]** [R37].
- **Exit criteria:** a non-developer can install the app, create a bottle, and run an installer and a game without using the terminal. The release zip passes `verify-app-bundle.sh`.

### v0.4 "Steam and dependencies" (about 3 weeks)

- **Scope:**
  - The recipe engine with `license`/`sourceHosts`/`sourceKind`, `RecipeValidator` and `TermsCatalog`.
  - The Steam recipe (§6), `SteamLibrary` and `ImageIndexer`, and auto image rules.
  - `WinetricksRunner` through the catalog tool entry, and the native `vcrun2022` verb.
  - `PrefixTemplateCache` (APFS clones), and the "Restart Steam web helper" action.
- **Exit criteria:**
  - On a clean Mac, one click produces a Steam client that can log in and download a game. This is tested on each runtime release.
  - A D3D11 game started by Steam uses DXMT, and Steam's own processes use Wine's DLLs (checked in the logs with `+loaddll`).

### v0.5 "D3DMetal and upscalers" (about 3 weeks)

- **Scope:** `GPTKImporter` with the licence UI and the signature policy (V24), views, per-image MetalFX/NVAPI rules (V25), DXR, DXMT NVEXT/spatial upscaling, the full `auto` policy, and shader-cache clearing.
- **Exit criteria:**
  - A D3D12 title runs with an imported GPTK 3.0, both launched directly and started by Steam.
  - MetalFX shows up in the Metal HUD **[H]** [R17].

### v0.6 "Polish" (about 3 weeks)

- **Scope:** Mac shortcuts and the `mallow://` scheme, the diagnostics bundle, FSEvents-based discovery and Steam-library re-indexing, localisation scaffolding, accessibility review, and `PrefixAudit` cleanup of legacy native DLLs in `doctor`.

### v0.8 "Distribution" (about 2 weeks, plus Apple account lead time)

- **Scope:**
  - A project Developer ID. This needs an entity to hold the $99/yr account (§10, Q5).
  - Notarisation and a stapled ticket.
  - Sparkle 2.10.0 with an EdDSA key and an appcast on GitHub Pages. This needs `AppUpdater.swift` (`#if canImport(Sparkle)`), `-add_rpath @executable_path/../Frameworks`, and Sparkle's notices in `THIRD_PARTY_LICENSES.md`.
  - Runtime update channels (stable/preview).
  - homebrew-cask submission once notarised.

### v0.9 "Import and community" (about 3 weeks)

- **Scope:**
  - `BottleImporter`: copy or adopt existing plain Wine prefixes, including those made by other frontends, with `ProvenanceGuard` and `PrefixAudit` quarantine.
  - Settings from other tools' metadata are **not** interpreted beyond the environment variables the user sees.
  - The community recipe repository, opened only after the §2.9 prerequisites: CC0, DCO, host allowlist, takedown process. Review grades and upstream-watch automation.

### v1.0 release criteria

1. At least two active maintainers with release rights and split key custody.
2. The runtime is rebuilt on the latest CodeWeavers LGPL drop, and every [L] item in §11 that the shipped features depend on has been resolved.
3. The Steam recipe passes on the current Steam client.
4. At least 30 titles are documented with backend and result.
5. No open data-loss bugs.
6. The licence audit is complete (§2.3): every static and dynamic component has its notice, and every binary has its source beside it.
7. Legal review of §2.4 and of the name (§2.6) is complete.
8. User and contributor docs are published.

### 8.3 After 1.0

- **Rosetta:** macOS 27 is the last release with full Rosetta, and macOS 28 keeps a gaming subset whose scope is unclear **[H]** [R38]. Track Apple's wording.
- **Native arm64:** prototype ARM64EC plus FEX once CodeWeavers publishes LGPL source for its ARM64 work and the question of the `com.apple.developer.cross-architecture-support` entitlement is settled **[L]** [R6].
- **Build hosts:** move `deps.yml` and `runtime.yml` to the arm64 cross-build before the x86_64 macOS images are retired (announced for about August 2027) **[M]**.
- **Graphics:** DXMT 1.0 and its D3D12 work; KosmicKrisp as a possible path to DXVK 2.x; GPTK 4 (check its licence).
- **Launchers:** Epic and GOG through legendary/gogdl instead of running their Windows launchers.

---

## 9. Risks

| Risk | Impact | Mitigation |
|---|---|---|
| Rosetta 2 is limited in macOS 28 (fall 2027) **[H]** | The x86_64 Wine approach may stop working | §8.3 native-arm64 research; clear user communication; stay close to upstream and CodeWeavers work |
| Steam/CEF changes break the client without warning | The headline feature breaks | Smoke test on every runtime release; fast runtime channel; web-helper restart action |
| One or two volunteers carry the runtime build | Burnout, as with Whisky and Gcenx | GOVERNANCE (≥2 maintainers), everything scripted in CI, weekly upstream-watch |
| x86_64 build hosts disappear (Intel Homebrew bottles already gone for key formulae **[H]**; x86_64 runners end about August 2027 **[M]**) | Runtime builds break | Dependencies built from source by our scripts (v0.2); Homebrew used only for build tools; the arm64 cross-build job |
| The name "Mallow" fails formal clearance, or a holder objects later | Rename cost, confusion | G0 formal search; single-source `ProductIdentity`; pre-checked fallback "Mullion" |
| Patch 0002 cannot read the image name early enough (V2) | Per-game backends for Steam-started games fall back to a single bottle backend | `init_startup_info` fallback; directly launched games still get their own backend |
| GPTK licence scope (2A(i)) and future GPTK 4 terms | Legal exposure, or D3DMetal loses users | User-supplied import only, licence shown and accepted, legal review |
| Our patches conflict with future CX-source drops | Backend switching breaks | Patches are small and covered by smoke tests (g)–(i) |
| D3DMetal needs CX-specific internals, and GPTK updates change them **[M]** | D3DMetal breaks after a GPTK update | Record the tested GPTK version in `import.json`; warn on unknown versions |
| Codec patents (H.264, HEVC, AAC decoders in FFmpeg) **[L]** | Legal exposure in some jurisdictions | No encoders are built (no x264/x265); legal review; `ffmpeg-components.txt` can drop patent-encumbered decoders |
| An incomplete licence notice slips into a release | Licence non-compliance | Mechanical `gen-licenses.py`; CI fails on any `libs/*` or dylib without a notice; `verify-app-bundle.sh` |
| SteamSetup.exe is not pinned or Authenticode-verified | Tampered installer | HTTPS to Valve's CDN host (final URL checked), header and size checks. Future: a pure-Swift Authenticode check of the Valve certificate chain (MS-PE spec) |
| Unnotarised distribution | Gatekeeper friction; TCC grants reset on every update (cdhash designated requirement) **[H]** | Phase to Developer ID (v0.8); document "Open Anyway" |
| Disk pressure on dev machines (design host has about 1.6 GB free) | Local builds and tests fail in confusing ways | Fake runtime for all local work; `dev-clean.sh`; real-runtime tests only in CI |
| The community sees a "CrossOver replacement" as parasitic | Reputation, contributor goodwill | §2.8 commitments; no support load pushed onto CodeWeavers (patch 0003) |
| Microsoft download link rot, or third-party mirrors disappearing | Verbs fail | Recipes name their hosts; alternatives must be vendor hosts or reviewed mirrors; never self-hosted |

---

## 10. Open questions (decisions needed)

| # | Question | Status | Needed by |
|---|---|---|---|
| Q1 | Licence | **Decided (2026-09-23, project owner):** 0BSD (frontend, scripts, docs), LGPL-2.1-or-later (runtime patches), CC0-1.0 (recipes, schemas) (§2.1). `LICENSE` is already committed as 0BSD. | G0 |
| Q2 | Name | **Decided provisionally:** "Mallow" (fallback "Mullion"), pending formal USPTO/EUIPO searches and a lawyer's opinion (§2.6, V31). Decided **before** Q4. | G0 |
| Q4 | GitHub org, Pages URL, bundle identifier | **Proposed:** `mallow-project`, `io.github.mallow-project.Mallow`. Register the org as soon as Q2 closes. | G0 (the catalog URL and bundle ID are compiled into the app) |
| Q3 | Legal review of the GPTK import flow (§2.4), the LGPL source procedure (§2.3) and codec patents | Open | v0.5 / v1.0 |
| Q5 | Which legal entity holds the Apple Developer ID and the signing keys (for example a fiscal host)? | Open | v0.8 |
| Q6 | Base policy after CX 26.3: follow each CodeWeavers LGPL drop, or rebase the CX diff onto upstream Wine releases? | Open | v0.9 |
| Q7 | Should we cooperate with existing open runtime efforts (highball-engine, LGPL) on a shared patch series, a shared runtime, or a shared dependency build? | Open | v0.2 |
| Q8 | Default for `ROSETTA_ADVERTISE_AVX` | **Decided:** off, which is Apple's documented default ("Defaults to 0 (OFF)" **[H]** [R17]); recipes opt in per title. Draft 1's "on, following Apple's documentation" was wrong. | done |
| Q9 | Telemetry: none (proposed), or opt-in only? | Open | v0.3 |
| Q10 | Media stack: keep the from-source GStreamer subset, or take the official GStreamer.framework's LGPL build (§3.11.2)? | Open; from source is the plan | v0.2 |
| Q11 | Is `winegstreamer` still needed at all with Wine 11's FFmpeg-based `winedmo`, or only for quartz/wmvcore? | Open **[M]** | v0.2 |
| Q12 | Reconcile `SECURITY_MODEL.md` defaults (z: removal, Seatbelt profile, winebrowser) with this design (§3.14) | **Decided:** secure defaults (`hideHostRoot: true`, `linkHomeFolders: false`). Seatbelt profile integration into `LaunchPlanner`/`PosixSpawner` is still to be specified | v0.1 (defaults), v0.2 (profile) |

---

## 11. Verification backlog (assumptions register)

Each row must be closed, with a note, a test and a source, before the feature that depends on it ships.

| # | Assumption | Tag | How to verify | Blocks |
|---|---|---|---|---|
| V1 | The sha256 of `crossover-sources-26.3.0.tar.gz` equals the highball-engine pin | M | Download in CI and compare | v0.2 |
| V2 | Patch 0002 can read the process image path lazily at the first builtin search **and** at CX's `init_non_native_support` | M | Prototype plus smoke test (i) | v0.2 (map), v0.4 (Steam per-game) |
| V3 | Wine's configure accepts `@rpath/…` soname pins, and dlopen resolves them | M | CI build plus `dlopen_all` and MoltenVK enumeration with `DYLD_*` unset | v0.2 |
| V4 | D3DMetal works through a prepended symlink view (dyld realpath for `@loader_path`) | M | Import GPTK 3.0 on a test Mac; run a D3D12 sample | v0.5 |
| V5 | The CX source contains personality-routine unwinding for builtins (D3DMetal C++ exceptions) | M | Run a D3DMetal title on our runtime; grep `dlls/ntdll/unix/signal_x86_64.c` | v0.5 |
| V6 | `CX_ACTIVE_GRAPHICS_BACKEND` exists in the CX source, and what it does | L | `grep -r` in `sources/wine` during the runtime build (sets `features.activeBackendHint`) | v0.5 (DLSS frame gen only) |
| V7 | Gcenx builds honour `WINEDLLPATH_PREPEND` | M | `RuntimeCapabilityProbe` on the pinned build, plus a manual test | v0.1 (DXVK builtin on Standard Wine) |
| V8 | Standard Wine lacks the `macdrv_functions` export (so no DXMT) | M | Probe (export trie) | v0.1 |
| V9 | Hiding d3d12 under DXMT/DXVK helps rather than hurts | L | Test the matrix with 3 titles each | v0.2 (the default) |
| V10 | `wineserver` inherits client stdout (the pipe EOF issue) | L | Irrelevant as long as we never use pipes; test only if pipes are ever introduced | none |
| V11 | GitHub macOS runners have a GUI session for `wndtest.exe` | M | First runtime CI run | v0.2 |
| V12 | CLT is present on `macos-26` runners after `xcode-select -s` | L | The first `ci.yml` run | v0.1 CI |
| V13 | Steam's 64-bit installer path (`Program Files (x86)` or `Program Files`) | L | Run the recipe | v0.4 |
| V14 | `LC_ALL=en_US.UTF-8` helps steamwebhelper | L | A/B test; the default is now no locale | none |
| V15 | `gameoverlayrenderer` must still be disabled with the 64-bit client | M | A/B test | v0.4 |
| V16 | `softwareupdate --install-rosetta` needs admin rights; without `--agree-to-license` it prompts in Terminal | M | Test as a standard user | v0.3 |
| V17 | TCC attributes a Wine child's microphone, camera or local-network access to Mallow | L | Test with a Windows voice-chat app | v0.6 |
| V18 | GPTK 4 licence text and payload layout | L | Read them when GPTK 4 is released | post-v0.5 |
| V19 | The GPTK 3.0 payload matches Apple's Read Me (`redist/lib/wine/x86_64-{unix,windows}`, `nvngx-on-metalfx.*`) | M (Read Me is H) | The importer enumerates the user's own dmg; checked on a real machine | v0.5 |
| V20 | `POSIX_SPAWN_SETSID` is available and behaves as expected on macOS 15/26 | M | Unit test in `LaunchServiceIntegrationTests` | v0.1 |
| V21 | CX Dock-name hack (`CW HACK 22144`) behaviour without `WINEDLLPATH` | M | Observe the Dock with our runtime | v0.3 (cosmetic) |
| V22 | Steam's first update needs about 1 GB free | L | Measure | v0.4 (preflight threshold) |
| V23 | Whether the name "Wine" is a trademark, and who holds it | L | Check the WineHQ site and a trademark database | before the public announcement |
| V24 | Which signature GPTK 3.0's `D3DMetal.framework` and `libd3dshared.dylib` carry (`anchor apple` or Developer ID with Apple's team ID) | **L** | `codesign -dvvv -r-` on a real GPTK 3.0 dmg; fill `TrustedAppleTeams.gptk`; record the requirement in `import.json` | v0.5 |
| V25 | A full-path load of a missing `C:\windows\system32\nvngx.dll` falls back to the builtin search (so the per-image `views/metalfx` works without a `system32` copy) | M | A DLSS title with MetalFX, launched directly and by Steam | v0.5 |
| V26 | `ac_cv_lib_soname_vulkan=` (empty cache) makes configure skip the Khronos loader | M | Configure log plus the `SONAME_LIBVULKAN` assertion | v0.2 |
| V27 | How Gcenx's Standard Wine finds Vulkan (bundled loader/ICD json or not), and whether it runs with `DYLD_*` unset from outside its `.app` layout | **L** | Import the pinned tarball in CI; `vkprobe.exe`; `cmd /c echo`; text rendering | v0.1 |
| V28 | (closed by design) Moving Wine out of `Wine Stable.app` may break discovery | — | Not done: the tree is kept intact | — |
| V29 | `.update-timestamp` semantics (mtime of `wine.inf`, "disable") match Wine 11's own check | M | Read `wineboot`/loader source; `PrefixUpdateCheck` test against a real runtime | v0.2 |
| V30 | `flock` works on bottles stored on exFAT/SMB external volumes | M | Test; else read-only with explanation | v0.6 |
| V31 | "Mallow" is free in USPTO/EUIPO classes 9 and 42 | **L** | Formal search + lawyer | G0 |
| V32 | The FFmpeg component list and the GStreamer subset cover winedmo/winegstreamer needs (H.264, WMV/ASF, Bink) | M | `mfprobe.exe` + title tests (cutscenes) | v0.2 |
| V33 | glib builds for x86_64 macOS with `-Dnls=disabled` and the proxy-libintl fallback | M | `deps.yml` first run | v0.2 |
| V34 | `D3DM_ENABLE_METALFX=1` and `DXMT_ENABLE_NVEXT=1` are harmless in images whose rule lacks the view | L | A/B with two titles | v0.5 |
| V35 | Whether Gcenx's `WINEDLLPATH_PREPEND` patch exports prepend dirs as `WINEDLLDIR%u` | L | Smoke test (h) against the pinned Standard Wine | v0.1 (mitigated by `updatePrefix`) |
| V36 | CX-source Wine has no builtin `nvapi`/`nvapi64` of its own | L | `ls lib/wine/*-windows` of our build | v0.5 |
| V37 | `SteamAPI_RestartAppIfNecessary` relaunches through Steam with Steam's environment | M | Launch a Steamworks title directly; inspect child env with `+loaddll` | v0.4 |
| V38 | `renamex_np(…, RENAME_SWAP)` swaps two directories atomically on APFS | M | `ComponentInstallerTests` on APFS | v0.2 |
| V39 | No other user-visible CX strings point at CodeWeavers beyond `winedbg.rc` | M | `audit-vendor-strings.sh` review of all hits | v0.2 |
| V40 | `flock` locks on separate open file descriptions in one process exclude each other on macOS | M | `BottleStoreTests` | v0.1 |

---

## 12. References

**Wine source code**

- [R1] CodeWeavers, CrossOver source: https://www.codeweavers.com/crossover/source ; https://media.codeweavers.com/pub/crossover/source/crossover-sources-26.3.0.tar.gz
- [R2] highball-engine pinned inputs and CI timings: https://github.com/gauthierpiarrette/highball-engine/blob/HEAD/inputs.json ; https://github.com/gauthierpiarrette/highball-engine/actions
- [R3] CX-source mirrors: https://github.com/dappermint/winecx ; https://github.com/PhoenicisOrg/winecx
- [R4] WineHQ macOS builds (Gcenx): https://github.com/Gcenx/macOS_Wine_builds ; https://github.com/Gcenx/macports-wine
- [R5] Homebrew cask disabled: https://formulae.brew.sh/api/cask/wine-stable.json ; https://github.com/Gcenx/macOS_Wine_builds/issues/168
- [R6] frankea/winecx-gptk (build notes and Steam findings): https://github.com/frankea/winecx-gptk
- [R7] Wine 11.0 ANNOUNCE: https://raw.githubusercontent.com/wine-mirror/wine/wine-11.0/ANNOUNCE.md
- [R8] Wine 11.0 `dlls/ntdll/unix/loader.c` (`set_dll_path` lines ~361–385; `find_builtin_dll` ~1245–1362; USER/HOME handling): https://raw.githubusercontent.com/wine-mirror/wine/wine-11.0/dlls/ntdll/unix/loader.c
  - [R8-debug] `dlls/ntdll/unix/debug.c`
  - [R8-shell] `dlls/shell32/shellpath.c`
- [R9] Wine 11.0 `server/request.c` (server dir, lock, `wait_for_lock`, `kill_lock_owner`, `shutdown_master_socket`) and `server/registry.c` (`save_period`): https://raw.githubusercontent.com/wine-mirror/wine/wine-11.0/server/request.c
- [R10] Wine 11.0 `server/signal.c`, `server/main.c`
- [R11] winemac.drv options: https://github.com/wine-mirror/wine/blob/master/dlls/winemac.drv/macdrv_main.c
  - [R11-retina] https://github.com/dappermint/winecx-gptk/issues/11
  - [R11-deps] https://brew.sh/2026/09/13/homebrew-7.0.0/

**Graphics backends and GPTK**

- [R12] DXMT: https://github.com/3Shain/dxmt/releases/tag/v0.80 ; https://github.com/3Shain/dxmt/blob/main/LICENSE ; https://github.com/3Shain/dxmt/wiki/DXMT-Installation-Guide-for-Geeks
- [R13] DXMT variables: https://github.com/3Shain/dxmt/blob/main/docs/CUSTOMIZATION.md ; https://github.com/3Shain/dxmt/blob/main/docs/DEVELOPMENT.md
- [R14] DXVK-macOS: https://github.com/Gcenx/DXVK-macOS/releases/tag/v1.10.3-20230507-repack
- [R15] MoltenVK: https://github.com/KhronosGroup/MoltenVK/releases/tag/v1.4.2
- [R16] Apple GPTK licence (EA18380): https://github.com/user-attachments/files/23971305/License.pdf ; https://github.com/Sikarugir-App/Sikarugir/tree/main/D3DMetal
- [R17] Apple GPTK 3.0 Read Me (documented variables, MetalFX procedure): https://github.com/Sikarugir-App/Sikarugir/blob/main/D3DMetal/3.0/Read%20Me.pdf
- [R18] frankea/Whisky GPTKImporter (user-supplied model): https://github.com/frankea/Whisky/blob/main/WhiskyKit/Sources/WhiskyKit/WhiskyWine/GPTKImporter.swift
- [R19] frankea/Whisky BottleSettings: https://github.com/frankea/Whisky/blob/main/WhiskyKit/Sources/WhiskyKit/Whisky/BottleSettings.swift
  - [R19-steam] https://github.com/frankea/Whisky/blob/main/docs/SteamCompatibility.md
- [R22] Gcenx `WINEDLLPATH_PREPEND` patch (prior art; not copied): https://github.com/Gcenx/macports-wine/blob/master/devel/game-porting-toolkit/files/1002-ntdll-d3dmetal-env.diff ; https://github.com/Heroic-Games-Launcher/HeroicGamesLauncher/pull/5342#issuecomment-3936553327
- [R23] Metal Performance HUD: https://developer.apple.com/documentation/xcode/customizing-metal-performance-hud
- [R31] MSync: https://github.com/marzent/wine-msync ; https://github.com/dappermint/winecx/tree/crossover-26.3.0/dlls/ntdll/unix
- [R32] CX 26.3 LGPL `loader.c` (`set_dll_path` identical to upstream; `CX_APPLEGPTK_LIBD3DSHARED_PATH`; CW HACK 22144): https://raw.githubusercontent.com/dappermint/winecx/crossover-26.3.0/dlls/ntdll/unix/loader.c
- [R48] Wine load-order parsing: https://raw.githubusercontent.com/wine-mirror/wine/wine-11.0/dlls/ntdll/unix/loadorder.c
  - [R48-wined3d] https://gitlab.winehq.org/wine/wine/-/wikis/Useful-Registry-Keys
- [R50] Wine 11.0 `dlls/appwiz.cpl/addons.c` (Mono 10.4.1, Gecko 2.47.4, `WINEDATADIR`); `dlls/ntdll/unix/env.c`; https://dl.winehq.org/wine/wine-mono/ ; https://dl.winehq.org/wine/wine-gecko/
- [R51] DXMT on vanilla builds: https://github.com/gauthierpiarrette/highball/issues/5
- [R52] D3DMetal and personality routines: https://github.com/frankea/Whisky/issues/163

**Prior-art frontends**

- [R20] Whisky (archived, GPL-3.0): https://github.com/Whisky-App/Whisky
  - [R20-prior-art] Sikarugir: https://github.com/Sikarugir-App/Sikarugir
- [R21] Whisky maintenance notice: https://docs.getwhisky.app/maintenance-notice
- [R40] Bottles config model: https://github.com/bottlesdevs/Bottles/blob/main/bottles/backend/models/config.py
- [R41] Mythic engine update catalog: https://github.com/MythicApp/Mythic/blob/main/Mythic/Utilities/Engine/Engine%2BUpdateCatalog.swift
- [R42] Heroic launcher env: https://github.com/Heroic-Games-Launcher/HeroicGamesLauncher/blob/main/src/backend/launcher.ts

**Wine programs, file formats, Steam, anti-cheat**

- [R24] wineboot: https://github.com/wine-mirror/wine/blob/master/programs/wineboot/wineboot.c
  - [R24-start] `programs/start/start.c`
  - [R24-wt] winetricks comment on `wineserver -w` after wineboot
- [R25] winecfg version table: https://github.com/wine-mirror/wine/blob/master/programs/winecfg/appdefaults.c
- [R26] MS-SHLLINK: https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-shllink/
- [R27] PE format: https://learn.microsoft.com/en-us/windows/win32/debug/pe-format
- [R28] winetricks 20260125: https://github.com/Winetricks/winetricks
- [R29] Steam 64-bit transition: https://www.tomshardware.com/video-games/pc-gaming/steam-begins-64-bit-transition-on-windows-as-32-bit-support-enters-final-countdown
- [R30] Black Steam window on WineHQ 11.17: https://github.com/Gcenx/macOS_Wine_builds/issues/170
- [R39] CodeWeavers on anti-cheat: https://support.codeweavers.com/anti-cheat

**Apple platform, toolchain, distribution**

- [R33] `dlopen(3)` man page on macOS 26.5 (leaf-name search: `DYLD_LIBRARY_PATH` → caller/main `LC_RPATH` → cwd → fallbacks; `@rpath` support), read locally.
- [R34] swift-argument-parser 1.8.2: https://github.com/apple/swift-argument-parser
- [R35] Sparkle: https://github.com/sparkle-project/Sparkle ; https://sparkle-project.org/documentation/
- [R36] GitHub macOS 26 runners: https://github.blog/changelog/2026-02-26-macos-26-is-now-generally-available-for-github-hosted-runners/ ; https://github.com/actions/runner-images/blob/main/images/macos/macos-26-arm64-Readme.md
- [R37] Homebrew 5.0.0 (quarantine and Gatekeeper policy): https://brew.sh/2025/11/12/homebrew-5.0.0/
- [R38] Rosetta timeline: https://developer.apple.com/news/?id=w5ngl9k2 ; https://www.macrumors.com/2026/06/10/macos-golden-gate-last-to-support-intel-apps/
  - [R38-ci] https://github.com/actions/runner-images/issues/13045
- [R43] swift-testing under CLT: https://forums.swift.org/t/error-no-such-module-testing/74784 ; https://github.com/swiftlang/swift-package-manager/issues/10557
- [R44] Game Mode and child processes: https://developer.apple.com/forums/thread/787702
- [R45] LGPL-2.1: https://www.gnu.org/licenses/old-licenses/lgpl-2.1.html
- [R46] Build provenance: https://github.com/actions/attest-build-provenance
- [R47] CryptoKit Curve25519 signing: https://developer.apple.com/documentation/cryptokit/curve25519/signing

**Added in Draft 2**

- [R53] Conflicting "Decanter" project (GPL-3.0, created 2026-08-25, v0.9.1 on 2026-09-22; `Package.swift` with `DecanterKit`/`decanter`/`DecanterApp`): https://github.com/ricardothesillyllama/Decanter (checked with the GitHub API on 2026-09-23)
- [R54] Homebrew `ffmpeg` formula (`license: GPL-3.0-or-later`, no x86_64 macOS bottle): https://formulae.brew.sh/api/formula/ffmpeg.json
- [R55] Homebrew `gstreamer` formula: https://formulae.brew.sh/api/formula/gstreamer.json
- [R57] GNU GPL v3 text (incl. §6 Corresponding Source): https://www.gnu.org/licenses/gpl-3.0.txt ; LGPL v3: https://www.gnu.org/licenses/lgpl-3.0.txt
- [R58] CX 26.3 `programs/winedbg/winedbg.rc` (links to codeweavers.com): https://raw.githubusercontent.com/dappermint/winecx/crossover-26.3.0/programs/winedbg/winedbg.rc
- [R59] Upstream wine-11.0 `programs/winedbg/winedbg.rc`: https://raw.githubusercontent.com/wine-mirror/wine/wine-11.0/programs/winedbg/winedbg.rc
- [R61] Wine 11.0 `dlls/ntdll/unix/env.c` (locale selection; `WINEDLLDIR%u` export): https://raw.githubusercontent.com/wine-mirror/wine/wine-11.0/dlls/ntdll/unix/env.c
- [R62] Wine 11.0 `dlls/setupapi/fakedll.c` (`create_wildcard_dlls`): https://raw.githubusercontent.com/wine-mirror/wine/wine-11.0/dlls/setupapi/fakedll.c
- [R63] Wine 11.0 `configure.ac` (Vulkan/MoltenVK soname order): https://raw.githubusercontent.com/wine-mirror/wine/wine-11.0/configure.ac
- [R64] `man softwareupdate` on macOS 26.5 ("--agree-to-license … without any user interaction"), read locally; Apple SLAs: https://www.apple.com/legal/sla/
- [R65] Wine 11.0 `dlls/ntdll/unix/server.c` (server start retries) and `server/request.c` (lock): https://raw.githubusercontent.com/wine-mirror/wine/wine-11.0/dlls/ntdll/unix/server.c
- [R66] winetricks 20260125 `corefonts` (github.com/pushcx/corefonts) and `d3dcompiler_47` (raw.githubusercontent.com/mozilla/fxc2) download sources: https://raw.githubusercontent.com/Winetricks/winetricks/20260125/src/winetricks
- [R67] Microsoft .NET Framework supplemental licence terms, as recorded in ScanCode LicenseDB (wording for 4.8 not verified **[M]**): https://scancode-licensedb.aboutcode.org/
- [R69] MoltenVK `ExternalRevisions`: https://github.com/KhronosGroup/MoltenVK/tree/main/ExternalRevisions
- [R70] Sparkle licence (bsdiff, sais-lite, ed25519 notices): https://github.com/sparkle-project/Sparkle/blob/2.x/LICENSE
- [R71] Independent JPEG Group README (binary-distribution acknowledgement): https://www.ijg.org/files/README
- [R72] FSEvents (file-level events): https://developer.apple.com/documentation/coreservices/file_system_events
- [R73] SE-0461 (nonisolated nonsending by default, `@concurrent`): https://github.com/swiftlang/swift-evolution/blob/main/proposals/0461-async-function-isolation.md
- [R74] "mallow - no buy tracker": https://getmallow.app
- [R75] Mallow Technologies Pvt Ltd: https://mallow-tech.com/
- [R76] Apple iTunes Search API queries used for the App Store checks: https://itunes.apple.com/search?term=mallow&entity=macSoftware ; https://itunes.apple.com/search?term=mallow&entity=software
- [R77] GitHub search API (`search/repositories`, `users/<org>`) queries run on 2026-09-23 for "mallow" and "mullion"
- [R78] USPTO trademark search: https://tmsearch.uspto.gov/ ; EUIPO eSearch: https://euipo.europa.eu/eSearch/
- [R81] GStreamer macOS packages: https://gstreamer.freedesktop.org/download/#macos
- [R82] Homebrew formula API (bottle availability per OS/arch): https://formulae.brew.sh/api/formula/glib.json (and `gstreamer`, `ffmpeg`, `sdl2-compat`, `mingw-w64`, `gnu-tar`)
- [R84] FFmpeg licensing (`--disable-gpl`, LGPL build): https://github.com/FFmpeg/FFmpeg/blob/master/LICENSE.md
- [R85] Wine 11.0 bundled libraries: https://gitlab.winehq.org/wine/wine/-/tree/wine-11.0/libs
- [R86] Developer Certificate of Origin: https://developercertificate.org/
- [R87] CC0 1.0: https://creativecommons.org/publicdomain/zero/1.0/

---

## 13. Resolved review issues

Draft 1 was reviewed from two angles, legal (L) and feasibility (F). Every blocker and major issue is resolved below, and so are all the minor ones. "Agreed" means the reviewer's fix was adopted as proposed. "Varied" means the problem is fixed by a different mechanism, and the rationale is given.

| # | Lens / severity | Issue | Resolution | Where | Verdict |
|---|---|---|---|---|---|
| L1 | legal / **blocker** | "Decanter" is used by an active same-purpose GPL project with identical SwiftPM names, and the reviewer reports the same data folder too | Renamed to **Mallow**, the name already in `LICENSE` and `SECURITY_MODEL.md`. We confirmed the conflict with the GitHub API [R53], and ran a partial clearance on "Mallow" (GitHub, Homebrew, both App Stores, web) [R74]–[R77]. Formal USPTO/EUIPO searches are a G0 exit criterion (V31), with "Mullion" pre-checked as the fallback. All identifiers are listed in §2.6.1 and come from `ProductIdentity`. Q2 is now decided before Q4. The data root gets a `.mallow-root.json` marker, and a foreign root is refused. | §2.6, §2.6.1, §3.4.1, §8 G0, §10 | Agreed. The data folder stays human-readable (not the bundle ID); the marker gives the protection. |
| L2 | legal / major | Licence undecided while the design already follows frankea/Whisky | Q1 decided by the project owner: **0BSD**. SPDX headers updated. Code reuse from GPL frontends is **forbidden**; they are credited in `NOTICE` for ideas only. Matching file and type names are kept, with independently written implementations (§2.1, §2.7). | §2.1, §2.7, §8 G0 | Varied: the critic's GPL recommendation was superseded by the owner's 0BSD choice. |
| L3 | legal / major | Homebrew FFmpeg/GStreamer are GPL builds labelled LGPL | FFmpeg built from pinned source (`--disable-gpl --disable-nonfree --disable-version3 --disable-encoders --disable-programs`, decoders only). GStreamer core/base/good subset + gst-libav from source, `-Dgpl=disabled`, no ugly or bad. `avcodec_license()` must be LGPL, a leaf-name denylist and an SPDX allowlist apply, and `components[].license` is generated. | §2.2, §3.11.1, §3.11.2, §3.7.3 | Agreed; the official GStreamer.framework is kept as an unplanned alternative (Q10) |
| L4 | legal / major | `deps-sources` is not complete corresponding source for Homebrew-built libraries | Superseded: no bundled library comes from Homebrew any more. `deps-sources` holds the upstream tarballs **plus our own build scripts** (`runtime/deps/**`) and any patches, so it is complete by construction. It is published beside every runtime release. | §2.3 item 2, §3.11.2 A | Varied: the reviewer's "better" option (bring the from-source build forward) was taken. That makes the formula-capture rule unnecessary. `bundle-dylibs.sh` still fails if anything resolves outside `$DEPS_PREFIX`. |
| L5 | legal / major | Statically linked third-party notices missing (Wine `libs/*`, MoltenVK components, LLVM in `winemetal.so`, DXMT vendored code) | `gen-licenses.py` generates `licenses/` mechanically: Wine `libs/*`, deps, MoltenVK `ExternalRevisions`, and the IJG sentence. DXMT packaging ships the LLVM (incl. NCSA), DXBCParser, nvapi and mingw-headers licences. `staticComponents` is required in `backend.json`. CI fails on any gap. | §2.2, §2.3, §3.11.3, §3.12, §3.7.5 | Agreed |
| L6 | legal / major | Release app contains no licence texts | `build-app.sh` copies `LICENSE`, `NOTICE` and a generated `THIRD_PARTY_LICENSES.md` into `Contents/Resources`. `AcknowledgementsView` shows them with a per-tag source link (`MallowSourceURL`). `verify-app-bundle.sh` in `ci.yml` and `release-app.yml` enforces this. | §3.9, §3.10 | Agreed |
| L7 | legal / major | CX `winedbg.rc` sends crash users to CodeWeavers | Patch 0003. A source-tree vendor-string audit with a reviewed allowlist, and a binary scan (ASCII + UTF-16LE) that fails on any `codeweavers.com`. Copyright headers and `AUTHORS` untouched. | §2.6, §3.11.2, §3.11.3, §3.11.4 | Varied: the links point to **our tracker**, not back to WineHQ, because WineHQ asks for reports against unmodified Wine [M] |
| L8 | legal / major | Runtime and bottle imports could bring in CrossOver's launcher or Apple's D3DMetal | `ProvenanceGuard`: enclosing `com.codeweavers.*` bundle, `cx*` tools, `apple_gptk`, `D3DMetal.framework`, `libd3dshared.dylib`, `anchor apple` Mach-O. Used by `importDirectory`, `StandardWineImporter` and `BottleImporter`. `PrefixAudit` quarantines Apple translation DLLs and MetalFX bridges in imported prefixes. Unit tests with synthetic trees. | §2.4 rule 7, §3.4.1, §3.4.5, §3.4.8, §7.3 | Agreed |
| L9 | legal / major | Verb recipes: third-party mirrors, EULAs skipped by `-q`, dotnet48 needs a Windows licence | `sourceHosts`/`sourceKind`/`license` required in every recipe. The corefonts and d3dcompiler_47 mirrors are named. `TermsCatalog` terms are shown before any winetricks run, including the passthrough, which needs `--yes`. `dotnet48` is removed from the built-ins, with a Windows-licence warning. wine-mono is the default. | §2.2, §2.5, §3.7.7, §3.4.9 | Agreed |
| L10 | legal / minor | Rosetta install accepts Apple's SLA silently | `RosettaConsentSheet` with an SLA link and explicit Agree, recorded as a `ConsentRecord`. The CLI needs `--accept-apple-license`; otherwise it prints the interactive command. | §3.4.1, §3.9, §3.8.1 | Agreed |
| L11 | legal / minor | Wrong LGPL section cited | Now cites LGPL-2.1 §1 and §4 (and GPL-3 §6(d) for the LGPL-3 components). A hard same-place rule for every host. Source URL shown in the UI. The written-offer wording is dropped; retention is "as long as binaries are offered", plus 3 years as an extra precaution. | §2.3 | Agreed |
| L12 | legal / minor | Clean-room lapses: CX-inspected facts, AVX default | Payload facts re-sourced to Apple's Read Me, with names enumerated at import. Toolchain re-sourced to [R2][R6]. "(local inspection)" citations removed. AVX off by default; Q8 corrected. | §2.4, §2.7, §3.11.1, §4.6, §4.7, §10 | Agreed |
| L13 | legal / minor | Community recipe repo lacks licence, DCO, host policy, takedown | CC0-1.0, DCO, `allowed-hosts.json` with maintainer approval via `CODEOWNERS`, and a published DMCA/abuse contact and procedure before the repository opens. | §2.9, §3.2 | Agreed |
| F1 | feasibility / **blocker** | Intel Homebrew no longer ships needed bottles; the result was GPL, minos 15, sdl2-compat | `deps.yml` builds a minimal dependency set from pinned source (x86_64, `MACOSX_DEPLOYMENT_TARGET=14.0`, meson/ninja from pip, real SDL2 2.32.x), cached as release `deps-<hash>`, with minos and path checks. Packaging with GNU tar moved to an arm64 job. We re-verified the bottle facts [R82]. | §3.11.1, §3.11.2, §8 v0.2 | Agreed |
| F2 | feasibility / major | Backend chosen per launch in the env: Steam's choice leaks to games; env overrides beat AppDefaults; libd3dshared loaded everywhere | Patch 0002 is now a **per-image DLL path map file** with a per-image libd3dshared column. `T` load orders go to the registry (global + AppDefaults deltas), never to `WINEDLLOVERRIDES`, and the precedence is documented. The steam template has an explicit `dxmt` `*` rule with `hideD3D12: false`, `wined3d` rules for Steam's images, and auto rules per installed game. Golden `graphics-plan-steam.json`, smoke test (i), and fake-wine child test. | §3.11.4, §4.1, §4.5, §6.1, §7 | Varied: the map is a **file** named by `WINEDLLPATH_PREPEND_MAPFILE`, not an inline env value, so it can be long and updated while Steam runs. Load orders common to all backends live in the global key; only deltas are per exe. |
| F3 | feasibility / major | Prepend dirs leak into `system32` via `WINEDLLDIR%u` during the automatic prefix update | Patch 0001 keeps prepend entries in a private list that is never exported. The `updatePrefix` preflight runs `wineboot -u` with base layers only (no map, no backend) when the runtime changed or `.update-timestamp` is stale. Smoke test (h). | §3.11.4, §5.1, §3.11.2 | Agreed. We wait for the `wineboot` process to exit rather than for the server to stop, because the next process talks to the same server. |
| F4 | feasibility / major | Reconcile removes files other running processes need; per-program nvapi/nvngx were bottle-wide | Desired set = files of every backend the map references (config-derived, so Steam-started games are covered). Environment mode adds running programs. Removals only while the server is stopped. nvapi64/nvngx never go into `system32`: they are per-image views. Test with two concurrent backends. | §4.3, §4.5, §3.4.6, §7.3 | Varied: in imageMap mode the set comes from configuration rather than from tracking running programs, which also covers games Mallow never launched |
| F5 | feasibility / major | `NonisolatedNonsendingByDefault` runs Kit work on the main thread | The feature is disabled for every target (re-verified on the host: plain nonisolated async then runs off-main). Every heavy API is marked `@concurrent` or is an actor method, listed in §3.5. `ConcurrencyIsolationTests` with `ThreadProbe`; lint guard. | §3.3, §3.4, §3.5 | Agreed, plus the extra step of disabling the feature |
| F6 | feasibility / major | Synthesised Codable does not match the documented JSON; missing keys throw | Normative wire rules and a table (§3.7.0). `@Defaulted` for every persisted field (pattern tested on the host). `nil` is never written, and the examples are updated. Hand-written Codable for enums and path-bearing types. WF0 fixtures land before the modules are split. | §3.7.0, §3.4, §8 v0.1 | Agreed |
| F7 | feasibility / major | No writer for `AppliedState`; layering break; unclear when edits apply | `SettingsPlan.compute` (pure) moved to the Wine layer. `AppliedState` = `server` + `prefix` with explicit fields. **`LaunchService` is the only writer**, because every Wine spawn goes through it. `BottleSettingsApplier.edit`: apply now if stopped, hot parts plus pending reasons if running. Pending is derived, not stored. | §3.4.2, §3.4.4, §3.4.7, §3.4.8, §3.5, §5.6, §5.7 | Varied: one writer for all of `AppliedState`, instead of applier plus LaunchService. `pendingApply` is derived, so it cannot go stale. |
| F8 | feasibility / major | Revision check + rename is not atomic across processes; the directory DispatchSource misses edits | `flock` on `.mallow/config.lock` (and `settings.json.lock`) for the whole read-modify-write. FSEvents file-level watcher over `Bottles/` and external bottles. Two-process test. | §1.3, §3.4.1, §3.4.2, §3.5 | Agreed |
| F9 | feasibility / major | `fcntl` lock semantics under-specified; the idle watcher could hold or mis-detect the lock | Exact protocol documented. Mallow never takes the server lock. The idle watcher polls `F_GETLK` every 500 ms, starts only after a pid is seen, and requires `kill(pid,0) == ESRCH`. | §3.4.4, §5.6 | Agreed (the polling alternative) |
| F10 | feasibility / major | fake-wine cannot `fork()`; in-process lock tests are meaningless | `fake-wine --hold-lock` (spawns itself, pid file) and `--flock`. `FakeWineServer` test helper; no in-process locks in tests. | §7.2, §7.3 | Agreed |
| F11 | feasibility / major | Forced `en_US.UTF-8` breaks non-Unicode apps | `locale` is absent by default; `LANG`/`LC_ALL` are set only when chosen per bottle or per program. Steam's `LC_ALL` dropped (V14). Goldens updated. | §3.7.2, §4.7, §5.2, §6.1 | Agreed |
| F12 | feasibility / major | Files reached via `Z:` break when `z:` is removed | `PrefixStaging`: `.reg` files and installers are staged in `drive_c/windows/temp/mallow/<uuid>/` and used through `C:`. Tests with `z:` removed; fake-wine fails on a missing drive link. | §3.4.4, §5.7, §6.1, §7 | Agreed |
| F13 | feasibility / major | Runtime lifecycle contradictory (`.previous` vs new IDs; `pinned` undefined; unsafe replace) | Side-by-side installs. `.previous` only for same-ID repair via `RENAME_SWAP`. `pinned` defined (unpinned bottles move only at a cold start, via `updatePrefix`). Refusals while any user of the runtime has a live server. `RuntimeUsage` injected. | §3.11.7, §3.4.3 | Agreed. `runtime.id` is meaningful only when pinned, so no second writer is needed for it. |
| F14 | feasibility / major | Standard Wine not obtainable in-app; Vulkan via the Khronos loader; relocation risk | Builtin pinned component + `mallow runtime install standard-wine-stable-11.0_1`. The `.app` tree is kept intact. `VK_DRIVER_FILES`/`VK_ICD_FILENAMES`, or a generated ICD json. CI real-runtime tests with `DYLD_*` unset. DYLD fallback only for flavor "standard", if V27 requires it. | §3.11.6, §3.4.3, §8 v0.1 | Agreed |
| F15 | feasibility / minor | Configure may pick the Khronos loader | `ac_cv_lib_soname_vulkan=` plus assertions on `SONAME_LIBVULKAN` and `SONAME_LIBSDL2`, with messages naming the pin. | §3.11.2 | Agreed |
| F16 | feasibility / minor | Probe byte-search ambiguities; `nm` unavailable to users | NUL-terminated markers; `MachOExports` export-trie parser for `_macdrv_functions`; Vulkan provider probe. Tests with decoys. | §3.4.3, §7.3 | Agreed |
| F17 | feasibility / minor | Catalog selection undefined; two winetricks paths | `family`, `versionKey`, channel order, `archive.format` (`file` supported by `ComponentInstaller`). Winetricks comes only through the tool component (catalog or builtin); `WinetricksRunner` only resolves the path. | §3.7.4, §3.4.3, §3.4.9 | Agreed |
| F18 | feasibility / minor | Late exit sources, unordered events, non-escaping progress | One waitpid thread per child. `EventBus` is a class with synchronous ordered `post`; `programStarted` is posted before the waiter starts. `@escaping @Sendable` progress. | §3.4.1, §5.4 | Agreed |
| F19 | feasibility / minor | bash 3.2 `set -u` with empty arrays; unset variables | `${A[@]+"${A[@]}"}` form, defaults for `VERSION`/`BUILD_NUMBER`, `#!/bin/bash`, and shellcheck in `lint.sh`. | §3.10, §7.4 | Agreed |
| F20 | feasibility / minor | File-list inconsistencies | `AppUpdater` inside `#if canImport(Sparkle)`; `-add_rpath` step (v0.8); `MALLOW_CLI` exported; golden count fixed (11 launch goldens; create-bottle owned by `BottleCreatorIntegrationTests`); new test files; the staleness check is attributed to the CI job; `SecCodeSignatureChecker` added; the Swift schema test only decodes. | §3.2, §3.3, §3.10, §7.3–7.5 | Varied: `CodeSignatureChecker` lives in **Support**, not Graphics, because `ProvenanceGuard` (Support) needs it |
| F21 | feasibility / minor | GPTK signature requirement unverified | V24 [L]. `CodeSignatureChecker` returns `SigningInfo`. The policy accepts `anchor apple`, or Apple-generic with a trusted team ID. Both files are checked. The observed requirement is recorded in `import.json`. | §2.4, §3.4.1, §3.4.6, §11 | Agreed |
