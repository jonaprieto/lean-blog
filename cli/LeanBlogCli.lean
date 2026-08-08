/-
Copyright (c) 2026 Jonathan Prieto-Cubides. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/
import LeanBlog
import VersoBlog

/-!
# `leanblog` command

This first CLI keeps the workflow intentionally small. A target registry is a tab-separated file
with `name`, `href`, and `description` columns. A later declaration extractor can produce the same
file without changing the source format.
-/

namespace LeanBlog.Cli

open Verso Doc
open Verso.Genre.Blog

private def usage : String := r#"Usage:
  leanblog init [<directory>]
  leanblog check <post.lean.md> [--targets <targets.tsv>]
  leanblog build <post.lean.md> [--targets <targets.tsv>] [--output <dir>] [--css <site.css>]
"#

private def starterPost : String := r#"---
title: Your first LeanBlog post
date: 2026-08-08
authors: Your Name
---

# Your first LeanBlog post

Write ordinary Markdown here. Add declaration targets to `targets.tsv`, then link to them with
standard Markdown syntax such as [`Sum`](lean:Sum).
"#

private def starterTargets : String :=
  "# name<TAB>href<TAB>description\n"

private def starterReadme : String := r#"# Your LeanBlog

Edit `posts/starter.lean.md`, add declaration targets to `targets.tsv`, and run these commands from
the LeanBlog repository:

```text
lake exe leanblog check posts/starter.lean.md --targets targets.tsv
lake exe leanblog build posts/starter.lean.md --targets targets.tsv
```
"#

structure BuildConfig where
  targets : Option String := none
  output : String := ".lake/build/site"
  css : String := "theme/dist/site.css"

inductive Command where
  | init (directory : String)
  | check (source : String) (targets : Option String)
  | build (source : String) (config : BuildConfig)

private def parseTargetsOption : List String → Option String → Except String (Option String)
  | [], targets => .ok targets
  | "--targets" :: path :: rest, none => parseTargetsOption rest (some path)
  | "--targets" :: _, some _ => .error "--targets may only be supplied once"
  | "--targets" :: [], _ => .error "--targets expects a file path"
  | option :: _, _ => .error s!"Unknown option '{option}'"

private def parseBuildOptions : List String → BuildConfig → Except String BuildConfig
  | [], config => .ok config
  | "--targets" :: path :: rest, config =>
    if config.targets.isSome then
      .error "--targets may only be supplied once"
    else
      parseBuildOptions rest {config with targets := some path}
  | "--targets" :: [], _ => .error "--targets expects a file path"
  | "--output" :: path :: rest, config =>
    parseBuildOptions rest {config with output := path}
  | "--output" :: [], _ => .error "--output expects a directory path"
  | "--css" :: path :: rest, config =>
    parseBuildOptions rest {config with css := path}
  | "--css" :: [], _ => .error "--css expects a stylesheet path"
  | option :: _, _ => .error s!"Unknown option '{option}'"

private def parseCommand : List String → Except String Command
  | ["--help"] | ["-h"] => .error usage
  | ["init"] => .ok <| Command.init "."
  | ["init", directory] => .ok <| Command.init directory
  | "init" :: _ => .error "init accepts at most one directory"
  | "check" :: source :: rest => do
    pure <| Command.check source (← parseTargetsOption rest none)
  | "check" :: [] => .error "check expects a .lean.md source path"
  | "build" :: source :: rest =>
    do
      let config ← parseBuildOptions rest {}
      pure <| Command.build source config
  | "build" :: [] => .error "build expects a .lean.md source path"
  | [] => .error usage
  | command :: _ => .error s!"Unknown command '{command}'\n\n{usage}"

private def fromExcept {α : Type} : Except String α → IO α
  | .ok value => pure value
  | .error error => throw <| IO.userError error

private def createIfMissing (path : System.FilePath) (contents : String) : IO Bool := do
  if ← path.pathExists then
    pure false
  else
    IO.FS.writeFile path contents
    pure true

private def initBlog (directory : String) : IO Unit := do
  let root : System.FilePath := directory
  let posts := root.join "posts"
  IO.FS.createDirAll posts
  let files := #[
    (posts.join "starter.lean.md", starterPost),
    (root.join "targets.tsv", starterTargets),
    (root.join "README.md", starterReadme)
  ]
  let mut created := 0
  let mut skipped := 0
  for (path, contents) in files do
    if ← createIfMissing path contents then
      created := created + 1
      IO.println s!"created {path}"
    else
      skipped := skipped + 1
      IO.println s!"kept {path}"
  IO.println s!"initialized {root} ({created} created, {skipped} kept)"
  let starter := posts.join "starter.lean.md"
  let targets := root.join "targets.tsv"
  IO.println s!"next: edit {starter}"
  IO.println s!"then run: lake exe leanblog check {starter} --targets {targets}"

private def parseTargetLine (line : String) : Except String (Option (Lean.Name × Target)) := do
  let line := line.trimAscii.toString
  if line.isEmpty || "#".isPrefixOf line then
    pure none
  else
    match line.splitOn "\t" with
    | [name, href, description] =>
      let name := name.trimAscii.toString.toName
      if name == .anonymous then
        .error s!"Invalid declaration name in targets file: '{line}'"
      else
        pure <| some (name, {
          href := href.trimAscii.toString
          description := description.trimAscii.toString
        })
    | _ => .error s!"Targets must have three tab-separated columns: '{line}'"

private def loadTargets (path? : Option String) : IO DeclarationIndex := do
  match path? with
  | none => pure DeclarationIndex.empty
  | some path =>
    let contents ← IO.FS.readFile path
    let mut index := DeclarationIndex.empty
    for line in contents.splitOn "\n" do
      if let some (name, target) ← fromExcept (parseTargetLine line) then
        index := index.add name target
    pure index

private def checkSource (sourcePath : String) (targetsPath? : Option String) : IO Unit := do
  let source ← IO.FS.readFile sourcePath
  let post ← fromExcept (parsePost source)
  let index ← loadTargets targetsPath?
  let _ ← fromExcept (post.toPart index)
  IO.println s!"checked {sourcePath} ({post.document.blocks.size} blocks)"

private def buildSource (sourcePath : String) (config : BuildConfig) : IO Unit := do
  let source ← IO.FS.readFile sourcePath
  let post ← fromExcept (parsePost source)
  let index ← loadTargets config.targets
  let contents ← fromExcept (post.toPart index)
  let css ← IO.FS.readFile config.css
  let home : Part Page := Part.mk #[] "LeanBlog" none #[] #[]
  let blogPage : Part Page := Part.mk #[] "Posts" none #[] #[]
  let post : BlogPost := {id := `post, contents}
  let site : Site := .page `home home #[.blog "posts" `blog blogPage #[post]]
  let status ← blogMain (Theme.make css) site {} ["--output", config.output]
  if status != 0 then
    throw <| IO.userError s!"Verso failed to build {sourcePath}"
  IO.println s!"built {config.output}"

def main (args : List String) : IO UInt32 := do
  try
    match parseCommand args with
    | .error error =>
      IO.eprintln error
      if error == usage then pure 0 else pure 1
    | .ok (.init directory) =>
      initBlog directory
      pure 0
    | .ok (.check source targets) =>
      checkSource source targets
      pure 0
    | .ok (.build source config) =>
      buildSource source config
      pure 0
  catch error =>
    IO.eprintln s!"error: {error}"
    pure 1

end LeanBlog.Cli

def main (args : List String) : IO UInt32 := LeanBlog.Cli.main args
