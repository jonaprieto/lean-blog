#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import vm from "node:vm";

const output = process.argv[2] ?? ".lake/build/site";
const manifestPath = process.argv[3];
const searchDir = path.join(output, "-verso-search");
const searchPage = path.join(output, "search", "index.html");

const read = (file) => fs.readFileSync(path.join(searchDir, file), "utf8");
const manifest = manifestPath
  ? JSON.parse(fs.readFileSync(manifestPath, "utf8"))
  : { queries: [] };
const context = { console, window: null };
context.window = context;
vm.createContext(context);

for (const file of ["elasticlunr.min.js", "searchIndex.js"]) {
  vm.runInContext(read(file), context, { filename: file });
}

if (!context.searchIndex) throw new Error("search index did not initialize");

const checks = manifest.queries ?? [];
const refs = Object.keys(context.searchIndex.documentStore.docInfo ?? {});
if (refs.length === 0) throw new Error("search index has no documents");

for (const { query, expected } of checks) {
  const results = context.searchIndex.search(query, {
    expand: true,
    bool: "AND",
    fields: { header: { boost: 1.25 }, contents: { boost: 1 } },
  });
  if (!results.some(({ ref }) => ref === expected)) {
    throw new Error(`search query '${query}' missed ${expected}`);
  }
}

const lazyRef = manifest.lazyRef ?? checks[0]?.expected;
if (lazyRef) {
  const bucketNumber = [...Buffer.from(lazyRef)].reduce((sum, byte) => sum + byte, 0) % 256;
  const version = context.searchIndexVersion;
  const bucketName = `searchIndex_${bucketNumber}.${version}.js`;
  let resolved = null;
  context.docContents[bucketNumber] = { resolve: (docs) => { resolved = docs; } };
  vm.runInContext(read(bucketName), context, { filename: bucketName });
  const doc = resolved?.[lazyRef];
  if (!doc) throw new Error(`lazy search bucket did not resolve ${lazyRef}`);
}

const page = fs.readFileSync(searchPage, "utf8");
for (const required of ["data-search-host", "search-page.js", '<base href=".././">']) {
  if (!page.includes(required)) throw new Error(`search page is missing ${required}`);
}

console.log(`search index OK (${checks.length} manifest queries, ${refs.length} documents)`);
