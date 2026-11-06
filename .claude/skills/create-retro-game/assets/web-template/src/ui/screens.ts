// EXAMPLE GAME (replace): one painter per screen kind, from docs/UI-DESIGN.md.
// Each returns the keys the touch keypad offers.
import type { Screen } from "../engine/screens";
import { ANY, Offer } from "../zx/input";
import { BLACK, BLUE, CYAN, RED, WHITE, YELLOW, ZXScreen } from "../zx/screen";
import { LAMP } from "./art";
import { at, Painter } from "./paint";
import { TEXT } from "./text";

type Draw<K extends Screen["kind"]> = (p: Painter, s: Extract<Screen, { kind: K }>) => Offer;

const draw: { [K in Screen["kind"]]: Draw<K> } = {
  night(p, s) {
    p.page(s.storm ? BLACK : BLUE, WHITE, s.storm ? RED : BLUE);
    p.text(2, ` ${TEXT.night(s.night)} `, at(BLACK, YELLOW, { bright: true }));
    p.icon(15, 5, LAMP, at(YELLOW, s.storm ? BLACK : BLUE, { bright: true }));
    p.para(10, s.storm ? TEXT.storm : TEXT.calm, at(WHITE, s.storm ? BLACK : BLUE, { flash: s.storm }), 1, true);
    p.text(13, TEXT.oil(s.oil), at(CYAN, s.storm ? BLACK : BLUE));
    p.text(17, TEXT.askTrim);
    p.footer(TEXT.pressKey);
    return [["y", "Y"], ["n", "N"]];
  },
  ending(p, s) {
    p.page(s.survived ? YELLOW : BLACK, s.survived ? BLACK : WHITE);
    p.text(8, s.survived ? TEXT.survived : TEXT.lost, at(s.survived ? BLACK : WHITE, s.survived ? YELLOW : BLACK, { bright: true }));
    p.text(11, TEXT.nights(s.nights));
    p.footer(TEXT.pressKey);
    return [[ANY, "KEY"]];
  },
};

export function drawScreen(z: ZXScreen, s: Screen): Offer {
  return (draw[s.kind] as Draw<typeof s.kind>)(new Painter(z), s as never);
}

export function drawTitle(z: ZXScreen): Offer {
  const p = new Painter(z).page(BLUE, WHITE, BLACK);
  p.text(4, ` ${TEXT.title} `, at(BLACK, YELLOW, { bright: true }));
  p.text(6, TEXT.subtitle, at(CYAN, BLUE));
  p.icon(15, 9, LAMP, at(YELLOW, BLUE, { bright: true }));
  p.footer(TEXT.pressKey);
  return [[ANY, "PLAY"]];
}
