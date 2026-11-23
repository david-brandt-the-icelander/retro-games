// Words the page shows in more than one place.

export const GAME_NAME = "Kvarðinn";

/** "Svona er spilað": the lobby's how-to-play text (at most eight lines). */
export const howTo = (goal: number): string[] => [
  "Skiptið ykkur í tvö lið. Í hverri umferð gefur einn úr liðinu vísbendingu.",
  "Spjaldið sýnir tvær andstæður, til dæmis „Kalt ↔ Heitt“.",
  "Aðeins sá sem gefur vísbendingu sér hvar leynimarkið er á kvarðanum.",
  "Hann eða hún segir eða skrifar vísbendingu sem á heima einmitt þar – til dæmis „kaffi“ fyrir nokkuð heitt.",
  "Liðið ræðir saman og dregur vísinn þangað sem það heldur að markið sé. Einn læsir ágiskuninni.",
  "Nálægt miðju marksins gefur 4 stig, svo 3 og 2. Hitt liðið má giska hvort markið sé vinstra eða hægra megin við vísinn (1 stig).",
  `Fyrsta liðið sem nær ${goal} stigum vinnur. Í „Allir saman“ reynir hópurinn að slá eigið met.`,
];

export function esc(s: string): string {
  return s.replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]!);
}

/** "1 stig", "3 stig": stig is the same in the singular and plural. */
export const stig = (n: number): string => `${n} stig`;
