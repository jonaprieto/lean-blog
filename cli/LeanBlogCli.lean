/-
Copyright (c) 2026 Jonathan Prieto-Cubides. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/
import LeanBlog
import Lean.Data.Json
import Argus
import Argus.Term
import SubVerso.Compat
import SubVerso.Highlighting.Code
import VersoBlog

/-!
# `leanblog` command

The CLI reads Verso's generated `xref.json` automatically. A target registry is still accepted as
an override for declarations documented elsewhere.
-/

namespace LeanBlog.Cli

open Lean
open Argus
open TermColor
open TermColor.Diagnostics
open Verso Doc
open Verso.Genre.Blog

private def starterPost : String := r#"---
title: Your first LeanBlog post
date: 2026-08-08
authors: Your Name
tags: lean, tutorial
---

Write ordinary Markdown here. Link to declarations with standard Markdown syntax such as
[`MyDeclaration`](lean:MyDeclaration).

Lean fences are highlighted with Verso and SubVerso:

```lean
def answer : Nat := 42

#eval answer
```
"#

private def starterReadme : String := r#"# Your LeanBlog

Edit `posts/starter.lean.md`, build the Verso cross-reference index, and run these commands from
your Lake project:

```text
lake build :literateHtml
lake exe leanblog check posts
lake exe leanblog build posts
```

The source argument can be one `.md` or `.lean.md` file or a directory. Directory mode walks nested
folders, sorts posts by path, and builds one archive. When local Verso docs
exist, `build` copies them into the site's `/api` directory so declaration links work in the
generated site.
"#

structure LinkConfig where
  targets : Option String := none
  xref : Option String := none
  docsRoot : String := "/api"

structure BuildConfig where
  links : LinkConfig := {}
  output : String := ".lake/build/site"
  css : String := "theme/dist/site.css"
  docsDirectory : String := "api"

argus_opts InitOptions where
  directory : Option String := Spec.opt (Spec.arg "DIRECTORY" "Blog directory" Param.path)

private def targetsSpec :=
  Spec.opt (Spec.flag "targets" none "Declaration target registry (TSV)" Param.path)

private def xrefSpec :=
  Spec.opt (Spec.flag "xref" none "Verso cross-reference index" Param.path)

private def docsRootSpec :=
  Spec.map (·.getD "/api")
    (Spec.opt (Spec.flag "docs-root" none "URL path for generated API docs" Param.str))

argus_opts CheckOptions where
  source : String := Spec.arg "SOURCE" "Markdown file or posts directory" Param.path;
  targets : Option String := targetsSpec;
  xref : Option String := xrefSpec;
  docsRoot : String := docsRootSpec

argus_opts BuildOptions where
  source : String := Spec.arg "SOURCE" "Markdown file or posts directory" Param.path;
  targets : Option String := targetsSpec;
  xref : Option String := xrefSpec;
  docsRoot : String := docsRootSpec;
  docsDirectory : String := Spec.map (·.getD "api")
    (Spec.opt (Spec.flag "docs-directory" none "Generated API docs directory" Param.path));
  output : String := Spec.map (·.getD ".lake/build/site")
    (Spec.opt (Spec.flag "output" none "Generated site directory" Param.path));
  css : String := Spec.map (·.getD "theme/dist/site.css")
    (Spec.opt (Spec.flag "css" none "Compiled site stylesheet" Param.path))

inductive Action where
  | init (options : InitOptions)
  | check (options : CheckOptions)
  | build (options : BuildOptions)

private def checkAction (options : CheckOptions) : Action := .check options

private def buildAction (options : BuildOptions) : Action := .build options

private def leanblogCommand : Argus.Command Action :=
  Argus.group "leanblog"
    [ Argus.cmd "init" (Spec.map Action.init InitOptions.spec)
        (description := "Create a starter blog in a directory")
    , Argus.cmd "check" (Spec.map checkAction CheckOptions.spec)
        (description := "Validate Markdown posts and declaration links")
    , Argus.cmd "build" (Spec.map buildAction BuildOptions.spec)
        (description := "Render the blog and copy generated API docs")
    ]
    (version := some "0.1.0")
    (description := "A Lean-aware Markdown blog generator.")

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
    let destination := joinUrlPath ⟨config.output⟩ config.docsDirectory
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
  let isMarkdown (path : System.FilePath) := path.toString.endsWith ".md"
  let path : System.FilePath := sourcePath
  unless ← path.pathExists do
    throw <| IO.userError s!"Source path not found: {sourcePath}"
  if ← path.isDir then
    let paths ← path.walkDir
    let files :=
      (paths.filter isMarkdown).qsort fun left right =>
        left.toString < right.toString
    if files.isEmpty then
      throw <| IO.userError s!"No Markdown posts found below {sourcePath}"
    pure files
  else if isMarkdown path then
    pure #[path]
  else
    throw <| IO.userError s!"Expected a .md file or posts directory: {sourcePath}"

private def loadPost (path : System.FilePath) : IO LoadedPost := do
  let source ← IO.FS.readFile path
  match parsePost source with
  | .ok source => pure {path, source}
  | .error error => throw <| IO.userError s!"{path}: {error}"

private def loadPosts (sourcePath : String) : IO (Array LoadedPost) := do
  let paths ← sourceFiles sourcePath
  paths.mapM loadPost

private def markdownText (text : Array MD4Lean.AttrText) : String :=
  text.foldl (init := "") fun result part =>
    match part with
    | .normal value | .entity value => result ++ value
    | .nullchar => result

