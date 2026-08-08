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
---

The [`PostSource`](lean:LeanBlog.PostSource) type represents a parsed post.
```

`lean:` links resolve through the generated Verso cross-reference index by default; an unresolved
declaration is a build error. Use `--targets targets.tsv` for declarations documented elsewhere.
See [the starter post](examples/posts/starter.lean.md) and the visual collection prototype.

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

Build the starter post through Verso:

```text
lake exe leanblog init .
lake build leanblog
lake build :literateHtml
lake exe leanblog check examples/posts/starter.lean.md
lake exe leanblog build examples/posts/starter.lean.md
```

`leanblog init` is safe to rerun: it creates `posts/starter.lean.md` and `README.md` only when they
do not already exist, so it will not overwrite writing in progress.

The generated site is in `.lake/build/site`; open `.lake/build/site/index.html` after building the
stylesheet with the commands above.

The current lowering slice covers paragraphs, headings, fenced code, inline emphasis, math,
images, ordinary links, and declaration links. Lists, tables, block quotes, and raw HTML are
rejected explicitly until their HTML semantics are defined for the blog theme.

## Build

```text
lake build LeanBlog LeanBlog.Properties tests readme demo leanblog :literateHtml
```

## Design direction

LeanBlog owns the `.lean.md` frontend, site indexing, references, collections, CLI, and theme.
Verso owns document lowering, Lean highlighting, and HTML generation. Tailwind and daisyUI are part
of the first visual prototype and the generated starter site; the Lean build consumes the generated
CSS at build time.

## License

Apache-2.0.

See [CONTRIBUTING.md](CONTRIBUTING.md) for collaborator setup and CI access.
