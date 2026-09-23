---
# SPDX-License-Identifier: 0BSD
description: Honest answers about Mallow. Is it free? Is it CrossOver? Does it run anti-cheat games? Is it safe? Why 0BSD? Why not Whisky? Intel Macs? D3DMetal?
---

# FAQ

!!! info "Mallow is pre-alpha"

    Mallow is in the design phase and no code exists yet. The answers below describe what is **planned**. If something here disagrees with the [design document](DESIGN.md) or the [security model](SECURITY_MODEL.md), those documents win, and this page gets fixed.

## The basics

### Can I use Mallow today?

No. There is nothing to download yet. See [Getting started](getting-started.md) for what the first releases are planned to look like, and follow the [devlog](blog/index.md) for progress.

### Is Mallow free?

Yes, in both senses.

- **Free of charge.** There is no paid edition and no subscription.
- **Free to reuse.** Mallow's own code, scripts and docs are released under [0BSD](legal.md). You can use them for anything, commercial use included, change them and redistribute them. You don't even have to credit us.

The Wine runtime that Mallow downloads is licensed LGPL-2.1-or-later, and its complete source is published with every runtime release. The games and apps you run are yours, under their own licences.

### Is Mallow CrossOver? Is it made by CodeWeavers?

No. Mallow is an independent open-source project. It is **not affiliated with or endorsed by CodeWeavers**. "CrossOver" is a trademark of CodeWeavers, and we use the name only to describe what Mallow is an alternative to.

Both projects are built on Wine. CodeWeavers funds much of Wine's macOS work and publishes the LGPL source of its Wine. The Mallow Runtime is built from those published sources, under the LGPL. We never use anything from inside CodeWeavers' commercial app, and we never send our users to CodeWeavers for support.

If you want a polished, supported product today, CrossOver is it, and buying it helps fund Wine development that everyone benefits from.

### Is Mallow an emulator? Do I need a copy of Windows?

Mallow is not an emulator, and you don't need Windows. Wine reimplements the Windows programming interfaces on top of macOS, so Windows programs run as normal Mac processes. Rosetta 2 translates their Intel code for Apple Silicon. [How it works](how-it-works.md) explains the details.

A few Microsoft add-ons have licence terms of their own. For example, the .NET Framework's terms allow its use only by people who have a Windows licence. Mallow shows you the terms before it installs anything like that, and it doesn't offer those add-ons as one-click installs.

### How fast will games run?

It depends on the game, the graphics backend and your Mac, and we won't guess before there is something to measure. Version 1.0 is planned to ship with at least 30 titles documented with the backend used and the result.

## Compatibility

### Does it run games with anti-cheat?

Mostly no. Games that need **kernel-level** anti-cheat, and most games with **user-mode** anti-cheat, cannot work under Wine on macOS. Mallow will never try to bypass or trick anti-cheat. Recipes are planned to mark such games with an "anti-cheat: unsupported" badge, so you know before you try.

### Will it run Steam?

That is the plan. A one-click Steam setup is planned for v0.4, along with per-game graphics backends for games that Steam starts. Epic and GOG support through open tools (legendary and gogdl) is planned for after 1.0.

### Does it work on Intel Macs?

No. Mallow targets **Apple Silicon Macs with macOS 15 or later**. It might be possible to make it work on Intel Macs, but we don't support or test that.

### What happens when Apple removes Rosetta?

Apple has said that macOS 27 is the last release with full Rosetta, and that macOS 28 keeps a subset for games. How much that covers isn't clear yet. Mallow depends on Rosetta 2, so we follow Apple's announcements closely. A native Apple Silicon Wine is a research topic for after version 1.0.

## Security

### Is it safe to run Windows programs with Mallow?

Safer than with plain Wine, but no tool can promise complete safety.

**Plain Wine is not a sandbox.** A Windows program under Wine can read your files, see your whole disk through drive `Z:`, and even skip Wine and talk to macOS directly. So Windows malware *can* harm a Mac.

**Mallow is designed to contain programs.**

- Every Windows program is planned to run inside a **macOS kernel sandbox** that Mallow generates for each bottle.
- By default, a program can reach only its own bottle, the read-only runtime, the system files it needs, and folders you choose to share.
- New bottles have no `Z:` drive and no links into your home folder.
- An **Untrusted** mode runs a program with no network and no shared folders, in a disposable copy of a bottle that is deleted when it quits.

