/-
Copyright (c) 2026 Jonathan Prieto-Cubides. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/
import LeanBlog
import Lean.Data.Json
import SubVerso.Compat
import SubVerso.Highlighting.Code
import VersoBlog
import Verso.Output.Html.ElasticLunr
import VersoLiterateCode
import VersoSearch

/-!
# `leanblog` command

The CLI reads Verso's generated `xref.json` automatically. A target registry is still accepted as
an override for declarations documented elsewhere.
-/

namespace LeanBlog.Cli

open Lean
open Verso Doc Output Html
open Verso.Genre.Blog
open Verso.Search

private def starterPost : String := r#"---
title: Your first LeanBlog post
date: 2026-08-08
authors: Your Name
tags: lean, tutorial
---

Write ordinary Markdown here. Once your project has generated API documentation, declaration
links use standard Markdown syntax with a `lean:` destination.

Lean fences are highlighted with Verso and SubVerso:

```lean
def answer : Nat := 42

#eval answer
```
"#

private def starterConfig : String := r#"{
  "title": "Your LeanBlog",
  "tagline": "A calm home for your writing.",
  "author": "",
  "siteUrl": "",
  "basePath": "/",
  "footer": "Built with LeanBlog, Verso, Tailwind, and daisyUI.",
  "archiveTitle": "Recent posts",
  "archiveLabel": "All posts",
  "docsRoot": "/api",
  "docsDirectory": "api",
  "defaultTheme": "system",
  "navigation": []
}
"#

private def starterGitignore : String := ".lake/\ntheme/node_modules/\ntheme/dist/\n"

private def starterToolchain : String := "leanprover/lean4:v4.32.2\n"

private def starterLakefile : String := r#"import Lake
open Lake DSL

package «my-leanblog» where
  version := v!"0.1.0"
  leanOptions := #[
    ⟨`autoImplicit, false⟩,
    ⟨`relaxedAutoImplicit, false⟩
  ]

require leanblog from git
  "https://github.com/jonaprieto/lean-blog" @ "main"

