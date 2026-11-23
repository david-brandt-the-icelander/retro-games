// Pinochle's address on icelander.net, and the role every file is served under (invite-only, granted at icelander.net/private/admin).
// A module of its own: the Worker's main module may export nothing but its handler.
export const BASE = "/games/pinochle";
/** Where Pinochle used to be: every address under it is sent, for good, to the same place under BASE. */
export const OLD_BASE = "/games/fresh/pinochle";
export const ROLE = "games:pinochle";
