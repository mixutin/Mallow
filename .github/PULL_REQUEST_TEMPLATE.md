## What does this change?

<!-- One or two sentences. Link the issue or Discussion, for example "Fixes #123" or "Refs #45". -->

## Why?

<!-- The problem this solves, or the design section it implements (for example "DESIGN.md §3.5"). -->

## How was it tested?

<!-- The commands you ran (for example `scripts/test.sh`), and your macOS version and Mac model if it matters. For docs, say whether you previewed the site. -->

## Security impact

<!--
Required. Does this touch the sandbox, trust modes, process spawning, the environment,
downloads, signatures, imports, recipes, the diagnostics bundle, the mallow:// URL scheme,
entitlements, CI or release signing? If so, explain what could go wrong and how this change
prevents it. Otherwise write "None".
Never describe an undisclosed vulnerability here. Report it privately (SECURITY.md).
-->

## Checklist

<!-- Tick what applies. Strike through (~~like this~~) any item that doesn't apply. See CONTRIBUTING.md for details. -->

- [ ] **DCO:** every commit is signed off (`git commit -s`).
- [ ] **Tests:** added or updated (unit, `fake-wine` integration or golden tests), with no network access in unit tests. `scripts/test.sh` and `scripts/lint.sh` pass.
- [ ] **Generated files:** regenerated where needed (golden files with `MALLOW_UPDATE_GOLDENS=1`, built-in recipes, third-party licences), in a separate commit, and every golden change is explained above.
- [ ] **Docs:** updated where behaviour changes, including DESIGN.md if this touches a normative section (§3.2, §3.4, §3.7) and SECURITY_MODEL.md if security behaviour changes. Anything that isn't shipped yet is described as "planned".
- [ ] **Licence:** new files carry an SPDX header. Nothing is copied from GPL projects (Whisky, Heroic, Bottles, Mythic and others) or from CrossOver. Any reused permissive code is recorded in `NOTICE` and `THIRD_PARTY_LICENSES.md`.
- [ ] **Provenance:** every new environment variable, registry key or DLL rule cites an open source in a code comment.
- [ ] **Clean room:** if I recently read a GPL implementation of the same thing, I've said so below, so a second maintainer can review it.
- [ ] **Security:** the "Security impact" section is filled in. If this change is security-sensitive, I understand it needs two approving reviews.

## Notes for reviewers

<!-- Anything else: open questions, follow-up work, or parts you'd like reviewers to look at closely. -->
