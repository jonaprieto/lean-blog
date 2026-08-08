/-
Copyright (c) 2026 Jonathan Prieto-Cubides. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/
import LeanBlog
import Lean.Data.Json
import VersoBlog

/-!
# `leanblog` command

The CLI reads Verso's generated `xref.json` automatically. A target registry is still accepted as
an override for declarations documented elsewhere.
-/

namespace LeanBlog.Cli

open Lean
open Verso Doc
open Verso.Genre.Blog

private def usage : String := r#"Usage:
  leanblog init [<directory>]
  leanblog check <source> [--targets <targets.tsv>] [--xref <xref.json>]
    [--docs-root <path>]
  leanblog build <source> [--targets <targets.tsv>] [--xref <xref.json>]
    [--docs-root <path>]
    [--output <dir>] [--css <site.css>]
"#

private def starterPost : String := r#"---
title: Your first LeanBlog post
date: 2026-08-08
authors: Your Name
---

Write ordinary Markdown here. Link to declarations with standard Markdown syntax such as
[`MyDeclaration`](lean:MyDeclaration).
"#

private def starterReadme : String := r#"# Your LeanBlog

Edit `posts/starter.lean.md`, build the Verso cross-reference index, and run these commands from
your Lake project:

```text
lake build :literateHtml
lake exe leanblog check posts
lake exe leanblog build posts
```

The source argument can be one `.lean.md` file or a directory. Directory mode walks nested folders,
sorts posts by path, and builds one archive. When the local Verso docs exist, `build` copies them
into the site's `/api` directory so declaration links work in the generated site.
"#

structure LinkConfig where
  targets : Option String := none
  xref : Option String := none
  docsRoot : String := "/api"

structure BuildConfig where
  links : LinkConfig := {}
  output : String := ".lake/build/site"
  css : String := "theme/dist/site.css"

inductive Command where
  | init (directory : String)
  | check (source : String) (links : LinkConfig)
  | build (source : String) (config : BuildConfig)

private def parseLinkOptions : List String → LinkConfig → Except String LinkConfig
  | [], config => .ok config
  | "--targets" :: path :: rest, config =>
    if config.targets.isSome then
      .error "--targets may only be supplied once"
    else
      parseLinkOptions rest {config with targets := some path}
  | "--targets" :: [], _ => .error "--targets expects a file path"
  | "--xref" :: path :: rest, config =>
    if config.xref.isSome then
      .error "--xref may only be supplied once"
    else
      parseLinkOptions rest {config with xref := some path}
  | "--xref" :: [], _ => .error "--xref expects a file path"
  | "--docs-root" :: path :: rest, config =>
    parseLinkOptions rest {config with docsRoot := path}
  | "--docs-root" :: [], _ => .error "--docs-root expects a URL path"
  | option :: _, _ => .error s!"Unknown option '{option}'"

private def parseBuildOptions : List String → BuildConfig → Except String BuildConfig
  | [], config => .ok config
  | "--targets" :: path :: rest, config =>
    if config.links.targets.isSome then
      .error "--targets may only be supplied once"
    else
      parseBuildOptions rest {config with links := {config.links with targets := some path}}
  | "--targets" :: [], _ => .error "--targets expects a file path"
  | "--xref" :: path :: rest, config =>
    if config.links.xref.isSome then
      .error "--xref may only be supplied once"
    else
      parseBuildOptions rest {config with links := {config.links with xref := some path}}
  | "--xref" :: [], _ => .error "--xref expects a file path"
  | "--docs-root" :: path :: rest, config =>
    parseBuildOptions rest {config with links := {config.links with docsRoot := path}}
  | "--docs-root" :: [], _ => .error "--docs-root expects a URL path"
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
    pure <| Command.check source (← parseLinkOptions rest {})
  | "check" :: [] => .error "check expects a .lean.md source path or posts directory"
  | "build" :: source :: rest =>
    do
      let config ← parseBuildOptions rest {}
      pure <| Command.build source config
  | "build" :: [] => .error "build expects a .lean.md source path or posts directory"
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

private def defaultDocsDirectory : System.FilePath := ".lake/build/literate-html"

private def copyFile (source target : System.FilePath) : IO Unit := do
  IO.FS.withFile source .read fun input =>
    IO.FS.withFile target .write fun output => do
      while true do
        let contents ← input.read 65536
        if contents.isEmpty then
          break
        output.write contents

private def copyDirectory (source target : System.FilePath) : IO Unit := do
  let mut todo : List (System.FilePath × System.FilePath) := [(source, target)]
  while !todo.isEmpty do
    match todo with
    | [] => break
    | (source, target) :: rest =>
      todo := rest
      IO.FS.createDirAll target
      for entry in ← source.readDir do
        let destination := target.join entry.fileName
        if ← entry.path.isDir then
          todo := (entry.path, destination) :: todo
        else
          copyFile entry.path destination

private def joinUrlPath (root : System.FilePath) (url : String) : System.FilePath :=
  url.splitOn "/" |>.filter (!·.isEmpty) |>.foldl (init := root) fun path segment =>
    path.join ⟨segment⟩

private def copyGeneratedDocs (config : BuildConfig) : IO Bool := do
  let xref := defaultDocsDirectory.join "xref.json"
  let useLocalDocs := match config.links.xref with
    | none => true
    | some path => (path : System.FilePath) == xref
  if !useLocalDocs || !(← xref.pathExists) then
    pure false
  else
    let destination := joinUrlPath ⟨config.output⟩ config.links.docsRoot
    copyDirectory defaultDocsDirectory destination
    pure true

