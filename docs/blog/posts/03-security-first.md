---
# SPDX-License-Identifier: 0BSD
date: 2026-09-23
authors:
  - mixutin
categories:
  - Security
slug: security-first
description: "Wine is not a sandbox. Mallow's plan: a kernel sandbox around every Windows program, secure-by-default bottles, disposable Untrusted bottles, a red-team suite, and honest limits."
---

# Security first: running Windows apps without trusting them

Many people assume a Windows program can't hurt a Mac. Under Wine, that isn't true. Security is a headline feature for Mallow, so here's what we're planning, what we've tested so far, and where the limits are.

<!-- more -->

## Wine is not a sandbox

Wine is a compatibility layer, not a security boundary. A program running under stock Wine:

- runs as you, with your full file permissions;
- sees your whole disk through drive `Z:`;
- gets `Documents`, `Desktop` and `Downloads` as links to your real folders;
- can ask Wine to open files and URLs with native Mac apps;
- can skip Wine entirely and make raw macOS system calls from its own machine code.

That last point is why Wine settings alone can't fix this. A Windows info-stealer under stock Wine could read `~/.ssh`, browser profiles and documents, then send them over the network.

Our goal: **running a suspicious `.exe` in Mallow should put at risk only the bottle it runs in, never the rest of the Mac.**

## The kernel does the real work

The one real security boundary in the plan is the macOS kernel sandbox, Seatbelt. Mallow will generate a sandbox profile for each bottle and run every Wine process under it. The kernel enforces it, so it still applies when a program bypasses Wine with raw system calls, and child processes can't remove it. The profile hides your home folder, then re-allows only the bottle, the read-only runtime and folders you've explicitly shared. It also blocks escape hatches that launch things outside the sandbox, such as Apple Events and LaunchServices.

We've already checked the basics on macOS 26.5 (Apple M4):

| Test | Result |
|---|---|
| A sandboxed process writes to a denied folder | Blocked by the kernel ("Operation not permitted") |
| A sandboxed process connects out with the network denied | Blocked (DNS fails, no connection) |
| An x86_64 program runs through Rosetta 2 inside the sandbox | Works |

The third matters most, because Mallow runs an x86_64 Wine under Rosetta. These were small, focused checks, not Wine running a real game under the full profile. Proving that is the red-team suite's job.

Apple marks `sandbox-exec` as deprecated, but it still works in macOS 26, and a tiny launcher that calls the same API is our fallback.

## Secure-by-default bottles

New bottles will also be hardened. There's no `Z:` drive; folders you share get their own drive letters. `Documents`, `Desktop` and the rest are real folders inside the bottle, not links into your home folder. Wine's helpers that create Mac file associations or open native apps are off, and opening a link needs your OK. Mallow also watches autostart entries and tells you when a new one appears.

These layers help, but they aren't a security boundary on their own. The sandbox is.

## Trust modes and disposable bottles

Each launch gets a trust mode:

- **Standard** (the default): the bottle plus your explicit shares, network on. For games, Steam and apps you know.
- **Offline**: the same, with the network off.
- **Untrusted**: no shares, no network, and a **disposable bottle**.

A disposable bottle is an APFS clone of a clean template. Cloning is instant and copy-on-write, so it uses almost no extra disk. The clone is deleted when the program exits, unless you choose "Keep this bottle".

To pick a default, Mallow will check whether an `.exe` or `.msi` was downloaded (macOS's quarantine flag) and whether it's Authenticode-signed. Unsigned downloads default to Untrusted, and the dialog says why.

Mallow's own downloads are protected too: a signed manifest with a SHA-256 hash per file, HTTPS only, and no "install anyway" button on a mismatch.

## The red-team plan

Please don't take any of this on trust. A test suite will check every release with harmless probe programs that try to escape and report back. No real malware is involved.

The probes try to read `~/.ssh` and the keychain, write to `LaunchAgents`, peek into other bottles, run `/bin/sh`, reach the network when it's off, follow a symlink out of the bottle, and outlive the program. Then they try it all again as **raw system calls from Windows code**, bypassing Wine.

One check goes the other way: Steam, a DirectX 11 game, audio, controllers and the clipboard must **still work**. A sandbox that breaks games won't get used.

Roughly: the first sandbox profile and Untrusted mode in the earliest releases, the red-team suite in CI by v0.3, a stricter profile by v0.5, and an external security review before 1.0.

## Honest limits

- **Mallow is not an antivirus.** It limits what a program can reach; it doesn't judge whether it's malicious.
- **No sandbox is perfect.** Kernel, GPU-driver or Rosetta bugs can in principle break any sandbox. Keep macOS updated.
- **A bottle is only as safe as what's in it.** Malware in your Steam bottle can steal the Steam session stored there, so keep untrusted things in separate bottles or Untrusted mode.
- **Shared folders are shared.** Ransomware can encrypt anything shared read-write, so shares default to read-only.
- **The first profile is a deny-list.** It blocks the known escape routes; the tighter allow-list is planned for v0.5.

As Mallow will tell you the first time you use Untrusted mode: it reduces risk a lot, but don't run things you know are malware on a Mac with important data.

The full details, including open questions, are in the [security model](https://github.com/mixutin/Mallow/blob/main/docs/SECURITY_MODEL.md).
