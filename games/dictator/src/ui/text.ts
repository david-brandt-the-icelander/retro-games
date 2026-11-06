// Every player-facing string, from docs/UI-DESIGN.md: on-screen text and screen-reader text.

// ── Names ────────────────────────────────────────────────────────────────

/** On-screen group labels, in group order. */
export const LABELS = ["ARMY", "PEASANTS", "SAMOSAS", "CONTRAS", "HONDURAS", "SEC. POLICE", "EAST", "WEST"] as const;
/** Spoken group names, for the start of a line ("Army: popularity 6"). */
export const SPOKEN = ["Army", "Peasants", "Samosa family", "Contras", "Honduras", "State Security", "Moscow and Havana", "Washington"] as const;
/** Spoken group names inside a sentence. */
export const SPOKEN_THE = ["the Army", "the Peasants", "the Samosa family", "the Contras", "Honduras", "State Security", "Moscow and Havana", "Washington"] as const;

export const NEIGHBOUR = "Honduras";
export const POWER = { east: "Moscow", west: "Washington" } as const;

// ── Number formats ───────────────────────────────────────────────────────

/** Money held in thousands: 0 → $0; 1 → $1,000; −119 → -$119,000. */
export function money(v: number): string {
  if (v === 0) return "$0";
  const digits = String(Math.abs(v)).replace(/\B(?=(\d{3})+(?!\d))/g, ",");
  return `${v < 0 ? "-" : ""}$${digits},000`;
}

/** A change with its sign always shown: +4, -3. */
export const signed = (n: number): string => (n > 0 ? `+${n}` : `${n}`);

/** Spoken change: "plus 4", "minus 3". */
export const spokenChange = (n: number): string => `${n > 0 ? "plus" : "minus"} ${Math.abs(n)}`;

/** A label on the left, an amount right-aligned to `width` columns. */
export function ledger(label: string, amount: string, width: number): string {
  return label + " ".repeat(Math.max(1, width - label.length - amount.length)) + amount;
}

// ── Footers and letterheads ──────────────────────────────────────────────

export const PROMPT = {
  any: "PRESS A KEY OR TAP TO GO ON",
  yes: "Y = YES   ANY OTHER KEY = NO",
  menu: "PRESS 1-5, OR ANY OTHER KEY",
  section: "NUMBER: CHOOSE  OTHER: BACK",
  help: "PRESS 1-6 TO ASK FOR HELP",
  nextPage: "ANY KEY: NEXT PAGE",
  backToTitle: "ANY KEY: BACK TO THE TITLE",
  takePower: "ANY KEY: TAKE POWER",
  titleKeys: "H HOW TO PLAY  A ABOUT  M SOUND",
} as const;

export const OFFICE = {
  howto: "HOW TO RULE",
  about: "ABOUT SAMOSA",
  palace: "THE PALACE",
  treasury: "STATE TREASURY",
  security: "STATE SECURITY",
  audience: "AUDIENCE HALL",
  counsel: "PRIVATE COUNSEL",
  signature: "FOR SIGNATURE",
  directorate: "THE DIRECTORATE",
  offshore: "OFFSHORE DESK",
  foreign: "FOREIGN MINISTRY",
  reckoning: "FINAL RECKONING",
} as const;

/** Keypad button labels. */
export const BUTTON = {
  next: "NEXT", yes: "YES", no: "NO", noDecision: "NO DECISION", back: "BACK",
  play: "PLAY", howto: "HOW TO", about: "ABOUT",
} as const;

export const SOUND_STATE = (on: boolean): string => `SOUND: ${on ? "ON" : "OFF"}`;
export const SOUND_SPOKEN = (on: boolean): string => (on ? "Sound on." : "Sound off.");

// ── Extras: title, how to play, about ───────────────────────────────────

export const TITLE = {
  name: "Samosa",
  tagline: "New dynasty. Same old palace.",
  speech: "Samosa. New dynasty. Same old palace. A picture of an empty palace balcony with a microphone. Press any key to take power, H for how to play, A for about, M for sound.",
} as const;

