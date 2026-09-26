---
# SPDX-License-Identifier: 0BSD
description: Help test and build Mallow's development preview, finish the core models, and keep tests, documentation and the roadmap synchronized.
---

# Contributing

Mallow has moved beyond a document-only repository: the initial library and setup preview now build. The complete runtime, bottle, launch and sandbox features remain unfinished. The current work is in the [roadmap](../roadmap.md) and [bootstrap addendum](../BOOTSTRAP.md).

## Start here

Read the [complete contributor guide](https://github.com/mixutin/Mallow/blob/main/CONTRIBUTING.md), then the [development setup](dev-setup.md) and [architecture tour](architecture-tour.md). For testing rather than coding, use the [Mac preview checklist](../development-preview.md). The [writing guide](writing-docs.md) explains site and devlog conventions.

## The ground rules

Be kind and follow the Code of Conduct. Reference an issue for substantial work, use the correct file licence and sign off your own contributions with the DCO. Never copy GPL frontend implementations or proprietary CrossOver files. Source every new environment/registry/DLL rule. Do not commit vendor binaries or real malware. Report security vulnerabilities privately through SECURITY.md.

Every change includes applicable tests and a review of README, changelog, roadmap and affected website pages. Explain genuine no-impact areas in the PR. Current documentation must distinguish working code, CI evidence and user-Mac testing. Dated devlog posts remain historical records.

The complete security review, governance and licensing requirements are in CONTRIBUTING.md and GOVERNANCE.md. Owner-delegated AI work is not an independent reviewer, second release maintainer or fabricated human DCO certification.

## Where help is needed now

| Work | Start here |
|---|---|
| Test the native app on a Mac | [Preview guide](../development-preview.md) and [issue #42](https://github.com/mixutin/Mallow/issues/42) |
| Finish model and wire-format coverage | [WF0 issue #9](https://github.com/mixutin/Mallow/issues/9) and DESIGN.md §3.4/§3.7 |
| Safe runtime activation and dependencies | [Bootstrap boundary](../BOOTSTRAP.md) and the next-work roadmap |
| Verify assumptions | DESIGN.md §11; record the actual platform and result |
| Build the secure launch pipeline | The planned security model and its unverified integration work |
| Documentation and accessibility | Current preview pages, setup controls and test reports |

## Changing the design

Do not silently change normative APIs, persisted formats, security defaults or release gates. Include the corresponding design proposal/update and follow the governance process. The early preview's explicitly limited interfaces are recorded in BOOTSTRAP.md; they do not replace the complete future architecture.

## Getting help

Ask in [GitHub Discussions](https://github.com/mixutin/Mallow/discussions), open a reproducible [issue](https://github.com/mixutin/Mallow/issues), or read the [full contribution rules](https://github.com/mixutin/Mallow/blob/main/CONTRIBUTING.md).
