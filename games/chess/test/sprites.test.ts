import assert from "node:assert/strict";
import test from "node:test";
import { grid, pixels } from "../src/sprites";

test("every piece is 16×16 and leaves room for its outline at every edge", () => {
  for (const t of ["p", "n", "b", "r", "q", "k"] as const) {
    const g = grid(t);
    assert.equal(g.length, 16, t);
    for (const row of g) assert.equal(row.length, 16, `${t}: ${row}`);
    assert.ok(!/[^.]/.test(g[0] + g[15]), `${t}: top and bottom rows are empty`);
    for (const row of g) assert.ok(row[0] === "." && row[15] === ".", `${t}: left and right columns are empty`);
    assert.ok(pixels(t, "w").length > 40);
  }
});
