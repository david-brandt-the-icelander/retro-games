// Dulmál's address on icelander.net, and how rooms are named.
// A module of its own so the tests can use it without the Worker's main module.
export const BASE = "/games/fresh/dulmal";

/** Room codes: four letters that are easy to read aloud and type, with no I, O, J, Q, C, W or Z. */
export const CODE_LETTERS = "ABDEFGHKLMNPRSTUVXY";
export const CODE_LENGTH = 4;
export const CODE_RE = new RegExp(`^[${CODE_LETTERS}]{${CODE_LENGTH}}$`);
