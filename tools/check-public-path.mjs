#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";

const files = [
  "lakefile.lean",
  "lake-manifest.json",
  ".pre-commit-config.yaml",
  "CONTRIBUTING.md",
  ".github/workflows/ci.yml",
  ".github/workflows/docs.yml",
];
const forbidden = /lean-argus|precommit-lean|ECOSYSTEM_READ_TOKEN|PRIVATE_DEPS_READ_TOKEN/;
const failures = files.flatMap((file) => {
  const contents = fs.readFileSync(path.resolve(file), "utf8");
  return forbidden.test(contents) ? [`${file}: contains a private template dependency`] : [];
});

if (failures.length > 0) {
  console.error(failures.join("\n"));
  process.exitCode = 1;
} else {
  console.log("public template path OK");
}
