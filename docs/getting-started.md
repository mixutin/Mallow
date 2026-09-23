---
# SPDX-License-Identifier: 0BSD
description: There is nothing to install yet. What you can do today, what the first Mallow releases are planned to look like, and what you will need.
---

# Getting started

!!! warning "There is nothing to install yet"

    Mallow is **pre-alpha** and in the **design phase**. No application code exists yet, so there is no app, no command-line tool and no runtime to download. Anything that claims to be a Mallow download today is not from this project.

This page covers what you can do today, and what installing and using Mallow is **planned** to look like once the first builds exist.

## What you can do today

- **Learn how it will work.** [How it works](how-it-works.md) explains Wine, Rosetta 2, the graphics backends, bottles and the sandbox in plain English.
- **Follow progress.** Read the [devlog](blog/index.md), or subscribe to its [RSS feed](https://mixutin.github.io/Mallow/feed_rss_created.xml). On GitHub, choose **Watch → Custom → Releases** on the [repository](https://github.com/mixutin/Mallow) to hear about the first build.
- **Read the plan.** The [roadmap](roadmap.md) lists the milestones in order. The [design document](DESIGN.md) and the [security model](SECURITY_MODEL.md) explain every decision.
- **Help shape it.** Questions, corrections and design reviews are the most useful contributions right now. See [Contributing](contributing/index.md).

## What you will need (planned)

| Requirement | Details |
|---|---|
| **A Mac with Apple Silicon** | M1 or later. Intel Macs are not supported. |
| **macOS 15 Sequoia or later** | Some features need newer versions. For example, DLSS-to-MetalFX upscaling with D3DMetal needs macOS 26. |
| **Rosetta 2** | Mallow will offer to install it. Installing Rosetta means accepting Apple's licence, so Mallow asks you first and never accepts for you. |
| **Free disk space** | Mallow checks before it acts. Creating a bottle is planned to need at least 500 MB free, and the one-click Steam setup at least 2 GB. Games need their own space on top. |
| **Your own games and apps** | Mallow runs Windows software you already have. It doesn't provide games. |

You won't need Xcode or a copy of Windows.

## The first releases (planned)

The [roadmap](roadmap.md) has the full list. In short:

| Milestone | Who it's for | What it is planned to include |
|---|---|---|
| **v0.1 "Foundations"** | Developers | The `mallow` command-line tool, bottles, and an interim "Standard Wine" runtime. No app yet. |
| **v0.2 "Own runtime"** | Developers | The Mallow Runtime, built in public CI and signed, with DXMT and per-program graphics backends. |
| **v0.3 "Mac app"** | Everyone | The first Mac app. A download on GitHub Releases and a Homebrew tap. |
| **v0.4 "Steam and dependencies"** | Everyone | One-click Steam, and installers for common Windows components. |
| **v0.5 "D3DMetal and upscalers"** | Everyone | Importing D3DMetal from your own copy of Apple's Game Porting Toolkit. |

## What installing is planned to look like

Once v0.3 ships, the plan is:

1. **Download** the app from [GitHub Releases](https://github.com/mixutin/Mallow/releases), or install it with Homebrew from the project's tap.
2. **Open it.** Early builds are not notarised by Apple, so macOS will stop the first launch. You allow it in **System Settings → Privacy & Security → Open Anyway**. Notarised builds with automatic updates are planned for v0.8.
3. **Onboarding.** Mallow walks you through three steps:
    1. **Rosetta 2.** If it's missing, Mallow shows Apple's licence and installs Rosetta only after you choose **Agree and Install**.
    2. **Runtime.** Mallow downloads the Wine runtime and checks it against a pinned hash or a signed catalog before installing it.
    3. **Your first bottle.** Give it a name and pick a template (for example "gaming" or "steam").
4. **Run something.** Drag a Windows installer or `.exe` onto the Mallow window, or use **Run…** in the toolbar.

## A preview of the command-line tool

The `mallow` CLI is planned to do everything the app does. Here is roughly how the v0.1 milestone test is expected to look. Commands and output may change before release.

```sh
mallow runtime install standard-wine-stable-11.0_1
mallow bottle create Test
mallow run --bottle Test --wait notepad
```

And a few more planned commands:

```sh
mallow doctor                                   # check Rosetta, runtimes and bottles
mallow bottle set Games graphics.backend=dxmt   # choose a graphics backend
mallow run --bottle Games --dry-run Setup.exe   # print the launch plan, run nothing
mallow install steam --bottle Steam --yes       # one-click Steam (v0.4)
mallow diagnostics --bottle Games               # a support bundle, without D3DMetal files
```

The full planned command tree is in [DESIGN.md §3.8](DESIGN.md#38-the-mallow-cli).

## What Mallow won't do

To avoid disappointment later:

- **Anti-cheat.** Games that need kernel-level anti-cheat, and most games with user-mode anti-cheat, won't work. Mallow will never try to get around anti-cheat.
- **Bundled D3DMetal.** Mallow never ships Apple's D3DMetal. You import it from your own copy of Apple's Game Porting Toolkit (planned for v0.5).
- **Intel Macs.** Not supported.
- **Mac App Store.** Mallow won't be distributed there, because the App Store's sandbox doesn't allow an app to start Wine.

The [FAQ](faq.md) has more questions and honest answers.
