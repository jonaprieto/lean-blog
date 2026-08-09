---
title: Using Sum in another post
date: 2026-08-02
authors: Jonathan Prieto-Cubides
tags: lean, tutorial, examples
---

# Using a type from another post

## Reusing the definition

The [definition post for `Sum`](2026-8-3-sum-a-small-algebra-of-choices/) introduced the two
constructors. Here we use them in a second article, and the [`DeclarationIndex`](lean:LeanBlog.DeclarationIndex)
link in this sentence points to the generated API documentation.

```lean
def label {α β : Type} : Sum α β → String
  | .left _ => "left"
  | .right _ => "right"
```

## Linking back to context

The same idea works in prose: a value can be left or right, and readers can jump back to the
[definition of `Sum`](2026-8-3-sum-a-small-algebra-of-choices/) whenever they need the original context.
