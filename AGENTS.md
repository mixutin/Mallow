<!-- SPDX-License-Identifier: 0BSD -->

# Repository maintenance instructions

Applies to all of Mallow. Read CONTRIBUTING.md, ROADMAP.md, docs/DESIGN.md, docs/BOOTSTRAP.md, docs/runtime-installation.md and the security model for the relevant area before changing it.

## Work on the owner's behalf

The owner delegates implementation and routine maintenance to the assistant. Use the authorized `mixutin/Mallow` connection. Make concrete tested changes. Owner-authorized merges require exact-head checks; never bypass branch protections or invent approvals. AI assistance is not a second independent maintainer, reviewer, signing-key custodian or human DCO certification. Do not change governance, security guarantees or release gates merely to make checks pass.

## Performance and security are acceptance requirements

Keep hashing, extraction and scanning off the UI's main actor. Use bounded inputs/buffers, explicit cancellation and useful progress. Do not rehash large runtimes at every startup or flood UI updates. Loaders indicate actual work, do not impose delays, respect reduced motion and stop when idle.

Never trade correctness or security silently for speed: do not skip checksums, trust arbitrary URLs/archives, accept partial installation, overwrite foreign state or weaken sandbox defaults. Describe trust boundaries honestly. A local receipt is not an authenticated trust root; installed metadata is not a fresh integrity check; Wine installation is not Windows-launch readiness. Measure startup/RSS/throughput and later game FPS before making performance claims. Record workload, source revision, hardware and OS.

## Documentation is part of every change

Review/update README.md, CHANGELOG.md, ROADMAP.md and affected pages under both `docs/` and `docs-fi/` with the code. Check off implemented/tested subfeatures; do not mark a milestone finished until its exit criteria pass. Keep separate lists for implementation, CI evidence and actual-Mac acceptance.

`docs/roadmap.md` embeds the root English roadmap; preserve this single source. `docs-fi/roadmap.md` is an explicitly translated summary and must be updated alongside it. Full app/technical-document localization remains unfinished unless actually done. Preserve dated devlog posts; add a new post for meaningful progress. Record genuinely unaffected surfaces in the PR instead of inventing changes.

Update DESIGN.md for normative API/format changes; early staging exceptions and file ownership are documented in BOOTSTRAP.md and runtime-installation.md. Security-model changes must remain explicit. Never describe planned protection as implemented merely because a configuration type exists.

## Validate, merge and verify publication

Run applicable tests and `scripts/build-docs.sh` for **both** strict language builds and generated-output checks. The isolated network check `scripts/test-runtime-install.sh` installs the real pinned archive but never executes Wine; unit tests remain offline. Record unavailable tools/platforms honestly and inspect CI instead. Review the full diff for accidental deletions.

For authorized merges, inspect exact head/checks, merge without force and confirm the resulting main commit. App builds publish commit-addressed development prereleases only after their checks. Inspect assets before claiming a downloadable release. Docs publish one bilingual Pages artifact; inspect both strict builds and the deployment. A green PR build is neither a publication nor a real-Mac GUI/game test.

Keep unfinished issues open. Do not promise unattended work outside an explicitly configured automation. Do not modify permissions merely to work around a missing local tool.
