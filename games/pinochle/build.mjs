// Builds Pinochle into dist/games/pinochle/ and the tests into dist-test/.
//
//   node build.mjs           the page, its scripts and the PWA files from public/
//   node build.mjs --test    the TypeScript tests
//
// server/ (the Node WebSocket server for online rooms) is not part of the site.
import { build } from "esbuild";
import { cpSync, mkdirSync, readdirSync, rmSync } from "node:fs";

const SITE = "dist/games/pinochle";

if (process.argv.includes("--test")) {
  rmSync("dist-test", { recursive: true, force: true });
  const tests = readdirSync("test").filter((f) => f.endsWith(".test.ts")).map((f) => `test/${f}`);
  await build({ entryPoints: tests, bundle: true, platform: "node", format: "esm", target: "node22", outdir: "dist-test", outExtension: { ".js": ".mjs" } });
} else {
  rmSync("dist", { recursive: true, force: true });
  mkdirSync(SITE, { recursive: true });
  cpSync("public", SITE, { recursive: true });
  cpSync("web/_headers", "dist/_headers");
}
