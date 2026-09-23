---
# SPDX-License-Identifier: 0BSD
description: How to help build Mallow while it is still in design. The ground rules (0BSD, DCO sign-off, clean-room), where help is needed, and where to start.
---

# Contributing

Thanks for your interest in Mallow! Everyone is welcome: Swift developers, Wine and build-system people, writers, testers, security researchers, and people who have never contributed to an open-source project before.

!!! info "Where the project is"

    Mallow is **pre-alpha** and at **Gate G0, "Before any code"**. The repository holds the design, the security model and the community files. Application code starts with v0.1 "Foundations". So right now the most valuable contributions are **reading the design critically, checking its assumptions, and improving the docs**.

This section of the site helps you get oriented. The complete contributor guide, covering workflow, review, coding standards and security-sensitive changes, is [CONTRIBUTING.md](https://github.com/mixutin/Mallow/blob/main/CONTRIBUTING.md) in the repository.

## Start here

<div class="grid cards" markdown>

-   :material-map-marker-path:{ .lg .middle } **[Architecture tour](architecture-tour.md)**

    ---

    A guided 10-minute walk through the design document: the modules, the launch planner, the on-disk layout, and where to start.

-   :material-laptop:{ .lg .middle } **[Development setup](dev-setup.md)**

    ---

    What you need (no Xcode), how builds and tests are planned to work, how to preview this site, and how to save disk space.

-   :material-file-document-edit-outline:{ .lg .middle } **[Writing docs and devlog posts](writing-docs.md)**

    ---

    How the site and the devlog are organised, front matter for posts, and the style guide.

-   :material-book-open-variant:{ .lg .middle } **[The design](../DESIGN.md)**

    ---

    The source of truth for how Mallow works. The [security model](../SECURITY_MODEL.md) sets the security defaults.

</div>

## The ground rules

1. **Be kind.** Everyone follows the [Code of Conduct](https://github.com/mixutin/Mallow/blob/main/CODE_OF_CONDUCT.md).
2. **Talk first about big changes.** For anything larger than a small fix, open an issue or a [Discussion](https://github.com/mixutin/Mallow/discussions) before you write it.
3. **Sign off every commit** with `git commit -s`. This adds a `Signed-off-by:` line, which certifies the [Developer Certificate of Origin](https://developercertificate.org/): that you wrote the change, or otherwise have the right to submit it under the project's licences.
4. **Your contribution is 0BSD**, like the rest of Mallow's own code and docs. The exceptions are Wine patches in `runtime/patches/` (LGPL-2.1-or-later) and recipes and schemas (CC0-1.0).
5. **Follow the clean-room rule.** Never copy code from GPL projects (Whisky, Heroic, Bottles, Mythic and others) into Mallow, and never use anything from inside CodeWeavers' commercial CrossOver app. Ideas are fine; code is not. Details are on the [Legal & licensing](../legal.md#the-clean-room-rule) page.
6. **Cite your sources.** Every environment variable, registry key or DLL rule that Mallow sets must cite an open source in a code comment (the *provenance rule*).
7. **Report vulnerabilities privately**, as described in [SECURITY.md](https://github.com/mixutin/Mallow/blob/main/SECURITY.md). Never in a public issue.

Signing off looks like this:

```sh
git commit -s -m "docs: explain bottle templates"
```

It adds this line to your commit message, using the name and email from your Git settings:

```text
Signed-off-by: Your Name <you@example.com>
```

Forgot it? `git commit --amend -s` fixes the last commit, and `git rebase --signoff main` fixes every commit on your branch.

## Where help is needed now

| Area | What would help | Where to look |
|---|---|---|
| **Design review** | Challenge the design. Look hard at claims tagged **[L]** (unverified), the open questions and anything that seems over-built. | [DESIGN.md §10](../DESIGN.md#10-open-questions-decisions-needed), [§11](../DESIGN.md#11-verification-backlog-assumptions-register) |
| **Verify an assumption** | Many decisions rest on facts that still need a test on a real Mac. Pick one from the verification backlog and report what you found, with your macOS version and Mac model. | [DESIGN.md §11](../DESIGN.md#11-verification-backlog-assumptions-register) |
| **Runtime CI** | The public GitHub Actions pipeline that builds the Wine runtime from pinned sources, with licence audits and smoke tests. | [DESIGN.md §3.11](../DESIGN.md#311-runtime-build-pipeline-runtime-depsyml-runtimeyml) |
| **Sandbox red-team** | Review the Seatbelt profile sketch, experiment with `sandbox-exec`, and help design the harmless probe programs. | [Security model §3–§4](../SECURITY_MODEL.md#3-defense-layers), [§7](../SECURITY_MODEL.md#7-open-questions) |
| **Docs** | Explain things in plain English, proofread, add diagrams, write a devlog post. | [Writing docs](writing-docs.md) |
| **Legal know-how** | The name clearance, the Apple toolkit licence, the LGPL source procedure and codec patents all need expert eyes. | [DESIGN.md §2](../DESIGN.md#2-legal-and-licensing-model) |

When the Swift package lands, the library is planned to be split into modules that people can pick up in parallel. The [architecture tour](architecture-tour.md#where-to-start) explains how that is planned to work.

## Changing the design

[DESIGN.md](../DESIGN.md) is the source of truth, and the [security model](../SECURITY_MODEL.md) sets the security defaults. To change either:

1. Open a Discussion titled `RFC: <topic>`, describing the problem, your proposal, the alternatives and the effect on security and licensing.
2. Open a pull request that edits the document. Tag new facts with how well they are verified (**[H]**, **[M]** or **[L]**), add new [L] items to the verification backlog, and add sources to the references.
3. Code that disagrees with a normative section of the design (the Swift API in §3.4 and the file formats in §3.7) is not merged until the design is updated.

## Getting help

- Questions about contributing: [GitHub Discussions](https://github.com/mixutin/Mallow/discussions).
- Something specific, like a bug in these docs: [open an issue](https://github.com/mixutin/Mallow/issues).
- The full process: [CONTRIBUTING.md](https://github.com/mixutin/Mallow/blob/main/CONTRIBUTING.md).
