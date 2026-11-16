// Builds Iron Haze into dist/games/fresh/iron-haze/ and the tests into dist-test/.
//
//   node build.mjs           the whole site: landing page, the Godot web export (play/), the desktop builds (download/)
//   node build.mjs --web     the landing page and the web export only (quicker, for local work)
//   node build.mjs --test    the TypeScript tests
//
// The exports need Godot 4.7.2 with its export templates; set GODOT to its path if it isn't on the PATH as "godot".
// Cloudflare serves static files of at most 25 MiB, so the engine and every download are stored in parts of
// 20 MiB (name.0, name.1, …) and the Worker joins them again (worker/index.ts).
import { build } from "esbuild";
import { execFileSync } from "node:child_process";
import { cpSync, existsSync, mkdirSync, readFileSync, readdirSync, rmSync, statSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";

const SITE = "dist/games/fresh/iron-haze";
const PART = 20 * 1024 * 1024;
const DOWNLOADS = [
  { file: "iron-haze-windows.zip", key: "windows" },
  { file: "iron-haze-macos.zip", key: "macos" },
  { file: "iron-haze-linux.zip", key: "linux" },
];
const args = process.argv.slice(2);

/** Writes data as parts of at most PART bytes: path.0, path.1, … */
function writeParts(path, data) {
  for (let i = 0; i * PART < data.length || i === 0; i++) writeFileSync(`${path}.${i}`, data.subarray(i * PART, (i + 1) * PART));
}

const megabytes = (n) => `${(n / (1024 * 1024)).toFixed(0)} MB`;

if (args.includes("--test")) {
  rmSync("dist-test", { recursive: true, force: true });
  const tests = readdirSync("test").filter((f) => f.endsWith(".test.ts")).map((f) => `test/${f}`);
  await build({ entryPoints: tests, bundle: true, platform: "node", format: "esm", target: "node22", outdir: "dist-test", outExtension: { ".js": ".mjs" } });
} else {
  const webOnly = args.includes("--web");
  rmSync("dist", { recursive: true, force: true });
  rmSync("build", { recursive: true, force: true });
  mkdirSync(`${SITE}/play`, { recursive: true });
  mkdirSync(`${SITE}/download`, { recursive: true });
  const godot = process.env.GODOT ?? "godot";
  const run = (...a) => execFileSync(godot, ["--headless", "--path", "godot", ...a], { stdio: "inherit" });
  run("--import");

  // The browser build (Compatibility renderer, WebGL 2).
  run("--export-release", "Web", resolve(`${SITE}/play/index.html`));
  const wasm = readFileSync(`${SITE}/play/index.wasm`);
  writeParts(`${SITE}/play/index.wasm`, wasm);
  rmSync(`${SITE}/play/index.wasm`);

  // The desktop builds (Forward+), zipped.
  const sizes = {};
  if (!webOnly) {
    for (const os of ["linux", "windows", "macos"]) mkdirSync(`build/${os}`, { recursive: true });
    run("--export-release", "Linux", resolve("build/linux/IronHaze.x86_64"));
    run("--export-release", "Windows", resolve("build/windows/IronHaze.exe"));
    run("--export-release", "macOS", resolve("build/macos/IronHaze.zip"));
    for (const f of ["README.txt"]) writeFileSync(`build/${f}`, readme());
    execFileSync("zip", ["-q", "-9", "-j", resolve("build/iron-haze-linux.zip"), "build/linux/IronHaze.x86_64", "build/README.txt"]);
    execFileSync("zip", ["-q", "-9", "-j", resolve("build/iron-haze-windows.zip"), "build/windows/IronHaze.exe", "build/README.txt"]);
    cpSync("build/macos/IronHaze.zip", "build/iron-haze-macos.zip");
    for (const d of DOWNLOADS) {
      const data = readFileSync(`build/${d.file}`);
      writeParts(`${SITE}/download/${d.file}`, data);
      sizes[d.key] = megabytes(data.length);
    }
  }

  // The landing page, with the downloads' sizes and the build's version.
  const version = new Date().toISOString().slice(0, 10) + (process.env.GITHUB_SHA ? ` (${process.env.GITHUB_SHA.slice(0, 7)})` : "");
  let page = readFileSync("web/index.html", "utf8");
  for (const d of DOWNLOADS) page = page.replaceAll(`{{${d.key}}}`, sizes[d.key] ?? "not built");
  page = page.replaceAll("{{version}}", version);
  writeFileSync(`${SITE}/index.html`, page);
  for (const f of ["shell.css", "boot.js", "favicon.svg"]) cpSync(`web/${f}`, `${SITE}/${f}`);
  for (const f of ["battle.png", "base.png", "hud.png"]) cpSync(`docs/${f}`, `${SITE}/${f}`);
  cpSync("web/_headers", "dist/_headers");

  // Nothing over Cloudflare's per-file limit.
  const walk = (dir) => readdirSync(dir, { withFileTypes: true }).flatMap((e) => (e.isDirectory() ? walk(`${dir}/${e.name}`) : [`${dir}/${e.name}`]));
  for (const f of walk("dist")) if (statSync(f).size > 25 * 1024 * 1024) throw new Error(`${f} is over 25 MiB`);
  if (!existsSync(`${SITE}/play/index.pck`)) throw new Error("the web export wrote no index.pck");
}

function readme() {
  return `Iron Haze, a dieselpunk real-time strategy game, from https://icelander.net/games/fresh/iron-haze/

Run IronHaze.exe (Windows) or IronHaze.x86_64 (Linux; chmod +x it first). The builds aren't code-signed:
on Windows choose "More info", then "Run anyway".

Press F1 in the game for the controls. F2 switches between the full graphics and a quicker mode.
Destroy every structure of the Iron Dominion to win.
`;
}
