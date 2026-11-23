// Dulmál's address on icelander.net, the role every request needs, and how rooms are named.
// A module of its own: the Worker's main module may export only its handler and the Durable Object.
export const BASE = "/games/dulmal";

/** Invite-only: granted to each player at icelander.net/private/admin. */
export const ROLE = "games:dulmal";

/** Room codes: four letters that are easy to read aloud and type, with no I, O, J, Q, C, W or Z. */
export const CODE_LETTERS = "ABDEFGHKLMNPRSTUVXY";
export const CODE_LENGTH = 4;
export const CODE_RE = new RegExp(`^[${CODE_LETTERS}]{${CODE_LENGTH}}$`);
