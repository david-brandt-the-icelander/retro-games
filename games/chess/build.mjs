// Builds the game into dist/games/retro/chess/ and the tests into dist-test/.
//
//   node build.mjs          the whole site: the Godot web export, the page bridge, Stockfish, headers
//   node build.mjs --test   the TypeScript tests
//
// The Godot export needs Godot 4.7.2 with its web export templates; set GODOT to its path if it
// isn't on the PATH as "godot".
import { build } from "esbuild";
import { execFileSync } from "node:child_process";
import { cpSync, mkdirSync, readFileSync, readdirSync, rmSync, writeFileSync } from "node:fs";

const SITE = "dist/games/retro/chess";
const args = process.argv.slice(2);

if (args.includes("--test")) {
  rmSync("dist-test", { recursive: true, force: true });
  const tests = readdirSync("test").filter((f) => f.endsWith(".test.ts")).map((f) => `test/${f}`);
  await build({ entryPoints: tests, bundle: true, platform: "node", format: "esm", target: "node22", outdir: "dist-test", outExtension: { ".js": ".mjs" } });
} else {
  rmSync("dist", { recursive: true, force: true });
  mkdirSync(`${SITE}/engine`, { recursive: true });
  const godot = process.env.GODOT ?? "godot";
  execFileSync(godot, ["--headless", "--path", "godot", "--import"], { stdio: "inherit" });
  execFileSync(godot, ["--headless", "--path", "godot", "--export-release", "Web", `../${SITE}/index.html`], { stdio: "inherit" });
  // Cloudflare serves static files of at most 25 MiB; the engine is bigger, so it goes up in parts
  // and the Worker joins them again (worker/index.ts).
  const wasm = readFileSync(`${SITE}/index.wasm`);
  const PART = 20 * 1024 * 1024;
  for (let i = 0; i * PART < wasm.length; i++) writeFileSync(`${SITE}/index.wasm.${i}`, wasm.subarray(i * PART, (i + 1) * PART));
  rmSync(`${SITE}/index.wasm`);
  cpSync("web/_headers", "dist/_headers");
  cpSync("web/shell.css", `${SITE}/shell.css`);
  cpSync("web/favicon.svg", `${SITE}/favicon.svg`);
  const sf = "node_modules/stockfish";
  cpSync(`${sf}/bin/stockfish-19-lite-single.js`, `${SITE}/engine/stockfish.js`);
  cpSync(`${sf}/bin/stockfish-19-lite-single.wasm`, `${SITE}/engine/stockfish.wasm`);
  cpSync(`${sf}/Copying.txt`, `${SITE}/engine/COPYING.txt`);
  await build({ entryPoints: { bridge: "bridge/main.ts" }, bundle: true, minify: true, target: "es2020", outdir: SITE });
}
