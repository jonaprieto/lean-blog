#!/usr/bin/env node

import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";

const DEFAULT_POST_COUNT = 100;
const root = process.cwd();
const postCountIndex = process.argv.indexOf("--posts");
const postCount = postCountIndex >= 0
  ? Number.parseInt(process.argv[postCountIndex + 1], 10)
  : DEFAULT_POST_COUNT;
if (!Number.isInteger(postCount) || postCount < 1) {
  throw new Error("--posts must be a positive integer");
}

const tempRoot = fs.mkdtempSync(path.join(os.tmpdir(), "leanblog-benchmark-"));
const postsRoot = path.join(tempRoot, "posts");
const outputRoot = path.join(tempRoot, "site");
fs.mkdirSync(postsRoot, { recursive: true });

const run = (label, command, args) => {
  const started = process.hrtime.bigint();
  const result = spawnSync(command, args, { cwd: root, stdio: "ignore" });
  const elapsedMs = Number(process.hrtime.bigint() - started) / 1_000_000;
  if (result.status !== 0) throw new Error(`${label} failed with status ${result.status}`);
  return elapsedMs;
};

const postBody = (index) => {
  const number = String(index + 1).padStart(3, "0");
  const month = (index % 12) + 1;
  const day = (Math.floor(index / 12) % 28) + 1;
  return `---
title: Benchmark post ${number}
date: 2024-${String(month).padStart(2, "0")}-${String(day).padStart(2, "0")}
authors: Benchmark Author
tags: benchmark, lean
---

# Benchmark post ${number}

This generated post exercises the renderer with searchable prose, a unique benchmark value, and
links that remain ordinary Markdown.

## Searchable section ${number}

The benchmark includes a deliberately unique phrase benchmark-search-${number}.

### Details

The post also contains inline mathematics $a^2 + b^2 = c^2$.

\`\`\`lean title="Benchmark${number}.lean"
def benchmarkValue${number} : Nat := ${index + 1}

#eval benchmarkValue${number}
\`\`\`
`;
};

for (let index = 0; index < postCount; index += 1) {
  const group = path.join(postsRoot, `group-${String(index % 10).padStart(2, "0")}`);
  fs.mkdirSync(group, { recursive: true });
  fs.writeFileSync(
    path.join(group, `post-${String(index + 1).padStart(3, "0")}.lean.md`),
    postBody(index),
  );
}
fs.writeFileSync(path.join(tempRoot, "xref.json"), "{}\n");

const leanblog = process.env.LEANBLOG_BIN ?? path.join(root, ".lake", "build", "bin", "leanblog");
const timingsMs = {
  check: run("check", leanblog, ["check", postsRoot]),
  css: run("css", "npm", ["run", "build:css", "--prefix", "theme"]),
  docs: run("docs", "lake", ["build", ":literateHtml"]),
};
timingsMs.render = run("render", leanblog, [
  "build", postsRoot, "--output", outputRoot, "--xref", path.join(tempRoot, "xref.json"),
]);

const fileSize = (directory) => {
  let total = 0;
  const visit = (current) => {
    for (const entry of fs.readdirSync(current, { withFileTypes: true })) {
      const file = path.join(current, entry.name);
      if (entry.isDirectory()) visit(file);
      else total += fs.statSync(file).size;
    }
  };
  visit(directory);
  return total;
};

const keepBenchmark = Boolean(process.env.KEEP_BENCHMARK);
const report = {
  posts: postCount,
  timingsMs,
  totalMs: Object.values(timingsMs).reduce((total, elapsed) => total + elapsed, 0),
  outputBytes: fileSize(outputRoot),
};
if (keepBenchmark) report.outputDirectory = outputRoot;
console.log(JSON.stringify(report, null, 2));

if (!keepBenchmark) fs.rmSync(tempRoot, { recursive: true, force: true });
