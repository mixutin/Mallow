<!-- SPDX-License-Identifier: 0BSD -->

# Getting Help

> **Mallow is pre-alpha and in its design phase.** There is no app to download yet, and nothing is ready to run your games. Everything described in the docs is **planned**. If someone offers you a "Mallow" download today, it is not from this project.

## Where to ask

| You want to… | Go to |
|---|---|
| Ask a question, share an idea, or talk about the design | [GitHub Discussions](https://github.com/mixutin/Mallow/discussions) |
| Report a bug in Mallow | A [bug report](https://github.com/mixutin/Mallow/issues/new?template=bug_report.yml) (once there is code to have bugs) |
| Say how a game or app runs | A [compatibility report](https://github.com/mixutin/Mallow/issues/new?template=compatibility_report.yml) |
| Suggest a feature | A [feature request](https://github.com/mixutin/Mallow/issues/new?template=feature_request.yml), or a Discussion if it's still a rough idea |
| Report a security vulnerability | **Privately**, as described in [SECURITY.md](https://github.com/mixutin/Mallow/blob/main/SECURITY.md). Never in public |
| Report a Code of Conduct problem | Privately, as described in the [Code of Conduct](https://github.com/mixutin/Mallow/blob/main/CODE_OF_CONDUCT.md) |
| Contribute | [CONTRIBUTING.md](https://github.com/mixutin/Mallow/blob/main/CONTRIBUTING.md) |
| Read the docs | [mixutin.github.io/Mallow](https://mixutin.github.io/Mallow/) |

Please ask questions in Discussions rather than in issues. Issues are for work that needs doing, and answers in Discussions are easier for the next person to find.

## What to include

A good question gets a good answer faster. Once Mallow exists, please include:

- **Your Mac:** the model and chip (for example "MacBook Air, M2, 16 GB"), from Apple menu → About This Mac.
- **Your macOS version:** also in About This Mac, or run `sw_vers` in Terminal.
- **Your Mallow version**, and whether it's an official release or a build from source (with the commit).
- **The runtime and graphics backend** the bottle uses (for example `mallow-runtime-11.0-r1` and DXMT).
- **The bottle's trust mode:** Standard, Offline or Untrusted.
- **The Windows program:** its name, version, and where it came from (Steam, GOG, an installer…).
- **What you did, what you expected, and what happened instead.**
- **Logs.** Every launch is planned to write a log to `~/Library/Logs/Mallow/Bottles/<bottle>/`. Its first lines (the header) will show the versions and settings Mallow used. `mallow doctor` will check your setup, and `mallow diagnostics --bottle <name>` will build a bundle that leaves out your imported D3DMetal copy and your bottle's `C:` drive, and replaces your home folder path with `~`.

**Before you post anything, check it for personal information.** Never share passwords, product keys, game files or D3DMetal files.

## What we can't help with

- **CrossOver, Whisky or other Wine frontends.** Please ask their own communities. CrossOver users can contact CodeWeavers' support.
- **Mallow problems at WineHQ or CodeWeavers.** Mallow's runtime is a modified Wine build, so please report its problems to us, not to WineHQ or CodeWeavers.
- **Anti-cheat.** Games with kernel-level anti-cheat, and most games with user-mode anti-cheat, can't run under Wine on macOS. We don't work around anti-cheat.
- **Pirated software.** We only help with software you own a legitimate copy of.
- **Apple's Game Porting Toolkit itself.** Mallow will import your copy of D3DMetal, but it can't change or redistribute it.

## Response times

Mallow is run by volunteers, and there is no paid support. We aim to reply within about a week, and often sooner. Other community members are warmly encouraged to help each other.
