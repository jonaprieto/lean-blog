---
title: How a LeanBlog post is built
date: 2026-08-06
authors: Jonathan Prieto-Cubides
tags: architecture, lean
---

## Source model

A post travels through three small layers. [`PostSource`](lean:LeanBlog.PostSource) is the source
model from the Markdown module. Its [`toPart`](lean:LeanBlog.PostSource.toPart) method lowers the
parsed body into the Verso blog representation after every `lean:` destination has been resolved.

### Parsing source

Markdown becomes a small, explicit source model before any theme code runs. This keeps authoring
errors close to the input file and makes the later rendering stages easier to test.

### Lowering to Verso

The parsed body is lowered only after declaration destinations have been resolved, so links and
content travel together into the generated post.

## Declaration links

The link registry lives in a separate module. A [`DeclarationIndex`](lean:LeanBlog.DeclarationIndex)
maps a Lean name to one or more [`Target`](lean:LeanBlog.Target) values. That separation means a
future frontend can reuse the same links without knowing anything about Markdown.

### Registry boundary

The registry stores resolved targets while Markdown remains responsible for syntax. The boundary
is deliberately small: a frontend asks for a target and receives a normal URL.

## Source files and themes

Here is the shape of a source file:

```text
---
title: A post
date: 2026-08-06
authors: Jonathan Prieto-Cubides
---

The [`Target`](lean:LeanBlog.Target) is a generated link.
```

The theme stays at the edge. [`Theme.make`](lean:LeanBlog.Theme.make) receives the compiled CSS and
hands Verso the page templates, so writing content does not require learning the HTML template API.

## Lean examples

The same post can include an ordinary Lean example:

```lean title="Greeting.lean"
def greeting : String := "LeanBlog"

#eval greeting
```
