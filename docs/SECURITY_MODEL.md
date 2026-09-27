# Mallow Security Model

> Status: **Design (draft)**. Part of the Mallow design; see `DESIGN.md` for the overall architecture.
> Items marked 🧪 still need to be validated by the red-team test suite before they ship.

## Current implementation boundary — 27 September 2026

The development preview installs the one pinned Wine archive and offers local file-integrity verification. It does **not** execute Wine/Windows programs, create bottles, or implement the kernel sandbox described below. The following layers remain the target model, not shipped protection. Earlier dated experiments are design-host observations, not tests of this application's launch path.

The implemented installer uses approved HTTPS sources, compiled size/SHA-256 pins, a verified private snapshot, bounded extraction, confined links, owned data roots, advisory locks and completed-tree registration. It does not restore archive-provided owner/ACL/xattr metadata or change system-wide Gatekeeper settings. A local unsigned receipt detects corruption but cannot authenticate files against an attacker able to edit both the receipt and payload. No download or installation happens merely because the app is opened; user consent precedes effects.

Startup reads bounded metadata rather than rehashing all installed files. Full verification is explicit and uses streaming buffers off the UI's main actor. These performance choices do not waive checks during installation or imply a kernel boundary. Power-loss durability, stale-staging recovery, repair/rollback, general import/provenance and signed catalogs remain unfinished. See [runtime installation design](runtime-installation.md), [bootstrap addendum](BOOTSTRAP.md) and the [roadmap](roadmap.md) for exact scope and tests. Report undisclosed vulnerabilities privately through SECURITY.md.

## 1. Why this exists

Wine is a compatibility layer, **not a sandbox**. Out of the box, a Windows program running under Wine:

- runs as the logged-in macOS user, with that user's full file permissions;
- sees the whole Mac file system through drive `Z:` (mapped to `/`);
- gets `Documents`, `Desktop`, `Downloads`, etc. inside the prefix as **symlinks to the real folders in `$HOME`**;
- can ask Wine to open files and URLs with native Mac apps (`winebrowser`, `start /unix`, `ShellExecute`);
- can create Mac-side file associations and menu entries (`winemenubuilder`);
- can bypass Wine entirely by issuing raw macOS system calls from its own machine code.

So "it's just a Windows virus, it can't hurt a Mac" is false. A Windows info-stealer running under stock Wine can read `~/.ssh`, browser profiles and documents, and send them over the network.

Mallow's goal: **running a suspicious `.exe` in Mallow should put at risk only the bottle it runs in, never the rest of the Mac.**

## 2. Threat model

| In scope | Out of scope |
|---|---|
| Malicious or trojanized Windows programs (stealers, ransomware, droppers, adware, crypto-miners) | Kernel / GPU-driver / Rosetta zero-day exploits (sandbox reduces but cannot eliminate this) |
| Compromised game installers or mods | A user who explicitly shares a sensitive folder into a bottle |
| Programs that try to escape via Wine features (Z: drive, host-exec, symlinks) | Physical access, malware already on the Mac |
| Programs that issue raw macOS syscalls to bypass Wine | Detecting or cleaning malware (Mallow is **not** an antivirus) |
| Persistence attempts (autostart, LaunchAgents, login items) | Anti-cheat compatibility |
| Tampered Mallow runtime downloads (supply chain) | |

**Target security invariant:** a Windows process launched by Mallow can read and write only (a) its own bottle, (b) the read-only runtime, (c) the system files it needs to run, and (d) folders the user has explicitly shared with that bottle. This must apply whether it goes through Wine or not. It is not yet implemented by the development preview.

## 3. Defense layers

Security comes from layer 1. Layers 2–5 reduce the attack surface and make accidents less likely, but **no layer except the kernel sandbox is a real security boundary.** These describe the target product.

### Layer 1: Kernel sandbox (the real boundary)