export const HOWTO_PAGES: readonly (readonly string[])[] = [
  [
    "You are President Ortiga of", "Nicaragua. The Samosas ruled", "before you; they left by air.", "",
    "Every month a group of the", "nation wants something, and", "every refusal makes enemies.", "",
    "There is no winning. A reign", "ends when you are killed or", "when you flee the country.", "",
    "Then you are scored: on how", "popular you were, how long you", "lasted and, if you got out", "alive, what you took with you.",
  ],
  [
    "Eight groups watch you:", "1 ARMY        5 HONDURAS", "2 PEASANTS    6 SEC. POLICE", "3 SAMOSAS     7 EAST",
    "4 CONTRAS     8 WEST", "EAST: Moscow and Havana.", "WEST: Washington and its CIA.", "SEC. POLICE: State Security.", "",
    "POP. 0-9: how much they like", "you. STR. 0-9: how strong they", "are (EAST and WEST: none).",
    "A group whose POP. sinks to a", "secret line, which moves each", "month, turns on you. CONTRAS", "always do.",
  ],
  [
    "A month in the palace:", "1 The treasury pays the", "  monthly costs. In debt, the", "  army, police and your guard",
    "  lose heart instead.", "2 A group asks a favour. Ask", "  your adviser, then grant it", "  or refuse. Refusing costs",
    "  what it would have gained.", "  Too poor? You must refuse.", "3 Assassins strike; Honduras", "  may threaten or invade.",
    "4 You make one decision.", "5 News, perhaps a revolution.",
  ],
  [
    "Each month you may take one", "decision from five sections,", "or none at all.", "",
    "Most can be taken only once.", "More guards and the Swiss", "account can be used again.", "",
    "Moscow and Washington each", "lend once, if they like you", "and you have ruled long", "enough. Money sent to Swiss",
    "banks is yours, if you live.", "", "A helicopter may fly you out.", "It starts two times in three.",
  ],
  [
    "State Security sells its files", "for $1,000, if it is loyal,", "strong, and you can pay.", "",
    "A file shows every group's", "POP. and STR., and any plots:", "RISE +n: plans to revolt with", "group n. HIRE AN ASSASSIN:",
    "plans to have you shot.", "", "A revolt needs its two groups'", "strengths to reach the figure",
    "in the file. Loyal or strong", "police foil most assassins.",
  ],
  [
    "When revolution comes, run or", "fight. To fight, call on a", "group that still likes you.", "Crush the revolt and you may",
    "punish its leaders.", "", "Run by helicopter, if you have", "one, or on foot over the",
    "mountains to Honduras. More", "CONTRAS there, less chance.", "", "SCORE: total popularity, plus",
    "3 a month ruled. Alive? Plus", "10, and 1 for every $10,000", "in Switzerland.", "M turns sound on and off.",
  ],
];

export const HOWTO = {
  pageOf: (page: number, pages: number) => `PAGE ${page} OF ${pages}`,
  speech: (page: number, pages: number, lines: readonly string[]) =>
    `How to rule, page ${page} of ${pages}. ${lines.map((l) => l.trim()).filter(Boolean).join(" ")} ` +
    (page < pages ? "Press any key for the next page." : "Press any key to go back to the title."),
} as const;

export const ABOUT = {
  credit: [
    "Inspired by Dictator (1983) by", "Don Priestley, published by", "DK'Tronics. Independent remake,",
    "not affiliated with or endorsed", "by the original rights holders.",
  ],
  remake: [
    "Remade by David Brandt, 2026.", "A caricature of Nicaraguan", "history, not a record. No real",
    "person is portrayed. MPL-2.0.", "github.com/david-brandt-the-", "icelander/retro-games",
  ],
  speech: "About Samosa. Inspired by Dictator (1983) by Don Priestley, published by DK'Tronics. Independent remake, not affiliated with or endorsed by the original rights holders. Remade by David Brandt, 2026. A caricature of Nicaraguan history, not a record. No real person is portrayed. Licence MPL-2.0. Source code at github.com/david-brandt-the-icelander/retro-games. Press any key to go back to the title.",
} as const;

// ── Speech endings ───────────────────────────────────────────────────────

export const PRESS_ANY = "Press any key.";
const PRESS_YES = "Press Y for yes, any other key for no.";

// ── Game screens ─────────────────────────────────────────────────────────