lean_exe «leanblog-site» where
  root := `Main
"#

private def starterMain : String := r#"import LeanBlog.Cli

def main (args : List String) : IO UInt32 := LeanBlog.Cli.main args
"#

private def starterThemePackage : String := include_str "../../theme/package.json"

private def starterThemeLock : String := include_str "../../theme/package-lock.json"

private def starterThemeCss : String :=
  (include_str "../../theme/src/app.css")
    |>.replace "@source \"../../site\";" "@source \"../../posts\";"
    |>.replace "@source \"../../src\";" "@source \"../../posts\";"

private def starterBuildScript : String := r#"#!/usr/bin/env node

import { spawnSync } from "node:child_process";

const run = (label, command, args) => {
  console.log(`\n==> ${label}`);
  const result = spawnSync(command, args, { stdio: "inherit" });
  if (result.error) throw new Error(`${label} could not start: ${result.error.message}`);
  if (result.status !== 0) throw new Error(`${label} failed with exit code ${result.status}`);
};

try {
  run("Install and build theme", "npm", ["ci", "--prefix", "theme"]);
  run("Build Tailwind and daisyUI CSS", "npm", ["run", "build:css", "--prefix", "theme"]);
  run("Validate posts", "lake", ["exe", "leanblog-site", "check", "posts"]);
  run("Render site", "lake", [
    "exe", "leanblog-site", "build", "posts", "--css", "theme/dist/site.css",
  ]);
  console.log("\nBuilt .lake/build/site");
} catch (error) {
  console.error(`\nBuild failed: ${error.message}`);
  process.exitCode = 1;
}
"#

private def starterWorkflow : String := r#"name: Pages

on:
  push:
    branches: [main]
  pull_request:
  workflow_dispatch:

permissions:
  contents: read

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5
      - uses: actions/setup-node@v5
        with:
          node-version: lts/*
          cache: npm
          cache-dependency-path: theme/package-lock.json
      - uses: leanprover/lean-action@v1
        with:
          build-args: "leanblog"
      - name: Build site
        run: node tools/build-site.mjs
      - uses: actions/upload-pages-artifact@v4
        with:
          path: .lake/build/site

  deploy:
    if: github.event_name != 'pull_request' && github.ref == 'refs/heads/main'
    needs: build
    runs-on: ubuntu-latest
    permissions:
      pages: write
      id-token: write
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    steps:
      - uses: actions/deploy-pages@v4
        id: deployment
"#

private def starterReadme : String := r#"# My LeanBlog

A Lean-aware blog generated with [LeanBlog](https://github.com/jonaprieto/lean-blog).

## Build

Install Lean 4.32.2 and Node.js, then run:

```text
npm ci --prefix theme
node tools/build-site.mjs
```

The generated site is `.lake/build/site`. Edit files in `posts/` and `leanblog.json`; the
generator accepts both `.md` and `.lean.md` posts, walks nested directories, and validates
`lean:` declaration links against Verso's generated documentation.

## Deploy

The included `.github/workflows/pages.yml` publishes the site with GitHub Pages after you enable
Pages for the repository using GitHub Actions.
"#

structure LinkConfig where
  targets : Option String := none
  xref : Option String := none
  docsRoot : String := "/api"

structure BuildConfig where
  links : LinkConfig := {}
  site : SiteConfig := {}
  output : String := ".lake/build/site"
  css : String := "theme/dist/site.css"
  docsDirectory : String := "api"

structure InitOptions where
  directory : Option String := none

structure CheckOptions where
  source : String
  config : Option String := none
  targets : Option String := none
  xref : Option String := none
  docsRoot : Option String := none

structure BuildOptions where
  source : String
  config : Option String := none
  targets : Option String := none
  xref : Option String := none
  docsRoot : Option String := none
  docsDirectory : Option String := none
  output : String := ".lake/build/site"
  css : String := "theme/dist/site.css"

inductive Action where
  | init (options : InitOptions)
  | check (options : CheckOptions)
  | build (options : BuildOptions)

private def usage : String := r#"Usage: leanblog <command> [options]

Commands:
  init [DIRECTORY]                 Create a standalone starter project
  check SOURCE [options]           Validate Markdown posts and declaration links
  build SOURCE [options]           Render the blog and copy generated API docs

Common options:
  --config PATH                    Site configuration JSON file
  --targets PATH                   Declaration target registry (TSV)
  --xref PATH                      Verso cross-reference index
  --docs-root URL                  URL path for generated API docs

Build options:
  --docs-directory PATH            Generated API docs directory
  --output PATH                    Generated site directory
  --css PATH                       Compiled stylesheet
  -h, --help                       Show this help
  --version                        Show the version
"#

structure RawOptions where
  positionals : List String := []
  config : Option String := none
  targets : Option String := none
  xref : Option String := none
  docsRoot : Option String := none
  docsDirectory : Option String := none
  output : Option String := none
  css : Option String := none

private def parseRaw : List String → RawOptions → Except String RawOptions
  | [], options => .ok options
  | "--config" :: [], _ => .error "--config requires a value"
  | "--config" :: value :: rest, options =>
    if value.startsWith "-" then .error "--config requires a value"
    else parseRaw rest {options with config := some value}
  | "--targets" :: [], _ => .error "--targets requires a value"
  | "--targets" :: value :: rest, options =>
    if value.startsWith "-" then .error "--targets requires a value"
    else parseRaw rest {options with targets := some value}
  | "--xref" :: [], _ => .error "--xref requires a value"
  | "--xref" :: value :: rest, options =>
    if value.startsWith "-" then .error "--xref requires a value"
    else parseRaw rest {options with xref := some value}
  | "--docs-root" :: [], _ => .error "--docs-root requires a value"
  | "--docs-root" :: value :: rest, options =>
    if value.startsWith "-" then .error "--docs-root requires a value"
    else parseRaw rest {options with docsRoot := some value}
  | "--docs-directory" :: [], _ => .error "--docs-directory requires a value"
  | "--docs-directory" :: value :: rest, options =>
    if value.startsWith "-" then .error "--docs-directory requires a value"
    else parseRaw rest {options with docsDirectory := some value}
  | "--output" :: [], _ => .error "--output requires a value"
  | "--output" :: value :: rest, options =>
    if value.startsWith "-" then .error "--output requires a value"
    else parseRaw rest {options with output := some value}
  | "--css" :: [], _ => .error "--css requires a value"
  | "--css" :: value :: rest, options =>
    if value.startsWith "-" then .error "--css requires a value"
    else parseRaw rest {options with css := some value}
  | "-h" :: _, _ | "--help" :: _, _ => .error "help"
  | "--version" :: _, _ => .error "version"
  | option :: rest, options =>
    if option.startsWith "-" then .error s!"unknown option: {option}"
    else parseRaw rest {options with positionals := options.positionals ++ [option]}

termination_by args _ => args

private def parseAction : List String → Except String Action
  | [] => .error "missing command"
  | "init" :: rest => do
    let options ← parseRaw rest {}
    match options.positionals with
    | [] => pure <| .init {}
    | [directory] => pure <| .init {directory := some directory}
    | _ => .error "init accepts at most one DIRECTORY"
  | "check" :: rest => do
    let options ← parseRaw rest {}
    let source ← match options.positionals with
      | [source] => pure source
      | [] => .error "check requires SOURCE"
      | _ => .error "check accepts exactly one SOURCE"
    pure <| .check {
      source
      config := options.config
      targets := options.targets
      xref := options.xref
      docsRoot := options.docsRoot
    }
  | "build" :: rest => do
    let options ← parseRaw rest {}
    let source ← match options.positionals with
      | [source] => pure source
      | [] => .error "build requires SOURCE"
      | _ => .error "build accepts exactly one SOURCE"
    pure <| .build {
      source
      config := options.config
      targets := options.targets
      xref := options.xref
      docsRoot := options.docsRoot
      docsDirectory := options.docsDirectory
      output := options.output.getD ".lake/build/site"
      css := options.css.getD "theme/dist/site.css"
    }
  | command :: _ => .error s!"unknown command: {command}"

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
  let themeSource := root.join "theme" |>.join "src"
  let workflowDirectory := root.join ".github" |>.join "workflows"
  let toolsDirectory := root.join "tools"
  IO.FS.createDirAll posts
  IO.FS.createDirAll themeSource
  IO.FS.createDirAll workflowDirectory
  IO.FS.createDirAll toolsDirectory
  let files := #[
    (posts.join "starter.lean.md", starterPost),
    (root.join "README.md", starterReadme),
    (root.join "leanblog.json", starterConfig),
    (root.join ".gitignore", starterGitignore),
    (root.join "lean-toolchain", starterToolchain),
    (root.join "lakefile.lean", starterLakefile),
    (root.join "Main.lean", starterMain),
    (root.join "theme" |>.join "package.json", starterThemePackage),
    (root.join "theme" |>.join "package-lock.json", starterThemeLock),
    (themeSource.join "app.css", starterThemeCss),
    (toolsDirectory.join "build-site.mjs", starterBuildScript),
    (workflowDirectory.join "pages.yml", starterWorkflow)
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
  IO.println s!"then run: node {toolsDirectory.join "build-site.mjs"}"

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

private def loadSiteConfig (configured? : Option String) : IO SiteConfig := do
  let path : System.FilePath := configured?.getD "leanblog.json"
  if !(← path.pathExists) then
    pure {}
  else
    let json ← fromExcept <| Json.parse (← IO.FS.readFile path)
    match SiteConfig.fromJson? json with
    | .ok config => pure config
    | .error error =>
      throw <| IO.userError s!"{path}: invalid site configuration: {error}"

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

private def codeLinks (index : DeclarationIndex) (name : Lean.Name) :
    Array Verso.Code.CodeLink :=
  (index.resolve name).getD #[] |>.map fun target => {
    shortDescription := "docs"
    description := target.description
    href := target.href
  }

private def codeLinkTargets (index : DeclarationIndex) :
    Verso.Code.LinkTargets TraverseContext where
  const := fun name _ => codeLinks index name
  option := fun name _ => codeLinks index name
  definition := fun name _ => codeLinks index name
  moduleName := fun name _ => codeLinks index name

structure LoadedPost where
  path : System.FilePath
  raw : String
  source : PostSource

private def relatedLimit : Nat := 3

private def sharedTagCount (left right : List String) : Nat :=
  left.foldl (init := 0) fun count tag =>
    if right.contains tag then count + 1 else count

private def newerDate (left right : Date) : Bool :=
  if left.year != right.year then decide (left.year > right.year)
  else if left.month != right.month then decide (left.month > right.month)
  else decide (left.day > right.day)

private def relatedPosts (current : LoadedPost) (posts : Array LoadedPost) : Array LoadedPost :=
  let candidates := posts.filter (·.path != current.path)
  (candidates.qsort fun left right =>
    let leftScore := sharedTagCount current.source.tags left.source.tags
    let rightScore := sharedTagCount current.source.tags right.source.tags
    if leftScore == rightScore then newerDate left.source.date right.source.date
    else decide (leftScore > rightScore)).take relatedLimit

private def relatedCard (post : LoadedPost) : Verso.Output.Html :=
  let href := defaultPostName post.source.date post.source.title ++ "/"
  let tags := String.intercalate " · " post.source.tags
  let dateAndTags := post.source.date.toIso8601String ++
    (if tags.isEmpty then "" else " · " ++ tags)
  Verso.Output.Html.tag "a" #[("href", href), ("class", "leanblog-related-card")] <|
    Verso.Output.Html.tag "div" #[("class", "related-card-body")] <|
      Verso.Output.Html.seq #[
        Verso.Output.Html.tag "h3" #[] (.text true post.source.title),
        Verso.Output.Html.tag "p" #[] (.text true dateAndTags)
      ]

private def relatedSection (posts : Array LoadedPost) : String :=
  let content := Verso.Output.Html.seq #[
    Verso.Output.Html.tag "h2" #[
      ("id", "leanblog-related-title"), ("class", "leanblog-related-heading")
    ] (.text true "Continue reading"),
    Verso.Output.Html.tag "div" #[
      ("class", "leanblog-related-grid")
    ] (Verso.Output.Html.seq (posts.map relatedCard))
  ]
  Verso.Output.Html.asString (breakLines := false) <|
    Verso.Output.Html.tag "section" #[
      ("class", "leanblog-related"), ("aria-labelledby", "leanblog-related-title")
    ] content

private def injectRelatedPosts (output : String) (posts : Array LoadedPost) : IO Unit := do
  let marker := "<div id=\"leanblog-related-posts\"></div>"
  for current in posts do
    let slug := defaultPostName current.source.date current.source.title
    let page := (System.FilePath.mk output).join slug |>.join "index.html"
    let html ← IO.FS.readFile page
    unless html.contains marker do
      throw <| IO.userError s!"Verso post template marker not found in {page}"
    let related := relatedPosts current posts
    IO.FS.writeFile page <| html.replace marker (relatedSection related)

private def rawPage (config : SiteConfig) (post : LoadedPost) : String :=
  let content := {{
    <html lang="en">
      <head>
        <meta charset="utf-8"/>
        <meta name="viewport" content="width=device-width, initial-scale=1"/>
        <base href="../.././"/>
        <title>{{post.source.title}} " · raw"</title>
        <link rel="stylesheet" href="-verso-data/leanblog.css"/>
      </head>
      <body class="site-body min-h-screen bg-base-100 text-base-content">
        <div class="site-shell flex min-h-screen flex-col">
          <header class="site-header">
            <div class="site-header-inner">
              <a class="site-brand" href="../../">{{config.title}}</a>
              <nav class="site-nav" aria-label="Raw source navigation">
                <a class="site-link site-link-strong" href="../">"Back to post"</a>
              </nav>
            </div>
          </header>
          <main class="site-main w-full flex-1"><div class="site-content">
            <article class="raw-source-page">
              <p class="page-kicker">"Raw source"</p>
              <h1 class="page-title">{{post.source.title}}</h1>
              <pre class="raw-source-code"><code>{{Html.text true post.raw}}</code></pre>
            </article>
          </div></main>
        </div>
      </body>
    </html>
  }}
  content.asString (breakLines := true)

private def searchInitJs : String := r##"
import { domainMappers, searchPriorities } from "./domain-mappers.js";
import { registerSearch } from "./search-box.js";

const searchHTML = `<div id="search-wrapper" class="verso-search-results">
  <div class="combobox combobox-list">
    <div class="group">
      <div
        id="cb1-input"
        class="cb_edit"
        contenteditable="true"
        role="searchbox"
        placeholder="Search posts..."
        aria-autocomplete="list"
        aria-expanded="false"
        aria-controls="cb1-listbox"
        aria-haspopup="listbox"
        aria-label="Search posts"
        spellcheck="false"
        autocorrect="false"
        autocapitalize="none"
        inputmode="search"
      ></div>
    </div>
    <ul id="cb1-listbox" role="listbox" aria-label="Search results"></ul>
  </div>
