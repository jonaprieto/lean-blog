/-
Copyright (c) 2026 Jonathan Prieto-Cubides. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/
import MD4Lean
import VersoBlog
import LeanBlog.Icons
import LeanBlog.Links

/-!
# Markdown source

The source format is intentionally small and explicit:

```
---
title: A post
date: 2026-08-07
authors: Jonathan Prieto-Cubides
tags: lean, tutorial
---

The [`Sum`](lean:Sum) type has two constructors.
```

The body is parsed by MD4Lean. `lean:` destinations are resolved before lowering to Verso, so a
misspelled declaration is a build error instead of a dead hyperlink.
-/

namespace LeanBlog

open Verso Doc Output Html
open Verso.Genre.Blog

/-- The source-level metadata shared by a Markdown post and its Verso value. -/
structure PostSource where
  /-- The title shown in the post and collection. -/
  title : String
  /-- The publication date. -/
  date : Date
  /-- The authors shown in the post metadata. -/
  authors : List String := []
  /-- Short labels shown with the post in the collection. -/
  tags : List String := []
  /-- The parsed Markdown body. -/
  document : MD4Lean.Document
deriving Repr

private def parseField (line : String) : Except String (String × String) :=
  let parts := line.splitOn ":"
  match parts with
  | [] => .error s!"Malformed front matter line: {line}"
  | key :: value =>
    if value.isEmpty then
      .error s!"Missing value for front matter field '{key.trimAscii}'"
    else
      .ok (key.trimAscii.toString, String.intercalate ":" value |>.trimAscii.toString)

private def parseNatField (field : String) (value : String) : Except String Nat :=
  match value.toNat? with
  | some value => .ok value
  | none => .error s!"Front matter field '{field}' expects a natural number, got '{value}'"

private def parseDate (value : String) : Except String Date := do
  let parts := value.splitOn "-"
  match parts with
  | [year, month, day] =>
    let year ← parseNatField "date" year
    let month ← parseNatField "date" month
    let day ← parseNatField "date" day
    pure {year := year, month, day}
  | _ => .error s!"Front matter date must use YYYY-MM-DD, got '{value}'"

private def parseFrontMatter (lines : List String) :
    Except String (List (String × String) × List String) := do
  match lines with
  | "---" :: rest =>
    let rec collectFields (fields : List (String × String)) (remaining : List String) :
        Except String (List (String × String) × List String) :=
      match remaining with
      | [] => .error "Front matter is missing its closing '---'"
      | "---" :: body => .ok (fields, body)
      | line :: more => do
        let field ← parseField line
        collectFields (fields.concat field) more
    collectFields [] rest
  | _ => .error "A Markdown post must start with front matter delimited by '---'"

private def field? (fields : List (String × String)) (key : String) : Option String :=
  fields.find? (·.fst == key) |>.map (·.snd)

private def requireField (fields : List (String × String)) (key : String) : Except String String :=
  match field? fields key with
  | some value => .ok value
  | none => .error s!"Front matter is missing '{key}'"

/-- Parse a Markdown source string into a post with a CommonMark body. -/
def parsePost (source : String) : Except String PostSource := do
  let (fields, bodyLines) ← parseFrontMatter (source.splitOn "\n")
  let title ← requireField fields "title"
  let dateString ← requireField fields "date"
  let date ← parseDate dateString
  let authorsString := field? fields "authors" |>.getD ""
  let authors := authorsString.splitOn "," |>.map (·.trimAscii.toString) |>.filter (!·.isEmpty)
  let tagsString := field? fields "tags" |>.getD ""
  let tags := tagsString.splitOn "," |>.map (·.trimAscii.toString) |>.filter (!·.isEmpty)
  let body := String.intercalate "\n" bodyLines
  let some document := MD4Lean.parse body
      (parserFlags := MD4Lean.MD_DIALECT_GITHUB ||| MD4Lean.MD_FLAG_LATEXMATHSPANS)
    | .error "Markdown parser rejected the post body"
  pure {title, date, authors, tags, document}

private def attrText (text : Array MD4Lean.AttrText) : Except String String := do
  let mut result := ""
  for part in text do
    match part with
    | .normal value | .entity value => result := result ++ value
    | .nullchar => throw "Markdown link contains a null character"
  pure result

private def attrTextD (text : Array MD4Lean.AttrText) : String :=
  match attrText text with
  | .ok value => value
  | .error _ => ""

private def stripQuotes (value : String) : String :=
  match value.toList with
  | '"' :: rest =>
    match rest.reverse with
    | '"' :: inner => String.ofList inner.reverse
    | _ => value
  | '\'' :: rest =>
    match rest.reverse with
    | '\'' :: inner => String.ofList inner.reverse
    | _ => value
  | _ => value

private def codeTitle? (info lang : Array MD4Lean.AttrText) : Option String :=
  let info := attrTextD info
  let language := attrTextD lang
  let suffix := info.dropPrefix language |>.trimAscii.toString
  if !"title=".isPrefixOf suffix then
    none
  else
    let title := stripQuotes <| suffix.drop 6 |>.trimAscii.toString
    if title.isEmpty then none else some title

