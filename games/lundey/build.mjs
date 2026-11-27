// Builds Lundey into dist/games/lundey/ and the tests into dist-test/.
//
//   node build.mjs           the page from public/ and the game bundled from src/main.ts
//   node build.mjs --watch   the same, rebuilding the bundle as the source changes
//   node build.mjs --test    the TypeScript tests
import { build, context } from "esbuild";
import { cpSync, mkdirSync, readdirSync, renameSync, rmSync } from "node:fs";
import { basename } from "node:path";

const SITE = "dist/games/lundey";
const args = process.argv.slice(2);

if (args.includes("--test")) {
  rmSync("dist-test", { recursive: true, force: true });
  const tests = readdirSync("test").filter((f) => f.endsWith(".test.ts")).map((f) => `test/${f}`);
  await build({ entryPoints: tests, bundle: true, platform: "node", format: "esm", target: "node22", outdir: "dist-test", outExtension: { ".js": ".mjs" } });
} else {
  rmSync("dist", { recursive: true, force: true });
  mkdirSync(SITE, { recursive: true });
  cpSync("public", SITE, { recursive: true, filter: (src) => basename(src) !== ".dev" }); // .dev/ documents the folder; it is not served
  renameSync(`${SITE}/_headers`, "dist/_headers"); // _headers must sit at the assets root
  const opts = { entryPoints: { game: "src/main.ts" }, bundle: true, minify: true, target: "es2020", outdir: SITE };
  if (args.includes("--watch")) { const c = await context(opts); await c.watch(); console.log("watching…"); }
  else await build(opts);
}
