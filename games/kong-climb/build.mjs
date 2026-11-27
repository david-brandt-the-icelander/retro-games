// Builds the game into dist/<BASE_PATH>/ as it is served, and the tests into dist-test/.
// The page and its stylesheet are copied from public/; the game's script is bundled from src/client/main.ts.
import { build } from "esbuild";
import { cpSync, mkdirSync, readdirSync, rmSync } from "node:fs";
import { basename } from "node:path";

/** The game is served at https://icelander.net/games/recreations/arcade/kong-climb/ (set BASE_PATH="" to build at the root). */
const BASE_PATH = process.env.BASE_PATH ?? "games/recreations/arcade/kong-climb";

if (process.argv.includes("--test")) {
  rmSync("dist-test", { recursive: true, force: true });
  const tests = readdirSync("test").filter((f) => f.endsWith(".test.ts")).map((f) => `test/${f}`);
  await build({ entryPoints: tests, bundle: true, platform: "node", format: "esm", target: "node20", outbase: ".", outdir: "dist-test", outExtension: { ".js": ".mjs" } });
} else {
  const site = BASE_PATH ? `dist/${BASE_PATH}` : "dist";
  rmSync("dist", { recursive: true, force: true });
  mkdirSync(site, { recursive: true });
  cpSync("public", site, { recursive: true, filter: (src) => basename(src) !== ".dev" }); // .dev/ documents the folder; it is not served
  await build({ entryPoints: ["src/client/main.ts"], bundle: true, minify: true, format: "iife", target: "es2020", outfile: `${site}/kong.js` });
}