export const WELCOME = {
  best: (best: number) => ["Back again, President Ortiga?", `Record to beat: ${best} points.`, "History expects little of you."],
  first: ["The palace is yours, Ortiga.", "The Samosas left in a hurry.", "Do try to leave more slowly."],
  voucher: ["The first ledger and the first", "State Security file are free."],
  speech: (lines: readonly string[]) =>
    `The Palace. ${lines.join(" ")} Voucher: the first ledger and the first State Security file are free. ${PRESS_ANY}`,
} as const;

export const MONTH = {
  heading: "MONTH",
  line: "of the eternal revolution",
  speech: (m: number) => `Month ${m} of the eternal revolution.`,
} as const;

export const TREASURY = {
  holds: "Treasury holds",
  solvent: "Solvent, for the moment.",
  debt: "IN DEBT! CREDITORS CIRCLE.",
  costs: "Monthly costs",
  swiss: "Swiss nest egg",
  speechLines: (treasury: number, costs: number, swiss: number) =>
    `The treasury holds ${money(treasury)}. ${treasury < 0 ? "In debt! Creditors circle." : "Solvent, for the moment."} ` +
    `Monthly costs ${money(costs)}.` + (swiss > 0 ? ` Swiss nest egg ${money(swiss)}.` : ""),
  speech: (treasury: number, costs: number, swiss: number) =>
    `State Treasury. ${TREASURY.speechLines(treasury, costs, swiss)} ${PRESS_ANY}`,
} as const;

export const REPORT = {
  classified: "TOP SECRET: BURN AFTER READING",
  bought: (m: number) => `File for month ${m}`,
  first: "Opening file, on the house",
  final: "FINAL FILE, FOR THE ARCHIVE",
  heading: "No GROUP         POP.  STR.",
  rise: (faction: string, allyNo: number, ally: string) => `${faction} RISE +${allyNo} ${ally}`,
  assassin: (faction: string) => `${faction} HIRE AN ASSASSIN`,
  noPlots: "No plots uncovered. Yet.",
  bodyguard: (p: number) => `Your bodyguard strength: ${p}`,
  revolt: (r: number) => `A revolt needs strength ${r}`,
  speechTitle: { first: "the opening file", bought: (m: number) => `for month ${m}`, final: "the final file" },
  speechPlotRise: (faction: number, ally: number) =>
    `Plot: ${SPOKEN_THE[faction]} ${faction === 0 ? "plans" : "plan"} a revolution with group ${ally + 1}, ${SPOKEN_THE[ally]}.`,
  speechPlotAssassin: (faction: number) =>
    `Plot: ${SPOKEN_THE[faction]} ${faction === 0 ? "plans" : "plan"} to have you assassinated.`,
  speechNoPlots: "No plots uncovered.",
  speechOdds: (p: number, r: number) => `Bodyguard strength ${p}. A revolt needs strength ${r}.`,
} as const;

export const OFFER = {
  ask: ["Psst. The latest file on who", (price: string) => `plots what? Only ${price}.`] as const,
  none: "No dossier this time, sorry.",
  disloyal: (pop: number) => `Police loyalty too low: ${pop}`,
  weak: (str: number) => `Police too weak: strength ${str}`,
  cannotPay: "Treasury cannot pay for it.",
  speechAvailable: (price: string) => `State Security. Psst. The latest file on who plots what? Only ${price}. ${PRESS_YES}`,
  speechUnavailable: (reasons: readonly string[]) => `State Security. No dossier this time, sorry. ${reasons.map((r) => r + ".").join(" ")}`,
} as const;

export const BANKRUPT = {
  stamp: "BANKRUPT",
  lines: ["Nobody is paid. It shows:", "ARMY popularity -1", "SEC. POLICE popularity -1", "SEC. POLICE strength -1", "Your bodyguard -1"],
  speech: "Bankrupt! Nobody is paid. It shows: Army popularity minus 1. State Security popularity minus 1. State Security strength minus 1. Your bodyguard minus 1.",
} as const;

export const AUDIENCE = {
  announce: (faction: string) => `Announcing: the ${faction}!`,
  speech: (faction: number, lines: readonly string[]) =>
    `Audience hall. Announcing: ${SPOKEN_THE[faction]}! The petition: ${lines.join(" ")} ${PRESS_ANY}`,
} as const;

