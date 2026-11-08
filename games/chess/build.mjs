// Builds the game into dist/<BASE_PATH>/ and the tests into dist-test/.
// Stockfish (the lite, single-threaded WebAssembly build) and the two pixel fonts are copied from
// node_modules with their licences.
import { build, context } from "esbuild";
import { cpSync, mkdirSync, readdirSync, renameSync, rmSync } from "node:fs";

const BASE_PATH = process.env.BASE_PATH ?? "retro/chess";
const args = process.argv.slice(2);

if (args.includes("--test")) {
  rmSync("dist-test", { recursive: true, force: true });
  const tests = readdirSync("test").filter((f) => f.endsWith(".test.ts")).map((f) => `test/${f}`);
  await build({ entryPoints: tests, bundle: true, platform: "node", format: "esm", target: "node22", outdir: "dist-test", outExtension: { ".js": ".mjs" } });
} else {
  const site = BASE_PATH ? `dist/${BASE_PATH}` : "dist";
  rmSync("dist", { recursive: true, force: true });
  mkdirSync(`${site}/engine`, { recursive: true });
  mkdirSync(`${site}/fonts`, { recursive: true });
  cpSync("public", site, { recursive: true });
  if (BASE_PATH) renameSync(`${site}/_headers`, "dist/_headers"); // _headers must sit at the assets root
  const sf = "node_modules/stockfish";
  cpSync(`${sf}/bin/stockfish-19-lite-single.js`, `${site}/engine/stockfish.js`);
  cpSync(`${sf}/bin/stockfish-19-lite-single.wasm`, `${site}/engine/stockfish.wasm`);
  cpSync(`${sf}/Copying.txt`, `${site}/engine/COPYING.txt`);
  for (const [pkg, file, out] of [
    ["press-start-2p", "press-start-2p-latin-400-normal.woff2", "press-start-2p.woff2"],
    ["vt323", "vt323-latin-400-normal.woff2", "vt323.woff2"],
  ]) {
    cpSync(`node_modules/@fontsource/${pkg}/files/${file}`, `${site}/fonts/${out}`);
    cpSync(`node_modules/@fontsource/${pkg}/LICENSE`, `${site}/fonts/${pkg}-OFL.txt`);
  }
  const opts = { entryPoints: { game: "src/main.ts" }, bundle: true, minify: true, sourcemap: true, target: "es2020", outdir: site };
  if (args.includes("--watch")) { const c = await context(opts); await c.watch(); console.log("watching…"); }
  else await build(opts);
}