</div>`;

const data = fetch("xref.json").then((response) => {
  if (!response.ok) throw new Error(`Search metadata failed: ${response.status}`);
  return response.json();
});

window.addEventListener("load", () => {
  if (document.querySelector("[data-search-host]")) return;
  const mount = document.querySelector(".site-header-inner");
  if (!mount) return;
  mount.insertAdjacentHTML("beforeend", searchHTML);
  const searchWrapper = document.querySelector(".combobox-list");
  data.then((json) => {
    registerSearch({
      searchWrapper,
      data: json,
      domainMappers,
      searchPriorities,
      docPriorities: window.docPriorities ?? {},
      searchPagePath: window.searchPagePath ?? "search/",
    });
  }).catch((error) => console.error(error));
});

document.addEventListener("keydown", (event) => {
  if (event.key !== "/" || event.metaKey || event.ctrlKey || event.altKey) return;
  const target = event.target;
  if (target instanceof HTMLElement &&
      target.closest("input, textarea, select, button, a, [contenteditable='true']")) return;
  const search = document.querySelector("#search-wrapper .cb_edit, #search-page-input");
  if (!(search instanceof HTMLElement)) return;
  event.preventDefault();
  search.focus();
});
"##

private def searchThemeJs (config : SiteConfig) : String :=
  let configuredTheme := match config.defaultTheme with
    | "dark" => "'dark'"
    | "light" => "'light'"
    | _ => "preferred"
  (r#"
(() => {
  const root = document.documentElement;
  const stored = (() => {
    try { return localStorage.getItem("leanblog-theme"); } catch (_) { return null; }
  })();
  const preferred = window.matchMedia?.("(prefers-color-scheme: dark)").matches
    ? "dark" : "light";
  root.dataset.theme = stored === "dark" || stored === "light" ? stored : preferred;
  const update = () => {
    const dark = root.dataset.theme === "dark";
    document.querySelectorAll("[data-theme-toggle]").forEach((button) => {
      button.querySelector("[data-theme-icon-light]").hidden = dark;
      button.querySelector("[data-theme-icon-dark]").hidden = !dark;
      button.setAttribute("aria-label", dark ? "Use light theme" : "Use dark theme");
    });
  };
  document.addEventListener("DOMContentLoaded", () => {
    update();
    document.querySelectorAll("[data-theme-toggle]").forEach((button) => {
      button.addEventListener("click", () => {
        root.dataset.theme = root.dataset.theme === "dark" ? "light" : "dark";
        try { localStorage.setItem("leanblog-theme", root.dataset.theme); } catch (_) {}
        update();
      });
    });
  });
})();
"#).replace
    "root.dataset.theme = stored === \"dark\" || stored === \"light\" ? stored : preferred;"
    ("root.dataset.theme = stored === \"dark\" || stored === \"light\" ? stored : " ++
      configuredTheme ++ ";")

private def searchPage (config : SiteConfig) : String :=
  let searchAssets := Verso.Search.searchAssetTags
  let initialTheme := if config.defaultTheme == "dark" then "dark" else "light"
  let page := {{
    <html lang="en" data-theme={{initialTheme}}>
      <head>
        <meta charset="utf-8"/>
        <meta name="viewport" content="width=device-width, initial-scale=1"/>
        {{Theme.siteMetadata config}}
        <base href=".././"/>
        <title>"Search · "{{config.title}}</title>
        <link rel="stylesheet" href="-verso-data/leanblog.css"/>
        {{searchAssets}}
        <script>{{Html.text false (searchThemeJs config)}}</script>
      </head>
      <body class="site-body min-h-screen bg-base-100 text-base-content">
        <div class="site-shell flex min-h-screen flex-col">
          <header class="site-header">
            <div class="site-header-inner">
              <a class="site-brand" href=".">{{config.title}}</a>
              <nav class="site-nav" aria-label="Primary">
                {{Theme.navigation config}}
              </nav>
              <button type="button" class="site-theme-toggle" data-theme-toggle
                aria-label="Toggle color theme">
                <span data-theme-icon-light>{{Icon.toHtml .moon}}</span>
                <span data-theme-icon-dark hidden>{{Icon.toHtml .sun}}</span>
              </button>
            </div>
          </header>
          <main class="site-main w-full flex-1">
            <div class="site-content">
              <article class="search-page-content">
                <p class="page-kicker">"Archive"</p>
                <h1 class="page-title">"Search posts"</h1>
                <p class="search-page-intro">
                  "Search titles, tags, headings, prose, mathematics, and code."
                </p>
                <div data-search-host class="search-page-host" role="search"
                  aria-label="Search posts"></div>
                <div id="search-page-results"></div>
              </article>
            </div>
          </main>
          <footer class="site-footer">
            <div class="site-footer-inner">
              {{config.footer}}
            </div>
          </footer>
        </div>
        <script type="module" src="-verso-search/search-page.js"></script>
      </body>
    </html>
  }}
  page.asString (breakLines := true)

private def searchableAttrText (text : Array MD4Lean.AttrText) : String :=
  text.foldl (init := "") fun result part =>
    match part with
    | .normal value | .entity value => result ++ value
    | .nullchar => result

mutual
  private def searchableInline : MD4Lean.Text → String
    | .normal value | .entity value => value
    | .nullchar => ""
    | .br value | .softbr value => value
    | .em content | .strong content | .u content | .del content => searchableInlines content
    | .code content => String.join content.toList
    | .latexMath content | .latexMathDisplay content => String.join content.toList
    | .img _ _title alt => searchableInlines alt
    | .wikiLink _target content => searchableInlines content
    | .a _href _title _isAuto content => searchableInlines content

  private def searchableInlines (content : Array MD4Lean.Text) : String :=
    content.foldl (init := "") fun result inline => result ++ searchableInline inline

  private def searchableBlock : MD4Lean.Block → String
    | .p content => searchableInlines content
    | .header _level content => searchableInlines content
    | .code _info _lang _fence content => String.join content.toList
    | .hr => ""
    | .blockquote _ | .ul _ _ _ | .ol _ _ _ _ | .html _ | .table _ _ => ""
end

private def searchableBody (document : MD4Lean.Document) : String :=
  document.blocks.toList.map searchableBlock |> String.intercalate "\n\n"

private def searchBucket (ref : String) : UInt8 := Id.run do
  let mut hash := 0
  let mut index := 0
  while h : index < ref.utf8ByteSize do
    hash := hash + ref.getUTF8Byte ⟨index⟩ h
    index := index + 1
  hash

private def writeSearchAssets (config : BuildConfig) (posts : Array LoadedPost) : IO Unit := do
  let builder := ({refField := "id" : IndexBuilder})
    |>.addField "id"
    |>.addField "header"
    |>.addField "contents"
  let mut index := builder.build
  for post in posts do
    let ref := defaultPostName post.source.date post.source.title ++ "/"
    let tags := String.intercalate " " post.source.tags
    let contents := tags ++ "\n\n" ++ searchableBody post.source.document
    index := index.addDoc ref #[ref, post.source.title, contents]
  let (extracted, docs) := index.extractDocs
  let indexData := extracted.toJson.compress
  let version := Verso.Search.hashHex (hash indexData)
  let mut buckets : Std.HashMap UInt8 (Std.HashMap String Doc) := {}
  for (ref, doc) in docs do
    let doc := doc.insert "context" ""
    buckets := buckets.alter (searchBucket ref) fun existing =>
      some (existing.getD {} |>.insert ref doc)
  let searchDir := (System.FilePath.mk config.output).join "-verso-search"
  IO.FS.createDirAll searchDir
  for (bucket, bucketDocs) in buckets do
    let docsJson := Verso.Search.bucketDocsToJson bucketDocs {}
    IO.FS.writeFile (searchDir / s!"searchIndex_{bucket}.{version}.js")
      s!"window.docContents[{bucket}].resolve({docsJson.compress});"
  let indexJs := "const __verso_searchIndexData = " ++ indexData ++ ";\n\n" ++
    "const __versoSearchIndex = elasticlunr ? " ++
      "elasticlunr.Index.load(__verso_searchIndexData) : null;\n" ++
    "window.docContents = {};\n" ++
    "window.searchIndex = elasticlunr ? __versoSearchIndex : null;\n" ++
    "window.docPriorities = {};\n" ++
    "window.searchIndexVersion = " ++ toString (Json.str version) ++ ";\n"
  IO.FS.writeFile (searchDir / "searchIndex.js") indexJs
  IO.FS.writeFile (searchDir / "elasticlunr.min.js") Verso.Output.Html.elasticlunr.min.js
  VersoLiterateCode.emitSearchBox searchDir (some "search/")
  IO.FS.writeFile (searchDir / "search-init.js") searchInitJs
  -- The quick-jump combobox and the full-text page share Verso's declaration index. Keep the
  -- source generated by `:literateHtml` at the site root so nested pages resolve it against their
  -- `<base>` element just like the copied API documentation does.
  let xref := match config.links.xref with
    | some path => (path : System.FilePath)
    | none => defaultDocsDirectory.join "xref.json"
  let xrefOutput := (System.FilePath.mk config.output).join "xref.json"
  if ← xref.pathExists then
    copyFile xref xrefOutput
  else
    IO.FS.writeFile xrefOutput "{}\n"
  let searchPageDir := (System.FilePath.mk config.output).join "search"
  IO.FS.createDirAll searchPageDir
  IO.FS.writeFile (searchPageDir / "index.html") (searchPage config.site)

private def versionCssHref (html css : String) : String :=
  let marker := "href=\"-verso-data/leanblog.css"
  let version := Verso.Search.hashHex (hash css)
  let replacement := s!"href=\"-verso-data/leanblog.css?v={version}"
  match html.splitOn marker with
  | [] => html
  | first :: rest =>
    first ++ String.intercalate "" (rest.map fun part =>
      replacement ++ (part.dropWhile (· != '"')).copy)

private def versionCssLinks (output : String) (css : String) : IO Unit := do
  let root : System.FilePath := output
  for page in (← root.walkDir).filter (·.toString.endsWith ".html") do
    let html ← IO.FS.readFile page
    let versioned := versionCssHref html css
    unless versioned == html do
      IO.FS.writeFile page versioned

private def writeRawPages (output : String) (site : SiteConfig)
    (posts : Array LoadedPost) : IO Unit := do
  for post in posts do
    let slug := defaultPostName post.source.date post.source.title
    let directory := (System.FilePath.mk output).join slug |>.join "raw"
    IO.FS.createDirAll directory
    IO.FS.writeFile (directory.join "index.html") (rawPage site post)

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
  | .ok parsed => pure {path, raw := source, source := parsed}
  | .error error => throw <| IO.userError s!"{path}: {error}"

private def loadPosts (sourcePath : String) : IO (Array LoadedPost) := do
  let paths ← sourceFiles sourcePath
  paths.mapM loadPost

private structure LeanCodeBlock where
  postPath : System.FilePath
  source : String

private def markdownText (text : Array MD4Lean.AttrText) : String :=
  text.foldl (init := "") fun result part =>
    match part with
    | .normal value | .entity value => result ++ value
    | .nullchar => result

private def leanCodeBlocks (posts : Array LoadedPost) : Array LeanCodeBlock := Id.run do
  let mut blocks := #[]
  for post in posts do
    for block in post.source.document.blocks do
      match block with
      | .code _info lang _fence content =>
        if markdownText lang == "lean" || markdownText lang == "lean4" then
          blocks := blocks.push {
            postPath := post.path
            source := String.join content.toList
          }
      | _ => pure ()
  blocks

private structure HighlightResult where
  rendered : SubVerso.Highlighting.Highlighted
  environment : Lean.Environment
  declarations : Array Lean.Name

private def highlightLean (code : String) (environment : Lean.Environment) :
    IO (Option HighlightResult) := do
  try
    let inputCtx := Parser.mkInputContext code "<leanblog-code>"
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
    let result := {result with
      items := result.items.map (fun item => {item with messages := Lean.MessageLog.empty})}
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
    | .ok (highlighted, commandState) =>
      let declarations := commandState.env.constants.toList.filterMap fun (name, _) =>
        if environment.constants.find? name |>.isSome then none else some name
      pure <| some {
        rendered := highlighted
        environment := commandState.env
        declarations := declarations.toArray
      }
    | .error _ => pure none
  catch _ =>
    pure none

private structure HighlightedCode where
  source : String
  rendered : SubVerso.Highlighting.Highlighted
  declarations : Array Lean.Name
  target : Target

private def highlightLeanCodes (posts : Array LoadedPost) : IO (Array HighlightedCode) := do
  let mut highlighted := #[]
  let mut environment ← Lean.mkEmptyEnvironment
  for block in leanCodeBlocks posts do
    if let some result ← highlightLean block.source environment then
      let some post := posts.find? (·.path == block.postPath)
        | continue
      let slug := defaultPostName post.source.date post.source.title
      let target : Target := {
        href := slug ++ "/"
        description := s!"Declaration from `{post.source.title}`"
      }
      highlighted := highlighted.push {
        source := block.source
        rendered := result.rendered
        declarations := result.declarations
        target
      }
      environment := result.environment
  pure highlighted

private def addLocalTargets (index : DeclarationIndex)
    (highlighted : Array HighlightedCode) : DeclarationIndex :=
  highlighted.foldl (init := index) fun index code =>
    code.declarations.foldl (init := index) fun index name =>
      index.add name code.target

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
  let index := addLocalTargets index highlighted
  let highlight? := fun source =>
    highlighted.find? (·.source == source) |>.map (·.rendered)
  let contents ← posts.mapM (fun post => lowerPost post index highlight?)
  let css ← IO.FS.readFile config.css
  let home : Part Page := Verso.Doc.Part.mk #[.text config.site.title] config.site.title none
    #[.para #[.text config.site.tagline]] #[]
  let blogPosts := contents.mapIdx fun index contents =>
    {id := Lean.Name.mkSimple s!"post{index}", contents}
  -- A root blog is not registered by Verso's root-site traversal. An empty blog child keeps the
  -- archive at `/` while using the normal directory-blog path that registers categories correctly.
  let site : Site := .page `home home #[.blog "" `blog home blogPosts]
  let status ← blogMain (Theme.make css config.site) site (codeLinkTargets index)
    ["--output", config.output]
  if status != 0 then
    throw <| IO.userError s!"Verso failed to build {sourcePath}"
  injectRelatedPosts config.output posts
  writeRawPages config.output config.site posts
  writeSearchAssets config posts
  versionCssLinks config.output css
  if ← copyGeneratedDocs config then
    IO.println s!"copied local API docs to {joinUrlPath ⟨config.output⟩ config.docsDirectory}"
  IO.println s!"built {config.output}"