export const ADVICE = {
  ask: "A word of counsel, President?",
  askSpeech: `Private counsel. A word of counsel, President? ${PRESS_YES}`,
  marker: "=>",
  key: "=> marks the petitioners",
  measure: { popularity: "popularity", strength: "strength" } as const,
  speech: (text: readonly string[], lines: ReadonlyArray<{ group: number; measure: string; change: number; own: boolean }>) =>
    `Private counsel. ${text.join(" ")} ` +
    lines.map((l) => `${SPOKEN[l.group]} ${l.measure} ${spokenChange(l.change)}.${l.own ? " This is the petitioners' own line." : ""}`).join(" ") +
    ` ${PRESS_ANY}`,
} as const;

export const DIALOG = {
  petition: (faction: string) => `Petition of the ${faction}`,
  decree: "By decree of President Ortiga",
  paidIn: (a: string) => `Paid in at once: ${a}`,
  paidOut: (a: string) => `Paid out at once: ${a}`,
  costsRise: (a: string) => `Costs rise ${a} a month`,
  costsFall: (a: string) => `Costs fall ${a} a month`,
  free: "Free of charge. Splendid.",
  speech: (header: string, text: readonly string[], money: readonly string[], affordable: boolean) =>
    `For signature. ${header}. ${text.join(" ")} ${money.map((m) => (m.endsWith(".") ? m : m + ".")).join(" ")} ` +
    (affordable ? PRESS_YES : "There is no money to cover this."),
} as const;

export const CASH_SHORT = {
  lines: ["The vaults echo. There is no", "money for that, not a cent."],
  ask: (power: string) => `Ask ${power} for a loan?`,
  speech: (item: string, hints: readonly string[]) =>
    `State treasury. ${item}. The vaults echo. There is no money for that, not a cent.${hints.map((h) => " " + h).join("")}`,
} as const;

export const MUST_REFUSE = {
  lines: ["The treasury cannot stretch", "that far. The answer is no."],
  speech: "Audience hall. The treasury cannot stretch that far. The answer is no.",
} as const;

export const MENU = {
  title: (m: number) => `Your decision for month ${m}`,
  sections: ["Reward a single group", "Gifts for the whole nation", "Look after number one", "Find money, somehow", "Make a group stronger"],
  other: "Any other key: skip this month",
  speech: (m: number) =>
    `The Directorate. Your decision for month ${m}. ${MENU.sections.map((t, i) => `${i + 1}, ${t}.`).join(" ")} Any other key: skip this month.`,
} as const;

export const SECTION = {
  title: (n: number) => `${n}. ${MENU.sections[n - 1]}`,
  used: ["This section is all used up.", "Your past self was thorough."],
  speech: (n: number, options: ReadonlyArray<readonly [number, string]>) =>
    `The Directorate, section ${n}: ${MENU.sections[n - 1]}. ${options.map(([k, l]) => `${k}, ${l}.`).join(" ")} Press a number to choose, any other key to go back.`,
  usedSpeech: (n: number) => `Section ${n}: ${MENU.sections[n - 1]}. This section is all used up. Your past self was thorough.`,
} as const;

export const SWISS = {
  was: "Treasury was",
  slipped: "Slipped away:",
  moved: "Nobody saw a thing.",
  nothing: ["Not a dollar to spare.", "The briefcase stays empty."],
  speech: (before: number, moved: number) =>
    `Offshore desk. Treasury was ${money(before)}. ` +
    (moved > 0 ? `Slipped away: ${money(moved)}. Nobody saw a thing.` : "Not a dollar to spare. The briefcase stays empty."),
} as const;

export const LOAN = {
  letter: (power: string) => `Your letter to ${power}`,
  considered: "is being considered.",
  waitSpeech: (power: string) => `Foreign Ministry. Your letter to ${power} is being considered.`,
  early: (p: string) => [`${p} says: too soon.`, "Come back when your regime", "has lasted a little longer."],
  noMore: (p: string) => [`${p}: one loan only.`, "You have had yours.", "Final answer."],
  refusedEast: ["With fraternal regret, the", "Central Committee finds no", "spare roubles. Next plan?"],
  refusedWest: ["Congress has passed an", "amendment forbidding it.", "Have a nice day."],
  granted: (p: string, a: string) => [`${p} sighs: fine.`, `${a} is on its way.`, "It will not forget this."],
  resultSpeech: (lines: readonly string[]) => `Foreign Ministry. ${lines.join(" ")} ${PRESS_ANY}`,
} as const;

