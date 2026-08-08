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

private def primary : Template := do
  let posts := (← param? "posts").getD .empty
  pure {{
    <html lang="en" data-theme="light">
      <head>
        <meta charset="utf-8"/>
        <meta name="viewport" content="width=device-width, initial-scale=1"/>
        <title>{{← param (α := String) "title"}}</title>
        {{← builtinHeader}}
      </head>
      <body class="min-h-screen bg-base-200 text-base-content">
        <main class="mx-auto max-w-5xl px-4 py-8 sm:px-6 lg:px-8">
          <header class="mb-10 flex items-center justify-between gap-4">
            <a class="text-lg font-bold tracking-tight" href=".">"LeanBlog"</a>
            <span class="badge badge-ghost">"Lean-aware writing"</span>
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
              <span>{{(md : Post.PartMetadata).authors.map ({{<span>{{Html.text true ·}}</span>}}) |>.toArray}}</span>
              <span aria-hidden="true">"·"</span>
              <time datetime={{md.date.toIso8601String}}>{{md.date.toIso8601String}}</time>
            </div>
          }}
        }}
      </div>
      <div class="leanblog-prose">{{← param "content"}}</div>
    </article>
  }}

private def archiveEntry : Template := do
  let post : BlogPost ← param "post"
  let summary ← param "summary"
  let target ← post.postName'
  pure #[{{
    <a class="card border border-base-300 bg-base-100 shadow-sm transition hover:-translate-y-0.5 hover:shadow-md"
       href={{target}}>
      <div class="card-body">
        <h2 class="card-title">{{post.contents.titleString}}</h2>
        {{summary}}
        <span class="link link-primary mt-2">"Read more"</span>
      </div>
    </a>
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
