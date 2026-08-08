---
title: Markdown, math, and diagrams
date: 2026-08-04
authors: Jonathan Prieto-Cubides
tags: markdown, math, mermaid
---

# Ordinary Markdown

## Inline mathematics

LeanBlog accepts `.md` files as well as `.lean.md` files. Inline mathematics such as
$a^2 + b^2 = c^2$ is rendered with KaTeX.

## Display mathematics

Display mathematics works too:

$$
\sum_{i=1}^{n} i = \frac{n(n+1)}{2}
$$

## Diagrams

Mermaid diagrams use a normal fenced code block:

```mermaid
flowchart LR
  Markdown --> KaTeX
  KaTeX --> Mermaid
```