private def checkLinks (options : CheckOptions) : IO LinkConfig := do
  let site ← loadSiteConfig options.config
  pure {
    targets := options.targets
    xref := options.xref
    docsRoot := options.docsRoot.getD site.docsRoot
  }

private def buildConfig (options : BuildOptions) : IO BuildConfig := do
  let site ← loadSiteConfig options.config
  pure {
    links := {
      targets := options.targets
      xref := options.xref
      docsRoot := options.docsRoot.getD site.docsRoot
    }
    site
    output := options.output
    css := options.css
    docsDirectory := options.docsDirectory.getD site.docsDirectory
  }

private def runAction : Action → IO UInt32
  | .init options => do
    initBlog (options.directory.getD ".")
    pure 0
  | .check options => do
    checkSource options.source (← checkLinks options)
    pure 0
  | .build options => do
    buildSource options.source (← buildConfig options)
    pure 0

private def reportError (error : String) : IO UInt32 := do
  let stderr ← IO.getStderr
  stderr.putStrLn s!"leanblog: {error}"
  pure 2

def main (args : List String) : IO UInt32 := do
  match args with
  | ["--help"] | ["-h"] =>
    IO.println usage
    pure 0
  | ["--version"] =>
    IO.println "leanblog 0.1.0"
    pure 0
  | _ =>
    match parseAction args with
    | .ok action =>
      try runAction action
      catch error => reportError error.toString
    | .error "help" =>
      IO.println usage
      pure 0
    | .error "version" =>
      IO.println "leanblog 0.1.0"
      pure 0
    | .error error => reportError error

end LeanBlog.Cli
