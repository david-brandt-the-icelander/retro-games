// Every word the page shows, in Icelandic, in one place so a native speaker can check it.
import type { ErrorCode, Team } from "../shared/protocol";

export const GAME_NAME = "Dulmál";

export const TEAM_NAME: Record<Team, string> = { hraun: "Hraun", jokull: "Jökull" };
/** Eignarfall: „sögumaður Hrauns“. */
export const TEAM_GEN: Record<Team, string> = { hraun: "Hrauns", jokull: "Jökuls" };
/** Þágufall: „hjá Hrauni“. */
export const TEAM_DAT: Record<Team, string> = { hraun: "Hrauni", jokull: "Jökli" };

export const T = {
  tagline: "Orðaleikur fyrir tvö lið — saman í stofunni eða hvert í sínu horni.",

  // Upphafssíða
  newGame: "Nýr leikur",
  yourName: "Nafnið þitt",
  namePlaceholder: "t.d. Sigga",
  createRoom: "Stofna herbergi",
  joinGame: "Ganga í leik",
  roomCode: "Kóði herbergis",
  codePlaceholder: "t.d. HKLS",
  go: "Áfram",
  creating: "Augnablik…",

  // Að ganga í herbergi
  room: (code: string) => `Herbergi ${code}`,
  whatName: "Hvað heitir þú?",
  join: "Ganga í leikinn",
  rejoin: "Hefurðu verið með áður, t.d. í öðru tæki? Veldu nafnið þitt:",
  bigScreen: "Stór skjár",
  bigScreenHint: "Notaðu þetta á sjónvarpi eða skjávarpa sem allir í stofunni sjá. Skjárinn sýnir borðið en aldrei litina á földu orðunum.",
  useAsScreen: "Nota þetta tæki sem stóran skjá",
  noRoom: "Þetta herbergi finnst ekki. Það kann að vera útrunnið eða kóðinn rangur.",
  toStart: "Á upphafssíðu",

  // Anddyri
  invite: "Bjóddu fleirum",
  inviteHint: "Sendu tengilinn, eða leyfðu fólki að skanna kóðann með símanum.",
  copyLink: "Afrita tengil",
  copied: "Tengill afritaður",
  share: "Deila",
  showQr: "Sýna QR-kóða",
  hideQr: "Fela QR-kóða",
  teams: "Liðin",
  you: "þú",
  host: "stjórnandi",
  away: "fjarri",
  clueGiver: "Sögumaður",
  guesser: "Giskari",
  clueGiverHint: "gefur vísbendingar og sér litina",
  guesserHint: "giskar á orðin",
  switchTeam: "Skipta um lið",
  becomeClueGiver: "Verða sögumaður",
  makeClueGiver: "Gera að sögumanni",
  removePlayer: "Fjarlægja",
  shuffle: "Stokka upp liðin",
  start: "Hefja leik",
  waitForHost: (name: string) => `Bíðum eftir að ${name} hefji leikinn.`,
  needTeams: "Hvort lið þarf einn sögumann og minnst einn giskara (minnst 4 leikmenn).",
  rename: "Breyta nafni",
  save: "Vista",
  leave: "Hætta í leiknum",
  leaveConfirm: "Viltu hætta í leiknum? Sætið þitt losnar.",
  howTo: "Svona er leikið",
  screenTip: "Ertu með sjónvarp eða skjávarpa? Opnaðu tengilinn þar og veldu „Stór skjár“.",

  // Stillingar (stjórnandi)
  settings: "Stillingar",
  timer: "Tímamörk í hverri umferð",
  timerOff: "Engin",
  timerChoice: (s: number) => (s === 60 ? "1 mínúta" : s === 90 ? "1½ mínúta" : `${s / 60} mínútur`),
  wordList: "Orðalisti",
  builtinList: "Innbyggði listinn er í notkun.",
  customList: (n: number) => `Þinn eigin listi er í notkun (${n} orð).`,
  pasteHint: "Límdu inn þín eigin orð, eitt í hverja línu eða með kommu á milli. Minnst 25 orð.",
  useMyList: "Nota minn lista",
  useBuiltin: "Nota innbyggða listann",
  listSaved: "Nýi listinn gildir frá næsta leik.",

  // Í leik
  onTurn: (t: Team) => `${TEAM_NAME[t]} á leik`,
  left: "eftir",
  youGiveClue: "Nú gefur þú vísbendingu",
  teammateThinking: "Sögumaðurinn ykkar er að hugsa…",
  otherThinking: (t: Team) => `Sögumaður ${TEAM_GEN[t]} er að hugsa…`,
  yourTurnGuess: "Giskið! Ýttu á orð.",
  teamGuessing: "Liðið þitt giskar. Ekki gefa nein merki!",
  otherGuessing: (t: Team) => `${TEAM_NAME[t]} er að giska.`,
  guessesLeft: (n: number) => (n === 1 ? "1 gisk eftir" : `${n} gisk eftir`),
  clueLabel: "Vísbending",
  clueWord: "Eitt orð",
  cluePlaceholder: "t.d. Sjór",
  clueNumber: "Hve mörg orð á borðinu tengjast?",
  sendClue: "Senda vísbendingu",
  pick: (w: string) => `Velja „${w}“?`,
  yesPick: "Já, velja",
  cancel: "Hætta við",
  stopGuessing: "Hætta að giska",
  guessOneFirst: "Giskið á minnst eitt orð áður en þið hættið.",
  timeLeft: "Tími",

  // Hvað gerðist síðast
  gotClue: (t: Team, word: string, n: number) => `${TEAM_NAME[t]} fékk vísbendinguna „${word}“ ${n}.`,
  right: (by: string, w: string) => `${by} valdi „${w}“ — rétt!`,
  neutral: (by: string, w: string) => `${by} valdi „${w}“ — hlutlaust orð. Umferðinni er lokið.`,
  theirs: (by: string, w: string, t: Team) => `${by} valdi „${w}“ — orð ${TEAM_GEN[t]}. Umferðinni er lokið.`,
  ghostPicked: (by: string, w: string) => `${by} valdi drauginn, „${w}“!`,
  stopped: (t: Team) => `${TEAM_NAME[t]} hætti að giska.`,
  timeout: (t: Team) => `Tíminn rann út hjá ${TEAM_DAT[t]}.`,

  // Leikslok
  wins: (t: Team) => `${TEAM_NAME[t]} vinnur!`,
  wonAll: (t: Team) => `${TEAM_NAME[t]} fann öll sín orð.`,
  lostGhost: (t: Team) => `${TEAM_NAME[t]} valdi drauginn og tapaði.`,
  playAgain: "Nýr leikur, sömu lið",
  changeTeams: "Breyta liðum",
  hostCanRestart: (name: string) => `${name} getur hafið nýjan leik.`,

  // Valmynd
  menu: "Valmynd",
  close: "Loka",
  clues: "Vísbendingar",
  noClues: "Engar vísbendingar enn.",
  players: "Leikmenn",
  newBoard: "Nýtt borð",
  newBoardConfirm: "Hefja nýjan leik með sömu liðum? Þessum leik lýkur.",
  backToTeams: "Aftur í liðaval",
  backToTeamsConfirm: "Fara aftur í liðaval? Þessum leik lýkur.",

  // Stór skjár
  scanToJoin: "Skannaðu með símanum til að vera með",
  orOpen: "eða opnaðu",
  andEnterCode: "og sláðu inn kóðann",

  // Tenging
  connecting: "Tengist…",
  reconnecting: "Tengingin rofnaði. Tengist aftur…",

  // Spil
  kind: { hraun: "Hraun", jokull: "Jökull", neutral: "hlutlaust", ghost: "draugur" } as Record<string, string>,
  ghost: "Draugurinn",
};

