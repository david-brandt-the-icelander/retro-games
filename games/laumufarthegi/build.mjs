// Builds Laumufarþegi into dist/games/laumufarthegi/ and the tests into dist-test/.
//
//   node build.mjs           the page, its script and styles
//   node build.mjs --test    the TypeScript tests
import { build } from "esbuild";
import { cpSync, mkdirSync, readdirSync, rmSync } from "node:fs";

const SITE = "dist/games/laumufarthegi";

if (process.argv.includes("--test")) {
  rmSync("dist-test", { recursive: true, force: true });
  const tests = readdirSync("test").filter((f) => f.endsWith(".test.ts")).map((f) => `test/${f}`);
  await build({ entryPoints: tests, bundle: true, platform: "node", format: "esm", target: "node22", outdir: "dist-test", outExtension: { ".js": ".mjs" } });
} else {
  rmSync("dist", { recursive: true, force: true });
  mkdirSync(SITE, { recursive: true });
  for (const f of ["index.html", "style.css", "favicon.svg", "cover.svg"]) cpSync(`web/${f}`, `${SITE}/${f}`);
  cpSync("web/_headers", "dist/_headers");
  await build({ entryPoints: { app: "web/app.ts" }, bundle: true, minify: true, format: "esm", target: "es2020", outdir: SITE });
}
