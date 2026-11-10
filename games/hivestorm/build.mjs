// Builds the game into dist/<BASE_PATH>/ (or dist/ with BASE_PATH=""), and the tests into dist-test/.
import { build, context } from "esbuild";
import { cpSync, mkdirSync, readdirSync, renameSync, rmSync } from "node:fs";
import { basename } from "node:path";

/** The game is served at https://icelander.net/games/retro/hivestorm/ (set BASE_PATH="" to build at the root). */
const BASE_PATH = process.env.BASE_PATH ?? "games/retro/hivestorm";
const args = process.argv.slice(2);

if (args.includes("--test")) {
  rmSync("dist-test", { recursive: true, force: true });
  const tests = readdirSync("test").filter((f) => f.endsWith(".test.ts")).map((f) => `test/${f}`);
  await build({ entryPoints: tests, bundle: true, platform: "node", format: "esm", target: "node20", outdir: "dist-test", outExtension: { ".js": ".mjs" } });
} else {
  const site = BASE_PATH ? `dist/${BASE_PATH}` : "dist";
  rmSync("dist", { recursive: true, force: true });
  mkdirSync(site, { recursive: true });
  cpSync("public", site, { recursive: true, filter: (src) => basename(src) !== ".dev" }); // .dev/ documents the folder; it is not served
  if (BASE_PATH) renameSync(`${site}/_headers`, "dist/_headers"); // _headers must sit at the assets root
  const opts = { entryPoints: { game: "src/main.ts" }, bundle: true, minify: true, target: "es2020", outdir: site };
  if (args.includes("--watch")) { const c = await context(opts); await c.watch(); console.log("watching…"); }
  else await build(opts);
}
