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

private def categoryHref (path : String) (category : Post.Category) : String :=
  let base := if path.isEmpty then "" else path ++ "/"
  base ++ category.slug ++ "/"

private def tags (path : String) (metadata : Post.PartMetadata) : Html :=
  if metadata.categories.isEmpty then
    Html.empty
  else
    {{<div class="flex flex-wrap gap-2">
      {{metadata.categories.toArray.map fun tag =>
        {{<a href={{categoryHref path tag}} class="badge badge-outline transition
          hover:badge-primary">{{tag.name}}</a>}}}}
    </div>}}

private def categoryNav (categories : Post.Categories) : Html :=
  if categories.categories.isEmpty then
    Html.empty
  else
    {{<div class="mt-8 border-t border-base-300 pt-6">
      <p class="mb-3 text-xs font-bold uppercase tracking-[0.16em]
        text-base-content/50">"Topics"</p>
      <ul class="menu menu-sm -mx-3 rounded-box p-0">
        {{categories.categories.map fun (href, category) =>
          {{<li><a href={{href}}>{{category.name}}</a></li>}}}}
      </ul>
    </div>}}

private def mermaidAssets : Html :=
  let script := "import mermaid from \"https://cdn.jsdelivr.net/npm/mermaid@11/" ++
    "dist/mermaid.esm.min.mjs\";\n" ++
    "const renderMermaid = async () => {\n" ++
    "  const theme = document.documentElement.dataset.theme === \"dark\" ? " ++
    "\"dark\" : \"default\";\n" ++
    "  const diagrams = Array.from(document.querySelectorAll(\".mermaid\"));\n" ++
    "  if (diagrams.length === 0) return;\n" ++
    "  for (const diagram of diagrams) {\n" ++
    "    if (!diagram.dataset.mermaidSource) diagram.dataset.mermaidSource = " ++
    "diagram.textContent || \"\";\n" ++
    "    diagram.removeAttribute(\"data-processed\");\n" ++
    "    diagram.textContent = diagram.dataset.mermaidSource;\n" ++
    "  }\n" ++
    "  mermaid.initialize({ startOnLoad: false, securityLevel: \"strict\", theme });\n" ++
    "  await mermaid.run({ nodes: diagrams });\n" ++
    "};\n" ++
    "document.addEventListener(\"DOMContentLoaded\", renderMermaid);\n" ++
    "document.addEventListener(\"leanblog-theme-change\", renderMermaid);"
  {{<script type="module">{{Html.text false script}}</script>}}

private def themeAssets : Html :=
  let script := r#"
(() => {
  const root = document.documentElement;
  const stored = (() => {
    try { return localStorage.getItem('leanblog-theme'); } catch (_) { return null; }
  })();
  const preferred = typeof window.matchMedia === 'function' &&
    window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
  root.dataset.theme = stored === 'dark' || stored === 'light' ? stored : preferred;
  const update = () => {
    const dark = root.dataset.theme === 'dark';
    document.querySelectorAll('[data-theme-toggle]').forEach((button) => {
      button.querySelector('[data-theme-icon]').textContent = dark ? '☀' : '☾';
      button.setAttribute('aria-label', dark ? 'Use light theme' : 'Use dark theme');
    });
  };
  document.addEventListener('DOMContentLoaded', () => {
    update();
    document.querySelectorAll('[data-theme-toggle]').forEach((button) => {
      button.addEventListener('click', () => {
        root.dataset.theme = root.dataset.theme === 'dark' ? 'light' : 'dark';
        try { localStorage.setItem('leanblog-theme', root.dataset.theme); } catch (_) {}
        update();
        document.dispatchEvent(new CustomEvent('leanblog-theme-change'));
      });
    });
  });
})();
"#
  {{<script>{{Html.text false script}}</script>}}

private def footer : Html := {{
  <footer class="border-t border-base-300 bg-base-100">
    <div class="mx-auto flex max-w-7xl flex-col gap-2 px-4 py-8 text-sm
      text-base-content/55 sm:flex-row sm:items-center sm:justify-between sm:px-6 lg:px-8">
      <span class="font-semibold text-base-content">"LeanBlog"</span>
      <span>"A calm home for Lean-aware writing."</span>
    </div>
  </footer>
}}

private def header : TemplateM Html := do
  let header ← builtinHeader
  let emptySegments := (← currentPath).toList.foldl
    (fun count segment => if segment.isEmpty then count + 1 else count) 0
  let header ← if emptySegments == 0 then
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
  pure <| header ++ themeAssets ++ mermaidAssets

private def primary : Template := do
  let posts := (← param? "posts").getD .empty
  let categories := (← param? (α := Post.Categories) "categories").getD (.mk #[])
  pure {{
    <html lang="en" data-theme="light">
      <head>
        <meta charset="utf-8"/>
        <meta name="viewport" content="width=device-width, initial-scale=1"/>
        <title>{{← param (α := String) "title"}}</title>
        {{← header}}
      </head>
      <body class="min-h-screen bg-base-200 text-base-content">
        <div class="drawer lg:drawer-open">
          <input id="leanblog-drawer" type="checkbox" class="drawer-toggle"/>
          <div class="drawer-content flex min-h-screen flex-col">
            <header class="navbar sticky top-0 z-30 border-b border-base-300 bg-base-100/90 px-4
              backdrop-blur sm:px-6 lg:px-8">
              <div class="flex-none lg:hidden">
                <label for="leanblog-drawer" class="btn btn-square btn-ghost"
                  aria-label="Open navigation">"☰"</label>
              </div>
              <div class="flex-1">
              <a class="text-xl font-bold tracking-tight" href=".">"LeanBlog"</a>
                <span class="ml-3 hidden text-sm text-base-content/55 sm:inline">
                  "Lean-aware publishing"</span>
              </div>
              <div class="flex-none">
                <button type="button" class="btn btn-circle btn-ghost" data-theme-toggle
                  aria-label="Toggle color theme">
                  <span data-theme-icon aria-hidden="true">"☾"</span>
                </button>
              </div>
            </header>
            <main class="w-full flex-1">
              <div class="leanblog-shell mx-auto max-w-6xl px-4 py-8 sm:px-6 lg:px-8 lg:py-12">
                <div class="leanblog-home-intro">{{← param "content"}}</div>
                {{posts}}
              </div>
            </main>
            {{footer}}
          </div>
          <div class="drawer-side z-40">
            <label for="leanblog-drawer" class="drawer-overlay"
              aria-label="Close navigation"></label>
            <aside class="flex min-h-full w-64 flex-col border-r border-base-300 bg-base-100 p-5">
              <div>
                <p class="text-xs font-bold uppercase tracking-[0.2em] text-primary">"LeanBlog"</p>
                <p class="mt-2 text-sm leading-6 text-base-content/60">
                  "Notes, explanations, and Lean-aware documentation."</p>
              </div>
              <nav class="mt-8">
                <p class="mb-3 text-xs font-bold uppercase tracking-[0.16em]
                  text-base-content/50">"Explore"</p>
                <ul class="menu menu-sm -mx-3 rounded-box p-0">
                  <li><a class="font-semibold" href=".">"All posts"</a></li>
                </ul>
                {{categoryNav categories}}
              </nav>
              <div class="mt-auto border-t border-base-300 pt-6 text-xs leading-5
                text-base-content/50">
                "Built with LeanBlog, Verso, Tailwind, and daisyUI."
              </div>
            </aside>
          </div>
        </div>
      </body>
    </html>
  }}

private def page : Template := do
  pure {{
    <article class="mx-auto max-w-4xl rounded-xl border border-base-300 bg-base-100 p-6
      shadow-sm sm:p-10 lg:p-12">
      <h1 class="mb-8 text-4xl font-black tracking-tight sm:text-5xl">{{← param "title"}}</h1>
      <div class="leanblog-prose">{{← param "content"}}</div>
    </article>
  }}

private def post : Template := do
  let path := (← param? (α := String) "path").getD ""
  pure {{
    <div class="mx-auto grid max-w-6xl gap-8 lg:grid-cols-[minmax(0,1fr)_15rem] lg:items-start">
      <article class="rounded-xl border border-base-300 bg-base-100 p-6 shadow-sm sm:p-10 lg:p-12">
        <div class="mb-10 border-b border-base-300 pb-8">
          <p class="mb-3 text-xs font-bold uppercase tracking-[0.18em] text-primary">
            "A LeanBlog post"</p>
          <h1 class="mb-4 text-4xl font-black tracking-tight sm:text-5xl">{{← param "title"}}</h1>
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
              {{tags path md}}
            }}
          }}
        </div>
        <div class="leanblog-prose">{{← param "content"}}</div>
        <div id="leanblog-related-posts"></div>
      </article>
      <aside class="hidden lg:block">
        <div class="sticky top-24 rounded-box border border-base-300 bg-base-100 p-5 shadow-sm">
          <p class="text-xs font-bold uppercase tracking-[0.16em]
            text-base-content/50">"In this collection"</p>
          <a class="btn btn-primary btn-sm mt-4 w-full" href=".">"Browse all posts"</a>
          <p class="mt-4 text-xs leading-5 text-base-content/55">
            "Lean-aware writing with linked declarations, diagrams, and examples."</p>
        </div>
      </aside>
    </div>
  }}

private def archiveEntry : Template := do
  let post : BlogPost ← param "post"
  let summary ← param "summary"
  let path := (← param? (α := String) "path").getD ""
  let name ← post.postName'
  let target := if path.isEmpty then name else path ++ "/" ++ name
  pure #[{{
    <li class="h-full">
      <article class="card h-full rounded-xl border border-base-300 bg-base-100 shadow-sm
        transition hover:-translate-y-0.5 hover:shadow-md">
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
              {{tags path md}}
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
    <div class="mx-auto max-w-6xl">
      <div class="mb-8 flex flex-wrap items-end justify-between gap-4">
        <div>
          <p class="mb-2 text-xs font-bold uppercase tracking-[0.18em] text-primary">"Topic"</p>
          <h1 class="text-4xl font-black tracking-tight sm:text-5xl">{{category.name}}</h1>
        </div>
        <a class="btn btn-ghost btn-sm" href=".">"All posts"</a>
      </div>
    </div>
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