private def codeChrome (title? : Option String) : Html := {{
  {{match title? with
    | none => Html.empty
    | some title => {{<div class="leanblog-code-title">{{Html.text true title}}</div>}}}}
  <button type="button" class="code-copy-button" data-code-copy
    aria-label="Copy code" title="Copy code">{{Icon.clipboardDocument.toHtml}}</button>
}}

private def codeWrapper (info lang source : String) (title? : Option String)
    (contents : Array (Block Page)) : Block Page :=
  let classes := if title?.isSome then "leanblog-code has-title" else "leanblog-code"
  .other (.htmlWrapper "div" #[
    ("class", classes),
    ("data-code-source", source),
    ("data-code-info", info),
    ("data-code-language", lang)
  ]) contents

private def leanName (target : String) : Except String Lean.Name :=
  let name := target.toName
  if name == .anonymous then
    .error "A lean: link must name a declaration"
  else
    .ok name

private def linkedTarget (index : DeclarationIndex) (href : String) : Except String Target := do
  let name ← leanName (href.drop 5 |>.toString)
  match index.resolveOne name with
  | some target => pure target
  | none => .error <| s!"No declaration target registered for 'lean:{name}'; " ++
      "provide a generated xref.json or an explicit target"

mutual
  private def lowerInline (index : DeclarationIndex) : MD4Lean.Text → Except String (Inline Page)
    | .normal value => pure (Verso.Doc.Inline.text value)
    | .nullchar => pure (Verso.Doc.Inline.text "�")
    | .br value | .softbr value => pure (.linebreak value)
    | .entity value => pure (Verso.Doc.Inline.text value)
    | .em content => .emph <$> lowerInlines index content
    | .strong content => .bold <$> lowerInlines index content
    | .u content => .emph <$> lowerInlines index content
    | .del content => .other (.htmlSpan "line-through") <$> lowerInlines index content
    | .code content => pure (.code (String.join content.toList))
    | .latexMath content => pure (.math .inline (String.join content.toList))
    | .latexMathDisplay content => pure (.math .display (String.join content.toList))
    | .img src _title alt => do
      let alt := alt.foldl (init := "") fun result text =>
        match text with
        | .normal value => result ++ value
        | .code value => result ++ String.join value.toList
        | _ => result
      pure (.image alt (← attrText src))
    | .wikiLink target content => do
      let url ← attrText target
      .link <$> lowerInlines index content <*> pure url
    | .a href _title _isAuto content => do
      let href ← attrText href
      let url ←
        if "lean:".isPrefixOf href then (linkedTarget index href).map (·.href) else pure href
      .link <$> lowerInlines index content <*> pure url
  private def lowerInlines (index : DeclarationIndex) (content : Array MD4Lean.Text) :
      Except String (Array (Inline Page)) :=
    content.mapM (lowerInline index)

end

private def mermaidBlock (code : String) : Block Page :=
  .other (.blob {{<div class="mermaid">{{Html.text true code}}</div>}}) #[]

private def lowerBlock (index : DeclarationIndex)
    (highlight? : String → Option SubVerso.Highlighting.Highlighted) :
    MD4Lean.Block → Except String (Block Page)
    | .p content => .para <$> lowerInlines index content
    | .header level content => do
      let title ← lowerInlines index content
      pure <| .other (.docstringSection (level - 1)) #[.para title]
    | .code _info lang _fence content => do
      let code := String.join content.toList
      let language := attrTextD lang
      let info := attrTextD _info
      let title? := codeTitle? _info lang
      if language == "mermaid" then
        pure <| mermaidBlock code
      else
        let chrome := .other (.blob (codeChrome title?)) #[]
        let isLean := language == "lean" || language == "lean4"
        match if isLean then highlight? code else none with
        | some highlighted =>
          pure <| codeWrapper info language code title? #[chrome, .other (.highlightedCode {
            contextName := .anonymous
            showProofStates := false
          } highlighted) #[.code code]]
        | none => pure <| codeWrapper info language code title? #[chrome, .code code]
    | .blockquote _ => .error "Block quotes are not supported in Markdown posts yet"
    | .ul _ _ _ => .error "Lists are not supported in Markdown posts yet"
    | .ol _ _ _ _ => .error "Lists are not supported in Markdown posts yet"
    | .hr => pure (.other (.htmlDiv "leanblog-rule") #[])
    | .html _ => .error "Raw HTML is not supported in Markdown posts"
    | .table _ _ => .error "Tables are not supported in Markdown posts yet"

/-- Lower a parsed post to the Verso blog genre after resolving all `lean:` links. -/
def PostSource.toPartWithHighlight
    (source : PostSource) (index : DeclarationIndex)
    (highlight? : String → Option SubVerso.Highlighting.Highlighted) :
    Except String (Verso.Doc.Part Post) := do
  let content ← source.document.blocks.mapM (lowerBlock index highlight?)
  let categories := source.tags.map fun tag => {
    name := tag
    slug := slugifyTitle tag
  }
  pure <| Part.mk #[Verso.Doc.Inline.text source.title] source.title (some {
    date := source.date
    authors := source.authors
    categories
  }) content #[]

/-- Lower a parsed post without requiring a code-highlighting environment. -/
def PostSource.toPart (source : PostSource) (index : DeclarationIndex) :
    Except String (Verso.Doc.Part Post) :=
  source.toPartWithHighlight index (fun _ => none)

end LeanBlog
