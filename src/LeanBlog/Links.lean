/-
Copyright (c) 2026 Jonathan Prieto-Cubides. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/
import Lean.Data.NameMap

/-!
# Declaration links

The index is intentionally independent of Markdown and HTML. A compiler, documentation extractor,
or hand-written registry can populate it, and every source frontend can resolve against the same
targets.
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

/-- Select the first destination for a declaration. -/
def resolveOne (index : DeclarationIndex) (name : Lean.Name) : Option Target :=
  index.resolve name |>.bind (·[0]?)

end DeclarationIndex

end LeanBlog