export const NEWS = {
  alert: ["STOP PRESS! STOP PRESS!", "NEWS IS COMING DOWN THE WIRE"],
  alertSpeech: "Stop press! News is coming down the wire.",
  masthead: "LA PRENSA",
  headlineSpeech: (lines: readonly string[]) => `La Prensa. ${lines.join(" ")}`,
} as const;

export const ASSASSIN = {
  attempt: (faction: string) => ["CRACK! An assassin, paid by", `the ${faction}, takes aim!`],
  attemptSpeech: (faction: number) => `Crack! An assassin, paid by ${SPOKEN_THE[faction]}, takes aim!`,
  killed: ["President Ortiga is dead.", "The palace falls silent."],
  survived: ["Missed! The bullet bounced off", "a medal. Ortiga lives on!"],
} as const;

export const WAR = {
  threat: [`${NEIGHBOUR} threatens war!`, "Fear unites the nation.", "Army, Peasants, Samosas and", "State Security: popularity +1."],
  threatSpeech: `${NEIGHBOUR} threatens war! Fear unites the nation. Army, Peasants, Samosas and State Security: popularity plus 1.`,
  invades: `War! ${NEIGHBOUR} invades!`,
  ours: "OUR FORCES",
  theirs: "THEIR FORCES",
  guns: "The guns begin to roar...",
  invasionSpeech: (ours: number, theirs: number) =>
    `War! ${NEIGHBOUR} invades! Our forces ${ours}. Their forces ${theirs}. The guns begin to roar.`,
  won: [`${NEIGHBOUR} is beaten back!`, "Its army is no more."],
  lost: [`${NEIGHBOUR} wins the war.`, "The capital has fallen."],
} as const;

export const HELI = {
  escape: ["Up, up and away! Ortiga leaves", "by helicopter for Miami, with", "the Swiss bank details."],
  escapeSpeech: "A helicopter lifts off the palace roof. Up, up and away! Ortiga leaves by helicopter for Miami, with the Swiss bank details.",
  fail: ["The engine coughs twice and", "dies. The pilot shrugs.", "It will have to be on foot."],
  failSpeech: "The helicopter sits on the roof, smoking. The engine coughs twice and dies. The pilot shrugs. It will have to be on foot.",
} as const;

export const EXECUTION = {
  heliHeading: "The helicopter will not start.",
  neighbourHeading: `${NEIGHBOUR} takes the palace.`,
  lines: ["Condemned as a traitor", "by a court of one afternoon.", "Shot at dawn."],
} as const;

export const REVOLT = {
  alarm: "REVOLUTION!",
  streets: "The streets are full of rebels.",
  alarmSpeech: "Revolution! The streets are full of rebels.",
  ask: ["The mob is at the gates.", "Slip away while you still can?"],
  askSpeech: `The mob is at the gates. Slip away while you still can? ${PRESS_YES}`,
  risen: (faction: string, ally: string, combined: number) => [`${faction} have risen, joined by`, `${ally}. Their strength: ${combined}`],
  risenSpeech: (faction: number, ally: number, combined: number) =>
    `${cap(SPOKEN_THE[faction])} have risen, joined by ${SPOKEN_THE[ally]}. Their strength: ${combined}.`,
  who: "Who will stand by you?",
  helpSpeech: (faction: number, ally: number, combined: number, listed: readonly number[]) =>
    `${REVOLT.risenSpeech(faction, ally, combined)} Who will stand by you? ${listed.map((g) => `${g + 1}, ${SPOKEN[g]}.`).join(" ")} Press 1 to 6 to ask for help.`,
  alone: ["Nobody will lift a finger.", "You face the rebels alone,", "with only your bodyguard."],
  aloneSpeech: (faction: number, ally: number, combined: number) =>
    `${REVOLT.risenSpeech(faction, ally, combined)} Nobody will lift a finger. You face the rebels alone, with only your bodyguard. ${PRESS_ANY}`,
  joke: (group: string) => [`${group}? They despise you!`, "Even the guards are laughing.", "There is nothing for it: run!"],
  jokeSpeech: (group: number) => `${cap(SPOKEN_THE[group])}? They despise you! Even the guards are laughing. There is nothing for it: run!`,
  bodyguard: "Your bodyguard",
  noHelper: "No helper",
  rebels: "Rebels",
  blink: "Who will blink first?",
  strengthSpeech: (p: number, helper: number, h: number, rebels: number) =>
    `Your bodyguard ${p}. ${helper >= 0 ? `${SPOKEN[helper]} ${h}.` : "No helper."} Rebels ${rebels}. Who will blink first?`,
  start: ["The fighting has begun!", "Shots ring out in the square."],
  overthrown: ["The palace has fallen.", "President Ortiga is dragged", "out and shot. The statue too."],
  crushed: ["The revolt is crushed!", "Order, of a sort, returns."],
  punish: "Punish the ringleaders?",
  crushedSpeech: `The revolt is crushed! Order, of a sort, returns. Punish the ringleaders? ${PRESS_YES}`,
} as const;

