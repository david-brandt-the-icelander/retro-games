// Worst-case examples of every screen, shared by the layout test and the contact sheet.
// Add a sample for every screen kind and state: longest text, biggest numbers, every flag.
import type { Screen } from "../src/engine/screens";
import { drawScreen, drawTitle } from "../src/ui/screens";
import type { ZXScreen } from "../src/zx/screen";

export const SCREENS: Screen[] = [
  { kind: "night", night: 1, oil: 6, storm: false },
  { kind: "night", night: 999, oil: -99, storm: true },
  { kind: "ending", survived: true, nights: 7 },
  { kind: "ending", survived: false, nights: 999 },
];

/** Everything to render: game screens plus presentation-only extras. */
export const SAMPLES: Array<{ name: string; draw: (z: ZXScreen) => unknown }> = [
  { name: "title", draw: (z) => drawTitle(z) },
  ...SCREENS.map((s, i) => ({ name: `${s.kind}-${i}`, draw: (z: ZXScreen) => drawScreen(z, s) })),
];
