#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";

const output = process.argv[2] ?? ".lake/build/site";
const files = [];

const walk = (directory) => {
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    const file = path.join(directory, entry.name);
    if (entry.isDirectory()) walk(file);
    else files.push(file);
  }
};

const read = (file) => fs.readFileSync(path.join(output, file), "utf8");
const requireFile = (file) => {
  const full = path.join(output, file);
  if (!fs.statSync(full).isFile()) throw new Error(`missing generated file: ${file}`);
  return fs.readFileSync(full, "utf8");
};
const requireText = (text, required, context) => {
  for (const value of required) {
    if (!text.includes(value)) throw new Error(`${context} is missing ${value}`);
  }
};

if (!fs.statSync(output).isDirectory()) throw new Error(`missing output directory: ${output}`);
walk(output);

const relativeHtml = files
  .filter((file) => file.endsWith(".html"))
  .map((file) => path.relative(output, file));
const postPages = relativeHtml.filter((file) => {
  const html = fs.readFileSync(path.join(output, file), "utf8");
  return html.includes('class="post-page"');
});
if (postPages.length === 0) throw new Error("generated site has no post pages");

const archive = requireFile("index.html");
const search = requireFile("search/index.html");
const searchAssets = requireFile("-verso-search/searchIndex.js");
requireText(archive, [
  'class="site-header"',
  'class="post-list"',
  'class="post-entry-row"',
  'href="-verso-data/leanblog.css?v=',
], "archive");
requireText(search, [
  "data-search-host",
  "search-page.js",
  '<base href=".././">',
], "search page");
requireText(searchAssets, ["window.searchIndex", "window.searchIndexVersion"], "search index");

let tocPages = 0;
let codePages = 0;
for (const relativePost of postPages) {
  const post = read(relativePost);
  const postDirectory = path.dirname(relativePost);
  const postSlug = path.basename(postDirectory);
  const rawRelative = path.join(postDirectory, "raw/index.html");
  const raw = requireFile(rawRelative);
  requireText(post, [
    'class="post-title"',
    'class="post-actions post-actions-bottom"',
    'data-share-post',
    'data-print-post',
    `href="${postSlug}/raw/"`,
  ], `post ${relativePost}`);
  requireText(raw, ['class="raw-source-code"'], `raw page ${rawRelative}`);
  if (post.includes("data-post-toc")) {
    tocPages += 1;
    requireText(post, ["data-post-toc-depth=\"3\"", "data-toc-target", "buildTableOfContents"],
      `TOC post ${relativePost}`);
  }
  if (post.includes('class="leanblog-code')) {
    codePages += 1;
    requireText(post, ["data-code-copy", "addLineNumbers"], `code post ${relativePost}`);
  }
}
if (tocPages === 0) throw new Error("no generated post contains a table of contents");
if (codePages === 0) throw new Error("no generated post contains a code block");

console.log(`generated site OK (${postPages.length} posts, ${tocPages} TOCs, ${codePages} code pages)`);
