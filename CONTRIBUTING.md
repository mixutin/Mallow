<!-- SPDX-License-Identifier: 0BSD -->

# Contributing to Mallow

Thanks for your interest in Mallow!

Mallow is an open-source way to run Windows games and apps on Apple Silicon Macs. It uses Wine, Rosetta 2 and DirectX-to-Metal translation, and it is an open-source alternative to CrossOver. Everyone is welcome here: Swift developers, Wine and build-system people, writers, testers, security researchers, and people who have never contributed to an open-source project before.

> **Status: pre-alpha, design phase.** No application code exists yet. The repository holds the design ([DESIGN.md](https://github.com/mixutin/Mallow/blob/main/docs/DESIGN.md)), the security model ([SECURITY_MODEL.md](https://github.com/mixutin/Mallow/blob/main/docs/SECURITY_MODEL.md)) and the project's community files. Every feature mentioned in this guide is **planned** or **in design**, not working. This is a great time to shape the project.

## Contents

- [The short version](#the-short-version)
- [Where help is needed now](#where-help-is-needed-now)
- [Ways to contribute without writing code](#ways-to-contribute-without-writing-code)
- [Development setup](#development-setup)
- [Repository layout](#repository-layout)
- [Workflow](#workflow)
- [Coding standards](#coding-standards)
- [Clean-room and licensing rules](#clean-room-and-licensing-rules)
- [Security-sensitive changes](#security-sensitive-changes)
- [Changing the design](#changing-the-design)
- [Documentation and the devlog](#documentation-and-the-devlog)
- [Compatibility reports](#compatibility-reports)
- [Review process](#review-process)
- [Recognition](#recognition)
- [Getting help](#getting-help)

## The short version

1. Be kind. Everyone here follows the [Code of Conduct](https://github.com/mixutin/Mallow/blob/main/CODE_OF_CONDUCT.md).
2. For anything bigger than a small fix, open an issue or a [Discussion](https://github.com/mixutin/Mallow/discussions) first.
3. Sign off every commit with `git commit -s` ([why](#sign-off-your-commits-dco)).
4. Your contribution is licensed under **0BSD**, like the rest of Mallow's own code and docs. The exceptions are Wine patches (LGPL-2.1-or-later) and recipes and schemas (CC0-1.0).
5. Never copy code from GPL projects (Whisky, Heroic, Bottles, Mythic and others) into Mallow, and never use anything from inside CrossOver.app. Ideas are fine; code is not.
6. Changes to the sandbox, downloads, signatures or the release pipeline need **two reviews**.
7. Report security vulnerabilities privately, as described in [SECURITY.md](https://github.com/mixutin/Mallow/blob/main/SECURITY.md). Never report them in a public issue.

## Where help is needed now

The project is at **Gate G0 ("Before any code")**. Next comes v0.1 "Foundations", with the "Own runtime" work (v0.2) running in parallel. See the roadmap in [DESIGN.md §8](https://github.com/mixutin/Mallow/blob/main/docs/DESIGN.md).

| Area | What would help right now | Useful background |
|---|---|---|
| **Design review** | Read DESIGN.md and SECURITY_MODEL.md, then challenge them. Look hard at claims tagged **[L]** (unverified), the verification backlog (§11) and the open questions (§10). Tell us where the design is wrong, unclear or over-built. | Wine on macOS, Swift, macOS internals, software licensing |
| **Runtime CI** | The pipeline that builds the Wine runtime in public GitHub Actions from CodeWeavers' published LGPL Wine sources: building dependencies from pinned source, our three small Wine patches, the licence audits, the LGPL source packages and the smoke tests (DESIGN.md §3.11). | Wine builds, autotools and meson, mingw-w64, GitHub Actions macOS runners |
| **MallowKit modules** | Once the wire formats and model types land (step "WF0" of v0.1), the library is split into modules that people can pick up in parallel. Watch for tracking issues labelled `area:mallowkit` and `help wanted`. | Swift 6 concurrency, POSIX APIs, file formats (PE, Mach-O, `.lnk`) |
| **Docs** | Explain bottles, runtimes and graphics backends in plain English. Proofread the design for clarity. Help shape the docs site at [mixutin.github.io/Mallow](https://mixutin.github.io/Mallow/). | Technical writing |
| **Compatibility testing** | There is nothing to test yet. You can still help: pick an item from the verification backlog (DESIGN.md §11) that your Mac can check, and report the result. Later, send compatibility reports for your games. | A Mac with Apple Silicon, games you own |
| **Security red-team** | Review the Seatbelt sandbox profile sketch. Experiment with `sandbox-exec` and Wine on your own machine. Help answer the open questions in SECURITY_MODEL.md §7, and design the harmless probe programs from SECURITY_MODEL.md §4. | macOS sandboxing, Mach services, threat modelling |

Legal know-how is also very welcome. Several items need expert eyes before v1.0: the name clearance, the Apple Game Porting Toolkit licence, the LGPL source procedure and codec patents (DESIGN.md §2 and §10).

## Ways to contribute without writing code

- **Review the design.** Comment on anything that seems wrong, risky or confusing. A good question is a real contribution.
- **Verify an assumption.** Many design decisions rest on facts that still need a test on real hardware. Test one and post what you found, including your macOS version and Mac model.
- **Improve the docs.** Fix typos, rewrite unclear paragraphs, add diagrams, or write a devlog post.
- **Triage.** Reproduce bug reports, ask for missing details and spot duplicates.
- **Answer questions** in [Discussions](https://github.com/mixutin/Mallow/discussions).
- **Test games and apps** once there is something to test, and send [compatibility reports](#compatibility-reports).
- **Red-team the sandbox** (responsibly; see [SECURITY.md](https://github.com/mixutin/Mallow/blob/main/SECURITY.md)).
- **Translate.** Localisation support is planned for v0.6.
- **Tell people about Mallow, honestly.** Please don't describe planned features as if they already work.

## Development setup

### What you need

| Requirement | Notes |
|---|---|
| A Mac with Apple Silicon | M1 or later. Intel Macs are not supported. |
| macOS 15 (Sequoia) or later | The Swift package targets macOS 15. The design was written on macOS 26. |
| Swift 6.3 or later, from the **Command Line Tools** | Install with `xcode-select --install`, then check with `swift --version`. **Xcode is not needed.** If you already have Xcode, that works too. |
| Git and a GitHub account | For forking and pull requests. |
| Rosetta 2 | Only needed to run real Wine, not for building or testing. Install it with `softwareupdate --install-rosetta`. This asks you to accept Apple's licence. |
| Disk space | About 250 MB for one debug, release and test build of the Swift package. You need more if you run real Wine: creating a bottle requires at least 500 MB free, and the Steam recipe at least 2 GB. |
| Optional tools | `shellcheck` for the script linter, and Python 3 for the schema and recipe checks and the docs site. |

You never need to build the Wine runtime on your own Mac. It is built in public GitHub Actions. If you work on the runtime pipeline, run the workflows in your fork.

### Building and testing

> **These commands start working once the Swift package lands (planned for v0.1).** Until then, the repository holds only documents and the docs site.

```sh
# Fork on GitHub first, then:
git clone https://github.com/<your-username>/Mallow.git
cd Mallow

swift build                  # debug build of MallowKit, the mallow CLI, the app and fake-wine
scripts/test.sh              # the full test suite (works with Command Line Tools only)
scripts/test.sh --filter WineEnvironmentTests   # one suite; arguments go to `swift test`
scripts/lint.sh              # swift format, shellcheck and the layering rule
scripts/build-app.sh         # assemble and ad-hoc sign dist/Mallow.app
scripts/install-cli.sh       # symlink the mallow CLI into ~/.local/bin
scripts/dev-clean.sh         # delete build products to free disk space
```

Some notes:

- **Use `scripts/test.sh`, not plain `swift test`,** if you only have the Command Line Tools. The script adds the flags that swift-testing needs there, and builds `fake-wine` and `mallow` for the tests. With Xcode installed, plain `swift test` works too.
- **Keep your real data safe.** When you try the CLI by hand, point it at a throwaway data folder: `.build/debug/mallow --home "$TMPDIR/mallow-dev" doctor`. The `MALLOW_HOME` environment variable does the same.
- **Tests against a real Wine runtime are opt-in.** Run them with `MALLOW_REAL_RUNTIME=/path/to/runtime scripts/test.sh`. CI runs them on every runtime release. You don't need to run them locally.
- **Short on disk?** Run `scripts/dev-clean.sh` often. The tests use a fake runtime, so you never need a real one for day-to-day work.

## Repository layout

This is a summary of the authoritative layout in [DESIGN.md §3.2](https://github.com/mixutin/Mallow/blob/main/docs/DESIGN.md). Most of these folders don't exist yet.

```
.github/            CI workflows, issue forms, CODEOWNERS
Package.swift       the Swift package (SwiftPM only; no Xcode project)
Sources/
  MallowKit/        the library that does all the work, in layered folders (below)
  MallowCLI/        the `mallow` command-line tool
  MallowApp/        the SwiftUI app, a frontend over MallowKit
  FakeWine/         `fake-wine`, a test double for Wine's `wine` and `wineserver`
Tests/              swift-testing suites, wire-format fixtures and golden files
Resources/          Info.plist, entitlements and the icon, used to assemble the .app
catalog/            the component catalog; CI signs and publishes it
recipes/            declarative install recipes (CC0-1.0)
schemas/            JSON Schemas for every file format (CC0-1.0)
runtime/            the Wine runtime build pipeline and our Wine patches (patches are LGPL)
scripts/            build, test, lint and bundling scripts
docs/               design documents and the docs site
```

**MallowKit layering.** MallowKit is one SwiftPM target. Its folders form layers, and each folder may use only the folders to its left:

```
Support → Bottles → Runtime → Wine → Programs → Graphics → Launch → Operations → Recipes → Diagnostics → Composition
```

`scripts/lint.sh` will enforce this. The design is CLI first: every feature lands in MallowKit and the `mallow` CLI before it gets any UI.

**New files need a design change first.** DESIGN.md §3.2 lists every file. If your change needs a file that isn't listed, include the DESIGN.md update in the same pull request, or open a design discussion first.

## Workflow

### Talk first (for anything non-trivial)

Small fixes, such as typos, clear bugs or missing tests, can go straight to a pull request. For anything bigger, open an issue or a [Discussion](https://github.com/mixutin/Mallow/discussions) first so nobody wastes effort. For changes to the design, see [Changing the design](#changing-the-design).

If an issue is labelled `help wanted` or `good first issue`, comment on it to say you're working on it.

### Fork and branch

Fork the repository and add this repository as the `upstream` remote, so you can stay up to date:

```sh
git remote add upstream https://github.com/mixutin/Mallow.git
git fetch upstream
```

Then create a branch from `upstream/main`. Name it `<type>/<short-topic>` and use the same types as commit messages (below):

```
feat/bottle-store-locking
fix/launch-env-dyld-leak
docs/explain-graphics-backends
ci/runtime-deps-cache
design/telemetry-decision
```

For example: `git switch -c docs/explain-graphics-backends upstream/main`.

### Keep pull requests small

One logical change per pull request. Small PRs get reviewed faster and more carefully. As a rough guide, aim for under about 400 changed lines, not counting generated files. If a change is big, split it into a series and say so in the first PR.

Put regenerated files (golden files, `BuiltinRecipes.generated.swift`, `THIRD_PARTY_LICENSES.md`) in their own commit, so reviewers can tell them apart from hand-written changes.

### Write good commit messages

We use a loose form of [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <summary in the imperative, 72 characters at most>

<Body: what changed and why, wrapped at 72 characters.
Mention issues with "Fixes #123" or "Refs #123".>

Signed-off-by: Your Name <you@example.com>
```

- **Types:** `feat`, `fix`, `docs`, `design`, `test`, `refactor`, `perf`, `build`, `ci`, `chore`, `security`, `revert`.
- **Scopes:** an area (`mallowkit`, `cli`, `app`, `runtime`, `graphics`, `sandbox`, `recipes`, `docs`, `ci`) or a MallowKit folder (`bottles`, `launch`, `wine` and so on). The scope is optional.
- Examples:
  - `feat(bottles): write bottle.json atomically under flock`
  - `fix(launch): keep DYLD_* variables out of the child environment`
  - `docs(design): record the telemetry decision (Q9)`
  - `ci(runtime): pin the mingw-w64 build tool`

Nobody will reject a good change over a commit-message detail. The body, which explains *why*, matters more than the prefix.

### Sign off your commits (DCO)

Every commit must carry a `Signed-off-by:` line. Git adds it for you when you commit with `-s`:

```sh
git commit -s -m "fix(launch): keep DYLD_* variables out of the child environment"
```

**What it means.** By signing off, you agree to the [Developer Certificate of Origin](https://developercertificate.org/) (DCO), a short statement used by the Linux kernel and many other projects. In plain English, you certify that you wrote the change, or otherwise have the right to submit it, under the licence of the files it touches. For most of Mallow that licence is 0BSD (see [Clean-room and licensing rules](#clean-room-and-licensing-rules)).

**Why DCO and not a CLA.** There is no paperwork and nothing to sign in advance. You keep your copyright. Your contribution comes in under the same licence that everyone else gets ("inbound = outbound").

**Details:**

- Use a name you are known by. It doesn't have to be your legal name, but it can't be anonymous. Use an email address that works; your GitHub `noreply` address is fine.
- Forgot to sign off? For the last commit, run `git commit --amend --no-edit -s`. For every commit on your branch, run `git rebase --signoff upstream/main`. Then run `git push --force-with-lease`.
- A CI check (planned) verifies that every commit is signed off.
- Tip: `git config --global alias.cs "commit -s"` gives you a `git cs` shortcut.

### Open the pull request

- Fill in the pull request template. The **Security impact** section is required.
- Draft pull requests are welcome if you want early feedback.
- CI must pass. Once CI exists, it will run the linter, tests (in both Command Line Tools and Xcode modes), schema checks, recipe checks, generated-file checks, the DCO check and an app-bundle check (DESIGN.md §7.5).
- During review, prefer adding new commits over force-pushing, so reviewers can see what changed. Force-pushing to fix sign-offs is fine.

## Coding standards

These standards apply once code lands. Most of them come straight from the design (DESIGN.md §1.3, §3.5 and §7).

### Swift

- **Swift 6 language mode with strict concurrency checking,** in every target. Don't silence the checker with `@unchecked Sendable` or `nonisolated(unsafe)` unless a comment explains why the code is safe, and a reviewer agrees.
- **Never enable `NonisolatedNonsendingByDefault` (SE-0461).** It would move heavy MallowKit work onto the caller's actor, which is often the main thread. The linter will reject it.
- **Heavy work stays off the main thread.** Every public MallowKit API whose cost grows with its input (hashing, extracting, walking trees, parsing large files, spawning processes) is `@concurrent` or an actor method. Mark the heavy section with `ThreadProbe.mark(#function)`, and add the API to `ConcurrencyIsolationTests`.
- **Stateful services are actors. Model types are `Sendable` value types.**
- **One writer per piece of state.** Follow the ownership table in DESIGN.md §3.5. For example, only `BottleStore` writes `bottle.json`, and every Wine process for a bottle is spawned through `LaunchService`.
- **Planning is pure; effects go through protocols.** Anything that runs a process, touches the network or checks a code signature goes through `ProcessSpawner`, `HTTPClient` or `CodeSignatureChecker`, so tests can replace it.
- **Registry files are never edited directly.** Registry writes go through a Wine process (`regedit /S`).
- **Every write is atomic.** Write a temporary file, `fsync` it, then `rename` it, while holding the advisory lock.
- **`MallowError` is the only error type** that crosses the public API. Each case maps to a CLI exit code (DESIGN.md §3.8.3).
- **Product-visible names come from `ProductIdentity`.** Never hard-code the app name, bundle identifier or data folder paths.
- **Command Line Tools constraints.** No `#Preview`, no `@Entry` (write a manual `EnvironmentKey`), no SwiftPM `resources:` and no asset catalogs.
- **Formatting.** Run `swift format` with the repository's `.swift-format` configuration. `scripts/lint.sh` must pass.
- **The design's normative sections win.** DESIGN.md §3.4 (the Swift API) and §3.7 (file formats) are normative. If your code needs to differ from them, change the design first.

### Shell and Python scripts

- Shell scripts start with `#!/bin/bash`, the SPDX header and `set -euo pipefail`.
- They must work with the `/bin/bash` 3.2 that ships with macOS. Under `set -u`, expand arrays as `${A[@]+"${A[@]}"}`, and give every variable a default.
- Call system tools by absolute path when a look-alike could shadow them on `PATH` (for example `/usr/bin/codesign`).
- Scripts must pass `shellcheck`.
- Scripts don't use `sudo`. They download only pinned inputs (a URL plus a SHA-256 hash) and never pipe a download into a shell.

### Licence headers (SPDX)

Every file starts with an SPDX licence identifier:

| Files | Header (at the top, after any shebang or `swift-tools-version` line) |
|---|---|
| Swift sources and `Package.swift` | `// SPDX-License-Identifier: 0BSD` |
| Shell and Python scripts, YAML | `# SPDX-License-Identifier: 0BSD` |
| Markdown in the repository root | `<!-- SPDX-License-Identifier: 0BSD -->` |
| Docs-site pages and devlog posts (`docs/`) | `# SPDX-License-Identifier: 0BSD` as the first line of the YAML front matter, so the page's `#` heading stays first and becomes its title |
| Wine patches in `runtime/patches/` | `SPDX-License-Identifier: LGPL-2.1-or-later` |
| JSON in `recipes/` and `schemas/` | JSON has no comments. `recipes/LICENSE` and `schemas/LICENSE` (CC0-1.0) cover these files. |

### The provenance rule

**Every environment variable, registry key or DLL rule that Mallow sets must cite an open source in a code comment.** The source can be upstream Wine code, a vendor's public documentation, a file in CodeWeavers' LGPL source release, or our own test. For example:

```swift
// ROSETTA_ADVERTISE_AVX: documented in Apple's Game Porting Toolkit 3.0 Read Me,
// "Defaults to 0 (OFF)". Off by default; recipes opt in per title. [R17]

// CX_APPLEGPTK_LIBD3DSHARED_PATH: read with getenv() in dlls/ntdll/unix/loader.c
// of CodeWeavers' LGPL source release 26.3.0. [R32]
```

If the only source for a setting is something observed in CrossOver's proprietary files, we don't implement it. The same rule applies to default values.

### Tests

- **swift-testing only:** `import Testing`, `@Test` and `#expect`. XCTest is not available with the Command Line Tools.
- **No real Wine in unit tests.** Use `fake-wine`, a small Swift program that stands in for `wine` and `wineserver`. It records every call (arguments, environment, working directory) as a JSON line, and it simulates things like `wineboot --init` and the wineserver lock. It is a real binary, not a shell script: macOS strips `DYLD_*` variables from anything that runs through `/bin/sh`, so a script fake would give misleading results.
- **Golden tests.** The launch planner's output is compared with JSON files in `Tests/MallowKitTests/Golden/`. If you change behaviour on purpose, regenerate them with `MALLOW_UPDATE_GOLDENS=1 scripts/test.sh`, read every changed line, and explain the change in your pull request.
- **Wire-format fixtures.** Every persisted type has a fixture in `Tests/MallowKitTests/Fixtures/wire/`. A format change updates its fixture and, where needed, adds a migration.
- **No network in unit tests.** Use `StubHTTPClient`. The test suite must pass offline.
- **Hermetic tests.** Use temporary directories and `--home` or `MALLOW_HOME`. Never touch the real `~/Library/Application Support/Mallow`. Inject clocks, UUIDs and host facts instead of reading them.
- **Synthetic inputs only.** Build PE files, `.lnk` files and Mach-O files in code with the `Synthetic*` helpers. Never commit binaries taken from third-party software.
- **Bug fixes come with a test** that fails without the fix.
- **Security code needs negative tests.** Prove that what must be refused is refused.

## Clean-room and licensing rules

These rules keep Mallow's code free for everyone to use. They are adapted from DESIGN.md §2.7, which remains the authoritative version. **If you are unsure whether something is allowed, ask before you write the code.**

### Which licence your contribution uses

| Where you contribute | Licence | Notes |
|---|---|---|
| MallowKit, the CLI, the app, `fake-wine`, tests, scripts (including `runtime/**/*.sh` and `*.py`), docs | **0BSD** | Anyone may use, modify and redistribute it for any purpose, commercial included, with no attribution required. |
| Wine patches in `runtime/patches/` | **LGPL-2.1-or-later** | They are derivatives of Wine. |
| Recipes (`recipes/`) and JSON Schemas (`schemas/`) | **CC0-1.0** | So other tools can reuse the data and formats freely. |

Mallow is also made of parts other people wrote. The Wine runtime that Mallow downloads is LGPL-2.1-or-later, and its source is published with every runtime release. DXVK, DXMT and MoltenVK keep their own licences. D3DMetal (part of Apple's Game Porting Toolkit) is never bundled or distributed by us; users import their own copy.

### Allowed inputs

- **In the 0BSD frontend:** only code under permissive licences (0BSD, MIT, BSD, ISC, Apache-2.0, zlib, CC0), used under its licence. Keep the original headers. Record the reuse in `NOTICE` and `THIRD_PARTY_LICENSES.md`, and mention it in your pull request.
- **In the LGPL runtime (`runtime/patches/`):** upstream Wine, the LGPL files in CodeWeavers' published source release, and other LGPL-2.1-compatible code, used under its licence.
- **As ideas and facts only:** GPL frontends (Whisky and its forks, Heroic, Bottles, Mythic) and winetricks (LGPL). You may study their behaviour and file formats. Download URLs, hashes and registry keys are facts and may appear in CC0 recipes. **Code and script logic are never transcribed.**
- **Public vendor documentation,** such as Apple's developer documentation, the Game Porting Toolkit Read Me files, and Microsoft specifications like MS-SHLLINK and the PE format.
- **Your own experiments,** including inspecting *your own* copy of Apple's Game Porting Toolkit disk image.

### Forbidden inputs

- **Copyleft code (GPL, LGPL, MPL) in the frontend.** It never goes into MallowKit, the CLI, the app or the scripts. It would change the licence of the whole frontend.
- **Anything inside `/Applications/CrossOver.app`** beyond licence texts and version strings. That includes:
  - the `bin/wine` launcher script logic and its environment defaults;
  - the bottle templates;
  - the compatibility database;
  - configuration-file comments;
  - UI assets, strings and icons;
  - the bundled D3DMetal copy, and the file names or PE headers of CrossOver's binaries.
- **Code from unlicensed repositories.** You may read it for ideas, but not copy it. We credit such sources in `NOTICE`.
- **Apple and Microsoft binaries.** D3DMetal, Microsoft redistributables and fonts never enter the repository or any download we host.

### If you have recently read a GPL implementation

Names and behaviours can match other projects; implementations must be our own. If you have just read a GPL implementation of the function you're writing, **say so in your pull request**. A second maintainer then reviews it. Reviewers reject changes that look transcribed from a GPL project.

### New dependencies

Every new dependency needs a discussion first. Frontend dependencies must use a permissive licence. Their notices go into `THIRD_PARTY_LICENSES.md`, which is generated from `Package.resolved`.

### Names and trademarks

"CrossOver", "CX", "CodeWeavers", "Whisky" and "WineHQ" never appear in product names, identifiers, bundle IDs, UI labels or marketing. In docs, use them only descriptively (for example, "an open-source alternative to CrossOver") or where provenance or licence compliance needs them.

### Upstream first

If a bug lives in Wine, DXMT, DXVK, MoltenVK or winetricks, please try to fix it upstream too, and link the upstream change. Don't send bug reports about Mallow's runtime to WineHQ or CodeWeavers: it is a modified build, so report problems to us. We never work around anti-cheat systems, and we don't add storefront hacks.

## Security-sensitive changes

Security is a headline feature of Mallow. The design puts every Windows program inside a macOS kernel sandbox (Seatbelt). Bottles are secure by default: no `Z:` drive and no links into your home folder. An Untrusted mode runs programs in disposable bottles, and runtime downloads are signed. All of this is planned, and no sandbox is perfect. That is why these changes get extra care.

**A change is security-sensitive if it touches:**

- the sandbox profile, its generation, or anything about trust modes, shared folders or the network toggle;
- how processes are spawned or how their environment is built (`Launch/`, `PosixSpawner`, `WineEnvironment`);
- prefix hardening when bottles are created (drive letters, home-folder links, disabled host-integration programs);
- downloads, signatures and installs (`SignatureVerifier`, `TrustedKeys`, `CatalogClient`, `ComponentInstaller`, `ArchiveExtractor`, `Quarantine`, `HTTPClient`);
- imports and provenance checks (`ProvenanceGuard`, `GPTKImporter`, bottle and runtime imports);
- recipes and download-host rules (`RecipeRunner`, `RecipeValidator`, `recipes/allowed-hosts.json`);
- the diagnostics bundle (what it collects and redacts);
- the `mallow://` URL scheme, the app's entitlements, or `scripts/install-cli.sh`;
- CI workflows, release and signing scripts, `catalog/`, `runtime/patches/`;
- `docs/SECURITY_MODEL.md` or `SECURITY.md`.

`.github/CODEOWNERS` marks these paths.

**Rules for these changes:**

1. **Two approving reviews**, and the author's review doesn't count. Once there is a second maintainer, both reviews come from maintainers. Until then, the maintainer asks a second reviewer with the right expertise in the pull request, and the change waits for that review.
2. **Never merged on the day they are opened.** Other people get time to look.
3. **Fill in the "Security impact" section** of the pull request template: what could go wrong, and how the change prevents it.
4. **Keep the docs honest.** If behaviour changes, update `docs/SECURITY_MODEL.md` in the same pull request, and add or update red-team probes and negative tests.
5. **Never weaken a default quietly.** Relaxing a protection for compatibility must be opt-in, per bottle, and visible in the bottle's Security panel.
6. **Undisclosed vulnerabilities are never fixed in public first.** Report them privately ([SECURITY.md](https://github.com/mixutin/Mallow/blob/main/SECURITY.md)), and we'll fix them in a private fork.
7. **No real malware, ever.** Not in the repository, not in tests, not attached to issues. Red-team probes are harmless programs that try an escape and report whether it worked (SECURITY_MODEL.md §4).

## Changing the design

[DESIGN.md](https://github.com/mixutin/Mallow/blob/main/docs/DESIGN.md) is the source of truth for how Mallow works, and [SECURITY_MODEL.md](https://github.com/mixutin/Mallow/blob/main/docs/SECURITY_MODEL.md) sets the security defaults. To change either one:

1. **Open a Discussion** titled `RFC: <topic>`. Describe the problem, your proposal, the alternatives you considered, and the effect on security and licensing.
2. **Open a pull request** that edits the design document, and link the Discussion. Keep the document's conventions:
   - Tag each fact you add with how well it's verified: **[H]** (verified against a primary source or tested), **[M]** (credible but partly verified) or **[L]** (unverified).
   - Add every new [L] item to the verification backlog (§11).
   - Add sources to the references (§12).
3. **Wait for review.** Design changes follow the decision process in [GOVERNANCE.md](https://github.com/mixutin/Mallow/blob/main/GOVERNANCE.md). Decisions are recorded in the design document with a date.

Code that disagrees with a normative section of the design is not merged until the design is updated.

## Documentation and the devlog

Documentation lives in `docs/` and is published at [mixutin.github.io/Mallow](https://mixutin.github.io/Mallow/). Docs are licensed under 0BSD, like the code.

**Writing style:**

- Plain English, short sentences, friendly and concise. No hype.
- Be honest about status. Say "planned" or "in design" for anything that doesn't ship yet.
- Explain Wine and macOS terms the first time you use them, or link to where they are explained.
- In root-level files (`README.md`, this file and so on), use **absolute links** (`https://github.com/mixutin/Mallow/blob/main/...` or `https://mixutin.github.io/Mallow/...`). These files can also be embedded in docs-site pages, where relative links would break.
- Only add images you made yourself or that are openly licensed, and say where they came from.

**Previewing the site.** The site is built with MkDocs and the Material for MkDocs theme. The exact versions are pinned in `requirements-docs.txt`. To preview it:

```sh
python3 -m venv .venv && source .venv/bin/activate
python -m pip install -r requirements-docs.txt
mkdocs serve                  # then open http://127.0.0.1:8000/Mallow/
mkdocs build --strict         # the same check CI runs; warnings count as errors
```

More detail is in [Writing docs and devlog posts](https://mixutin.github.io/Mallow/contributing/writing-docs/).

### Writing a devlog post

The [devlog](https://mixutin.github.io/Mallow/blog/) shares progress, decisions and things we learned, including what didn't work. Anyone can propose a post.

1. Create a Markdown file in `docs/blog/posts/`. Name it like the existing posts: the next number, then a short slug (for example `05-steam-recipe-plan.md`). The file name doesn't appear in the URL; the date and the `slug` do.
2. Start the file with front matter:

   ```markdown
   ---
   # SPDX-License-Identifier: 0BSD
   date: 2026-09-23
   authors:
     - mixutin
   categories:
     - Roadmap
   slug: steam-recipe-plan
   description: One sentence for link previews and the RSS feed.
   ---

   # A clear, specific title

   One or two sentences that summarise the post. They appear on the devlog's index page.

   <!-- more -->

   The rest of the post.
   ```

   - Keep `date` on one line, in `YYYY-MM-DD` form. The RSS feed reads it from there. A post dated in the future is treated as a draft.
   - Reuse existing categories where you can, such as Announcements, Roadmap, Security, Licensing, Contributing or Project.
   - Add `draft: true` while you're still writing. Drafts show up in `mkdocs serve`, but they aren't published.

3. Use your GitHub handle under `authors`. If this is your first post, add yourself under `authors:` in `docs/blog/.authors.yml`:

   ```yaml
     your-handle:
       name: Your Name
       description: Contributor
       avatar: https://github.com/your-handle.png
       url: https://github.com/your-handle
   ```

4. Keep each post to one topic, and be honest about status: what works, what is planned, what failed and why.
5. Open a pull request with the `devlog` label. Posts follow the same review and sign-off rules as everything else.

## Compatibility reports

Once there are builds to try, compatibility reports tell everyone what works. Use the [compatibility report form](https://github.com/mixutin/Mallow/issues/new?template=compatibility_report.yml). One report covers one game or app on one setup.

| Rating | Meaning |
|---|---|
| **Platinum** | Works perfectly, out of the box. No tweaks needed. |
| **Gold** | Works perfectly after some tweaks (a different graphics backend, a setting, a dependency). |
| **Silver** | Works, with minor issues that don't stop you playing or working. |
| **Bronze** | Starts, but with major issues. Hard to play or use. |
| **Borked** | Doesn't start, crashes, or is unusable. |

**Good reports:**

- Say exactly which tweaks you used, so others can repeat them.
- Include the Mallow version, the runtime version, the graphics backend, your macOS version and your Mac model.
- Only cover software you own a legitimate copy of. We can't help with pirated software.
- Never attach game files, product keys or D3DMetal files. Check logs for personal information before you post them.

Games that need kernel-level or most user-mode anti-cheat won't work, and we will never try to work around anti-cheat. Rate them honestly (usually Borked), and mention the anti-cheat in your notes.

## Review process

- **Who reviews.** Every pull request needs at least one approving review from a maintainer. Security-sensitive changes need two (see [above](#security-sensitive-changes)). Maintainers are listed in [GOVERNANCE.md](https://github.com/mixutin/Mallow/blob/main/GOVERNANCE.md).
- **What reviewers look at.** Does it match the design? Is it correct and tested? Are the licence and provenance clean? What is the security impact? Are the docs updated? Is it clear enough for the next person?
- **Response times.** Mallow is run by volunteers. We aim to give a first response to new issues and pull requests within **7 days**, and to review your updates within 7 days too. If you've heard nothing after a week, a polite ping is welcome.
- **Merging.** Maintainers merge once CI is green and the reviews are in. We usually squash-merge, and we keep your `Signed-off-by:` lines in the final commit. A pull request with several meaningful commits may be rebase-merged instead.
- **Inactive pull requests.** If a pull request waits on its author for 30 days, a maintainer may close it (you can always reopen it) or finish it. When we finish your work, we keep your credit with a `Co-authored-by:` line.
- **Disagreements.** Discuss them in the open, and assume good faith. If you can't reach agreement, the decision process in [GOVERNANCE.md](https://github.com/mixutin/Mallow/blob/main/GOVERNANCE.md) applies.

## Recognition

0BSD requires no attribution, so nobody is obliged to credit anyone. We thank people anyway:

- **Release notes** thank every contributor by GitHub handle, and list our upstream contributions to Wine, DXMT, MoltenVK and others.
- **A contributors list** (planned for the README), in the style of [all-contributors](https://allcontributors.org/), recognises every kind of work: code, docs, design review, testing, compatibility reports, triage, translations and security reports.
- **GitHub's contributor graph** shows code contributions automatically.
- **Security reporters** are credited in the published advisory, unless they prefer not to be.

## Getting help

- Questions about contributing: start a thread in [Discussions](https://github.com/mixutin/Mallow/discussions).
- Questions about using Mallow: see [SUPPORT.md](https://github.com/mixutin/Mallow/blob/main/SUPPORT.md).
- Conduct concerns: see the [Code of Conduct](https://github.com/mixutin/Mallow/blob/main/CODE_OF_CONDUCT.md).
- Security issues: see [SECURITY.md](https://github.com/mixutin/Mallow/blob/main/SECURITY.md).

Thank you for helping build Mallow!
