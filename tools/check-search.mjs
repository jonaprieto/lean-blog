#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import vm from "node:vm";

const output = process.argv[2] ?? ".lake/build/site";
const searchDir = path.join(output, "-verso-search");
const searchPage = path.join(output, "search", "index.html");

const read = (file) => fs.readFileSync(path.join(searchDir, file), "utf8");
const context = { console, window: null };
context.window = context;
vm.createContext(context);

for (const file of ["elasticlunr.min.js", "searchIndex.js"]) {
  vm.runInContext(read(file), context, { filename: file });
}

if (!context.searchIndex) throw new Error("search index did not initialize");

const checks = [
  ["Declaration links", "2026-8-5-linking-across-leanblog-modules/"],
  ["flowchart", "2026-8-4-markdown-math-and-diagrams/"],
  ["PostSource", "2026-8-7-a-leanblog-post/"],
  ["mathematics", "2026-8-4-markdown-math-and-diagrams/"],
  ["greeting", "2026-8-7-a-leanblog-post/"],
];

for (const [query, expected] of checks) {
  const results = context.searchIndex.search(query, {
    expand: true,
    bool: "AND",
    fields: { header: { boost: 1.25 }, contents: { boost: 1 } },
  });
  if (!results.some(({ ref }) => ref === expected)) {
    throw new Error(`search query '${query}' missed ${expected}`);
  }
}

const bucketNumber = [...Buffer.from(checks[0][1])].reduce((sum, byte) => sum + byte, 0) % 256;
const version = context.searchIndexVersion;
const bucketName = `searchIndex_${bucketNumber}.${version}.js`;
let resolved = null;
context.docContents[bucketNumber] = { resolve: (docs) => { resolved = docs; } };
vm.runInContext(read(bucketName), context, { filename: bucketName });
const doc = resolved?.[checks[0][1]];
if (!doc || !doc.contents.includes("Declaration links")) {
  throw new Error(`lazy search bucket did not resolve ${checks[0][1]}`);
}

const page = fs.readFileSync(searchPage, "utf8");
for (const required of ["data-search-host", "search-page.js", '<base href=".././">']) {
  if (!page.includes(required)) throw new Error(`search page is missing ${required}`);
}

console.log(`search index OK (${checks.length} queries, ${bucketName})`);
