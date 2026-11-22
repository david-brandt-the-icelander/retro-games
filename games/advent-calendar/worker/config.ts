// The Advent calendar's address on icelander.net, and the invite-only role every file is served under.
// A module of its own: the Worker's main module may export nothing but its handler (workerd reads every
// named export there as an entrypoint).
export const BASE = "/games/fresh/advent-calendar";
export const ROLE = "games:advent-calendar";
