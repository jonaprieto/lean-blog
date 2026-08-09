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
    {{<div class="post-tags">
      {{metadata.categories.toArray.map fun tag =>
        {{<a href={{categoryHref path tag}} class="post-tag">{{tag.name}}</a>}}}}
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
  const buildTableOfContents = () => {
    document.querySelectorAll('[data-post-toc]').forEach((toc) => {
      const article = toc.closest('.post-page');
      const nav = toc.querySelector('[data-post-toc-nav]');
      const requestedDepth = Number.parseInt(toc.dataset.postTocDepth || '3', 10);
      const depth = Number.isFinite(requestedDepth) ? Math.max(1, Math.min(6, requestedDepth)) : 3;
      const headings = article
        ? Array.from(article.querySelectorAll(
            Array.from({ length: depth }, (_, index) => `.leanblog-prose h${index + 1}`).join(', '))
        : [];
      if (!nav || headings.length < 2) {
        toc.hidden = true;
        return;
      }
      const usedIds = new Set();
      const slugify = (text) => text.toLowerCase().trim()
        .replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
      const list = document.createElement('ol');
      headings.forEach((heading, index) => {
        const baseId = heading.id || slugify(heading.textContent || '') || `section-${index + 1}`;
        let id = baseId;
        let suffix = 2;
        while (
          usedIds.has(id) ||
          (document.getElementById(id) && document.getElementById(id) !== heading)
        ) {
          id = `${baseId}-${suffix}`;
          suffix += 1;
        }
        usedIds.add(id);
        heading.id = id;
        const item = document.createElement('li');
        const link = document.createElement('a');
        link.className = `post-toc-link post-toc-level-${heading.tagName.slice(1)}`;
        link.href = `#${id}`;
        link.textContent = heading.textContent || id;
        item.append(link);
        list.append(item);
      });
      nav.replaceChildren(list);
      toc.hidden = false;
    });
  };
  document.addEventListener('DOMContentLoaded', () => {
    update();
    buildTableOfContents();
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
  <footer class="site-footer">
    <div class="site-footer-inner">
      <span>"Built with LeanBlog, Verso, Tailwind, and daisyUI."</span>
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
  let posts := (← param? "posts")
  pure {{
    <html lang="en" data-theme="light">
      <head>
        <meta charset="utf-8"/>
        <meta name="viewport" content="width=device-width, initial-scale=1"/>
        <title>{{← param (α := String) "title"}}</title>
        {{← header}}
      </head>
      <body class="site-body min-h-screen bg-base-100 text-base-content">
        <div class="site-shell flex min-h-screen flex-col">
          <header class="site-header">
            <div class="site-header-inner">
              <a class="site-brand" href=".">"LeanBlog"</a>
              <nav class="site-nav" aria-label="Primary">
                <a class="site-link site-link-strong" href=".">"All posts"</a>
              </nav>
              <button type="button" class="site-theme-toggle" data-theme-toggle
                aria-label="Toggle color theme">
                <span data-theme-icon aria-hidden="true">"☾"</span>
              </button>
            </div>
          </header>
          <main class="site-main w-full flex-1">
            <div class="site-content">
              {{← param "content"}}
              {{match posts with
                | none => Html.empty
                | some posts => {{
                  <section class="site-posts" aria-labelledby="recent-posts-title">
                    <div class="site-section-heading">
                      <h2 id="recent-posts-title">"Recent posts"</h2>
                    </div>
                    {{posts}}
                  </section>
                }}}}
            </div>
          </main>
          {{footer}}
        </div>
      </body>
    </html>
  }}

private def page : Template := do
  pure {{
    <article class="page-content">
      <h1 class="page-title">{{← param "title"}}</h1>
      <div class="leanblog-prose">{{← param "content"}}</div>
    </article>
  }}

private def post : Template := do
  let path := (← param? (α := String) "path").getD ""
  pure {{
    <article class="post-page">
      <header class="post-header">
          <h1 class="post-title">{{← param "title"}}</h1>
          {{ match (← param? "metadata") with
            | none => Html.empty
            | some md => {{
              <div class="post-meta">
                <span>"By "{{
                  (md : Post.PartMetadata).authors.map
                    ({{<span>{{Html.text true ·}}</span>}}) |>.toArray
                }}</span>
                <span aria-hidden="true">"·"</span>
                <time datetime={{md.date.toIso8601String}}>
                  "Published "{{displayDate md.date}}
                </time>
              </div>
              {{tags path md}}
            }}
          }}
      </header>
      <div class="post-layout">
        <div class="post-main">
          <div class="leanblog-prose">{{← param "content"}}</div>
          <div id="leanblog-related-posts"></div>
        </div>
        <aside class="post-toc" data-post-toc data-post-toc-depth="3" hidden>
          <p class="post-toc-title">"On this page"</p>
          <nav data-post-toc-nav aria-label="Table of contents"></nav>
        </aside>
      </div>
    </article>
  }}

private def archiveEntry : Template := do
  let post : BlogPost ← param "post"
  let path := (← param? (α := String) "path").getD ""
  let name ← post.postName'
  let target := if path.isEmpty then name else path ++ "/" ++ name
  pure #[{{
    <li class="post-list-item">
      <article class="post-entry">
        <div class="post-entry-row">
          {{ match post.contents.metadata with
            | none => Html.empty
            | some md => {{
              <time class="post-entry-date" datetime={{md.date.toIso8601String}}>
                {{displayDate md.date}}</time>
            }}
          }}
          <h2 class="post-entry-title"><a href={{target ++ "/"}}>
            {{post.contents.titleString}}</a></h2>
          {{ match post.contents.metadata with
            | none => Html.empty
            | some _ => {{
              <span class="post-entry-details">{{toString (readingTime post)}} " min read"</span>
            }}
          }}
        </div>
      </article>
    </li>
  }}]

private def category : Template := do
  let category : Post.Category ← param "category"
  pure {{
    <div class="category-header">
      <div>
        <p class="page-kicker">"Topic"</p>
        <h1 class="page-title">{{category.name}}</h1>
      </div>
      <a class="site-back-link" href=".">"← All posts"</a>
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