Every Wine process (`wine`, `wineserver`, `wine-preloader`, and all their children) is planned to run under a macOS **Seatbelt sandbox profile** that Mallow generates for each bottle, using `sandbox-exec -f <profile>` or a small launcher helper that calls `sandbox_init`. The kernel must enforce it, including programs that make raw syscalls and bypass Wine. Child-process inheritance must be tested in Mallow's actual launch path.

**Design-host observations on macOS 26.5 / Apple M4 (2026-09-23):**

| Test | Result |
|---|---|
| Sandboxed process writes to a denied folder | ❌ `Operation not permitted` (kernel-enforced) |
| Sandboxed process opens an outbound network connection with network denied | ❌ Blocked (DNS resolution fails, no connection) |
| x86_64 binary via Rosetta 2 runs inside the sandbox | ✅ Works |

**Profile shape (unshipped sketch):**

```scheme
(version 1)
(allow default)

;; Files: hide the home folder, then allow only required paths.
(deny file-read* file-write* (subpath (param "HOME")))
(allow file-read* (subpath (param "RUNTIME_DIR")))
(allow file-read* file-write* (subpath (param "BOTTLE_DIR")))
(allow file-read* file-write* (subpath (param "BOTTLE_TMP")))
;; Explicit shares will be generated here.
(allow file-read* (literal (string-append (param "HOME") "/Library/Preferences/.GlobalPreferences.plist")))

(deny file-write* (subpath (string-append (param "HOME") "/Library/LaunchAgents")))
(deny file-write* (subpath "/Library/LaunchAgents") (subpath "/Library/LaunchDaemons"))

(deny process-exec*)
(allow process-exec* (subpath (param "RUNTIME_DIR")))

(deny appleevent-send)
(deny mach-lookup (global-name "com.apple.coreservices.launchservicesd"))
(deny mach-lookup (global-name "com.apple.SecurityServer"))
(deny mach-lookup (global-name "com.apple.backgroundtaskmanagementagent"))

;; Network-off sketch; wineserver socket requirements need measurement.
;; (deny network*)
;; (allow network* (local unix-socket (path-regex #"^/private/tmp/\.wine-")))
```

The sketch is not a security guarantee. Rule precedence, allowed runtime/backend paths, required Mach services, Rosetta execution, wineserver socket access and GUI compatibility must be validated before deployment. DESIGN.md §3.14 requires the launch-path revision first. LaunchServices, Apple Events and background-task registration need particular care because operations can be handed to processes outside the intended boundary. TCC is not a substitute for Mallow's tested sandbox. The deprecated sandbox-exec interface and any helper replacement must be evaluated against supported macOS versions.

### Layer 2: Wine prefix hardening (planned when a bottle is created)

| Stock Wine | Mallow target default |
|---|---|
| `dosdevices/z:` → `/` | Removed; explicit shared folders get separate drive letters |
| Home folders linked into the prefix | Real folders inside the bottle |
| `winemenubuilder.exe` creates Mac associations/menu entries | Disabled |
| Host-app/URL launch paths | Disabled or brokered through an explicit prompt, subject to validation |
| Registry Run/RunOnce and Startup entries | Watched and displayed, with changes reported |

No prefix-hardening action is implemented by the current installer. It only installs the runtime bundle.

### Layer 3: Trust levels per launch

| Mode | Files | Network | Bottle | Intended use |
|---|---|---|---|---|
| Standard | Bottle + explicit shares | On, toggleable | Persistent | Known apps and games |
| Untrusted | Bottle only | Off | Disposable clone | Unknown programs |
| Offline | Bottle + explicit shares | Off | Persistent | Programs that need no network |

Disposable bottles are planned as copy-on-write APFS clones of a clean template, with explicit keep/delete behavior. Quarantine and Authenticode checks are planned to guide the default mode. Unsigned internet downloads should default to Untrusted. These modes and checks remain unimplemented; a setup receipt does not supply them.

### Layer 4: Supply-chain integrity (Mallow's own downloads)

The target component system uses signed manifests/catalogs, pinned public keys, file hashes and anti-rollback. The interim installer uses one compiled-in upstream URL, byte count and SHA-256 instead; the local installation receipt is not that signed manifest.

