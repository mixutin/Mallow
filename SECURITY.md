<!-- SPDX-License-Identifier: 0BSD -->

# Security Policy

Security is a headline feature of Mallow, so we take reports seriously, even at this early stage.

> **Status: pre-alpha, design phase.** No application code exists and nothing has been released. Right now the most useful reports are about flaws in the **design**, especially the [security model](https://github.com/mixutin/Mallow/blob/main/docs/SECURITY_MODEL.md). Once code lands, this policy covers the code too.

## Supported versions

| Version | Supported |
|---|---|
| None released yet | Not applicable |

When releases begin:

- Security fixes go into the **latest release** of the Mallow app and CLI, and into the **latest Mallow Runtime**. Before 1.0, older releases don't get fixes; please update.
- Runtime and backend components are replaced through the signed catalog. A fix may be a new runtime release rather than a new app release.

**There are no official downloads yet.** If someone offers you a "Mallow" app or runtime download today, it is not from this project.

## Reporting a vulnerability

**Please report vulnerabilities privately. Never report them in a public issue, discussion or pull request.**

1. Go to the repository's [Security tab](https://github.com/mixutin/Mallow/security) and click **Report a vulnerability**, or open the form directly: <https://github.com/mixutin/Mallow/security/advisories/new>.
2. Describe the problem, and include:
   - what an attacker can do, and what they need first (for example, "a Windows program running in an Untrusted bottle can read `~/.ssh`");
   - steps to reproduce, or a harmless proof of concept;
   - the version or commit, your macOS version and your Mac model;
   - the trust mode (Standard, Untrusted or Offline), the runtime and the graphics backend, if they matter;
   - whether you plan to publish, and when.
3. Only the maintainers can see the report. We'll discuss it with you there, and we may invite you to a private fork to review the fix.

If you can't use GitHub's form, open a public issue that asks for a private contact. **Don't include any details.** A maintainer will get in touch.

## What happens next

These are our targets. Mallow is run by volunteers, but security reports come first.

| Step | Target |
|---|---|
| Acknowledge your report | Within 3 days, and never more than 7 |
| First assessment (is it valid, how severe) | Within 14 days |
| Fix released | As fast as severity requires. We aim for 90 days at most |
| Public disclosure | When the fix is released, or after 90 days, whichever comes first. We can agree on a different date with you, for example when an upstream project needs more time |

We publish each fixed vulnerability as a GitHub Security Advisory, with a CVE where appropriate. We credit you by name or handle, unless you'd rather stay anonymous.

## Scope

Mallow's security goal, from the [security model](https://github.com/mixutin/Mallow/blob/main/docs/SECURITY_MODEL.md): **a Windows program running in Mallow should put at risk only the bottle it runs in, never the rest of the Mac.** Anything that breaks that promise is in scope.

### In scope, from most to least severe

**Critical: sandbox escapes.** These are the most serious reports we can get. Examples:

- A program in a bottle reads or writes files outside its bottle, the read-only runtime and its explicitly shared folders. That includes going through symlinks, raw macOS system calls, or Wine features such as drive `Z:`.
- A program runs code outside the sandbox: through `exec`, LaunchServices, Apple Events, login items, launch agents, or anything else.
- A way around runtime signature checks: installing an unsigned or tampered runtime, backend or catalog, rolling the catalog back, or escaping the install folder through an archive.

**High.** Examples:

- Network access from a bottle with the network turned off.
- One bottle reading or writing another bottle.
- Keychain access from a bottle.
- Persistence that survives the program or its disposable bottle: autostart entries that run outside the bottle, or processes that outlive a disposable bottle.
- An Untrusted-mode bottle that isn't disposable when it should be, or that gets folders shared with it.
- A download that ends up on a host a recipe didn't declare.

**Medium and low.** Examples:

- A diagnostics bundle that leaks personal data, or that includes files it promises to leave out (such as your imported D3DMetal copy).
- `mallow://` URLs that can make Mallow do something the user didn't ask for.
- Secure-by-default bottle settings (no `Z:` drive, no links into your home folder, host-integration programs turned off) that are silently lost or weakened.
- Weaknesses in our CI and release pipeline: workflow injection, exposed secrets, or unpinned inputs in release builds.

### Out of scope

- **What a program does inside its own bottle.** A Windows program can damage its own bottle, and a malicious one can steal data you put in that bottle, such as a game launcher's login. The security model says so openly.
- **Folders you chose to share.** Anything shared read-write can be changed by programs in that bottle.
- **Malware detection.** Mallow is not an antivirus and doesn't decide whether a program is malicious.
- **Kernel, GPU-driver or Rosetta vulnerabilities.** Please report these to Apple. Do tell us if Mallow could reduce their impact.
- **Bugs in other projects:** Wine (unless the bug is in our patches or our build), DXVK, DXMT, MoltenVK, winetricks, Apple's Game Porting Toolkit or D3DMetal, CrossOver, and third-party Standard Wine builds. Please report these to their maintainers. We are happy to help coordinate, and we'll ship a fixed runtime as soon as one exists.
- **Anti-cheat.** Mallow doesn't support it and never works around it.
- **Physical access, or a Mac that is already compromised.**
- **Known limitations** listed in the security model (§6), such as the first sandbox profile being a deny-list, unless you show a concrete escape.
- **Automated scanner output** without a demonstrated impact, and missing "best practice" settings on the docs website.
- **Social engineering** of maintainers or users.

## Safe harbour

We won't take legal action against good-faith security research that follows this policy. Please:

- test only on machines and accounts that you own or have permission to use;
- use **harmless** proof-of-concept programs that show an escape and nothing more, like the probes in our red-team plan (security model §4). Never use real malware;
- don't access, change or delete other people's data;
- give us a reasonable chance to fix the problem before you publish.

## The security model in brief

The full design is in [docs/SECURITY_MODEL.md](https://github.com/mixutin/Mallow/blob/main/docs/SECURITY_MODEL.md). Everything below is **planned**; none of it exists yet.

Wine is a compatibility layer, not a sandbox. Out of the box, a Windows program under Wine can read your whole Mac through drive `Z:`. So Mallow plans five layers of defence:

1. **Kernel sandbox (the real boundary).** Every Windows program runs inside a macOS Seatbelt sandbox profile made for its bottle. The kernel enforces it, even against programs that bypass Wine with raw system calls.
2. **Secure-by-default bottles.** No `Z:` drive, real folders instead of links into your home folder, and Wine's ways of opening Mac apps turned off.
3. **Trust modes.** *Standard* for games and known apps, *Offline* for programs that don't need the internet, and *Untrusted* for anything suspicious. Untrusted mode has no network and no shared folders, and runs in a disposable APFS-clone bottle that is deleted when the program exits.
4. **Signed downloads.** Runtime components are listed in a manifest signed with Ed25519 and checked against pinned keys, with a SHA-256 hash per file. A mismatch is a hard failure.
5. **Transparency.** Each bottle shows its trust mode, network setting, shared folders and recent sandbox denials.

**No sandbox is perfect.** Mallow reduces risk a lot, but it can't protect against every kernel bug. It also can't protect what you put into a bottle yourself. Don't run known malware on a Mac with important data.

## Release signing keys

None yet. When the first signed runtime or catalog is published, this section will list the public keys and their fingerprints. The same keys are pinned in the app's source code. Under our [governance](https://github.com/mixutin/Mallow/blob/main/GOVERNANCE.md), no single person holds every release key.

## Abuse and takedown requests

For abuse reports and DMCA or other takedown requests, such as a recipe that points somewhere it shouldn't, see the procedure in [GOVERNANCE.md](https://github.com/mixutin/Mallow/blob/main/GOVERNANCE.md#abuse-and-takedown-requests). A dedicated project contact address will be published there and here before the community recipe repository opens (planned for v0.9).
