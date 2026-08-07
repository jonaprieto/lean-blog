/-
Copyright (c) 2026 Jonathan Prieto-Cubides. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/
import LeanBlog

open LeanBlog

def main : IO Unit := do
  let target : Target := {
    href := "/api/Sum.html#decl-Sum"
    description := "Definition of `Sum`"
  }
  let index := DeclarationIndex.add DeclarationIndex.empty `Sum target
  unless index.resolve `Sum == some #[target] do
    throw <| IO.userError "declaration index lookup failed"
  IO.println "LeanBlog tests passed"
