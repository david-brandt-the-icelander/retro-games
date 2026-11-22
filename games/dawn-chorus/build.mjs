// Builds the Dawn Chorus into dist/games/retro/dawn-chorus/ and the tests into dist-test/.
//
//   node build.mjs           the page, photos/ and audio/
//   node build.mjs --test    the TypeScript tests
//
import { build } from "esbuild";
import { cpSync, mkdirSync, readdirSync, rmSync, statSync } from "node:fs";

const SITE = "dist/games/retro/dawn-chorus";

if (process.argv.includes("--test")) {
  rmSync("dist-test", { recursive: true, force: true });
  const tests = readdirSync("test").filter((f) => f.endsWith(".test.ts")).map((f) => `test/${f}`);
  await build({ entryPoints: tests, bundle: true, platform: "node", format: "esm", target: "node22", outdir: "dist-test", outExtension: { ".js": ".mjs" } });
} else {
  rmSync("dist", { recursive: true, force: true });
  mkdirSync(SITE, { recursive: true });
  cpSync("index.html", `${SITE}/index.html`);
  for (const d of ["photos", "audio"]) cpSync(d, `${SITE}/${d}`, { recursive: true });
  cpSync("web/_headers", "dist/_headers");

  const walk = (dir) => readdirSync(dir, { withFileTypes: true }).flatMap((e) => (e.isDirectory() ? walk(`${dir}/${e.name}`) : [`${dir}/${e.name}`]));
  for (const f of walk("dist")) if (statSync(f).size > 25 * 1024 * 1024) throw new Error(`${f} is over 25 MiB`);
}
