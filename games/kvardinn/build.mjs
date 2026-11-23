// Builds Kvarðinn into dist/ (served by the Worker under its BASE) and the tests into dist-test/.
//
//   node build.mjs           the page: public/ copied, src/client/main.ts bundled to app.js
//   node build.mjs --test    the TypeScript tests in test/, with data/*.txt bundled as text
import { build } from "esbuild";
import { cpSync, mkdirSync, readdirSync, rmSync } from "node:fs";

if (process.argv.includes("--test")) {
  rmSync("dist-test", { recursive: true, force: true });
  const tests = readdirSync("test").filter((f) => f.endsWith(".test.ts")).map((f) => `test/${f}`);
  await build({ entryPoints: tests, bundle: true, platform: "node", format: "esm", target: "node22", outdir: "dist-test", outExtension: { ".js": ".mjs" }, loader: { ".txt": "text" } });
} else {
  rmSync("dist", { recursive: true, force: true });
  mkdirSync("dist", { recursive: true });
  cpSync("public", "dist", { recursive: true });
  await build({ entryPoints: ["src/client/main.ts"], bundle: true, format: "esm", target: "es2020", minify: true, sourcemap: false, outfile: "dist/app.js", legalComments: "none" });
}
