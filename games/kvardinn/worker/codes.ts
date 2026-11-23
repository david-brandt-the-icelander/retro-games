// Room codes, in a module of their own: the Worker's main module may export only its handler and the Durable Object.
/** Room codes: no I, O, Q, W, C or Z, so a code read aloud or off a TV is hard to get wrong. */
export const CODE_LETTERS = "ABDEFGHJKLMNPRSTUVXY";
export const CODE_RE = /^[ABDEFGHJKLMNPRSTUVXY]{4}$/;

export function newCode(): string {
  const a = new Uint32Array(4);
  crypto.getRandomValues(a);
  return [...a].map((n) => CODE_LETTERS[n % CODE_LETTERS.length]).join("");
}
