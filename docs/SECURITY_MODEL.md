# Mallow Security Model

> Status: **Design (draft)**. Part of the Mallow design; see `DESIGN.md` for the overall architecture.
> Items marked 🧪 still need to be validated by the red-team test suite before they ship.

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

**Security invariant:** a process launched by Mallow can read and write only (a) its own bottle, (b) the read-only runtime, (c) the system files it needs to run, and (d) folders the user has explicitly shared with that bottle. This applies whether it goes through Wine or not.

## 3. Defense layers

Security comes from layer 1. Layers 2–5 reduce the attack surface and make accidents less likely, but **no layer except the kernel sandbox is a real security boundary.**

### Layer 1: Kernel sandbox (the real boundary)

Every Wine process (`wine`, `wineserver`, `wine-preloader`, and all their children) runs under a macOS **Seatbelt sandbox profile** that Mallow generates for each bottle, using `sandbox-exec -f <profile>` or a small launcher helper that calls `sandbox_init`. The kernel enforces it, so it applies even to programs that make raw syscalls and bypass Wine. Child processes inherit it and can't remove it.

**Verified on macOS 26.5 / Apple M4 (2026-09-23):**

| Test | Result |
|---|---|
| Sandboxed process writes to a denied folder | ❌ `Operation not permitted` (kernel-enforced) |
| Sandboxed process opens an outbound network connection with network denied | ❌ Blocked (DNS resolution fails, no connection) |
| x86_64 binary via Rosetta 2 runs inside the sandbox | ✅ Works |

**Profile shape (sketch):**

```scheme
(version 1)
(allow default)                                   ; v1: deny-list for compatibility; see "Hardening roadmap"

;; --- Files: hide the home folder, then re-allow only what the bottle needs ---
(deny file-read* file-write* (subpath (param "HOME")))
(allow file-read* (subpath (param "RUNTIME_DIR")))              ; Wine + graphics backends, read-only
(allow file-read* file-write* (subpath (param "BOTTLE_DIR")))   ; this bottle only
(allow file-read* file-write* (subpath (param "BOTTLE_TMP")))   ; per-bottle temp dir
;; user-approved shares are emitted here, e.g.:
;; (allow file-read* (subpath "/Users/me/Games/ISOs"))                   ; read-only share
(allow file-read* (literal (string-append (param "HOME") "/Library/Preferences/.GlobalPreferences.plist")))  ; 🧪 needed by AppKit?

;; --- Never writable, even if shared by mistake ---
(deny file-write* (subpath (string-append (param "HOME") "/Library/LaunchAgents")))
(deny file-write* (subpath "/Library/LaunchAgents") (subpath "/Library/LaunchDaemons"))

;; --- Process execution: only the runtime's own binaries ---
(deny process-exec*)
(allow process-exec* (subpath (param "RUNTIME_DIR")))           ; 🧪 plus whatever Rosetta needs

;; --- Escape hatches that launch things OUTSIDE the sandbox ---
(deny appleevent-send)                                          ; no AppleScript/osascript control of other apps
(deny mach-lookup (global-name "com.apple.coreservices.launchservicesd"))  ; 🧪 blocks `open`/LaunchServices, may affect AppKit
(deny mach-lookup (global-name "com.apple.SecurityServer"))    ; 🧪 no Keychain access
(deny mach-lookup (global-name "com.apple.backgroundtaskmanagementagent")) ; 🧪 no login items

;; --- Network: per-bottle toggle (emitted only when network is OFF) ---
;; (deny network*)
;; (allow network* (local unix-socket (path-regex #"^/private/tmp/\.wine-")))  ; 🧪 keep wineserver's socket working
```

Notes:
- In SBPL, later rules take precedence, which is how "deny home, then allow the bottle" works. Bottles live under `~/Library/Application Support/Mallow/Bottles/<id>`, so the allow for the bottle must come after the deny for home.
- LaunchServices, Apple Events and background-task registration all **launch processes outside the sandbox**. Blocking them is required for the invariant.
- macOS privacy controls (TCC) are a second net. Screen recording, keystroke monitoring, camera and microphone still need the user's approval in System Settings, and keystrokes are only delivered to a program's own windows.
- `sandbox-exec` is marked deprecated by Apple but still works in macOS 26. The launcher helper calls the same underlying API, so if the CLI is ever removed, only the helper needs to change.

### Layer 2: Wine prefix hardening (applied when a bottle is created)

