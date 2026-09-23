<!-- SPDX-License-Identifier: 0BSD -->

# Governance

This document explains who runs Mallow, how decisions are made, how you can become a maintainer, and the promises we make about the project's licence.

Mallow is a young project, in its pre-alpha design phase. It starts **founder-led**, with one person having the final say (the model sometimes called "benevolent dictator for life", or BDFL). The plan is to become a **maintainer team** as the project grows. Both phases are described below, along with when the switch happens.

## Principles

- **Decisions happen in public.** We use GitHub issues, Discussions and pull requests. The only exceptions are security reports, Code of Conduct reports and personal matters.
- **Decisions are written down.** Design decisions are recorded in [DESIGN.md](https://github.com/mixutin/Mallow/blob/main/docs/DESIGN.md) with a date and who made them.
- **Security and honesty come first.** We don't weaken protections quietly, and we don't claim features work before they do.
- **Upstream first.** We send fixes to Wine, DXMT, MoltenVK, winetricks and other projects we depend on wherever we can.
- **Sustainability.** Whisky's maintainer archived it in 2025, citing burnout. We want Mallow to outlast any one person, so we share the work, the access and the keys.

## Roles

| Role | Who | What they can do |
|---|---|---|
| **Contributor** | Anyone who opens an issue, comments, reviews, writes docs or code, or tests | Everything in [CONTRIBUTING.md](https://github.com/mixutin/Mallow/blob/main/CONTRIBUTING.md). Contributor reviews are welcome on every pull request |
| **Triager** | Regular contributors who help sort issues | Label, assign, close and reopen issues and pull requests |
| **Maintainer** | People trusted with the project's direction and quality | Review and merge pull requests, make releases, take part in decisions, handle security and conduct reports |
| **Project lead** | Currently the founder, [@mixutin](https://github.com/mixutin) | Final say during the founder-led phase; breaks ties during the team phase |

### Current maintainers

| Maintainer | Role | Areas |
|---|---|---|
| [@mixutin](https://github.com/mixutin) (Mixutin) | Project lead, founder | Everything |

**We are looking for a second maintainer.** The design calls for at least two maintainers with release rights, and so do the rules on release keys below. If you want to help run the project, start contributing and say so in a Discussion.

## Phases

### Phase 1: founder-led (now)

This phase lasts while Mallow has **fewer than three maintainers**.

- Everyday changes are decided by pull request review, as described below.
- Significant decisions go through the RFC process. After the discussion, the project lead decides and explains the reasoning in public.
- The project lead may delegate decisions for an area (for example, the runtime pipeline) to another maintainer.

### Phase 2: maintainer team

This phase starts automatically when Mallow has **three or more active maintainers**. The switch is announced in Discussions and on the devlog.

- Decisions are made by the maintainers, by consensus where possible.
- If consensus can't be reached, the maintainers vote. A simple majority of active maintainers decides, and the project lead breaks ties. The project lead has no veto.
- The maintainers may choose a new project lead with a two-thirds majority.

## How decisions are made

### Everyday changes

Most decisions are made in pull requests. A change is merged when CI passes and it has the approvals described in [CONTRIBUTING.md](https://github.com/mixutin/Mallow/blob/main/CONTRIBUTING.md#review-process): one maintainer approval, or two approving reviews for security-sensitive changes. If a maintainer objects, the change waits until the objection is resolved or the decision process below settles it.

### Significant decisions (RFCs)

These decisions need a written proposal, called an RFC:

- changes to the normative parts of DESIGN.md: the Swift API (§3.4), the file formats (§3.7) and the repository layout (§3.2);
- changes to the [security model](https://github.com/mixutin/Mallow/blob/main/docs/SECURITY_MODEL.md), and any change that weakens a security default;
- licensing questions, new dependencies, new download hosts and new runtime inputs;
- the project's name, identity and governance;
- big changes to the roadmap.

The process:

1. **Open a Discussion** titled `RFC: <topic>`. Explain the problem, the proposal, the alternatives, and the effect on security, licensing and maintenance.
2. **Allow time for comments:** at least **7 days**, or **14 days** for the security model, licensing and governance.
3. **Open a pull request** that updates DESIGN.md, SECURITY_MODEL.md or this document, and link the Discussion.
4. **Decide.** Use the rules for the current phase. Record the decision in the document with the date and who decided, for example "Decided (2026-09-23, project lead)".

Urgent security fixes may skip the waiting time. The decision is then explained in public once the fix is released.

## Becoming a triager or maintainer

**Triager.** Any maintainer can invite a contributor who regularly helps with issues. Just keep helping, and you'll be asked.

**Maintainer.** We look for people who have shown, over **at least three months**:

- steady, high-quality contributions. Code, reviews, docs, runtime work, testing and triage all count;
- good judgement in reviews, including the clean-room, licensing and security rules;
- kind and constructive communication, in line with the [Code of Conduct](https://github.com/mixutin/Mallow/blob/main/CODE_OF_CONDUCT.md);
- some regular time for the project. It doesn't have to be a lot, but it should be predictable.

**How it works:**

1. Any maintainer can nominate someone. You can also nominate yourself by asking a maintainer.
2. The maintainers discuss the nomination privately.
3. In phase 1, the project lead decides after hearing the other maintainers. In phase 2, the nomination needs a two-thirds majority of active maintainers, and no objection may remain unresolved after 7 days.
4. The new maintainer is announced publicly, and added to the table above and to `.github/CODEOWNERS`.

**Maintainers must:**

- use two-factor authentication on GitHub. Maintainers who hold a release key must use a hardware security key;
- follow the review and release rules in this document and in CONTRIBUTING.md;
- step back from any decision where they have a conflict of interest.

### Stepping down

Anyone can step down at any time, and we'll thank them for their work. If a maintainer has been inactive for six months, we'll ask whether they want to continue. Former maintainers are listed as emeritus maintainers. Their access is removed, and any release key they held is rotated.

A maintainer can be removed for serious or repeated Code of Conduct violations, or for putting users at risk through negligence. In phase 1, the project lead decides. In phase 2, it takes a two-thirds majority of the other maintainers.

## Releases and key custody

Nothing has been released yet. These rules apply from the first release onward.

- **Everything is built in public CI** from tagged commits, never on a personal machine. App releases come from `v*` tags, runtime releases from `runtime-*` tags and backend releases from `backends-*` tags. The catalog is signed and published by CI (DESIGN.md §7.5).
- **Two maintainers for every signed release.** No release signed with the project's keys is published until Mallow has at least two maintainers with release rights. Every signed release is started by one maintainer and approved by another.
- **Split key custody.** The release keys, a current one and a next one (DESIGN.md §3.13), are held by two different maintainers. No one person holds both. The key CI signs with is stored only as a secret of a protected GitHub Actions environment, which requires a second maintainer's approval to run.
- **Key rotation and compromise.** A new key is announced in a catalog signed with both keys. If a key is compromised, we rotate it, publish a security advisory, and explain what users need to do.
- **Licence compliance is part of every release.** Every runtime and backend binary is published with its corresponding source beside it. Runtime releases are never deleted. If one must be withdrawn, its binaries are removed first, and its source stays available for at least three more years (DESIGN.md §2.3).
- **Release notes** thank contributors, and include an "upstream contributions" section.
- **Apple Developer ID (planned for v0.8).** Signing and notarising the app for macOS needs a legal entity to hold the account. That decision is still open (DESIGN.md §10, Q5).

## Security response

Security reports arrive through GitHub's private reporting, as described in [SECURITY.md](https://github.com/mixutin/Mallow/blob/main/SECURITY.md). Every maintainer is part of the security response. Fixes are developed in a private fork and published with an advisory. The two-review rule applies to security fixes too.

## Licence policy

Mallow's licences are a promise to everyone who uses or builds on the project.

- **Mallow's own code, scripts and docs are licensed under 0BSD, and this is meant to be permanent.** Anyone may use, copy, modify and redistribute them for any purpose, commercial included, with no attribution required.
- **We will not relicense Mallow's own code** under a copyleft or proprietary licence. We will not add an attribution requirement or a contributor licence agreement (CLA).
- **Contributions come in under the licence of the files they touch** (0BSD for most of the project), certified by the DCO sign-off. So every released version stays available under 0BSD, whatever happens to the project later.
- **The only change we would consider** is a move to another public-domain-equivalent licence, and only if 0BSD turned out to cause a real legal problem. That change would need an RFC with at least **30 days** of public comment, and the agreement of **every** active maintainer.
- **Recipes and JSON Schemas** stay CC0-1.0.
- **Our Wine patches** are LGPL-2.1-or-later, because Wine's licence requires it. The Wine runtime Mallow downloads is LGPL-2.1-or-later, and its source is published with every runtime release. DXVK, DXMT, MoltenVK and other components keep their own licences.
- **D3DMetal** (part of Apple's Game Porting Toolkit) is never bundled or distributed by Mallow. Users import their own copy.

## Name and trademarks

"Mallow" is the project's name, pending formal trademark searches (DESIGN.md §2.6). Other projects are free to build on Mallow's code, but please don't call a fork "Mallow" in a way that confuses users about who made it.

"CrossOver" is a trademark of CodeWeavers. We use it only descriptively, as in "an open-source alternative to CrossOver", and never as part of our name, branding or identifiers.

## Relationship with CodeWeavers and upstream projects

Mallow depends on the work CodeWeavers does and funds on Wine for macOS, and on many other open-source projects. We try to be a good neighbour:

- We send fixes upstream wherever possible.
- We never push support work onto CodeWeavers. Our runtime's crash dialog and every support link in the app will point to our own tracker.
- We don't add storefront hacks, and we never work around anti-cheat.
- We follow the clean-room rules in [CONTRIBUTING.md](https://github.com/mixutin/Mallow/blob/main/CONTRIBUTING.md#clean-room-and-licensing-rules): nothing from CrossOver's proprietary files, and no GPL code in our 0BSD frontend.

## Money

Mallow has no income, no paid features and no legal entity. If that changes, for example to hold the Apple Developer ID or to accept donations, it will go through a transparent fiscal host, and we'll announce it publicly. The code stays free either way.

## Code of Conduct enforcement

The maintainers enforce the [Code of Conduct](https://github.com/mixutin/Mallow/blob/main/CODE_OF_CONDUCT.md). A maintainer who is involved in a report takes no part in handling it. If a report concerns the only maintainer who could handle it, you can also use GitHub's own "Report content" feature, which goes to GitHub staff.

## Abuse and takedown requests

This covers abuse reports, and DMCA or other takedown requests, about anything the project publishes. That includes recipes, which point to downloads hosted elsewhere.

**How to contact us.** A dedicated project contact address will be published here and in [SECURITY.md](https://github.com/mixutin/Mallow/blob/main/SECURITY.md) before the community recipe repository opens (planned for v0.9). Until then:

- for anything sensitive, use the private reporting form at <https://github.com/mixutin/Mallow/security/advisories/new>, and start the title with "Takedown request:";
- otherwise, open a public issue.

You can also send DMCA notices about content hosted on GitHub directly to GitHub, under its [DMCA takedown policy](https://docs.github.com/en/site-policy/content-removal-policies/dmca-takedown-policy).

**What we do:**

1. We acknowledge the request within **7 days**.
2. We disable the recipe or content in question while we review it.
3. We record the outcome in a public log.

We never host warez, abandonware or file-locker links, and download hosts for recipes must be approved by a maintainer.

## Changing this document

Changes to this document follow the RFC process, with at least 14 days of comments. In phase 1, the project lead approves them. In phase 2, they need a two-thirds majority of active maintainers.
