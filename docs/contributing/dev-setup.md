---
# SPDX-License-Identifier: 0BSD
description: Step-by-step local setup for Mallow contributors. Command Line Tools only (no Xcode), the planned build and test commands, previewing this docs site, and disk-space tips.
---

# Development setup

!!! warning "The Swift package doesn't exist yet"

    Mallow is in the design phase. **Steps 1–3 and 6 work today.** The build, test and app commands in steps 4 and 5 describe the **planned** workflow from [DESIGN.md §7](../DESIGN.md#7-testing-strategy-and-ci). They start working when `Package.swift` lands in v0.1.

## 1. Check your Mac

| You need | Notes |
|---|---|
| **A Mac with Apple Silicon** | M1 or later. Intel Macs are not supported. |
| **macOS 15 Sequoia or later** | The package targets macOS 15. The design was written on macOS 26. |
| **Git and a GitHub account** | For forking and pull requests. |
| **Python 3.10 or later** | Only for the docs site and the schema checks. CI uses Python 3.12. |
| **Disk space** | About 250 MB for one debug, release and test build of the package, plus about 165 MB for the docs toolchain. See [Saving disk space](#8-saving-disk-space). |

**You don't need Xcode.** The whole project is designed to build and test with Apple's free **Command Line Tools**. If you already have Xcode, that works too.

**You don't need Rosetta or Wine** for everyday work. Tests use a fake Wine. You only need Rosetta 2 to run real Wine, and installing it means accepting Apple's licence:

```sh
softwareupdate --install-rosetta
```

## 2. Install the Command Line Tools (Swift 6.3)

```sh
xcode-select --install
swift --version
```

You want **Swift 6.3 or later**. Check which developer directory is active:

```sh
xcode-select -p   # prints /Library/Developer/CommandLineTools
```

If that prints a path inside `Xcode.app` instead, Xcode's toolchain is in use. That is fine. Just know which one you are testing with when you report a problem.

## 3. Get the code

Fork [mixutin/Mallow](https://github.com/mixutin/Mallow) on GitHub, then:

```sh
git clone https://github.com/<your-username>/Mallow.git
cd Mallow
git remote add upstream https://github.com/mixutin/Mallow.git
```

Set the name and email that your commit sign-offs will use:

```sh
git config user.name "Your Name"
git config user.email "you@example.com"
```

## 4. Build and test (planned for v0.1)

```sh
swift build                  # MallowKit, the mallow CLI, the app target and fake-wine
scripts/test.sh              # the full test suite, with Command Line Tools only
scripts/test.sh --filter WineEnvironmentTests   # one suite; arguments go to `swift test`
scripts/lint.sh              # swift-format, shellcheck and the module layering rule
```

Some things to know:

- **Use `scripts/test.sh`, not plain `swift test`**, when you only have the Command Line Tools. The Testing framework lives in an unusual place there, and the script adds the compiler and linker flags that find it. It also builds `fake-wine` and `mallow` first, and exports their paths as `MALLOW_FAKE_WINE` and `MALLOW_CLI` for the tests. With Xcode selected, plain `swift test` works too. ([DESIGN.md §7.4](../DESIGN.md#74-scriptstestsh-works-with-command-line-tools-only))
- **Tests never run real Wine.** Integration tests use `fake-wine`, a small Swift program that records how it was called and pretends to be `wine` and `wineserver`. The launch planner is pure, so most tests compare its output against golden JSON files. ([DESIGN.md §7.1](../DESIGN.md#71-principles))
- **Tests use swift-testing only** (`import Testing`, `@Test`, `#expect`). XCTest isn't available with the Command Line Tools.
- **Real-runtime tests are opt-in**, and CI runs them. You don't need them locally, but if you have a runtime unpacked somewhere:

    ```sh
    MALLOW_REAL_RUNTIME=/path/to/runtime scripts/test.sh
    ```

## 5. Try the CLI and the app safely (planned)

Never point a development build at your real data. Use a throwaway data folder with `--home`, or the `MALLOW_HOME` environment variable:

```sh
.build/debug/mallow --home "$TMPDIR/mallow-dev" doctor
export MALLOW_HOME="$TMPDIR/mallow-dev"
.build/debug/mallow --json bottle list
.build/debug/mallow run --bottle Test --dry-run notepad   # prints the launch plan, runs nothing
```

To build the app bundle (planned for v0.3). The script assembles and ad-hoc signs an arm64-only `Mallow.app` without Xcode:

```sh
scripts/build-app.sh
open dist/Mallow.app
```

`scripts/install-cli.sh` links the `mallow` CLI into `~/.local/bin`.

!!! tip "Don't build the Wine runtime on your Mac"

    The runtime and its dependencies are built in public GitHub Actions, on runners with plenty of disk space. If you want to work on that pipeline ([DESIGN.md §3.11](../DESIGN.md#311-runtime-build-pipeline-runtime-depsyml-runtimeyml)), run the workflows in your fork.

## 6. Preview the docs site

This site is built with [MkDocs](https://www.mkdocs.org/) and [Material for MkDocs](https://squidfunk.github.io/mkdocs-material/). The exact versions are pinned in `requirements-docs.txt`.

```sh
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements-docs.txt
mkdocs serve                   # Ctrl-C to stop
```

Then open **<http://127.0.0.1:8000/Mallow/>** (the root address redirects there). The page reloads when you save a file. Drafts and future-dated devlog posts are shown while serving, but left out of real builds.

Before you open a pull request, run the same check as CI:

```sh
mkdocs build --strict
```

`--strict` turns every warning into an error: a broken link, a link to a missing heading, a page missing from the navigation, or an unknown devlog author. The output goes to `site/`, which Git ignores, like `.venv/`.

When you're done, `deactivate` leaves the virtual environment.

## 7. Commit and open a pull request

```sh
git switch -c docs/explain-bottles
git commit -s -m "docs: explain bottle templates"
git push -u origin docs/explain-bottles
```

Every commit needs the `-s` sign-off ([why](index.md#the-ground-rules)). The [contributor guide](https://github.com/mixutin/Mallow/blob/main/CONTRIBUTING.md) covers branches, commit messages and review.

CI runs on every pull request:

- **Docs**: `mkdocs build --strict`.
- **Checks**: every JSON and YAML file must parse, and every `.swift` file must start with an SPDX licence header.
- **Swift**: `swift build` and the tests on an Apple Silicon macOS runner, once `Package.swift` exists.

## 8. Saving disk space

Mallow is designed to be developed on a Mac with little free space. The design host had about 1.6 GB free.

| What | Typical size | How to reclaim it |
|---|---|---|
| `.build/` (one debug, release and test build) | about 250 MB | `scripts/dev-clean.sh` (planned), `swift package clean`, or `rm -rf .build` |
| SwiftPM caches | varies | `rm -rf ~/Library/Caches/org.swift.swiftpm` (dependencies download again next time) |
| `.venv/` (docs toolchain) | about 165 MB | `rm -rf .venv` |
| `site/` (built docs) | a few MB | `rm -rf site` |
| A real Wine runtime | hundreds of MB | Not needed. Tests use `fake-wine` |
| A test bottle | needs at least 500 MB free to create | Use a throwaway `MALLOW_HOME`, and delete it when you're done |

Tips:

- Check free space with `df -h ~` before a big build. Builds that run out of space fail in confusing ways.
- `pip install --no-cache-dir -r requirements-docs.txt` avoids filling pip's cache.
- Real-runtime and Steam tests belong in CI, not on a laptop that's short on space.

## Troubleshooting

`no such module 'Testing'` with the Command Line Tools
:   Use `scripts/test.sh` instead of `swift test`. It adds the framework search paths the Command Line Tools need.

Tests can't find `fake-wine`
:   Run them through `scripts/test.sh`, which builds it and sets `MALLOW_FAKE_WINE`.

`mkdocs: command not found`
:   Activate the virtual environment first: `source .venv/bin/activate`.

`mkdocs build --strict` fails on a link
:   Link to the Markdown file (`../faq.md`), not the web address. Anchors must match a real heading. The error names the file and the link.