export const FLIGHT = {
  mountains: ["On foot, by night, over the", "northern mountains towards", `${NEIGHBOUR}. Contra country.`],
  mountainsSpeech: `A small figure walks over the mountains by moonlight. On foot, by night, over the northern mountains towards ${NEIGHBOUR}. Contra country.`,
  caught: ["Caught! The Contras cheer,", "dance a little, and settle the", "matter on the spot."],
  escaped: ["They missed! By dawn the", "President is safe across the", `border in ${NEIGHBOUR}.`],
  escapedSpeech: `Dawn over the mountains. They missed! By dawn the President is safe across the border in ${NEIGHBOUR}.`,
} as const;

export const FUNERAL = {
  lines: (m: number) => ["The nation mourns, officially.", "Flags at half mast, by order.", "A wreath from a grateful state.", `Months in power: ${m}.`],
  speech: (m: number) => `A laurel wreath. ${FUNERAL.lines(m).join(" ")} ${PRESS_ANY}`,
} as const;

export const RATING = {
  popularity: "Popularity, all groups",
  months: (m: number) => `Months ruled ${m} x 3`,
  survival: "Survival bonus",
  swiss: (s: string) => `Swiss ${s}/10`,
  total: (t: number) => `TOTAL ${t}`,
  best: (b: number) => `Best so far: ${b}`,
  newBest: "A new record! Statues ordered.",
  speech: (r: { popularity: number; months: number; monthsPoints: number; alive: boolean; survivalBonus: number; swiss: number; swissPoints: number; total: number; best: number; newBest: boolean }) =>
    `Final reckoning. Popularity, all groups: ${r.popularity}. Months ruled ${r.months}, times 3: ${r.monthsPoints}. ` +
    (r.alive ? `Survival bonus ${r.survivalBonus}. Swiss ${money(r.swiss)}, divided by 10: ${r.swissPoints}. ` : "") +
    `Total ${r.total}. Best so far ${r.best}. ${r.newBest ? "A new record! Statues ordered. " : ""}${PRESS_ANY}`,
} as const;

// ── Data texts (RULES §17) ───────────────────────────────────────────────

/** Requests R1–R24: two lines each. */
export const REQUEST_TEXT: readonly (readonly [string, string])[] = [
  ["Patriotic Military Service for", "every boy. Mothers will cope."],
  ["We need a firing range. That", "coffee farm looks suitable."],
  ["Contras in the Segovias again.", "Fund a sweep of the hills!"],
  [`The Contras hide in ${NEIGHBOUR}.`, "Let us cross over and raid!"],
  ["State Security keeps files on", "our generals. Sack its chief!"],
  ["Havana says 200 advisers. We", "count 3,000. Send them home!"],
  ["Raise our pay, and the boys", "may even close the casinos."],
  ["Moscow sent helicopters. Now", "we want the MiGs. And bullets."],
  ["Press gangs take our sons from", "the fields. Kindly stop them."],
  ["We pick the cotton and coffee", "for pennies. A fairer wage?"],
  ["The block wardens count our", "beans. Please call them off."],
  [`Boats from ${NEIGHBOUR} fish our`, "share of the gulf. Stop them."],
  ["Send the literacy brigades", "again. Every child, a reader!"],
  ["Let the farm workers' union", "meet with no informer present."],
  ["Our union leader sits in jail", "for speaking up. Release them!"],
  ["The Guard ran the numbers. Let", "the people run a lottery now!"],
  ["Soldiers keep 'requisitioning'", "our cattle. Keep them out."],
  ["Pesticides cost a fortune. So", "wages must fall. Naturally."],
  ["Seize the American fruit firm", "and hand it to the family."],
  [`A 35% tariff on ${NEIGHBOUR}!`, "Sovereignty, and our profits."],
  ["State Security has informers", "in our mills. Cut its budget."],
  ["Land tax hurts the biggest", "landowner most. That is us."],
  ["Lend us soldiers to pick the", "coffee. Unpaid, as before."],
  ["Dig us a grand canal. It can", "water our estates on the way."],
];