**But be realistic.** Mallow is not an antivirus. Bugs in macOS, Rosetta or GPU drivers can in principle break any sandbox. Anything inside a bottle, such as a saved Steam login, is exposed to every program in that bottle. Every release is planned to be checked by a red-team test suite, and an external security review is planned before 1.0. The [security model](SECURITY_MODEL.md) has the full details and limitations.

### Are Mallow's downloads safe?

Runtimes and graphics backends are planned to be built in public CI, listed in a signed catalog, and checked against signatures and SHA-256 hashes before installation. A mismatch is a hard failure, with no "install anyway" button. For downloads from other vendors, such as Steam or Microsoft's Visual C++ runtime, Mallow shows you the real download host and the licence terms first.

### How do I report a security problem?

Privately, please. Follow [SECURITY.md](https://github.com/mixutin/Mallow/blob/main/SECURITY.md), and never post vulnerabilities in a public issue.

### Does Mallow collect telemetry?

No telemetry is planned. The current proposal is no telemetry at all. The only alternative under discussion is strictly opt-in. See open question Q9 in the [design document](DESIGN.md#10-open-questions-decisions-needed).

## Licensing and D3DMetal

### Why 0BSD?

The project owner chose 0BSD because it is as close to public domain as a software licence gets:

- **The ideas can travel.** Other launchers, commercial apps and scripts can reuse our code (sandbox profiles, bottle handling, recipes) without legal friction.
- **No paperwork.** You don't have to carry our copyright notice around. That matters for small snippets and for docs.
- **It mixes freely.** Recipe data and schemas are CC0-1.0, also public-domain-like, so data and code can move between them.

The trade-off is that someone could build a closed product on Mallow's frontend. We accept that. The Wine runtime stays LGPL, so improvements to Wine itself remain open. The devlog post ["Why Mallow is 0BSD"](blog/posts/02-why-mallow-is-0bsd.md) has the longer story, and [Legal & licensing](legal.md) has the summary.

### Why not just use Whisky?

Whisky was a much-loved open-source Wine frontend for macOS, and it showed how good a Mac-native experience can be. Its maintainer archived it in 2025. Community forks carry it on, and if one of them works well for you, use it.

Mallow is a fresh design, not a fork, and it makes different choices:

- **Security first**: a kernel sandbox around every Windows program, secure bottle defaults and an Untrusted mode.
- **Its own runtime**, built in public CI from published LGPL sources, with small patches that give each game its own graphics backend even when Steam starts it.
- **CLI first**: everything is scriptable, with JSON output.
- **0BSD** instead of the GPL.

Because Whisky is GPL-licensed, we never copy its code into Mallow's 0BSD frontend. We learn from its ideas and behaviour, which copyright doesn't restrict, and we credit it and other projects in our [NOTICE](https://github.com/mixutin/Mallow/blob/main/NOTICE) file.

### Will you ship D3DMetal?

No, never. D3DMetal is part of Apple's Game Porting Toolkit, and Apple's licence doesn't allow us to redistribute it. Instead, Mallow plans to let you **import it from your own copy** of Apple's toolkit (planned for v0.5):

1. You download Apple's "Evaluation environment for Windows games" disk image with your own Apple ID.
2. Mallow shows you Apple's licence, from your own copy, and asks for an explicit "I accept".
3. Mallow copies the files unchanged. They stay on your Mac. They are never uploaded, and never included in diagnostics bundles.

Apple's licence describes the toolkit as being for developing, testing and evaluating games. Read it, and decide for yourself whether your use fits. See [Legal & licensing](legal.md#d3dmetal-apple-game-porting-toolkit).

### Why is it called Mallow?

The design started under the working name "Decanter", but another active project with the same purpose already used that name. "Mallow" is provisional until a formal trademark search is complete. The devlog post ["The name: from Decanter to Mallow"](blog/posts/04-from-decanter-to-mallow.md) tells the story.

## Getting involved

### How can I help?

Right now, the most useful things are reading the design and asking hard questions. You can also check an assumption on your own Mac, improve the docs, or help plan the runtime build and the sandbox tests. Start with [Contributing](contributing/index.md) and the [architecture tour](contributing/architecture-tour.md). Every commit needs a DCO sign-off (`git commit -s`).

### Where do I ask questions?

Open a thread in [GitHub Discussions](https://github.com/mixutin/Mallow/discussions), or an [issue](https://github.com/mixutin/Mallow/issues) for something specific.
