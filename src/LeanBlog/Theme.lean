/-
Copyright (c) 2026 Jonathan Prieto-Cubides. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/
import VersoBlog

/-!
# LeanBlog's first theme

The generator keeps Verso's traversal and output machinery, but owns the page templates. The
templates use stable Tailwind and daisyUI utility classes so a cloned blog has a useful visual
baseline before it is customized.
-/

namespace LeanBlog

open Verso Doc Output Html
open Verso.Genre.Blog
open Verso.Genre.Blog.Template

namespace Theme

private def monthName : Nat → String
  | 1 => "Jan"
  | 2 => "Feb"
  | 3 => "Mar"
  | 4 => "Apr"
  | 5 => "May"
  | 6 => "Jun"
  | 7 => "Jul"
  | 8 => "Aug"
  | 9 => "Sep"
  | 10 => "Oct"
  | 11 => "Nov"
  | 12 => "Dec"
  | month => toString month

private def displayDate (date : Date) : String :=
  s!"{monthName date.month} {date.day}, {date.year}"

private def readingTime (post : BlogPost) : Nat :=
  let wordsPerMinute := 200
  let words := post.contents.content.foldl (fun total block => total + block.wordCount) 0
  max 1 ((words + wordsPerMinute - 1) / wordsPerMinute)

private def tags (metadata : Post.PartMetadata) : Html :=
  if metadata.categories.isEmpty then
    Html.empty
  else
    {{<div class="flex flex-wrap gap-2">
      {{metadata.categories.toArray.map fun tag =>
        {{<span class="badge badge-ghost">{{tag.name}}</span>}}}}
    </div>}}

private def header : TemplateM Html := do
  let header ← builtinHeader
  let emptySegments := (← currentPath).toList.foldl
    (fun count segment => if segment.isEmpty then count + 1 else count) 0
  if emptySegments == 0 then
    pure header
  else
    let relativeSegment := "../"
    header.visitM (tag := fun name attrs content =>
      if name == "base" then
        let attrs := attrs.map fun (key, value) =>
          if key == "href" then
            (key, value.drop (emptySegments * relativeSegment.length) |>.toString)
          else
            (key, value)
        pure <| some (.tag name attrs content)
      else
        pure none)

private def primary : Template := do
  let posts := (← param? "posts").getD .empty
  pure {{
    <html lang="en" data-theme="light">
      <head>
        <meta charset="utf-8"/>
        <meta name="viewport" content="width=device-width, initial-scale=1"/>
        <title>{{← param (α := String) "title"}}</title>
        {{← header}}
      </head>
      <body class="min-h-screen bg-base-200 text-base-content">
        <main class="mx-auto max-w-5xl px-4 py-8 sm:px-6 lg:px-8">
          <header class="mb-10 flex items-center justify-between gap-4">
            <a class="text-lg font-bold tracking-tight" href=".">"LeanBlog"</a>
            <nav class="flex items-center gap-3 text-sm">
              <a class="link link-hover" href=".">"Posts"</a>
              <span class="badge badge-ghost">"Lean-aware writing"</span>
            </nav>
          </header>
          {{← param "content"}}
          {{posts}}
        </main>
      </body>
    </html>
  }}

private def page : Template := do
  pure {{
    <article class="rounded-box bg-base-100 p-6 shadow-sm sm:p-10">
      <h1 class="mb-8 text-4xl font-black tracking-tight">{{← param "title"}}</h1>
      <div class="leanblog-prose">{{← param "content"}}</div>
    </article>
  }}

private def post : Template := do
  pure {{
    <article class="rounded-box bg-base-100 p-6 shadow-sm sm:p-10">
      <div class="mb-8">
        <h1 class="mb-3 text-4xl font-black tracking-tight">{{← param "title"}}</h1>
        {{ match (← param? "metadata") with
          | none => Html.empty
          | some md => {{
            <div class="flex flex-wrap items-center gap-2 text-sm text-base-content/60">
              <span>{{
                (md : Post.PartMetadata).authors.map
                  ({{<span>{{Html.text true ·}}</span>}}) |>.toArray
              }}</span>
              <span aria-hidden="true">"·"</span>
              <time datetime={{md.date.toIso8601String}}>{{displayDate md.date}}</time>
            </div>
            {{tags md}}
          }}
        }}
      </div>
      <div class="leanblog-prose">{{← param "content"}}</div>
    </article>
  }}

private def archiveEntry : Template := do
  let post : BlogPost ← param "post"
  let summary ← param "summary"
  let name ← post.postName'
  let target ← match (← param? (α := String) "path") with
    | some path => pure <| if path.isEmpty then name else path ++ "/" ++ name
    | none => pure name
  pure #[{{
    <li class="h-full">
      <article class="card h-full border border-base-300 bg-base-100 shadow-sm transition
         hover:-translate-y-0.5 hover:shadow-md">
        <div class="card-body">
          {{ match post.contents.metadata with
            | none => Html.empty
            | some md => {{
              <div class="mb-3 flex flex-wrap items-center gap-2 text-xs font-semibold uppercase
                tracking-[0.14em] text-base-content/55">
                <time datetime={{md.date.toIso8601String}}>{{displayDate md.date}}</time>
                <span aria-hidden="true">"·"</span>
                <span>{{toString (readingTime post)}} " min read"</span>
              </div>
            }}
          }}
          <h2 class="card-title text-2xl"><a class="link-hover" href={{target ++ "/"}}>
            {{post.contents.titleString}}</a></h2>
          {{ match post.contents.metadata with
            | none => Html.empty
            | some md => {{
              <div class="flex flex-wrap items-center gap-2 text-sm text-base-content/60">
                <span>{{
                  (md : Post.PartMetadata).authors.map
                    ({{<span>{{Html.text true ·}}</span>}}) |>.toArray
                }}</span>
              </div>
              {{tags md}}
            }}
          }}
          <div class="leanblog-prose post-summary">{{summary}}</div>
          <a class="link link-primary mt-2" href={{target ++ "/"}}>
            "Read more"</a>
        </div>
      </article>
    </li>
  }}]

private def category : Template := do
  let category : Post.Category ← param "category"
  pure {{
    <article class="rounded-box bg-base-100 p-6 shadow-sm sm:p-10">
      <h1 class="text-4xl font-black tracking-tight">{{category.name}}</h1>
    </article>
  }}

/-- Build the initial Tailwind/daisyUI theme around an already-built stylesheet. -/
def make (css : String) : Verso.Genre.Blog.Theme where
  primaryTemplate := primary
  pageTemplate := page
  postTemplate := post
  archiveEntryTemplate := archiveEntry
  categoryTemplate := category
  cssFiles := #[("leanblog.css", css)]

end Theme

end LeanBlog
