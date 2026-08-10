---
title: Linking across LeanBlog modules
date: 2026-08-05
authors: Jonathan Prieto-Cubides
tags: links, lean
---

## Declaration links

Declaration links are useful when a post explains the framework itself. The source model from
`Markdown` is [`PostSource`](lean:LeanBlog.PostSource), the destination model from `Links` is a
[`DeclarationIndex`](lean:LeanBlog.DeclarationIndex), and the site presentation from `Theme` comes
from [`Theme.make`](lean:LeanBlog.Theme.make).

## Directory input

The CLI accepts either one file or a directory. In directory mode it walks nested folders, sorts
the posts by path, and gives Verso all of them in one blog category. This file is deliberately
nested so the example exercises that behavior rather than relying on a flat fixture directory.

## Generated destinations

The resulting collection keeps each post's title and date visible, while the declaration links
point into the copied API tree under `/api`.
