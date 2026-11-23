// Builds Dulmál into dist/games/dulmal/ and the tests into dist-test/.
//
//   node build.mjs           the page: public/ copied, src/client/main.ts bundled into app.js
//   node build.mjs --test    the TypeScript tests
//
// The Worker itself (worker/) is bundled by wrangler.
import { build } from "esbuild";
import { cpSync, mkdirSync, readdirSync, rmSync } from "node:fs";

const SITE = "dist/games/dulmal";

if (process.argv.includes("--test")) {
  rmSync("dist-test", { recursive: true, force: true });
  const tests = readdirSync("test").filter((f) => f.endsWith(".test.ts")).map((f) => `test/${f}`);
  await build({
    entryPoints: tests, bundle: true, platform: "node", format: "esm", target: "node22",
    outdir: "dist-test", outExtension: { ".js": ".mjs" }, loader: { ".txt": "text" },
  });
} else {
  rmSync("dist", { recursive: true, force: true });
  mkdirSync(SITE, { recursive: true });
  cpSync("public", SITE, { recursive: true });
  cpSync("web/_headers", "dist/_headers");
  await build({
    entryPoints: ["src/client/main.ts"], bundle: true, format: "iife", target: ["es2020", "safari14"],
    minify: true, sourcemap: false, outfile: `${SITE}/app.js`, legalComments: "eof",
  });
}
