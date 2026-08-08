---
title: A LeanBlog post
date: 2026-08-07
authors: Your Name
---

This starter is a real `.lean.md` post: front matter becomes the archive metadata, and the body is
lowered to Verso's blog document model. The [`PostSource`](lean:LeanBlog.PostSource) value keeps
the title, date, authors, and parsed Markdown together.

The important part is that links stay ordinary Markdown. This one resolves through the generated
Verso cross-reference index and becomes a link to the declaration page:

[`PostSource.toPart`](lean:LeanBlog.PostSource.toPart)

Build one file while writing, or point the same command at `examples/posts` to render the whole
collection. A normal external link works too: [Verso](https://github.com/leanprover/verso).

For declarations documented outside this project, use a `targets.tsv` override. Local declarations
from the generated API do not need a hand-maintained registry.