private def initBlog (directory : String) : IO Unit := do
  let root : System.FilePath := directory
  let posts := root.join "posts"
  IO.FS.createDirAll posts
  let files := #[
    (posts.join "starter.lean.md", starterPost),
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
  IO.println s!"next: edit {starter}"
  IO.println s!"then run: lake build :literateHtml && lake exe leanblog check {posts}"

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

private def findXref (configured? : Option String) : IO (Option System.FilePath) := do
  match configured? with
  | some path =>
    unless ← (path : System.FilePath).pathExists do
      throw <| IO.userError s!"Verso cross-reference file not found: {path}"
    pure <| some path
  | none =>
    let candidates : Array System.FilePath := #[
      ".lake/build/literate-html/xref.json",
      "xref.json"
    ]
    pure <| ← candidates.findM? (·.pathExists)

private def loadXref (path : System.FilePath) (docsRoot : String)
    (index : DeclarationIndex) : IO DeclarationIndex := do
  let json ← fromExcept <| Json.parse (← IO.FS.readFile path)
  let domains ← fromExcept <| json.getObj?
  let some constants := domains.get? "VersoHtml.constant"
    | pure index
  let contentsJson ← fromExcept <| Json.getObjVal? constants "contents"
  let contents ← fromExcept <| Json.getObj? contentsJson
  let mut index := index
  for (nameString, entriesJson) in contents.toList do
    let name := String.toName nameString
    if name == Lean.Name.anonymous || (index.resolve name).isSome then
      continue
    let entries ← fromExcept <| Json.getArr? entriesJson
    if let some entry := entries[0]? then
      let address ← fromExcept <| Json.getObjValAs? entry String "address"
      let id ← fromExcept <| Json.getObjValAs? entry String "id"
      let href := (docsRoot.dropSuffix "/").toString ++ address ++ "#" ++ id
      index := index.add name {
        href
        description := s!"Declaration `{nameString}`"
      }
  pure index

private def loadTargets (config : LinkConfig) : IO DeclarationIndex := do
  let mut index := DeclarationIndex.empty
  if let some path := config.targets then
    let contents ← IO.FS.readFile path
    for line in contents.splitOn "\n" do
      if let some (name, target) ← fromExcept (parseTargetLine line) then
        index := index.add name target
  if let some path ← findXref config.xref then
    index ← loadXref path config.docsRoot index
  pure index

structure LoadedPost where
  path : System.FilePath
  source : PostSource

private def sourceFiles (sourcePath : String) : IO (Array System.FilePath) := do
  let path : System.FilePath := sourcePath
  unless ← path.pathExists do
    throw <| IO.userError s!"Source path not found: {sourcePath}"
  if ← path.isDir then
    let paths ← path.walkDir
    let files :=
      (paths.filter fun path => path.toString.endsWith ".lean.md").qsort fun left right =>
        left.toString < right.toString
    if files.isEmpty then
      throw <| IO.userError s!"No .lean.md posts found below {sourcePath}"
    pure files
  else if path.toString.endsWith ".lean.md" then
    pure #[path]
  else
    throw <| IO.userError s!"Expected a .lean.md file or posts directory: {sourcePath}"

private def loadPost (path : System.FilePath) : IO LoadedPost := do
  let source ← IO.FS.readFile path
  match parsePost source with
  | .ok source => pure {path, source}
  | .error error => throw <| IO.userError s!"{path}: {error}"

private def loadPosts (sourcePath : String) : IO (Array LoadedPost) := do
  let paths ← sourceFiles sourcePath
  paths.mapM loadPost

private def lowerPost (post : LoadedPost) (index : DeclarationIndex) : IO (Part Post) := do
  match post.source.toPart index with
  | .ok contents => pure contents
  | .error error => throw <| IO.userError s!"{post.path}: {error}"

private def checkSource (sourcePath : String) (links : LinkConfig) : IO Unit := do
  let posts ← loadPosts sourcePath
  let index ← loadTargets links
  for post in posts do
    let _ ← lowerPost post index
    IO.println s!"checked {post.path} ({post.source.document.blocks.size} blocks)"
  IO.println s!"checked {posts.size} post(s)"

private def buildSource (sourcePath : String) (config : BuildConfig) : IO Unit := do
  let posts ← loadPosts sourcePath
  let index ← loadTargets config.links
  let contents ← posts.mapM (fun post => lowerPost post index)
  let css ← IO.FS.readFile config.css
  let home : Part Page := Verso.Doc.Part.mk #[.text "LeanBlog"] "LeanBlog" none
    #[.para #[.text "A calm home for Lean-aware writing."]] #[]
  let blogPage : Part Page := Verso.Doc.Part.mk #[.text "Posts"] "Posts" none #[] #[]
  let blogPosts := contents.mapIdx fun index contents =>
    {id := Lean.Name.mkSimple s!"post{index}", contents}
  let site : Site := .page `home home #[.blog "posts" `blog blogPage blogPosts]
  let status ← blogMain (Theme.make css) site {} ["--output", config.output]
  if status != 0 then
    throw <| IO.userError s!"Verso failed to build {sourcePath}"
  if ← copyGeneratedDocs config then
    IO.println s!"copied local API docs to {joinUrlPath ⟨config.output⟩ config.links.docsRoot}"
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
    | .ok (.check source links) =>
      checkSource source links
      pure 0
    | .ok (.build source config) =>
      buildSource source config
      pure 0
  catch error =>
    IO.eprintln s!"error: {error}"
    pure 1

end LeanBlog.Cli

def main (args : List String) : IO UInt32 := LeanBlog.Cli.main args
