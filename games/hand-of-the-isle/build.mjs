// Builds Hand of the Isle into dist/games/fresh/hand-of-the-isle/ and the tests into dist-test/.
//
//   node build.mjs           the landing page and the Godot web export (play/)
//   node build.mjs --test    the TypeScript tests
//
// The export needs Godot 4.7.2 with its export templates; set GODOT to its path if it isn't on the PATH as "godot".
// Cloudflare serves static files of at most 25 MiB, so the engine is stored in parts of 20 MiB
// (index.wasm.0, index.wasm.1, …) and the Worker joins them again (worker/index.ts).
import { build } from "esbuild";
import { execFileSync } from "node:child_process";
import { cpSync, existsSync, mkdirSync, readFileSync, readdirSync, rmSync, statSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";

const SITE = "dist/games/fresh/hand-of-the-isle";
const PART = 20 * 1024 * 1024;
const args = process.argv.slice(2);

/** Writes data as parts of at most PART bytes: path.0, path.1, … */
function writeParts(path, data) {
  for (let i = 0; i * PART < data.length || i === 0; i++) writeFileSync(`${path}.${i}`, data.subarray(i * PART, (i + 1) * PART));
}

if (args.includes("--test")) {
  rmSync("dist-test", { recursive: true, force: true });
  const tests = readdirSync("test").filter((f) => f.endsWith(".test.ts")).map((f) => `test/${f}`);
  await build({ entryPoints: tests, bundle: true, platform: "node", format: "esm", target: "node22", outdir: "dist-test", outExtension: { ".js": ".mjs" } });
} else {
  rmSync("dist", { recursive: true, force: true });
  mkdirSync(`${SITE}/play`, { recursive: true });
  const godot = process.env.GODOT ?? "godot";
  const run = (...a) => execFileSync(godot, ["--headless", "--path", "godot", ...a], { stdio: "inherit" });
  run("--import");

  // The browser build (Compatibility renderer, WebGL 2).
  run("--export-release", "Web", resolve(`${SITE}/play/index.html`));
  const wasm = readFileSync(`${SITE}/play/index.wasm`);
  writeParts(`${SITE}/play/index.wasm`, wasm);
  rmSync(`${SITE}/play/index.wasm`);

  // The landing page, with the build's version.
  const version = new Date().toISOString().slice(0, 10) + (process.env.GITHUB_SHA ? ` (${process.env.GITHUB_SHA.slice(0, 7)})` : "");
  writeFileSync(`${SITE}/index.html`, readFileSync("web/index.html", "utf8").replaceAll("{{version}}", version));
  for (const f of ["shell.css", "boot.js", "favicon.svg"]) cpSync(`web/${f}`, `${SITE}/${f}`);
  for (const f of ["island.png", "village.png"]) cpSync(`docs/${f}`, `${SITE}/${f}`);
  cpSync("web/_headers", "dist/_headers");

  // Nothing over Cloudflare's per-file limit.
  const walk = (dir) => readdirSync(dir, { withFileTypes: true }).flatMap((e) => (e.isDirectory() ? walk(`${dir}/${e.name}`) : [`${dir}/${e.name}`]));
  for (const f of walk("dist")) if (statSync(f).size > 25 * 1024 * 1024) throw new Error(`${f} is over 25 MiB`);
  if (!existsSync(`${SITE}/play/index.pck`)) throw new Error("the web export wrote no index.pck");
}