HTTPS and integrity mismatches must fail without an override. Dependency verbs are planned as declarative downloads/install steps rather than remote scripts. Runtime quarantine handling must occur only after appropriate verification; the present extractor does not restore incoming archive xattrs and does not implement generic recursive quarantine removal. Official own-runtime builds/source publication, signed backend components and user-supplied GPTK import remain later work. D3DMetal is never downloaded or bundled.

### Layer 5: Transparency and UX

The target bottle Security panel shows trust mode, network controls, explicit read-only/read-write shares and recent denials. Denials must be distinguishable from ordinary compatibility failures. Sharing is explicit and defaults to read-only. Honest limits accompany Untrusted mode; no antivirus or perfect-safety claim is allowed.

The current setup UI exposes installation/verification progress and errors, keeps consents unchecked, and never equates installed metadata with launch readiness. No bottle Security panel exists yet.

## 4. Red-team validation plan

The future suite uses harmless synthetic probes, not malware. These checks apply to the actual Windows-launch boundary once implemented, not to the installer alone.

| # | Probe | Expected |
|---|---|---|
| 1 | Access sensitive home data such as SSH keys, Keychains and browser profiles | Denied |
| 2 | Write outside the approved bottle/shares, including LaunchAgents | Denied |
| 3 | Access another bottle | Denied |
| 4 | Execute unapproved host binaries | Denied |
| 5 | Delegate host-app launches through LaunchServices/Apple Events | Denied |
| 6 | Network traffic with network disabled | Denied |
| 7 | Repeat access checks without relying on Wine's APIs | Denied |
| 8 | Follow an external-pointing bottle symlink | Denied |
| 9 | Query the host Keychain | Denied |
| 10 | Register persistent host startup items | Denied |
| 11 | Outlive the controlled program/bottle lifecycle | Stopped and cleaned according to mode |
| 12 | Normal graphics/audio/controller/clipboard and intended Steam workloads | Still function within documented permissions |

Native preliminary tests and later Windows integration must record OS, runtime and actual outcomes. The current unit suite instead tests the installer's consent, path/link, staging and integrity boundaries; it does not satisfy this table.

## 5. Hardening roadmap

| Version | Security milestone |
|---|---|
| Current preview | Pinned archive checks, bounded installation, root ownership and local integrity reports; no Windows execution |
| v0.1 | Prefix hardening and a tested launch sandbox; pinned interim runtime validation |
| v0.2 | Signed catalog/manifest system, Untrusted clones, network controls, trust prompts and denial handling |
| v0.3 | Harmless launch-boundary validation in CI, autostart monitoring and security UI |
| v0.5 | Measured allow-list profiles with the minimal required services/paths |
| v1.0 | External review, published threat-model evidence and advisory process |

## 6. Honest limitations

Mallow is not an antivirus. Kernel, GPU-driver and Rosetta vulnerabilities can in principle break a sandbox. A persistent bottle's data is exposed to programs inside it, and user-shared data is reachable according to the chosen permissions. A compatibility-oriented deny-list is not equivalent to a measured allow-list. All these remain design concerns for the future launch implementation.

The installed-file receipt is unsigned and local; same-user malicious software can potentially change both it and runtime files. Ownership markers and advisory locks coordinate well-behaved Mallow operations, not isolate hostile same-user processes. The preview cannot safely run a suspicious executable because it has no Windows execution feature. Compilation, archive installation and checksum success do not establish that boundary or game compatibility.

## 7. Open questions

1. Minimal services and system paths for Wine's Mac driver, Metal, CoreAudio and controllers under a deny-by-default profile.
2. Whether blocking delegation services breaks intended GUI or embedded-browser behavior.
3. Exact per-bottle wineserver socket needs for network-off operation.
4. Supported launch-sandbox mechanism and reliable diagnostics across macOS versions.
5. Clipboard policy for Untrusted mode.
6. Installer crash recovery, authenticated integrity baselines, repair/rollback and supported-filesystem durability/performance measurements.