| Stock Wine | Mallow default |
|---|---|
| `dosdevices/z:` → `/` | **Removed.** Shared folders get their own drive letters (`s:`, `t:` …) |
| `Documents`, `Desktop`, `Downloads`, `Music`, `Pictures`, `Videos` are symlinks into `$HOME` | **Real folders inside the bottle** (like winetricks' `isolate_home`) |
| `winemenubuilder.exe` creates Mac file associations and menu entries | **Disabled** (`winemenubuilder.exe=d` DLL override) |
| `winebrowser` / `start /unix` / `ShellExecute` can open native Mac apps and URLs | **Disabled** (`winebrowser.exe=d`). Opening URLs goes through a Mallow prompt ("Program wants to open https://… — Open / Copy / Deny") 🧪 |
| Registry `Run` / `RunOnce` / Startup folder run silently at every launch | **Watched.** Mallow lists autostart entries and alerts when a new one appears |

### Layer 3: Trust levels per launch

| Mode | Files | Network | Bottle | When |
|---|---|---|---|---|
| **Standard** (default) | Bottle + explicit shares | On (toggle) | Persistent | Games, Steam, known apps |
| **Untrusted** | Bottle only, no shares | **Off** | **Disposable APFS clone**, deleted when the program exits | Suspicious downloads, cracked or unknown tools, "just checking what this does" |
| **Offline** | Bottle + shares | Off | Persistent | Single-player games, old apps that don't need the internet |

**Disposable bottles:** Mallow clones a clean template bottle with APFS `clonefile(2)`. This is instant and copy-on-write, so it uses almost no extra disk. The program runs in the clone under the Untrusted profile, and the clone is deleted when the program exits. The user can choose "Keep this bottle" before closing it.

**Default choice:** when the user runs an `.exe` or `.msi`, Mallow checks:
- whether it still carries macOS's `com.apple.quarantine` flag (downloaded from the internet), and where from;
- whether it has a valid Authenticode signature, and the publisher name if so.

Unsigned files from the internet default to **Untrusted**, and the dialog shows why ("Unsigned · downloaded from Safari 3 minutes ago").

### Layer 4: Supply-chain integrity (Mallow's own downloads)

- Each runtime component (Wine build, DXVK, DXMT, MoltenVK, dependency packs) is listed in a **signed manifest**: an Ed25519 signature checked with CryptoKit against a public key pinned inside the app, plus a SHA-256 hash per file.
- HTTPS only. A hash or signature mismatch is a hard failure, with no "install anyway" button.
- Dependency verbs (vcredist, d3dcompiler_47, fonts …) are **declarative**: URL + SHA-256 + install steps. Mallow never downloads and runs a script from the internet.
- Mallow removes the quarantine flag from runtime files **only after** verifying them, so users don't get Gatekeeper popups without Gatekeeper being turned off.
- Official runtime builds come from public CI (GitHub Actions) using the published Wine sources, so anyone can reproduce and audit them.
- D3DMetal is never downloaded or bundled by Mallow. The user supplies it from Apple, and Mallow records its hash on import.

### Layer 5: Transparency and UX

- Every bottle shows a **Security** panel: trust mode, network on/off, shared folders (read-only or read-write), and recent sandbox denials ("Blocked: tried to read ~/.ssh/id_ed25519").
- Denials are logged, not silent, so users can tell "the game broke because of the sandbox" apart from "the game is broken".
- Sharing a folder is always explicit, per bottle, and read-only by default.
- The first time Untrusted mode is used, it shows a one-line honest disclaimer: *"Reduces risk a lot, but no sandbox is perfect. Don't run things you know are malware on a Mac with important data."*

## 4. Red-team validation plan

A test suite (`Tests/SecurityTests` + `scripts/redteam/`) checks the invariant on every release. It uses **harmless probe programs** that try to escape and report the result. No real malware is involved.

| # | Probe | Expected |
|---|---|---|
| 1 | Read `~/.ssh/*`, `~/Library/Keychains`, browser profile dirs | Denied |
| 2 | Write to `~/Desktop`, `~/Documents`, `~/Library/LaunchAgents` | Denied |
| 3 | List or read another bottle | Denied |
| 4 | `exec /bin/sh`, `/usr/bin/osascript`, `/usr/bin/open` | Denied |
| 5 | Launch an app via LaunchServices / Apple Events | Denied |
| 6 | Outbound TCP/UDP/DNS with network off | Denied |
| 7 | Same probes issued as **raw syscalls from PE code** (bypassing Wine) | Denied |
| 8 | Symlink inside the bottle pointing to `~/.ssh`, then read through it | Denied (the kernel checks the resolved path) |
| 9 | Keychain query via Security framework | Denied |
| 10 | Register a login item or launch agent | Denied |
| 11 | Survive after the program exits (daemonize, re-parent) | Killed with the bottle's wineserver; disposable bottle deleted |
| 12 | Normal workloads: Steam login + download, a DX11 game via D3DMetal/DXMT, audio, controller, clipboard | **Still work** (a sandbox that breaks games won't get used) |

The probes are built first as native macOS binaries (quick to iterate), then as Windows PE binaries run through Wine in CI.

## 5. Hardening roadmap

| Version | Security milestone |
|---|---|
| v0.1 | Layer 2 prefix hardening, signed runtime manifest, `sandbox-exec` deny-list profile with home-folder isolation |
| v0.2 | Untrusted mode with disposable APFS clones, network toggle, quarantine/Authenticode trust prompt, denial log UI |
| v0.3 | Red-team suite in CI, including raw-syscall PE probes; autostart watcher |
| v0.5 | Move from **deny-list (`allow default`) to allow-list (`deny default`)** profiles, with the minimal set of mach services and system paths games need, measured by the compatibility suite |
| v1.0 | External security review; published threat-model doc; security advisory process (`SECURITY.md`) |

## 6. Honest limitations

- **Not an antivirus.** Mallow limits what a program can reach. It doesn't decide whether a program is malicious.
- **Kernel, GPU-driver and Rosetta vulnerabilities** can in principle break any sandbox. Keep macOS updated.
- **Standard-mode bottles are only as safe as what you put in them.** Malware running in your "Steam" bottle can steal the Steam session stored in that bottle. Use separate bottles for untrusted things, or Untrusted mode.
- **Shared folders are shared.** Anything you share read-write can be encrypted by ransomware running in that bottle.
- **The v1 profile is a deny-list.** It blocks the known escape routes but isn't as tight as an allow-list. Tightening it is on the roadmap (v0.5).

## 7. Open questions

1. Minimal set of mach services and system paths for `winemac.drv` + Metal + CoreAudio + GameController under `deny default` 🧪
2. Does blocking `launchservicesd` break AppKit window creation or Steam's embedded browser? 🧪
3. The exact socket path wineserver uses on macOS in Mallow's layout, for the network-off rule 🧪
4. Whether to use `sandbox-exec` directly or ship a tiny signed launcher that calls `sandbox_init` (better errors, no deprecated CLI)
5. Clipboard in Untrusted mode: block entirely, or allow only pasting into the program?
