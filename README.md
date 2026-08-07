# leanblog

[![CI](https://github.com/jonaprieto/lean-blog/actions/workflows/ci.yml/badge.svg)](https://github.com/jonaprieto/lean-blog/actions/workflows/ci.yml)
[![Lean 4](https://img.shields.io/badge/Lean%204-v4.32.2-6f42c1)](lean-toolchain)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)

LeanBlog is a Lean-aware publishing framework built on top of Verso. It is intended to make blogs,
documentation, module catalogues, and tutorials pleasant to author while preserving links from
Lean names to their generated HTML definitions.

The current repository is the foundation scaffold. It does not yet parse `.lean.md` files or
generate a site; the first public seam is the shared declaration index that will drive both prose
references and highlighted Lean code.

## What it provides

The current foundation represents declaration destinations with a name-indexed map:

```lean
import LeanBlog

open LeanBlog

#eval (Target.mk "/api/Sum.html#decl-Sum" "Definition of `Sum`").href
-- "/api/Sum.html#decl-Sum"
```

Planned authoring syntax includes explicit references such as
``[`Sum`](lean:Sum)`` and ``[`List.map`](lean:List:map)``.

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

## Build

```text
lake build LeanBlog LeanBlog.Properties tests readme demo
```

## Design direction

LeanBlog owns the `.lean.md` frontend, site indexing, references, collections, CLI, and theme.
Verso owns document lowering, Lean highlighting, and HTML generation. Tailwind and daisyUI are part
of the first visual prototype and will remain theme-build tooling; the Lean build consumes the
generated CSS.

## License

Apache-2.0.
