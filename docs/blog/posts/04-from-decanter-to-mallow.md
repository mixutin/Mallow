---
# SPDX-License-Identifier: 0BSD
date: 2026-09-23
authors:
  - mixutin
categories:
  - Project
slug: from-decanter-to-mallow
description: Why the working name Decanter became Mallow, why name clashes matter, and how we use the CrossOver trademark only descriptively.
---

# The name: from Decanter to Mallow

A short post, but an important one. In the first draft of our design, this project was called **Decanter**. It's now **Mallow**. Here's why, and why we care about names more than you might expect.

<!-- more -->

## Why not Decanter

Wine tools love wine puns, and "Decanter" sat nicely next to "bottles". Unfortunately, it was taken. During review we found an active open-source project called [Decanter](https://github.com/ricardothesillyllama/Decanter) with the same purpose as ours: running Windows games on Apple Silicon Macs. It's GPL-3.0, was created in August 2026, and released v0.9.1 the day before we checked. Its Swift package even declares the same target names as our first draft. A reviewer also reported that it uses the same data folder we had planned. We didn't re-check that part, but it would have been the worst clash of all.

"Decanter" is also a wine-magazine brand. Two strikes.

If you were looking for that project, it's linked above. We wish it well.

## Why names matter

A name clash is more than awkward branding:

- **People get confused.** Search results, package names and bug reports end up in the wrong place.
- **Software can collide.** Mac apps usually keep their data in a folder named after the app under `~/Library/Application Support`. Two Wine frontends sharing one could quietly read and write each other's bottles and runtimes.
- **Trademarks are real.** Taking a name someone already uses in the same field invites a forced rename later, when it costs far more.

So we changed it now, while Mallow is still only a design.

## Why Mallow

"Mallow" was already in our `LICENSE` file and our security model draft. It's short, easy to say, and not already the name of a Mac app that runs Windows software. On 2026-09-23 we checked GitHub, Homebrew and both App Stores and found no conflict in our category. Some unrelated apps and a software company use the word, but in other fields.

It isn't fully cleared yet. Formal trademark searches (USPTO and EUIPO) and a lawyer's opinion are an exit criterion for our first milestone, which comes before any code. If they fail, we have a pre-checked fallback name. Either way, a rename should be mechanical: every product identifier will come from one place in the code. Mallow will also refuse to take over an existing data folder that doesn't carry its own marker file, so even an app that happens to pick the same folder name can't have its bottles touched.

If you still see "Decanter" in an old draft or a folder name, that's why.

## Trademark hygiene around CrossOver

"CrossOver" is a CodeWeavers trademark, so we only use it descriptively. Mallow is "an open-source alternative to CrossOver", and never anything that could pass for a CrossOver product. The same goes for "CodeWeavers", "CX", "Whisky" and "WineHQ": none of them will appear in product names, runtime IDs, bundle identifiers, UI labels or marketing. We use "Wine" only to describe what Mallow is built on.

Our runtime will be called "Mallow Runtime", described as "based on Wine 11.0". Where attribution is needed for provenance or licence compliance, we state the facts plainly, for example "Wine sources from CodeWeavers' LGPL source release 26.3.0".

One more detail: the crash dialog in CodeWeavers' published Wine source sends people to CodeWeavers' support pages. One of our three small runtime patches points it at our own issue tracker instead. Problems with Mallow should land with us, not with them.
