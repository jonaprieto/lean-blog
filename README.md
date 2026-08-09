# leanblog

[![CI](https://github.com/jonaprieto/lean-blog/actions/workflows/ci.yml/badge.svg)](https://github.com/jonaprieto/lean-blog/actions/workflows/ci.yml)
[![Lean 4](https://img.shields.io/badge/Lean%204-v4.32.2-6f42c1)](lean-toolchain)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)

LeanBlog is a Lean-aware publishing framework built on top of Verso. It is intended to make blogs,
documentation, module catalogues, and tutorials pleasant to author while preserving links from
Lean names to their generated HTML definitions. The CLI reads Verso's generated `xref.json`
automatically, while explicit target files remain available for external documentation.

## What it provides

Declaration destinations can be supplied explicitly when a target lives outside the generated
Verso documentation:

```lean
import LeanBlog

open LeanBlog

#eval (Target.mk "/api/Sum.html#decl-Sum" "Definition of `Sum`").href
-- "/api/Sum.html#decl-Sum"
```

The first authoring format is intentionally small:

```markdown
---
title: Sum in a post
date: 2026-08-07
authors: Jonathan Prieto-Cubides
tags: lean, tutorial
---

The [`PostSource`](lean:LeanBlog.PostSource) type represents a parsed post.
```

`lean:` links resolve through the generated Verso cross-reference index by default; an unresolved
declaration is a build error. Use `--targets targets.tsv` for declarations documented elsewhere.
See [the starter post](examples/posts/starter.lean.md), the [multi-post examples](examples/posts),
and the visual collection prototype.

Generated sites include a local full-text search; see [Search](#search) for the user-facing
behavior and build details.

The `leanblog` CLI uses [lean-argus](https://github.com/jonaprieto/lean-argus) for typed options,
derived help, shell completions, and terminal diagnostics. Runtime failures are rendered with the
workspace's `termcolor-diagnostics` stack instead of ad-hoc error strings.

## Quick start

```text
git clone https://github.com/jonaprieto/lean-blog
cd lean-blog
lake build
```

The first visual prototype is available at `examples/collection/index.html`. Build its local CSS
with:

```text
npm ci --prefix theme
npm run build:css --prefix theme
```

Then open `examples/collection/index.html` in a browser.

Build the example collection through Verso:

```text
lake exe leanblog init .
lake build leanblog
lake build :literateHtml
lake exe leanblog check examples/posts
lake exe leanblog build examples/posts
```

`leanblog init` is safe to rerun: it creates `posts/starter.lean.md` and `README.md` only when they
do not already exist, so it will not overwrite writing in progress.

The generated site is in `.lake/build/site`; open `.lake/build/site/index.html` after building the
stylesheet with the commands above. The homepage is the post archive, and individual posts are
nested below it. When `.lake/build/literate-html` exists, the build also copies the generated API
documentation to `.lake/build/site/api`.

## Search

`leanblog build` emits a `/search/` page and a compact search field in every generated page header.
The full-text index covers post titles, tags, headings, prose, mathematics, and fenced code. Verso's
Elasticlunr-compatible runtime provides stemming, weighted ranking, snippets, highlighting, and
lazy-loaded document buckets, so the site needs no search server or runtime API.

The header field is useful for quick navigation: type a query, move through results with the arrow
keys, and press Enter to open the selected post. Press `/` from page content to focus the field. The
full page at `/search/` keeps the query in the URL, shows result counts, and provides full-text and
domain filters, making searches bookmarkable and shareable.

The search assets are generated, not checked in. After building a site, its generated index can be
smoke-tested with:

```text
node tools/check-search.mjs .lake/build/site
```

The same check is run for the GitHub Pages output in CI. When the local Verso documentation build is
available, Lean declaration search uses the generated `xref.json` alongside post full-text search.

Directory mode walks nested folders and sorts `.md` and `.lean.md` files by path. A single file remains useful
for a fast edit-check-render loop.

Front matter supports `title`, `date`, `authors`, and comma-separated `tags`. Fenced `lean` blocks
are rendered with Verso/SubVerso syntax highlighting, math uses KaTeX, and fenced `mermaid` blocks
become diagrams. Add `title="Greeting.lean"` after a fence language to label a code block. Every
fenced code block has line numbers and a copy control; posts with at least two headings get a
right-hand table of contents showing levels 1–3 and the current section. Lean declarations
introduced by earlier code fences are carried into later fences, so references such as `Sum` can
link back to their defining post. Each post also receives a small generated “Continue reading”
section based on its neighboring topics. `lean:` links resolve to the copied declaration pages.

## GitHub Pages

Pushes to `main` build and deploy the example collection through
[`.github/workflows/docs.yml`](.github/workflows/docs.yml). The workflow uses the Pages base path so
the project site and its `/api` declaration links work at `https://jonaprieto.github.io/lean-blog/`.

The current lowering slice covers paragraphs, headings, fenced code, inline emphasis, KaTeX math,
Mermaid diagrams, images, ordinary links, and declaration links. Lists, tables, block quotes, and raw HTML are
rejected explicitly until their HTML semantics are defined for the blog theme.

See [TODO.md](TODO.md) for planned authoring fallbacks and diagnostics improvements.

## Build

```text
lake build LeanBlog LeanBlog.Properties tests readme demo leanblog :literateHtml
```

## Design direction

LeanBlog owns the Markdown frontend, `.lean.md` declaration links, site indexing, references,
collections, CLI, and theme.
Verso owns document lowering, Lean highlighting, and HTML generation. Tailwind and daisyUI are part
of the first visual prototype and the generated starter site; the Lean build consumes the generated
CSS at build time. The starter theme includes a responsive drawer/sidebar, clickable topics, a
post metadata rail, footer, and persisted light/dark switching.

## License

Apache-2.0.

See [CONTRIBUTING.md](CONTRIBUTING.md) for collaborator setup and CI access.
