#!/usr/bin/env node

import fs from "node:fs";
import http from "node:http";
import { createRequire } from "node:module";
import path from "node:path";

const require = createRequire(path.resolve("theme/package.json"));
const { chromium } = require("playwright");

const output = path.resolve(process.argv[2] ?? ".lake/build/site");
const postPath = process.argv[3] ?? "2025-1-2-fixture-guide/";
const referencePath = process.argv[4] ?? "2025-1-3-fixture-reference/";
const query = process.argv[5] ?? "searchable phrase";

if (!fs.statSync(output).isDirectory()) throw new Error(`missing output directory: ${output}`);

const server = http.createServer((request, response) => {
  try {
    const requestUrl = new URL(request.url ?? "/", "http://127.0.0.1");
    let relative = decodeURIComponent(requestUrl.pathname).replace(/^\/+/, "");
    if (relative === "" || !path.extname(relative)) relative = path.join(relative, "index.html");
    const file = path.resolve(output, relative);
    if (file !== output && !file.startsWith(`${output}${path.sep}`)) {
      response.writeHead(403);
      response.end("forbidden");
      return;
    }
    if (!fs.statSync(file).isFile()) throw new Error("not found");
    const contentTypes = {
      ".css": "text/css",
      ".html": "text/html",
      ".js": "text/javascript",
      ".json": "application/json",
      ".svg": "image/svg+xml",
    };
    response.writeHead(200, { "Content-Type": contentTypes[path.extname(file)] ?? "application/octet-stream" });
    fs.createReadStream(file).pipe(response);
  } catch (_) {
    response.writeHead(404);
    response.end("not found");
  }
});

const listen = () => new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
const close = () => new Promise((resolve, reject) => server.close((error) => error ? reject(error) : resolve()));

await listen();
const address = server.address();
const origin = `http://127.0.0.1:${address.port}`;
let browser;
try {
  const browserOptions = { headless: true };
  if (process.env.LEANBLOG_CHROMIUM_PATH) {
    browserOptions.executablePath = process.env.LEANBLOG_CHROMIUM_PATH;
  }
  browser = await chromium.launch(browserOptions);
  const context = await browser.newContext({ permissions: ["clipboard-read", "clipboard-write"] });
  await context.addInitScript(() => {
    Object.defineProperty(navigator, "share", { configurable: true, value: undefined });
  });
  const archive = await context.newPage();

  await archive.goto(`${origin}/`, { waitUntil: "networkidle" });
  const search = archive.locator("#search-wrapper .cb_edit");
  await search.waitFor();
  await search.click();
  await search.pressSequentially(query);
  const result = archive.locator("#search-wrapper [role=listbox] li").first();
  await result.waitFor();
  if (!(await result.textContent() ?? "").toLowerCase().includes("fixture guide")) {
    throw new Error("header search returned the wrong result");
  }
  const resultLink = result.locator("a").first();
  const resultHref = await resultLink.getAttribute("href");
  if (!resultHref) throw new Error("header search result has no link");
  await resultLink.click();
  await archive.waitForLoadState("domcontentloaded");
  if (!archive.url().includes(postPath)) throw new Error(`header search navigated to ${archive.url()}`);

  const toc = archive.locator("[data-post-toc]");
  await toc.waitFor();
  const tocLink = toc.locator("a", { hasText: "Fixture details" });
  await tocLink.click();
  if (!archive.url().includes("#fixture-details")) throw new Error("TOC navigation did not update the hash");
  if ((await tocLink.getAttribute("aria-current")) !== "location") {
    throw new Error("TOC navigation did not update the active section");
  }

  const rawLink = archive.locator("a", { hasText: "See raw" });
  await rawLink.click();
  await archive.locator(".raw-source-code").waitFor();
  await archive.goto(`${origin}/${postPath}`, { waitUntil: "networkidle" });

  let printed = false;
  await archive.evaluate(() => { window.print = () => { window.__leanBlogPrinted = true; }; });
  await archive.locator("[data-print-post]").click();
  printed = await archive.evaluate(() => window.__leanBlogPrinted === true);
  if (!printed) throw new Error("print action did not invoke window.print");

  const themeBefore = await archive.evaluate(() => document.documentElement.dataset.theme);
  await archive.locator("[data-theme-toggle]").click();
  const themeAfter = await archive.evaluate(() => document.documentElement.dataset.theme);
  if (themeBefore === themeAfter) throw new Error("theme toggle did not change the theme");

  const reference = await context.newPage();
  await reference.goto(`${origin}/${referencePath}`, { waitUntil: "networkidle" });
  const code = reference.locator(".leanblog-code").first();
  await code.locator("[data-code-copy]").click();
  const copiedCode = await reference.evaluate(() => navigator.clipboard.readText());
  if (!copiedCode.includes("fixtureSearchValue")) throw new Error("code copy returned the wrong source");
  const share = reference.locator("[data-share-post]");
  await share.click();
  const feedback = reference.locator("[data-post-action-feedback]");
  await reference.waitForFunction(() =>
    document.querySelector('[data-post-action-feedback]')?.textContent?.includes('Link copied'));
  if (!(await feedback.textContent()).includes("Link copied")) {
    throw new Error("share fallback did not copy the post URL");
  }

  console.log("browser smoke OK (search, TOC, raw, print, theme, copy, share)");
} finally {
  if (browser) await browser.close();
  await close();
}
