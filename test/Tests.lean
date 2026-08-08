/-
Copyright (c) 2026 Jonathan Prieto-Cubides. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/
import LeanBlog

open LeanBlog
open Verso Doc
open Verso.Genre.Blog

def main : IO Unit := do
  let target : Target := {
    href := "/api/Sum.html#decl-Sum"
    description := "Definition of `Sum`"
  }
  let index := DeclarationIndex.add DeclarationIndex.empty `Sum target
  unless index.resolve `Sum == some #[target] do
    throw <| IO.userError "declaration index lookup failed"
  let source := "---\n" ++
    "title: Sum in a post\n" ++
    "date: 2026-08-07\n" ++
    "authors: Jonathan Prieto-Cubides\n" ++
    "---\n\n" ++
    "The [`Sum`](lean:Sum) type is useful.\n"
  let post ← match parsePost source with
    | .ok post => pure post
    | .error error => throw <| IO.userError error
  let part ← match post.toPart index with
    | .ok part => pure part
    | .error error => throw <| IO.userError error
  unless part.titleString == "Sum in a post" do
    throw <| IO.userError "post title lowering failed"
  unless part.content.size == 1 do
    throw <| IO.userError "post body lowering failed"
  let expected : Block Page := .para #[
    .text "The ",
    .link #[.code "Sum"] target.href,
    .text " type is useful."
  ]
  unless part.content[0]? == some expected do
    throw <| IO.userError "declaration link lowering failed"
  IO.println "LeanBlog tests passed"
