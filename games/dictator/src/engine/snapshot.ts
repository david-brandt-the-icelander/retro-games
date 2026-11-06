// The state in RULES' own terms, for step-by-step comparison with a reference model.
import type { GameState, Plot } from "./state";

export interface Snapshot {
  pop: number[];
  str: number[];
  status: Plot[];
  ally: number[];
  treasury: number;
  costs: number;
  swiss: number;
  presidentStrength: number;
  month: number;
  threshold: number;
  revolutionStrength: number;
  plotPause: number;
  helicopter: boolean;
  loanEast: boolean;
  loanWest: boolean;
  requestUsed: boolean[];
  decisionUsed: boolean[];
  newsUsed: boolean[];
  alive: boolean;
  escaped: boolean;
  rng: number;
}

export function snapshot(s: GameState): Snapshot {
  return {
    pop: [...s.popularity],
    str: [...s.strength],
    status: [...s.plots],
    ally: [...s.allies],
    treasury: s.treasury,
    costs: s.costs,
    swiss: s.swiss,
    presidentStrength: s.bodyguard,
    month: s.month,
    threshold: s.threshold,
    revolutionStrength: s.revolutionStrength,
    plotPause: s.plotPause,
    helicopter: s.helicopter,
    loanEast: s.loanEast,
    loanWest: s.loanWest,
    requestUsed: [...s.requestUsed],
    decisionUsed: [...s.decisionUsed],
    newsUsed: [...s.newsUsed],
    alive: s.alive,
    escaped: s.escaped,
    rng: s.rng >>> 0,
  };
}
