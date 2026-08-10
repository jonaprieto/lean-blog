#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";

const roots = ["src", "cli", "test", "examples"];
const files = [];

const walk = (directory) => {
  if (!fs.existsSync(directory)) return;
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    const file = path.join(directory, entry.name);
    if (entry.isDirectory()) walk(file);
    else if (entry.isFile() && file.endsWith(".lean")) files.push(file);
  }
};

roots.forEach(walk);
const failures = [];
for (const file of files.sort()) {
  const lines = fs.readFileSync(file, "utf8").split("\n");
  lines.forEach((line, index) => {
    const location = `${file}:${index + 1}`;
    if (/[ \t]+$/.test(line)) failures.push(`${location}: trailing whitespace`);
    if (line.includes("\t")) failures.push(`${location}: tab character`);
    if ([...line].length > 100) failures.push(`${location}: exceeds 100 Unicode columns`);
  });
  const source = lines.join("\n");
  if (/\bsorry\b/.test(source)) failures.push(`${file}: contains sorry`);
}

if (failures.length > 0) {
  console.error(failures.join("\n"));
  process.exitCode = 1;
} else {
  console.log(`checked ${files.length} Lean source file(s)`);
}
