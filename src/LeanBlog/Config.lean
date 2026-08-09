/-
Copyright (c) 2026 Jonathan Prieto-Cubides. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/
import Lean.Data.Json

/-!
# Site configuration

The CLI reads `leanblog.json` when it exists. Keeping the configuration model separate from the
renderer lets a template change its identity and deployment details without editing framework code.
-/

namespace LeanBlog

open Lean

/-- A navigation link rendered in the site header. -/
structure NavigationItem where
  /-- The visible label. -/
  label : String
  /-- A site-relative URL. -/
  href : String
deriving Repr

/-- The user-facing identity and deployment settings for a LeanBlog site. -/
structure SiteConfig where
  /-- The site and browser title. -/
  title : String := "LeanBlog"
  /-- The short description shown on the archive. -/
  tagline : String := "A calm home for Lean-aware writing."
  /-- The default author metadata for the site. -/
  author : String := ""
  /-- The canonical site URL, when the deployment has one. -/
  siteUrl : String := ""
  /-- The deployment base path, retained for generated metadata. -/
  basePath : String := "/"
  /-- The footer text. -/
  footer : String := "Built with LeanBlog, Verso, Tailwind, and daisyUI."
  /-- The heading used above the archive entries. -/
  archiveTitle : String := "Recent posts"
  /-- The visible label for the archive navigation link. -/
  archiveLabel : String := "All posts"
  /-- The URL prefix used by declaration links. -/
  docsRoot : String := "/api"
  /-- The output directory name used for copied API documentation. -/
  docsDirectory : String := "api"
  /-- The initial color mode: `light`, `dark`, or `system`. -/
  defaultTheme : String := "system"
  /-- Additional links rendered in the primary navigation. -/
  navigation : Array NavigationItem := #[]
deriving Repr

namespace SiteConfig

/-- The defaults used when no configuration file is present. -/
def default : SiteConfig := {}

private def stringField (json : Json) (key : String) (fallback : String) : Except String String :=
  match json.getObjVal? key with
  | .error _ => pure fallback
  | .ok value => value.getStr?

private def navigationField (json : Json) : Except String (Array NavigationItem) := do
  match json.getObjVal? "navigation" with
  | .error _ => pure #[]
  | .ok value =>
    let entries ← value.getArr?
    entries.mapM fun entry => do
      let label ← entry.getObjValAs? String "label"
      let href ← entry.getObjValAs? String "href"
      pure {label, href}

/-- Decode a site configuration object, using defaults for omitted fields. -/
def fromJson? (json : Json) : Except String SiteConfig := do
  let _ ← json.getObj?
  let title ← stringField json "title" default.title
  let tagline ← stringField json "tagline" default.tagline
  let author ← stringField json "author" default.author
  let siteUrl ← stringField json "siteUrl" default.siteUrl
  let basePath ← stringField json "basePath" default.basePath
  let footer ← stringField json "footer" default.footer
  let archiveTitle ← stringField json "archiveTitle" default.archiveTitle
  let archiveLabel ← stringField json "archiveLabel" default.archiveLabel
  let docsRoot ← stringField json "docsRoot" default.docsRoot
  let docsDirectory ← stringField json "docsDirectory" default.docsDirectory
  let defaultTheme ← stringField json "defaultTheme" default.defaultTheme
  let navigation ← navigationField json
  pure {
    title := title
    tagline := tagline
    author := author
    siteUrl := siteUrl
    basePath := basePath
    footer := footer
    archiveTitle := archiveTitle
    archiveLabel := archiveLabel
    docsRoot := docsRoot
    docsDirectory := docsDirectory
    defaultTheme := defaultTheme
    navigation := navigation
  }

end SiteConfig

end LeanBlog
