<!-- SPDX-License-Identifier: 0BSD -->

# Repository maintenance instructions

These instructions apply to the whole Mallow repository. Read `CONTRIBUTING.md`, `ROADMAP.md`, `docs/DESIGN.md` and `docs/SECURITY_MODEL.md` before changing the relevant area.

## Work on the owner's behalf

The repository owner delegates implementation and routine maintenance work to the assistant. Use the authorized `mixutin/Mallow` connection for this repository. Make concrete, tested changes rather than presenting plans as completed work. Owner-authorized merges may be performed after inspecting the exact PR head and its checks; never bypass branch protections or invent approvals. AI assistance does not create a second independent maintainer, reviewer, signing-key custodian or human DCO certification. Do not change governance, security guarantees or release gates merely to make a check pass.

## Documentation is part of every change

For every change, review and update these together before it is considered complete:

- `CHANGELOG.md`: what changed, with remaining limitations.
- `ROADMAP.md`: actual implementation progress and the next unfinished work. Do not mark a milestone complete unless its exit criteria are met.
- `README.md`: current status, available features and working commands.
- Relevant pages under `docs/`, including the home page and developer setup when status or commands change. `docs/roadmap.md` embeds the root roadmap; preserve that single source of truth.
- `docs/DESIGN.md` when changing normative APIs, wire formats or planned source ownership; `docs/SECURITY_MODEL.md` when security behavior changes.

Keep current pages consistent. Preserve dated devlog posts as history; publish a new progress post for a meaningful milestone rather than rewriting old announcements. For a surface genuinely unaffected by a change, record the no-impact reason in the PR instead of adding misleading progress or meaningless edits.

## Validate, merge and verify publication

Run the applicable tests and `mkdocs build --strict` when available. If a local tool or platform is unavailable, state that and inspect the CI result instead; never claim an unrun check passed. Review diffs for accidental deletions and keep unrelated code intact.

For an authorized merge, check the exact head SHA and required statuses, merge without force, then verify the resulting `main` commit. Documentation is published by `.github/workflows/docs.yml` on relevant pushes to `main`. Inspect both the strict build and the GitHub Pages deployment before saying the website is deployed. A green PR documentation build is not a deployment. Do not modify permissions or release workflows just to work around a missing local tool.

Keep unfinished issues open. Do not claim a library model enforces a sandbox, or that a package builds an executable target which does not exist. Do not promise unattended maintenance or future work outside an explicitly configured automation.
