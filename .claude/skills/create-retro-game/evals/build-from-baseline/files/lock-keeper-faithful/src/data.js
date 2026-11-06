// Text and tables exactly as in the 1984 original.
export const TEXT = {
  title: ["LOCK KEEPER", "Keep the Marrowdeep Cut afloat", "by R. T. PLACEHOLDER", "(C) 1984 INVENTASOFT LIMITED", "Press I for the rules"],
  help: ["Boats come to your lock each day.", "Let them through for tolls, but", "every lockful drains the pound.", "Turn them away and folk grumble."],
  day: (d) => `Day ${d} at Lock Seven, Marrowdeep`,
  status: (s) => `Water ${s.water}  Coins ${s.coins}  Goodwill ${s.goodwill}`,
  prompt: "Open gates (O) or keep shut (K)?",
  rain: "Rain drums on the towpath. The pound fills.",
  next: "Press a key for the next day",
  endings: [
    "The pound runs dry and the boats sit in the mud.",
    "The bailiffs take your lock-house and your kettle.",
    "The boatmen petition Pellandine and you are dismissed.",
    "Twenty days kept well. You retire to a cottage by the Cut.",
  ],
  best: (h) => `Longest service: ${h} days`,
};

// DATA 900: toll, water used, goodwill gained.
export const BOATS = [
  { text: "A painted narrowboat toots its horn.", toll: 3, water: 1, goodwill: 1 },
  { text: "A coal barge wallows low in the water.", toll: 6, water: 2, goodwill: 0 },
  { text: "Pleasure cruisers sing as they drift up.", toll: 2, water: 1, goodwill: 1 },
  { text: "The Pellandine inspector wants passage.", toll: -8, water: 1, goodwill: 2 },
];
