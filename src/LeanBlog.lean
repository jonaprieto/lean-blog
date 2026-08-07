/-
Copyright (c) 2026 Jonathan Prieto-Cubides. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/
import Lean.Data.NameMap
import VersoBlog

/-!
# LeanBlog

The Lean-aware publishing framework built on top of Verso.

This foundation keeps declaration targets separate from rendering. Later layers will use the same
index for prose references and links emitted by highlighted Lean code.
-/

namespace LeanBlog

/-- An HTML destination for a declaration or generated page. -/
structure Target where
  /-- The relative or absolute URL of the target. -/
  href : String
  /-- A short description suitable for an accessible link title. -/
  description : String
deriving BEq, Repr

/-- The declarations that can be linked from a LeanBlog site. -/
abbrev DeclarationIndex := Lean.NameMap (Array Target)

namespace DeclarationIndex

/-- An empty declaration index. -/
def empty : DeclarationIndex := {}

/-- Add one destination to a declaration name. -/
def add (index : DeclarationIndex) (name : Lean.Name) (target : Target) : DeclarationIndex :=
  index.insert name ((index.find? name).getD #[] |>.push target)

/-- Look up all destinations registered for a declaration name. -/
def resolve (index : DeclarationIndex) (name : Lean.Name) : Option (Array Target) :=
  index.find? name

end DeclarationIndex

end LeanBlog
