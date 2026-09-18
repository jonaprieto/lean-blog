/-
Copyright (c) 2026 Jonathan Prieto-Cubides. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/
import LeanBlog

/-!
# LeanBlog properties

Machine-checked laws for the public LeanBlog model will live here. Keeping this as a sibling
library makes the axiom gate apply to the framework's semantic guarantees rather than only its
examples.
-/

namespace LeanBlog.Properties

theorem declarationIndexEmpty :
    (LeanBlog.DeclarationIndex.empty : LeanBlog.DeclarationIndex) = {} := by
  rfl

end LeanBlog.Properties