private def leanCodeBlocks (posts : Array LoadedPost) : Array String := Id.run do
  let mut blocks := #[]
  for post in posts do
    for block in post.source.document.blocks do
      match block with
      | .code _info lang _fence content =>
        if markdownText lang == "lean" || markdownText lang == "lean4" then
          blocks := blocks.push (String.join content.toList)
      | _ => pure ()
  blocks

private def highlightLean (code : String) : IO (Option SubVerso.Highlighting.Highlighted) := do
  try
    let inputCtx := Parser.mkInputContext code "<leanblog-code>"
    let environment ← Lean.mkEmptyEnvironment
    let commandState : Lean.Elab.Command.State := {
      env := environment
      maxRecDepth := 100000
    }
    let initialState : Lean.Elab.Frontend.State := {
      commandState
      parserState := {}
      cmdPos := 0
    }
    let (result, finalState) ←
      (SubVerso.Compat.Frontend.processCommands Lean.mkNullNode).run
        {inputCtx} |>.run initialState
    let result := result.updateLeading code
    let result := {result with items := result.items.map fun item => {item with messages := {}}}
    let action : Lean.Elab.Command.CommandElabM SubVerso.Highlighting.Highlighted := do
      Lean.Elab.Command.runTermElabM fun _ => do
        withTheReader Core.Context (fun context => {context with fileMap := inputCtx.fileMap}) do
          let highlighted ← SubVerso.Highlighting.highlightFrontendResult result
          pure <| highlighted.foldl (· ++ ·) .empty
    let commandContext : Lean.Elab.Command.Context := {
      cmdPos := 0
      fileName := inputCtx.fileName
      fileMap := inputCtx.fileMap
      snap? := none
      cancelTk? := none
    }
    match ← EIO.toIO' (action.run commandContext |>.run finalState.commandState) with
    | .ok (highlighted, _) => pure <| some highlighted
    | .error _ => pure none
  catch _ =>
    pure none

private structure HighlightedCode where
  source : String
  rendered : SubVerso.Highlighting.Highlighted

private def highlightLeanCodes (posts : Array LoadedPost) : IO (Array HighlightedCode) := do
  let mut highlighted := #[]
  for source in leanCodeBlocks posts do
    if let some rendered ← highlightLean source then
      highlighted := highlighted.push {source, rendered}
  pure highlighted

private def lowerPost (post : LoadedPost) (index : DeclarationIndex)
    (highlight? : String → Option SubVerso.Highlighting.Highlighted) : IO (Part Post) := do
  match post.source.toPartWithHighlight index highlight? with
  | .ok contents => pure contents
  | .error error => throw <| IO.userError s!"{post.path}: {error}"

private def checkSource (sourcePath : String) (links : LinkConfig) : IO Unit := do
  let posts ← loadPosts sourcePath
  let index ← loadTargets links
  for post in posts do
    let _ ← lowerPost post index (fun _ => none)
    IO.println s!"checked {post.path} ({post.source.document.blocks.size} blocks)"
  IO.println s!"checked {posts.size} post(s)"

private def buildSource (sourcePath : String) (config : BuildConfig) : IO Unit := do
  let posts ← loadPosts sourcePath
  let index ← loadTargets config.links
  let highlighted ← highlightLeanCodes posts
  let highlight? := fun source =>
    highlighted.find? (·.source == source) |>.map (·.rendered)
  let contents ← posts.mapM (fun post => lowerPost post index highlight?)
  let css ← IO.FS.readFile config.css
  let home : Part Page := Verso.Doc.Part.mk #[.text "LeanBlog"] "LeanBlog" none
    #[.para #[.text "A calm home for Lean-aware writing."]] #[]
  let blogPosts := contents.mapIdx fun index contents =>
    {id := Lean.Name.mkSimple s!"post{index}", contents}
  -- A root blog is not registered by Verso's root-site traversal. An empty blog child keeps the
  -- archive at `/` while using the normal directory-blog path that registers categories correctly.
  let site : Site := .page `home home #[.blog "" `blog home blogPosts]
  let status ← blogMain (Theme.make css) site {} ["--output", config.output]
  if status != 0 then
    throw <| IO.userError s!"Verso failed to build {sourcePath}"
  if ← copyGeneratedDocs config then
    IO.println s!"copied local API docs to {joinUrlPath ⟨config.output⟩ config.docsDirectory}"
  IO.println s!"built {config.output}"

private def checkLinks (options : CheckOptions) : LinkConfig :=
  { targets := options.targets, xref := options.xref, docsRoot := options.docsRoot }

private def buildConfig (options : BuildOptions) : BuildConfig :=
  { links := { targets := options.targets, xref := options.xref, docsRoot := options.docsRoot }
    output := options.output
    css := options.css
    docsDirectory := options.docsDirectory }

private def runAction : Action → IO UInt32
  | .init options => do
    initBlog (options.directory.getD ".")
    pure 0
  | .check options => do
    checkSource options.source (checkLinks options)
    pure 0
  | .build options => do
    buildSource options.source (buildConfig options)
    pure 0

private def reportRuntimeError (error : IO.Error) : IO UInt32 := do
  let stderr ← IO.getStderr
  let target ← targetWithTty .auto (← stderr.isTty)
  let source := Source.named "leanblog" error.toString
  let diagnostic := (Diagnostic.error "command failed").withLabel
    (Label.primary (Span.point 0 0))
  stderr.putStr (Text.render target (TermColor.Diagnostics.render #[source] diagnostic))
  stderr.putStr "\n"
  pure 1

def main (args : List String) : IO UInt32 := do
  try
    Argus.Term.main leanblogCommand args runAction
  catch error =>
    reportRuntimeError error

end LeanBlog.Cli

def main (args : List String) : IO UInt32 := LeanBlog.Cli.main args
