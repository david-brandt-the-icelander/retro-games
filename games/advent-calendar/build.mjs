// Builds the Advent calendar into dist/games/fresh/advent-calendar/ and the tests into dist-test/.
//
//   node build.mjs           the page, its script and the art in assets/ (made by art/build.mjs, committed)
//   node build.mjs --test    the TypeScript tests
//
// The art sources and tools in art/ are not part of the site.
import { build } from "esbuild";
import { cpSync, mkdirSync, readdirSync, rmSync, statSync } from "node:fs";

const SITE = "dist/games/fresh/advent-calendar";

if (process.argv.includes("--test")) {
  rmSync("dist-test", { recursive: true, force: true });
  const tests = readdirSync("test").filter((f) => f.endsWith(".test.ts")).map((f) => `test/${f}`);
  await build({ entryPoints: tests, bundle: true, platform: "node", format: "esm", target: "node22", outdir: "dist-test", outExtension: { ".js": ".mjs" } });
} else {
  rmSync("dist", { recursive: true, force: true });
  mkdirSync(SITE, { recursive: true });
  for (const f of ["index.html", "calendar.js"]) cpSync(f, `${SITE}/${f}`);
  cpSync("assets", `${SITE}/assets`, { recursive: true });
  cpSync("web/_headers", "dist/_headers");

  const walk = (dir) => readdirSync(dir, { withFileTypes: true }).flatMap((e) => (e.isDirectory() ? walk(`${dir}/${e.name}`) : [`${dir}/${e.name}`]));
  for (const f of walk("dist")) if (statSync(f).size > 25 * 1024 * 1024) throw new Error(`${f} is over 25 MiB`);
}