/** Decision labels D1–D19. */
export const DECISION_LABEL: readonly string[] = [
  "Make the general my deputy", "Cuban doctors for clinics", "A pact with the Samosas", `Resell arms to ${NEIGHBOUR}`,
  "Gold mines for Washington", "A naval base for Moscow", "Tax cuts all round", "Giant metal trees", "Disband State Security",
  "Volunteer masked police", "More palace guards", "A helicopter, fuelled", "Half to my Swiss account", "Ask Moscow for a loan",
  "Ask Washington for aid", `Seize ${NEIGHBOUR}'s firms`, "Soviet tanks for the army", "Open the northern roads",
  "A Samosa family militia",
];

/** Decision texts for the options that reach advice and the dialog (D13–D15 never do). */
export const DECISION_TEXT: readonly (readonly [string, string] | null)[] = [
  ["The army chief shall be my", "deputy. That never ends badly."],
  ["Havana's doctors will staff", "free clinics for the workers."],
  ["The Samosas may rule their", "provinces; we split the rest."],
  ["Sell Washington's gifts to", `${NEIGHBOUR}, with a mark-up.`],
  ["Western miners may dig our", "gold. We keep the receipts."],
  ["Moscow may moor its fleet in", "the gulf. For a modest rent."],
  ["Taxes cut for everyone, just", "before the vote. Coincidence."],
  ["Plant giant metal trees down", "every boulevard. Very modern."],
  ["State Security is dissolved.", "Its files go to the bonfire."],
  ["Masked volunteers join State", "Security. What could go wrong?"],
  ["Train more guards, loyal to me", "alone. (Can be repeated.)"],
  ["A helicopter on the roof, kept", "fuelled. Miami is not far."],
  null, null, null,
  ["Every Honduran business here", "now belongs to the state."],
  ["T-55 tanks and rocket trucks", "for the army, gift-wrapped."],
  ["Peasants may travel the north", "freely. So may the Contras."],
  ["The Samosas may arm their", "estate guards. What a relief."],
];

const UPPER_NEIGHBOUR = NEIGHBOUR.toUpperCase();
const CROP = "COFFEE";

/** Headlines N1–N6: three lines each, in capitals. */
export const HEADLINE_TEXT: readonly (readonly [string, string, string])[] = [
  ["STATE SECURITY FILES FOUND", "IN A CRASHED CARGO PLANE", "CONTRAS READ THEM FIRST"],
  ["IRAN ARMS-DEAL CASH FLOWS", "TO THE CONTRAS. WASHINGTON", "'SHOCKED, SIMPLY SHOCKED'"],
  ["BLAST FLATTENS ARMY BARRACKS", "SOLDIERS SLEEP IN THE PARK", "POLICE: 'NOT US, HONEST'"],
  [`${CROP} PRICE CRASHES`, `SAMOSAS AND ${UPPER_NEIGHBOUR}`, "COUNT THE COST"],
  [`EARTHQUAKE HITS ${UPPER_NEIGHBOUR}`, "SAMOSAS SELL THEM PAVING", "STONES AT TRIPLE PRICE"],
  ["CROP-SPRAY SICKNESS SWEEPS", "THE COTTON BELT; CLINICS FULL", "ESTATES DENY EVERYTHING"],
];

/** Capitalise the first letter of a sentence. */
export function cap(s: string): string {
  return s.charAt(0).toUpperCase() + s.slice(1);
}
