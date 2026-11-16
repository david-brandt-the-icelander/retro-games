// The page (public/): it must work under its Content-Security-Policy (public/_headers), which allows
// scripts and styles from this origin and Google Fonts only: no inline script, no inline style.
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const read = (f: string) => readFileSync(new URL(`../../public/${f}`, import.meta.url), "utf8");
const html = read("index.html"), js = read("meg.js"), css = read("meg.css"), headers = read("_headers");

test("page: the script and stylesheet are files, not inline", () => {
  assert.match(html, /<script src="meg\.js"><\/script>/);
  assert.match(html, /<link rel="stylesheet" href="meg\.css">/);
  assert.equal(html.match(/<script(?![^>]*\ssrc=)[^>]*>/g), null, "an inline <script> would be blocked");
  assert.equal(html.match(/<style\b/g), null, "an inline <style> would be blocked");
  assert.equal(/\sstyle="/.test(html + js), false, "a style attribute would be blocked");
  assert.equal(/\son[a-z]+="/.test(html + js), false, "an inline event handler would be blocked");
});

test("page: the policy lets in exactly what the page loads from outside", () => {
  const outside = [...html.matchAll(/(?:href|src)="(https:\/\/[^/"]+)/g)].map((m) => m[1]);
  assert.deepEqual(outside, ["https://fonts.googleapis.com"]);
  assert.match(headers, /style-src 'self' https:\/\/fonts\.googleapis\.com/);
  assert.match(headers, /font-src https:\/\/fonts\.gstatic\.com/);
  assert.doesNotMatch(headers, /unsafe-inline|unsafe-eval/);
});

test("page: the game script parses, and names the elements the page has", () => {
  assert.doesNotThrow(() => new Function(js));
  for (const id of [...js.matchAll(/\$\('([A-Za-z]+)'\)/g)].map((m) => m[1])) assert.match(html + js, new RegExp(`id="${id}"`), id);
  assert.ok(css.length > 1000);
});
