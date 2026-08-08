# leanblog

[![CI](https://github.com/jonaprieto/lean-blog/actions/workflows/ci.yml/badge.svg)](https://github.com/jonaprieto/lean-blog/actions/workflows/ci.yml)
[![Lean 4](https://img.shields.io/badge/Lean%204-v4.32.2-6f42c1)](lean-toolchain)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)

LeanBlog is a Lean-aware publishing framework built on top of Verso. It is intended to make blogs,
documentation, module catalogues, and tutorials pleasant to author while preserving links from
Lean names to their generated HTML definitions. The first source slice parses `.lean.md` posts,
resolves explicit `lean:` links, and lowers them into Verso blog values.

## What it provides

Declaration destinations use a name-indexed map:

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

The [`Sum`](lean:Sum) type has two constructors.
```

`lean:` links must resolve through a `DeclarationIndex`; an unresolved declaration is a build error.
See [the starter post](examples/posts/starter.lean.md). Site generation and the CLI are the next
layer, while the visual collection prototype is already available.

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
lake build leanblog
lake exe leanblog check examples/posts/starter.lean.md --targets examples/targets.tsv
lake exe leanblog build examples/posts/starter.lean.md --targets examples/targets.tsv
```

The generated site is in `.lake/build/site`; open `.lake/build/site/index.html` after building the
stylesheet with the commands above.

The current lowering slice covers paragraphs, headings, fenced code, inline emphasis, math,
images, ordinary links, and declaration links. Lists, tables, block quotes, and raw HTML are
rejected explicitly until their HTML semantics are defined for the blog theme.

## Build

```text
lake build LeanBlog LeanBlog.Properties tests readme demo leanblog
```

## Design direction

LeanBlog owns the `.lean.md` frontend, site indexing, references, collections, CLI, and theme.
Verso owns document lowering, Lean highlighting, and HTML generation. Tailwind and daisyUI are part
of the first visual prototype and the generated starter site; the Lean build consumes the generated
CSS at build time.

## License

Apache-2.0.

See [CONTRIBUTING.md](CONTRIBUTING.md) for collaborator setup and CI access.
