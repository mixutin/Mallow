---
# SPDX-License-Identifier: 0BSD
description: Help test Mallow's runtime installer, measure performance, complete the secure launch pipeline and maintain English/Finnish documentation.
---

# Contributing

Mallow now has a runtime-installation/verification preview. The complete runtime lifecycle, multimedia setup, bottle/launch and kernel-sandbox features remain unfinished. See the [roadmap](../roadmap.md), [bootstrap addendum](../BOOTSTRAP.md) and [installer design](../runtime-installation.md). [Osallistumisohje suomeksi](https://mixutin.github.io/Mallow/fi/contributing/).

## Start here

Read [CONTRIBUTING.md](https://github.com/mixutin/Mallow/blob/main/CONTRIBUTING.md), [development setup](dev-setup.md) and [architecture tour](architecture-tour.md). Testers should use the [Mac checklist](../development-preview.md); documentation contributors should read [writing docs](writing-docs.md).

## The ground rules

Be kind. Reference substantial work, use the correct licence and sign off your own contributions truthfully. Never copy GPL frontend implementations, proprietary CrossOver files or vendor payloads into the project. Cite new environment/registry/DLL rules. Use harmless synthetic tests, not real malware. Report security vulnerabilities privately.

Every change reviews tests, README, CHANGELOG, ROADMAP and affected `docs/` and `docs-fi/` pages. Separate implementation, automated evidence, publication and actual Mac tests. Keep dated posts historical. Performance work needs measurement or explicit implementation-level wording; speed never excuses skipped checks or weaker security defaults.

Security/governance review rules remain in CONTRIBUTING.md and GOVERNANCE.md. Owner-directed AI work is not a second independent reviewer, maintainer or DCO certification.

## Where help is needed now

| Work | Starting point |
|---|---|
| Actual-Mac setup, accessibility and performance | [Preview tests](../development-preview.md), [#44](https://github.com/mixutin/Mallow/issues/44) |
| Model/format completeness | [WF0 #9](https://github.com/mixutin/Mallow/issues/9), DESIGN.md §3.4/§3.7 |
| Capabilities, media dependencies and lifecycle | [Installer boundary](../runtime-installation.md), the open roadmap tasks |
| Secure bottle/launch pipeline | Security model and its unverified integration work |
| Finnish/English docs and loader behavior | Both user-site trees and generated-output checks |
| Assumption verification | DESIGN.md §11, with actual hardware/OS/result |

## Changing the design

Do not silently redefine normative APIs, persisted formats, security defaults or release gates. Document proposals and staged exceptions, preserve completed/unfinished distinctions, and follow the review process. Early setup interfaces do not replace the full target architecture.

## Getting help

Use [Discussions](https://github.com/mixutin/Mallow/discussions), reproducible [issues](https://github.com/mixutin/Mallow/issues) and the [full rules](https://github.com/mixutin/Mallow/blob/main/CONTRIBUTING.md). Sensitive reports belong in the private security channel.
