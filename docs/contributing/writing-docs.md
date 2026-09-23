---
# SPDX-License-Identifier: 0BSD
description: How Mallow's docs site and devlog are organised, the front matter for devlog posts, the Markdown features you can use, and the writing style guide.
---

# Writing docs and devlog posts

Good docs matter as much as good code, and you don't need to know Swift to write them. This page explains how the site is put together, how to write a devlog post, and the house style.

## How the site is organised

The site at [mixutin.github.io/Mallow](https://mixutin.github.io/Mallow/) is built from the `docs/` folder with [MkDocs](https://www.mkdocs.org/) and [Material for MkDocs](https://squidfunk.github.io/mkdocs-material/). The configuration, including the navigation, is `mkdocs.yml` in the repository root.

| Section | Source | Web address |
|---|---|---|
| Home | `docs/index.md` | `/Mallow/` |
| How it works | `docs/how-it-works.md` | `/Mallow/how-it-works/` |
| Getting started | `docs/getting-started.md` | `/Mallow/getting-started/` |
| Devlog | `docs/blog/` (index page, posts and `.authors.yml`) | `/Mallow/blog/` |
| Roadmap | `docs/roadmap.md`, the site copy of the root `ROADMAP.md` | `/Mallow/roadmap/` |
| Design | `docs/DESIGN.md` and `docs/SECURITY_MODEL.md` | `/Mallow/DESIGN/` and `/Mallow/SECURITY_MODEL/` |
| Contributing | `docs/contributing/` | `/Mallow/contributing/` |
| FAQ | `docs/faq.md` | `/Mallow/faq/` |
| Legal & licensing | `docs/legal.md` | `/Mallow/legal/` |

Other things to know:

- **Root-level files** (`README.md`, `CONTRIBUTING.md`, `SECURITY.md` and so on) are written for GitHub. They are not pages on the site. They must use **absolute links** (`https://github.com/mixutin/Mallow/blob/main/…` or `https://mixutin.github.io/Mallow/…`), because they can also be embedded in site pages (see [Embedding a root-level file](#embedding-a-root-level-file)).
- **DESIGN.md and SECURITY_MODEL.md** are the design's source of truth. They follow their own review process ([Changing the design](index.md#changing-the-design)). Don't reword them as part of a docs clean-up.
- **The docs are 0BSD**, like the code. Contributions need a DCO sign-off (`git commit -s`), the same as code.
- **Publishing is automatic.** `.github/workflows/docs.yml` builds the site in strict mode on every pull request, and publishes it to GitHub Pages when a change reaches `main`.

## Adding or changing a page

1. Create or edit a Markdown file under `docs/`.
2. Start it with front matter that holds the SPDX licence line (as a YAML comment) and an optional `description` (used by search engines and link previews), then exactly one `#` heading:

    ```markdown
    ---
    # SPDX-License-Identifier: 0BSD
    description: One sentence that says what this page is for.
    ---

    # Page title
    ```

    The SPDX line goes inside the front matter, not in an HTML comment above the heading. MkDocs only takes a page's title from its `#` heading when that heading comes first.

3. Add a new page to `nav` in `mkdocs.yml`. The strict build fails on a page that isn't in the navigation.
4. Preview it with `mkdocs serve`, and check it with `mkdocs build --strict` (see [Development setup](dev-setup.md#6-preview-the-docs-site)).

### Links

- **Between pages, link to the Markdown file with a relative path:** `[the FAQ](../faq.md)`. MkDocs turns it into the right web address and checks that it exists.
- **To a heading, add its anchor:** `[exit codes](../DESIGN.md#383-exit-codes)`. To find an anchor, hover over the heading on the site and copy the link from the ¶ symbol. The strict build fails on an anchor that doesn't exist.
- **To a file outside `docs/`** (for example `CONTRIBUTING.md` or source code), use its full GitHub address.
- **To other websites**, use `https://` links. Plain web addresses in the text are turned into links automatically.

### Embedding a root-level file

To show a root-level file on a page without copying it, put a snippet line on a line of its own. In this page's Markdown source the line starts with a `;`, which stops the example itself from being embedded. Leave that `;` out in yours.

```markdown
;--8<-- "ROADMAP.md"
```

Paths are relative to the repository root, and a missing file fails the build. The embedded file brings its own `#` heading, so the page shouldn't add another one.

## Writing a devlog post

The [devlog](../blog/index.md) is where we share progress, decisions, research and things that didn't work out. Anyone can propose a post.

### 1. Create the file

Create a file in `docs/blog/posts/`, named like the existing posts: the next number, then a short slug (for example `05-first-runtime-build.md`). The file name only helps you find the post and keeps posts from the same day in order. The web address comes from the date and the slug in the front matter.

### 2. Add the front matter

```markdown
---
# SPDX-License-Identifier: 0BSD
date: 2026-10-01
authors:
  - mixutin
categories:
  - Project
slug: first-runtime-build
description: One sentence for search results, link previews and the RSS feed.
draft: true
---

# Our first runtime build

One or two sentences that sum up the post. They appear on the devlog's index page and in the RSS feed.

<!-- more -->

The rest of the post.
```

| Field | Required | Notes |
|---|---|---|
| `date` | Yes | Use the one-line form, `date: YYYY-MM-DD`. The RSS feed reads it. The longer `date:` / `created:` form works for the blog pages, but the feed can't read it and would show the build date instead. |
| `authors` | Yes | IDs from `docs/blog/.authors.yml`. An unknown ID fails the build. |
| `categories` | Yes | One or two. Reuse an existing one if you can: **Announcements**, **Roadmap**, **Project**, **Security**, **Licensing**, **Contributing**. Add a new category only when none fits. |
| `slug` | Recommended | Short, lowercase, words joined by hyphens. Without it, the slug comes from the title. |
| `description` | Recommended | One sentence, shown in link previews and the RSS feed. Put it in quotes if it contains a colon. |
| `draft` | Optional | `true` keeps the post out of the published site. It still shows in `mkdocs serve`. Remove the line when the post is ready. |

Posts dated in the future are treated as drafts until that date, so you can prepare a post ahead of time.

### 3. Add yourself as an author

If this is your first post, add yourself to `docs/blog/.authors.yml`, using your GitHub handle as the ID:

```yaml
authors:
  your-handle:
    name: Your Name
    description: Contributor
    avatar: https://github.com/your-handle.png
    url: https://github.com/your-handle
```

### 4. Check it and open a pull request

Preview the post with `mkdocs serve`. It appears on the devlog index, under its categories, and in the archive for its year. Run `mkdocs build --strict`, then open a pull request with the `devlog` label.

### After a post is published

- **Web addresses are permanent.** A post lives at `/Mallow/blog/YYYY/MM/DD/slug/`. Don't change its `date` or `slug` after it is published, or links to it break.
- **Corrections are welcome.** Fix typos quietly. For a change in substance, add a short, dated **Update** note at the top, so readers can see what changed.
- **The RSS feed** is at [`/Mallow/feed_rss_created.xml`](https://mixutin.github.io/Mallow/feed_rss_created.xml).

### What makes a good devlog post

- **One topic per post.** Aim for a 5-minute read. Split it if it grows.
- **Honest status.** What works, what is planned and what failed, and why. Failures and dead ends make good posts.
- **Show your sources.** Link to the DESIGN.md section, the upstream issue or the test that backs a claim.
- **Write for a curious Mac user,** not only for Wine experts. Explain each term once, or link to [How it works](../how-it-works.md).

## Markdown you can use

Beyond standard Markdown, the site supports these extensions.

**Admonitions** (call-out boxes). The types we use most are `note`, `info`, `tip`, `warning` and `danger`. A `???` instead of `!!!` makes a box that the reader can expand:

```markdown
!!! warning "Planned, not built"

    This feature is planned for v0.4.
```

**Diagrams** with [Mermaid](https://mermaid.js.org/). Keep them small, and label every arrow:

````markdown
```mermaid
flowchart LR
    exe["game.exe"] -- "Direct3D 11" --> dxmt["DXMT"] -- "Metal" --> gpu["GPU"]
```
````

**Code blocks** always name their language, for example `sh`, `swift`, `json` or `yaml`. Every block gets a copy button. Show commands without a `$` prompt, so that they paste cleanly, and put any explanation in a `#` comment.

**Tables**, **footnotes**, **definition lists**, **task lists**, **content tabs** (`=== "Tab"`), keyboard keys (`++cmd+q++`), highlighting (`==text==`) and **icons** (`:material-shield-lock:`) are also available. The [Material for MkDocs reference](https://squidfunk.github.io/mkdocs-material/reference/) shows the syntax for each.

## Style guide

**Voice**

- Plain English. Short sentences. Friendly and concise. No hype, and no marketing superlatives.
- Say "you" to the reader and "we" for the project.
- Explain a technical term the first time you use it, or link to where it is explained.
- Use descriptive link text, like "see the [FAQ](../faq.md)", never "click here".

**Honesty**

- **Be clear about status.** Mallow is pre-alpha and nothing is built yet. Say "planned", "in design" or "will" for anything that doesn't ship yet, and never describe a planned feature as if it works today.
- **Security claims need care.** Write "designed to" and "planned", and mention the limits. Never promise that something is completely safe. No sandbox is perfect, and the [security model](../SECURITY_MODEL.md) says so.
- **Facts match the design.** Numbers, versions and names should match DESIGN.md exactly. Link to the section rather than restating long details.

**Names and spelling**

- **Mallow** is the product, the **Mallow Runtime** is our Wine build, **MallowKit** is the library, and `mallow` (in code font) is the command-line tool.
- Write **Apple Silicon**, **macOS**, **Wine**, **Rosetta 2**, **D3DMetal**, **DXMT**, **DXVK**, **MoltenVK** and **wined3d** exactly like that.
- **"CrossOver" is a trademark of CodeWeavers.** Use it only descriptively, as in "an open-source alternative to CrossOver". Never use it as part of a name or title for anything of ours, and never suggest that Mallow is connected to CodeWeavers. The same goes for "Whisky" and "WineHQ".
- Be generous about other projects. Credit their ideas, and never run them down.
- We use **British spelling**, like DESIGN.md: "licence" (noun), "license" (verb), "behaviour", "organise". Proper names keep their own spelling, such as "BSD Zero Clause License" or the `LICENSE` file.
- Headings use sentence case: "How it works", not "How It Works".

**Formatting**

- Use emoji sparingly. On the site, prefer an admonition or an icon.
- Only add images you made yourself or that are openly licensed, and say where they came from. Prefer small SVGs, and always add alt text.
- Use `example.com` addresses and made-up names in examples. Never use real personal data.

## Before you open a pull request

- [ ] `mkdocs build --strict` passes.
- [ ] Every new page is in `nav`, has the SPDX line in its front matter, and has one `#` heading.
- [ ] Planned features are described as planned.
- [ ] Links are relative inside `docs/`, and absolute in root-level files.
- [ ] Every commit is signed off (`git commit -s`).

## A note on the site generator

Material for MkDocs went into maintenance mode in November 2025. Its maintainers are building a successor called [Zensical](https://zensical.org/), and they promised Material critical bug and security fixes for at least 12 months from then. We use Material because it is stable, and because its built-in blog plugin runs our devlog. Zensical is designed to read `mkdocs.yml` as it is, and it added a port of the blog plugin in September 2026. When that has matured, moving should be a small, separate pull request. The versions in `requirements-docs.txt` are pinned, so nothing changes until we choose to.
