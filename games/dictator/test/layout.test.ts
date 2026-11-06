import assert from "node:assert/strict";
import { test } from "node:test";
import { playGame } from "../src/engine/flow";
import { newGame } from "../src/engine/state";
import { ZXScreen } from "../src/zx/screen";
import { SAMPLES, SCREENS } from "./samples";

test("no screen runs off the edge, under the footer, or into art", () => {
  const z = new ZXScreen();
  for (const s of SAMPLES) {
    s.draw(z);
    assert.equal(z.clipped, 0, `${s.name}: ${JSON.stringify(z.textRows())}`);
  }
});

test("every screen kind the game can show has a sample", async () => {
  const seen = new Set<string>();
  for (let seed = 1; seed <= 200; seed++) {
    await playGame({ show: async (s) => { seen.add(s.kind); return seed % 2 ? "y" : "n"; } }, newGame(seed));
  }
  const sampled = new Set(SCREENS.map((s) => s.kind));
  for (const k of seen) assert.ok(sampled.has(k as never), `no sample for ${k}`);
});
