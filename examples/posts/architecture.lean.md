---
title: How a LeanBlog post is built
date: 2026-08-06
authors: Jonathan Prieto-Cubides
---

A post travels through three small layers. [`PostSource`](lean:LeanBlog.PostSource) is the source
model from the Markdown module. Its [`toPart`](lean:LeanBlog.PostSource.toPart) method lowers the
parsed body into the Verso blog representation after every `lean:` destination has been resolved.

The link registry lives in a separate module. A [`DeclarationIndex`](lean:LeanBlog.DeclarationIndex)
maps a Lean name to one or more [`Target`](lean:LeanBlog.Target) values. That separation means a
future frontend can reuse the same links without knowing anything about Markdown.

Here is the shape of a source file:

```lean
---
title: A post
date: 2026-08-06
authors: Jonathan Prieto-Cubides
---

The [`Target`](lean:LeanBlog.Target) is a generated link.
```

The theme stays at the edge. [`Theme.make`](lean:LeanBlog.Theme.make) receives the compiled CSS and
hands Verso the page templates, so writing content does not require learning the HTML template API.