/** Seven or eight short lines: the whole of the rules, shown in the lobby. */
export const HOW_TO: readonly string[] = [
  "Tvö lið, Hraun og Jökull, keppast við að finna sín orð á borðinu.",
  "Hvort lið hefur einn sögumann. Aðeins sögumennirnir sjá hvaða orð tilheyra hvoru liði.",
  "Sögumaður gefur vísbendingu: eitt orð og eina tölu, til dæmis „Sjór 2“.",
  "Talan segir hve mörg orð á borðinu tengjast vísbendingunni.",
  "Liðið giskar með því að ýta á orð. Það má giska einu sinni oftar en talan segir, eða hætta fyrr.",
  "Rétt orð: haldið áfram. Hlutlaust orð eða orð hins liðsins: hitt liðið á leik.",
  "Varist drauginn! Liðið sem velur hann tapar strax.",
  "Liðið sem fyrst finnur öll sín orð vinnur.",
];

export const ERROR: Record<ErrorCode, string> = {
  bad: "Eitthvað fór úrskeiðis. Reyndu aftur.",
  noRoom: "Þetta herbergi finnst ekki. Athugaðu kóðann.",
  full: "Herbergið er fullt.",
  name: "Skrifaðu nafnið þitt.",
  notHost: "Aðeins stjórnandinn getur gert þetta.",
  notNow: "Það er ekki hægt núna.",
  notYou: "Það er ekki komið að þér.",
  needTeams: "Hvort lið þarf einn sögumann og minnst einn giskara.",
  clueWord: "Vísbendingin á að vera eitt orð, án bila.",
  clueOnBoard: "Þetta orð er á borðinu. Veldu annað.",
  clueNumber: "Veldu tölu frá 1 upp í 9.",
  revealed: "Þetta orð er þegar komið upp.",
  guessFirst: "Giskið á minnst eitt orð áður en þið hættið.",
  fewWords: "Listinn þarf minnst 25 ólík orð.",
  seatTaken: "Þessi leikmaður er nú þegar tengdur í öðru tæki.",
};
