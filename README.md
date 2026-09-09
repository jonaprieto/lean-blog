# lean-blog

[![CI](https://github.com/jonaprieto/lean-blog/actions/workflows/ci.yml/badge.svg)](https://github.com/jonaprieto/lean-blog/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/jonaprieto/lean-blog?display_name=tag&sort=semver)](https://github.com/jonaprieto/lean-blog/releases)
[![Lean 4](https://img.shields.io/badge/Lean%204-v4.33.1-6f42c1)](lean-toolchain)
[![Docs](https://img.shields.io/badge/docs-GitHub%20Pages-4c8bf5)](https://jonaprieto.github.io/lean-blog/)
[![License](https://img.shields.io/badge/license-Apache--2.0-green)](LICENSE)

LeanBlog is a Lean-aware publishing framework built on top of Verso. It is intended to make blogs,
documentation, module catalogues, and tutorials pleasant to author while preserving links from
Lean names to their generated HTML definitions. The CLI reads Verso's generated `xref.json`
automatically, while explicit target files remain available for external documentation.

## Problem

Lean publishing needs an authoring workflow that keeps documentation readable while preserving
links from declarations to their generated definitions.

## Development

This project is maintained by its author with AI-assisted development tools.
Changes are reviewed, tested, and remain the maintainer's responsibility.

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
See [the starter post](site/posts/starter.lean.md), the [example collection](site/posts),
and the visual collection prototype.

Generated sites include a local full-text search; see [Search](#search) for the user-facing
behavior and build details.

The `leanblog` CLI is exported as a small library, uses only Lean and Verso dependencies, and can
be wrapped by an initialized site's own executable. This keeps the generated starter project
independent of private ecosystem tooling.

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

The canonical site build command runs the required preparation stages and renders the collection:

```text
node tools/build-site.mjs site/posts
```

Its output is in `.lake/build/site`. Use `node tools/build-site.mjs --help` for deployment-path and
incremental-build options. The equivalent individual commands are:

```text
lake exe leanblog init .
lake build leanblog
lake build :literateHtml
lake exe leanblog check site/posts
lake exe leanblog build site/posts
```

`leanblog init` creates a complete starter project: Lake metadata, a public CLI wrapper, the
toolchain pin, locked Tailwind/daisyUI theme files, a build script, GitHub Pages workflow,
configuration, README, and starter post. It is safe to rerun; every generated file is created
only when missing, so it will not overwrite writing in progress.

To create a new blog from the built CLI:

```text
lake exe leanblog init my-blog
cd my-blog
npm ci --prefix theme
node tools/build-site.mjs
```

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

The generic generated-site audit is also available:

```text
node tools/check-site.mjs .lake/build/site
```

For a reusable semantic search check, pass a manifest containing `queries` and an optional `lazyRef`:

```text
node tools/check-search.mjs .lake/build/fixture-site test/fixtures/search.json
```

The same check is run for the GitHub Pages output in CI. When the local Verso documentation build is
available, Lean declaration search uses the generated `xref.json` alongside post full-text search.

To measure the renderer against a generated collection, run:

```text
node tools/benchmark-build.mjs --posts 100
```

The benchmark creates its fixture under a temporary directory, reports each build stage and output
size, and removes the fixture when it finishes. Set `KEEP_BENCHMARK=1` to retain it for inspection.

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
post metadata rail, footer, and persisted light/dark switching. The repository and generated
starter use only public Lake dependencies and standard GitHub Actions; no private ecosystem token
is needed for a clean template checkout.

## License

Apache-2.0.

See [CONTRIBUTING.md](CONTRIBUTING.md) for local checks and CI setup.
