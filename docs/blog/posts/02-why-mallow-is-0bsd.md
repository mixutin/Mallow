---
# SPDX-License-Identifier: 0BSD
date: 2026-09-23
authors:
  - mixutin
categories:
  - Licensing
  - Contributing
slug: why-mallow-is-0bsd
description: Why Mallow's own code is 0BSD, how that sits next to an LGPL Wine runtime, the clean-room rules, and what it means for contributors.
---

# Why Mallow is 0BSD

Mallow's own code, scripts and docs use the BSD Zero Clause License, or 0BSD. It's about as close to public domain as a licence gets. You can use Mallow for anything, commercial use included, change it, and redistribute it, and you don't even have to keep our name on it.

This post explains why we chose it, how it sits next to a Wine runtime that's LGPL, and what it means if you'd like to contribute.

<!-- more -->

## Why 0BSD

The whole licence is one sentence of permission plus a warranty disclaimer. Compared with MIT or BSD-2-Clause, it drops the last remaining condition: you don't have to keep the copyright notice in copies.

Our reasons:

- **We want the ideas to travel.** If another launcher, a commercial app or a one-off script wants to reuse our sandbox profiles or bottle format once they exist, it should be able to. Every Mac that runs Windows software more safely is a win, whoever's name is on the app.
- **No licence maths.** Mallow's planned Swift dependencies (swift-argument-parser, and later Sparkle) are permissively licensed, and 0BSD adds no conditions of its own. Their notices will still ship with the app, as their licences require.
- **Docs and code mix freely.** The docs are 0BSD too, so a snippet can move from a guide into the code, or back, without a second thought.

Recipe data and JSON Schemas use CC0-1.0. It's also public-domain-equivalent, so other tools can adopt our formats, and recipes and code mix without friction.

## Living next to LGPL Wine

The Wine runtime Mallow will download is LGPL-2.1-or-later, and so are the small patches we write for it. That doesn't clash with 0BSD, because the app and the runtime are separate programs. The app starts Wine's binaries as separate processes and never links them. Under the standard FSF reading, that makes the two a "mere aggregate", so the runtime's LGPL doesn't reach the app.

We still take the LGPL's obligations seriously, and the plan makes them mechanical:

- Every GitHub Release that carries a runtime binary will also carry its complete source: the exact Wine source we built from, our patches and build scripts, plus every dependency's source and the scripts that build it.
- No runtime binary will ever be served from a host that doesn't serve the matching source beside it.
- A script will generate the licence notices inside the runtime, and CI will fail if any bundled library is missing one.
- The runtime will stay relinkable, so you can swap its LGPL libraries yourself.

Other components keep their own licences: DXVK-macOS (zlib), DXMT (MIT up to v0.80, LGPL after that) and MoltenVK (Apache-2.0). We'll ship their notices. D3DMetal is Apple's proprietary code, so we never bundle it; you import your own copy.

## The clean-room rules

A permissive licence only stays honest if everything under it can really be licensed that way. So we're strict about where code and knowledge come from.

**Nothing from CrossOver.app.** CodeWeavers publishes its Wine changes under the LGPL, and our runtime is built from that published source. The CrossOver app itself is proprietary. Nothing inside it beyond licence texts and version strings is an allowed input: not its launcher scripts, bottle templates, compatibility database, strings or artwork.

**No code copied from GPL projects.** Whisky, Heroic, Bottles, Mythic and other GPL frontends taught us a lot, and we'll credit them in `NOTICE`. But GPL code in our frontend would make the whole frontend GPL. So those projects are a source of ideas, behaviours and file formats only, and every line of Mallow's frontend is written fresh. Facts such as download URLs, hashes and registry keys are fine; transcribed logic is not.

**Every trick needs an open source.** Each environment variable, registry key or DLL rule we implement must cite a public source in a code comment, such as upstream Wine, the LGPL source release, or Apple's documentation. If the only evidence for something is a look inside CrossOver's proprietary files, we don't implement it.

We've already had to apply this to ourselves. Our first design draft cited three facts from a local CrossOver install, and it turned a Rosetta AVX setting on by default to match CrossOver's launcher. The second draft re-sourced those facts from open material and switched the default to off, which is what Apple's documentation says.

## What this means for contributors

- **You contribute under 0BSD.** Anyone may use your code for anything without crediting you. Please only contribute if you're happy with that.
- **Sign off your commits** with `git commit -s`. This adds a Developer Certificate of Origin line saying you have the right to submit the work under the project's licence.
- **Add the SPDX header** to new files: `// SPDX-License-Identifier: 0BSD` (with `#` in scripts). Wine patches use `LGPL-2.1-or-later` instead.
- **Say so if you've just read a GPL implementation** of what you're writing. That's fine; it just means a second maintainer reviews the pull request.
- **Permissive third-party code** (MIT, BSD, ISC, Apache-2.0, zlib, CC0) can come in under its own licence, with its headers kept and the reuse recorded in `NOTICE`.

The full rules are in the [contributing guide](https://github.com/mixutin/Mallow/blob/main/CONTRIBUTING.md) and section 2 of the [design document](https://github.com/mixutin/Mallow/blob/main/docs/DESIGN.md).

One last honest note: this is an engineering decision record, not legal advice. Parts of the plan, including the LGPL source procedure, are due for a lawyer's review before 1.0.
