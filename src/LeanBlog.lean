/-
Copyright (c) 2026 Jonathan Prieto-Cubides. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/
import LeanBlog.Links
import LeanBlog.Markdown

/-!
# LeanBlog

The Lean-aware publishing framework built on top of Verso.

This foundation keeps declaration targets separate from rendering. Later layers will use the same
index for prose references and links emitted by highlighted Lean code.
-/

/-!
# Public entry point

`LeanBlog` re-exports the small source and link model so a blog author can begin with one import.
The renderer and CLI will be layered on top of these values.
-/
