/-
Copyright (c) 2026 Jonathan Prieto-Cubides. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/
import VersoBlog
import VersoSearch.DomainSearch
import LeanBlog.Icons

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
      button.querySelector('[data-theme-icon-light]').hidden = dark;
      button.querySelector('[data-theme-icon-dark]').hidden = !dark;
      button.setAttribute('aria-label', dark ? 'Use light theme' : 'Use dark theme');
    });
  };
  const buildTableOfContents = () => {
    document.querySelectorAll('[data-post-toc]').forEach((toc) => {
      const article = toc.closest('.post-page');
      const nav = toc.querySelector('[data-post-toc-nav]');
      const requestedDepth = Number.parseInt(toc.dataset.postTocDepth || '3', 10);
      const depth = Number.isFinite(requestedDepth) ? Math.max(1, Math.min(6, requestedDepth)) : 3;
      const selectors = Array.from({ length: depth }, (_, index) =>
        `.leanblog-prose h${index + 1}`).join(', ');
      const headings = article
        ? Array.from(article.querySelectorAll(selectors))
        : [];
      if (!nav || headings.length < 2) {
        toc.hidden = true;
        return;
      }
      const usedIds = new Set();
      const slugify = (text) => text.toLowerCase().trim()
        .replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
      const list = document.createElement('ul');
      const stack = [{ level: 0, list }];
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
        const level = Number(heading.tagName.slice(1));
        while (stack.length > 1 && level <= stack[stack.length - 1].level) stack.pop();
        const item = document.createElement('li');
        const link = document.createElement('a');
        link.className = `post-toc-link post-toc-level-${heading.tagName.slice(1)}`;
        link.href = `#${id}`;
        link.textContent = heading.textContent || id;
        item.append(link);
        stack[stack.length - 1].list.append(item);
        const next = headings[index + 1];
        const nextLevel = next ? Number(next.tagName.slice(1)) : 0;
        if (nextLevel > level) {
          const nested = document.createElement('ul');
          item.append(nested);
          stack.push({ level, list: nested });
        }
      });
      nav.replaceChildren(list);
      toc.hidden = false;
      const links = Array.from(nav.querySelectorAll('a'));
      const setActive = (heading) => {
        links.forEach((link) => {
          const active = link.getAttribute('href') === `#${heading.id}`;
          link.classList.toggle('is-active', active);
          if (active) link.setAttribute('aria-current', 'location');
          else link.removeAttribute('aria-current');
        });
      };
      const updateActive = () => {
        let current = headings[0];
        headings.forEach((heading) => {
          if (heading.getBoundingClientRect().top <= 140) current = heading;
        });
        setActive(current);
      };
      updateActive();
      window.addEventListener('scroll', updateActive, { passive: true });
    });
  };
  const splitNode = (node) => {
    if (node.nodeType === 3) {
      return node.textContent.split('\n').map((text) => document.createTextNode(text));
    }
    if (node.nodeType !== 1) return [node.cloneNode(true)];
    const lines = [[]];
    Array.from(node.childNodes).forEach((child) => {
      splitNode(child).forEach((part, index) => {
        if (index > 0) lines.push([]);
        lines[lines.length - 1].push(part);
      });
    });
    return lines.map((children) => {
      const clone = node.cloneNode(false);
      clone.replaceChildren(...children);
      return clone;
    });
  };
  const addLineNumbers = (code, source) => {
    if (code.dataset.linesReady) return;
    const lines = [[]];
    Array.from(code.childNodes).forEach((child) => {
      splitNode(child).forEach((part, index) => {
        if (index > 0) lines.push([]);
        lines[lines.length - 1].push(part);
      });
    });
    if (source.endsWith('\n') && lines.length > 1 && lines[lines.length - 1].length === 0) {
      lines.pop();
    }
    const fragment = document.createDocumentFragment();
    lines.forEach((children, index) => {
      const line = document.createElement('span');
      line.className = 'leanblog-code-line';
      line.dataset.line = String(index + 1);
      line.append(...children);
      fragment.append(line);
    });
    code.replaceChildren(fragment);
    code.classList.add('leanblog-code-lines');
    code.dataset.linesReady = 'true';
  };
  const copyText = async (text) => {
    if (navigator.clipboard && navigator.clipboard.writeText) {
      await navigator.clipboard.writeText(text);
      return;
    }
    const textarea = document.createElement('textarea');
    textarea.value = text;
    textarea.setAttribute('readonly', '');
    textarea.style.position = 'fixed';
    textarea.style.opacity = '0';
    document.body.append(textarea);
    textarea.select();
    const copied = document.execCommand('copy');
    textarea.remove();
    if (!copied) throw new Error('Copy failed');
  };
  const enhanceCodeBlocks = () => {
    document.querySelectorAll('.leanblog-code').forEach((block) => {
      const code = block.querySelector('code.hl.lean.block, pre');
      const button = block.querySelector('[data-code-copy]');
      if (!code || !button) return;
      const source = (block.dataset.codeSource || code.textContent || '')
        .replace(/\r\n?/g, '\n');
      addLineNumbers(code, source);
      button.addEventListener('click', async () => {
        try {
          await copyText(source);
          button.classList.add('copied');
          button.setAttribute('aria-label', 'Code copied');
          button.title = 'Code copied';
          window.setTimeout(() => {
            button.classList.remove('copied');
            button.setAttribute('aria-label', 'Copy code');
            button.title = 'Copy code';
          }, 1600);
        } catch (_) {
          button.setAttribute('aria-label', 'Copy failed');
          button.title = 'Copy failed';
        }
      });
    });
  };
  const setupPostActions = () => {
    const feedback = document.querySelector('[data-post-action-feedback]');
    const showFeedback = (message) => {
      if (!feedback) return;
      feedback.textContent = message;
      window.setTimeout(() => { feedback.textContent = ''; }, 2200);
    };
    const share = document.querySelector('[data-share-post]');
    share?.addEventListener('click', async () => {
      const url = window.location.href.split('#')[0];
      try {
        if (navigator.share) await navigator.share({ title: document.title, url });
        else {
          await copyText(url);
          showFeedback('Link copied');
        }
      } catch (error) {
        if (error.name !== 'AbortError') showFeedback('Unable to share');
      }
    });
    document.querySelectorAll('[data-print-post]').forEach((button) => {
      button.addEventListener('click', () => window.print());
    });
  };
  document.addEventListener('DOMContentLoaded', () => {
    update();
    buildTableOfContents();
    enhanceCodeBlocks();
    setupPostActions();
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
  pure <| header ++ Verso.Search.searchAssetTags ++ themeAssets ++ mermaidAssets

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
                <span data-theme-icon-light>{{Icon.toHtml .moon}}</span>
                <span data-theme-icon-dark hidden>{{Icon.toHtml .sun}}</span>
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
  let postPath := (← currentPath).toList.filter (· != "")
  let rawHref := String.intercalate "/" (postPath ++ ["raw", ""])
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
          <div class="post-actions post-actions-bottom" aria-label="Post actions">
            <button type="button" class="post-action" data-share-post>
              {{Icon.toHtml .share}}<span>"Share"</span>
            </button>
            <a class="post-action" href={{rawHref}}>
              {{Icon.toHtml .codeBracket}}<span>"See raw"</span>
            </a>
            <button type="button" class="post-action" data-print-post>
              {{Icon.toHtml .printer}}<span>"Print this"</span>
            </button>
            <span class="post-action-feedback" data-post-action-feedback aria-live="polite"></span>
          </div>
          <div id="leanblog-related-posts"></div>
        </div>
        <aside class="post-toc" data-post-toc data-post-toc-depth="3" hidden>
          <p class="post-toc-title">"Sections"</p>
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
