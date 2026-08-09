#!/usr/bin/env node

import { spawnSync } from "node:child_process";

const options = {
  source: "examples/posts",
  output: ".lake/build/site",
  config: null,
  docsRoot: null,
  docsDirectory: null,
  css: null,
  skipDocs: false,
  skipCss: false,
};

const usage = () => `Usage: node tools/build-site.mjs [SOURCE] [options]

Options:
  --output PATH          Generated site directory
  --config PATH          Site configuration JSON file
  --docs-root URL        Declaration documentation URL prefix
  --docs-directory PATH Copied API documentation directory
  --css PATH             Compiled stylesheet path
  --skip-docs            Do not regenerate Verso API documentation
  --skip-css             Do not rebuild the Tailwind/daisyUI stylesheet
  --help                 Show this help
`;

const args = process.argv.slice(2);
for (let index = 0; index < args.length; index += 1) {
  const arg = args[index];
  const value = () => {
    if (index + 1 >= args.length) throw new Error(`${arg} needs a value`);
    index += 1;
    return args[index];
  };
  if (arg === "--help") {
    console.log(usage());
    process.exit(0);
  } else if (arg === "--output") options.output = value();
  else if (arg === "--config") options.config = value();
  else if (arg === "--docs-root") options.docsRoot = value();
  else if (arg === "--docs-directory") options.docsDirectory = value();
  else if (arg === "--css") options.css = value();
  else if (arg === "--skip-docs") options.skipDocs = true;
  else if (arg === "--skip-css") options.skipCss = true;
  else if (arg.startsWith("-")) throw new Error(`unknown option: ${arg}`);
  else if (options.source === "examples/posts") options.source = arg;
  else throw new Error(`unexpected argument: ${arg}`);
}

const run = (stage, command, commandArgs) => {
  console.log(`\n==> ${stage}`);
  const result = spawnSync(command, commandArgs, { stdio: "inherit" });
  if (result.error) throw new Error(`${stage} could not start: ${result.error.message}`);
  if (result.status !== 0) throw new Error(`${stage} failed with exit code ${result.status}`);
};

try {
  if (!options.skipDocs) run("Generate Verso documentation", "lake", ["build", ":literateHtml"]);
  if (!options.skipCss) run("Build Tailwind and daisyUI CSS", "npm", [
    "run", "build:css", "--prefix", "theme",
  ]);

  const checkArgs = ["exe", "leanblog", "check", options.source];
  if (options.config) checkArgs.push("--config", options.config);
  if (options.docsRoot) checkArgs.push("--docs-root", options.docsRoot);
  run("Validate posts and declaration links", "lake", checkArgs);

  const buildArgs = ["exe", "leanblog", "build", options.source, "--output", options.output];
  if (options.config) buildArgs.push("--config", options.config);
  if (options.docsRoot) buildArgs.push("--docs-root", options.docsRoot);
  if (options.docsDirectory) buildArgs.push("--docs-directory", options.docsDirectory);
  if (options.css) buildArgs.push("--css", options.css);
  run("Render site", "lake", buildArgs);
  console.log(`\nBuilt ${options.output}`);
} catch (error) {
  console.error(`\nBuild failed: ${error.message}`);
  process.exitCode = 1;
}
