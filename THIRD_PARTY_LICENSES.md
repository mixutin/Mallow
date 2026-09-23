<!-- SPDX-License-Identifier: 0BSD -->

# Third-party licences

> **This is a placeholder.** Mallow has no releases yet, so nothing listed here is distributed today. This file lists the third-party components Mallow **plans** to use, and their licences, following [DESIGN.md §2.2](https://github.com/mixutin/Mallow/blob/main/docs/DESIGN.md). From the first release on, `scripts/gen-third-party-licenses.sh` will generate this file for each release, with the full licence texts, and CI will fail if it is out of date. The generated file, not this placeholder, is the authoritative record.

Mallow's own code, scripts and documentation are licensed under [0BSD](https://github.com/mixutin/Mallow/blob/main/LICENSE). Credits for prior art are in [NOTICE](https://github.com/mixutin/Mallow/blob/main/NOTICE).

## Where licence notices will live

| What you download | Where its notices are |
|---|---|
| **Mallow app** (`Mallow.app`, including the `mallow` CLI) | `LICENSE`, `NOTICE` and this file inside the app bundle, shown under **Mallow → Acknowledgements**. `mallow licenses` prints them. |
| **Mallow Runtime** (separate download) | The runtime's own `licenses/` folder, generated at build time: Wine's `COPYING.LIB` and `AUTHORS`, every bundled library's licence, and `SOURCE.md` with the links to the matching source archives. `mallow licenses --runtime <id>` prints them. |
| **Graphics backends** (separate downloads) | Each backend's own `licenses/` folder, plus a `staticComponents` list in its `backend.json`. |

## 1. Linked into the Mallow app and CLI

| Component | Version | Licence (SPDX) | Planned from | Notes |
|---|---|---|---|---|
| [swift-argument-parser](https://github.com/apple/swift-argument-parser) | 1.8.2 | Apache-2.0 | v0.1 | Linked into the `mallow` CLI. Its licence text is reproduced below (Apache-2.0 §4(a)). |
| [Sparkle](https://github.com/sparkle-project/Sparkle) | 2.10.0 | MIT, plus notices for bsdiff (BSD-2-Clause), sais-lite and ed25519 | v0.8 | App updates. Sparkle's complete `LICENSE` file is reproduced below. |

## 2. Mallow Runtime (separate download)

The Mallow Runtime will be a build of Wine. It is a separate program: the app starts it but never links to it. Every runtime release will be published together with its complete corresponding source (the Wine source, our patches, every dependency's source, and our build scripts).

| Component | Version | Licence (SPDX) | Notes |
|---|---|---|---|
| Wine, from CodeWeavers' LGPL source release | 11.0 (source release 26.3.0) | LGPL-2.1-or-later | Plus three small patches of our own, also LGPL-2.1-or-later. |
| Libraries built into Wine's own DLLs (`libs/*`: capstone, jxr, ldap, tiff, png, jpeg, gsm, lcms2, musl, xml2, xslt, compiler-rt, faudio, tomcrypt and others) | as in Wine 11.0 | Mixed permissive (BSD-2-Clause, BSD-3-Clause, OpenLDAP, IJG, libpng, MIT and others) | Every notice is copied into `licenses/wine-bundled/<lib>/` by the build. |
| MoltenVK | 1.4.2 | Apache-2.0 | Also embeds SPIRV-Cross, SPIRV-Tools, cereal (BSD-3-Clause) and Vulkan-Headers, whose licences ship with it. |
| FreeType | pinned per release | FTL | FreeType's FTL option is used, not its GPL option. |
| GnuTLS, Nettle, GMP, libtasn1, libidn2, libunistring | pinned per release | LGPL-2.1-or-later, LGPL-3.0-or-later, or dual-licensed (Nettle and GMP: `GPL-2.0-or-later OR LGPL-3.0-or-later`) | Dynamically linked and replaceable. |
| GLib, GStreamer (core, base, a subset of good), gst-libav | pinned per release | LGPL-2.1-or-later | Built with GPL parts disabled. The "ugly" and "bad" plugin sets are not built. |
| libffi, PCRE2, ORC | pinned per release | MIT; BSD-3-Clause; BSD-2-Clause | GStreamer and GLib dependencies. |
| FFmpeg (decoders, demuxers and parsers only) | pinned per release | LGPL-2.1-or-later | Built with `--disable-gpl --disable-nonfree`. No encoders. |
| SDL2 | 2.32.x | Zlib | |
| zlib, libpng, brotli, bzip2 | pinned per release | Zlib; libpng-2.0; MIT; bzip2-1.0.6 | |
| wine-mono | 10.4.1 | MIT and others | Source published beside the runtime. |
| wine-gecko | 2.47.4 | MPL-2.0 and others | Source published beside the runtime, and users are told where to find it, as the MPL requires. |

The runtime's final SPDX identifiers come from its licence audit (`runtime/deps/inputs.json` and the generated `manifest.json`), never from hand-written lists like this one.

## 3. Graphics backends (separate downloads)

| Component | Version | Licence (SPDX) | Notes |
|---|---|---|---|
| [DXMT](https://github.com/3Shain/dxmt) | v0.80 | MIT (later versions: LGPL-2.1-or-later) | `winemetal.so` statically links LLVM 15 (`Apache-2.0 WITH LLVM-exception`, plus LLVM's legacy NCSA section). Also includes Microsoft DXBCParser (MIT), NVIDIA nvapi headers (MIT) and the mingw-w64 DirectX headers. All of these licence texts ship with the backend. |
| [DXVK-macOS](https://github.com/Gcenx/DXVK-macOS) | 1.10.3-20230507-repack | Zlib | Any statically included components are listed in the backend's `staticComponents`. |

## 4. Tools downloaded when first needed

| Component | Version | Licence (SPDX) | Notes |
|---|---|---|---|
| [winetricks](https://github.com/Winetricks/winetricks) | 20260125 | LGPL-2.1-or-later | Downloaded unmodified and checked against a pinned SHA-256. It is a script, so its source is the download itself. |
| cabextract | pinned per release | GPL-2.0-or-later | Before 1.0 you install it yourself (for example with Homebrew). From 1.0 we plan to ship it, with its source. |

## 5. Never distributed by Mallow

These are named here only so that nobody assumes otherwise.

| Item | Terms | How it reaches your Mac |
|---|---|---|
| D3DMetal (Apple Game Porting Toolkit) | Apple proprietary licence | You import it from your own copy of Apple's Game Porting Toolkit and accept Apple's licence yourself. Mallow never downloads, bundles, hosts or uploads it. |
| Steam client | Steam Subscriber Agreement | Downloaded from Valve's servers when you ask for it. |
| Microsoft redistributables and fonts | Each package's own terms | Downloaded from Microsoft or a named third-party mirror, only after Mallow shows you the terms and the real download host. |
| Anything from CodeWeavers' CrossOver app | Proprietary | Never used. Mallow refuses to import it. |

## 6. Required acknowledgements

These sentences are reproduced because the licences of components that Mallow plans to bundle ask for them.

- The Mallow Runtime will include libjpeg code. *This software is based in part on the work of the Independent JPEG Group.*
- Further notices (for example, the OpenLDAP notice) will be reproduced in full in the runtime's `licenses/` folder.

## 7. Licence texts

<!-- Generated section: scripts/gen-third-party-licenses.sh inserts the full licence text of every component in section 1 here, once per release. Do not edit by hand. -->

*No licence texts yet. Nothing has been released.*

---

Copyright (C) 2026 Mixutin and the Mallow contributors
