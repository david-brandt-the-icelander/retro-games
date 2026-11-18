// The list of everything build.mjs renders. Each entry makes one file in
// assets/: an 'image' (one picture) or an 'atlas' (trimmed sprites packed
// into one picture, with their rectangles and pivots in the manifest).
import { SP, speciesItems, earSpec, TAIL, face, HY } from './characters.mjs';

export const SHEETS = {};
for (const name of Object.keys(SP))
  SHEETS['sp-' + name] = () => {
    const S = SP[name];
    // the rig data the game needs to put the parts together
    const rig = { S, ear: earSpec(S), tail: S.tail ? TAIL[S.tail](S) : null, face: face(S), hy: HY(S) };
    return { kind: 'atlas', file: `sp-${name}.webp`, q: 0.86, items: speciesItems(name), meta: { rig } };
  };
import { houseSheet, doorSheet } from './house.mjs';
SHEETS.house = houseSheet;
SHEETS.doors = doorSheet;
import { commonSheet } from './common.mjs';
import { BACKDROPS, backdropSheet } from './backdrops.mjs';
SHEETS.common = commonSheet;
BACKDROPS.forEach((_, i) => { SHEETS['bg-' + String(i + 1).padStart(2, '0')] = () => backdropSheet(i + 1); });
