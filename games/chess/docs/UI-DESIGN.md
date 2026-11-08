# Gambit: UI design

Every screen, at the size it was designed for, with its layout, styles, text, states and behaviour. Build to this document and to the reference renders in [screens/](screens/); [DESIGN.md](DESIGN.md) says how to compare. The 3D table behind the screens is in [ART-BIBLE.md](ART-BIBLE.md); all values are also in [design-tokens.json](design-tokens.json).

## Canvas

- **Design size 1440 × 900.** Godot stretch mode `canvas_items`, aspect `expand`, HiDPI allowed: the UI scales with the window's height and wider windows show more table. The game screen needs at least about 1100 px of width; phone layouts are not designed yet.
- **Layers, back to front:**
  1. the 3D table, filling the window (a SubViewport with MSAA 4×, input passed through to it);
  2. the **veil**: a full-window rectangle in `#0B0C0F`, opacity 18 % on the title screen, 62 % on list screens (sign-in, set-up, lobby, contact, history), 0 % in a game; it fades over 0.4 s between screens and never takes clicks;
  3. the top bar;
  4. the current screen;
  5. the toast.
- Every container that only lays things out ignores the mouse, so clicks on the empty table reach the board (select, drag, turn the camera).

## Tokens

### Colour

| Token | Hex | Use |
|---|---|---|
| bg | `#0B0C0F` | the room behind everything, the veil |
| card | `#15171C` at 94 % | cards and the game panel |
| raised | `#1D2026` | rows, default buttons, toasts |
| line | `#2B2E36` | 1 px borders |
| ink | `#ECE8DF` | text |
| muted | `#8D919B` | secondary text |
| gold | `#D9B26B` | the accent: primary buttons, eyebrows, selection, "your move" |
| gold-dark | `#A8843F` | primary button pressed |
| red | `#E5566A` | danger buttons, errors, "Lost", "Reconnecting…" |
| green | `#6FCF97` | "Won", material advantage |
| inset | `#101216` | text fields, the transcript box |

### Type

Two families, both SIL OFL, embedded as WOFF2 (Latin subset):

| Style | Font | Size | Colour |
|---|---|---|---|
| Body (default) | Inter Regular 400 | 16 | ink |
| Strong | Inter SemiBold 600 | 16 | ink |
| Muted | Inter Regular | 14 | muted |
| Eyebrow | Inter SemiBold | 12 (no automatic capitals: headings like STRENGTH are written in capitals; names keep their own case) | gold |
| Button | Inter SemiBold | 15 | per variant |
| Heading | Playfair Display SemiBold 600 | 22 | ink |
| Title | Playfair Display Italic 400 | 64 (the title screen uses 96) | ink |

The Latin subset has no arrows or media symbols, so the UI uses words ("Back", "Next", "Play"), never ← → ▶ ⏮. It does have “ … — · × ” and accented Latin letters.

Antialiasing is on (grayscale).

### Components

All corner radii are in px; padding is left, top, right, bottom.

| Component | Normal | Hover | Pressed / on | Other |
|---|---|---|---|---|
| **Button** (default) | bg raised, 1 px line border, radius 10, padding 16 10 16 10, text ink | bg `#262A32`, border `#3B3F4A`, text white | bg `#17191E` | focus: 1 px gold border, no fill; disabled: bg `#17191E`, text muted; pointing-hand cursor |
| **Primary** | bg gold, radius 10, text `#17140E` | bg `#E6C27E` | bg gold-dark | — |
| **Ghost** | transparent, text muted | white at 6 % | white at 3 % | — |
| **Danger** | transparent, 1 px border red at 60 %, text red | red at 15 %, border red | — | asks "Sure?" (below) |
| **Chip** (toggle) | transparent, 1 px line border, radius 18, padding 14 8 14 8 | white at 5 %, border `#3B3F4A` | **on:** gold at 16 %, gold border, gold text | one chip in a group is on |
| **Text field** | bg inset, 1 px line border, radius 10, padding 14 10 14 10, text ink | — | **focus:** gold border, no fill | caret gold, placeholder muted at 70 %, selection gold at 30 % |
| **Card** | bg card (94 %), 1 px line border, radius 18, padding 22 20 22 20 | | | |
| **Row** (inside a card) | bg raised, radius 12, padding 12 10 12 10, no border | | | clickable rows show the pointing hand |
| **Inset** | bg inset, 1 px line border, radius 12, padding 12 10 12 10 | | | the transcript box |
| **Banner** | bg gold at 12 %, 1 px border gold at 50 %, radius 12, padding 14 10 14 10 | | | draw offers, "Looking at move…" |
| **Avatar** | a circle; the player's Google or GitHub picture, or until it loads (or if they have none) their initial in Inter SemiBold at 42 % of the size, ink, on a disc coloured HSV(hash(name) mod 360°, 0.35, 0.42) | | | sizes: 26 (chat), 34 (top bar, game rows), 40 (lobby rows), 44 (player plates), 72 (contact) |
| **Side dot** | a circle, 1 px border `#5A5D66`, fill `#ECE6D8` for White or `#1D1E24` for Black | | | sizes 9, 10, 12, 14 |
| **Slider** | track white at 10 %, 4 px, radius 3; the played part gold | | | grabber: a 16 px ivory disc |
| **Scrollbar** | invisible track; grabber white at 12 %, 6 px wide, radius 3 | grabber 22 % | 22 % | |
| **Toast** | bg raised, radius 12, padding 18 12 18 12, 1 px border gold (information) or red (error), body text | | | centred, 28 px above the bottom edge; fades in 0.2 s, stays 3.5 s, fades out 0.4 s; a new toast replaces the old |

**"Sure?" buttons.** Every Danger button asks first (in this design: **Resign** and **Remove from contacts**): the first press changes its label to "Sure? Resign" for 3 s; a second press within that time acts; otherwise it reverts.

### Spacing

Gaps between siblings: 18 (page columns and cards, top bar), 14 (game panel), 12 (default rows and boxes), 10 (lobby lists, contact rows), 8 (button rows), 2 (transcript entries, name over email).

## Formats

| What | Format | Examples |
|---|---|---|
| A clock time | `HH:MM`, 24-hour, the player's time zone | 14:05 |
| A day heading in the transcript | Today · Yesterday · `Weekday D Month` (plus the year if not this year), shown in capitals | TODAY · FRIDAY 6 NOVEMBER |
| How long ago | just now (< 1 min) · `N min ago` · `N h ago` (< 24 h) · then `D Mon, HH:MM` (with the year if not this year) | 44 min ago · 6 Nov, 10:35 |
| How long a move took | `Ns` · `Nm SSs` · `Nh MMm` · `Nd Nh` | 9s · 2m 05s · 4h 37m · 2d 4h |
| Moves in a game | full moves, the chess way (a move by each side is one move): No moves yet · 1 move · `N moves` | 4 moves |
| A record | `W win(s) · L loss(es) · D draw(s)`, singular for 1 | 1 win · 0 losses · 0 draws; short form in rows: `1W 0L 0D` |
| Move numbers | White `N.`, Black `N…` | 3. · 3… |

## The top bar

[screens/07-home-signed-in.png](screens/07-home-signed-in.png), [screens/01-home-signed-out.png](screens/01-home-signed-out.png)

A band across the top of the window, **72 px tall including its 18 px top margin**: its row of controls starts 18 px below the top edge and is 54 px tall (so the controls' centre line is 45 px from the top), with 28 px margins left and right and gaps of 18. Nothing else is in the band: list pages start at 92 px and the game panel at 84 px, below it.

1. **Gambit**: a Ghost button in Playfair Display Italic 28, ink (gold on hover). Goes to the title screen.
2. Ghost buttons **Play** (title screen), and for a signed-in player only, **Friends** (lobby) and **History**. Signed out, the bar has no Friends or History: **Sign in** and **Play a friend** lead to the sign-in screen.
3. A spacer.
4. Ghost button **Sound on** / **Sound off** (toggles all sound).
5. Signed in: avatar 34, the player's name (Strong), Ghost **Sign out** (gaps of 10). Signed out: Chip **Sign in** (goes to the lobby, which asks to sign in).

The bar is the same on every screen, including games.

## List screens: the page

Sign-in, set-up, lobby, contact and history share a page: 92 px from the top, 24 px from the bottom, a single scrolling column of a fixed width (given per screen), centred horizontally (side margins = max(16, (window width − column width) / 2)), with cards stacked 18 apart. The column scrolls vertically if it's taller than the window.

## 1. Title screen

Signed out [01](screens/01-home-signed-out.png) · signed in [07](screens/07-home-signed-in.png) · with a computer game in progress [05](screens/05-home-continue.png)

Veil 18 %. The table turns slowly with its board to the right (camera: distance 15.5, offset −0.2; see the art bible).

A column 460 px wide, left edge 72 px from the window's left, top 190 px above the window's vertical middle, gaps of 18:

| Element | Style | Text |
|---|---|---|
| Eyebrow | Eyebrow | CHESS, BEAUTIFULLY |
| Title | Title at 96 | Gambit |
| Lede | Muted at **18**, wrapping | Play a friend anywhere — invite them by email and take your time. Or face Stockfish, from gentle to merciless. |
| (an empty row) | | adds one gap |
| Buttons, gap 12 | Primary 220 × 52 · Button 220 × 52 | **Play a friend** (lobby) · **Play the computer** (set-up) |
| Only if a game against the computer is unfinished and has a move | Ghost | **Continue your game against level N** (opens it) |

## 2. Sign-in

[screens/02-sign-in.png](screens/02-sign-in.png)

Shown in place of the lobby, contact and history (signed-in parts) to anyone not signed in. Column 520. One card, gap 14:

| Element | Text |
|---|---|
| Heading | Sign in |
| Muted, wrapping | Sign in to play friends. Invite anyone by email; they sign in too, and your games, contacts and history are kept. |
| Primary, 48 tall, full width | **Continue with Google** (only if Google is set up) |
| Button, 48 tall, full width | **Continue with GitHub** (only if GitHub is set up) |
| Development only: a text field (placeholder "any@email.test (development sign-in)") and a Button **Dev sign-in** | |
| If neither provider is set up: Muted | Sign-in isn't available right now. You can still play the computer. |
| Muted, wrapping | We keep your name, email address and profile picture from Google or GitHub, so friends can find you, and your games. Nothing else. |

The provider buttons go to the provider and come back to the same page, signed in (an invitation in the address is kept through sign-in).

## 3. Computer set-up

[screens/03-computer-setup.png](screens/03-computer-setup.png)

Column 860. One card, gap 16:

- Heading **Play the computer**.
- Eyebrow **STRENGTH**, then a grid of 4 columns × 2 rows, gaps 10, of toggle tiles 190 × 92. A tile is a Chip with its own boxes: normal bg raised + line border, radius 12, padding 14 10 14 10; hover bg `#262A32` + border `#3B3F4A`; on: gold at 14 % + gold border, text gold. Text is Inter SemiBold 13, left-aligned, three lines: `N  Name` / description / rating. Exactly one is on; level 3 by default. Selecting one plays the *select* sound.

  | N | Name | Description | Rating |
  |---|---|---|---|
  | 1 | Pawn Pusher | Just learned the moves | ~400 |
  | 2 | Weekend Player | Plays fast, leaves pieces hanging | ~800 |
  | 3 | Club Novice | Knows a few tricks | ~1100 |
  | 4 | Café Regular | Punishes loose pieces | ~1400 |
  | 5 | Club Captain | Solid and patient | ~1700 |
  | 6 | County Champion | Sees tactics you miss | ~2000 |
  | 7 | Master | Bring your best game | ~2300 |
  | 8 | Stockfish | Full strength | 2800+ |
- Eyebrow **YOUR COLOUR**, then Chips **White** · **Random** · **Black** (gap 8; Random on by default).
- A row: Ghost **Back** (title screen), spacer, Primary **Start the game** 220 × 50.
- Muted: Stockfish 19 runs in your browser; the ratings are rough guides.

## 4. Lobby (Friends)

[screens/08-lobby.png](screens/08-lobby.png) · after sending an invitation [09](screens/09-lobby-invitation-sent.png)

Column 1120, two columns side by side (gap 18): left takes 1.15 shares of the width, right 1. Refreshes every 10 s while shown. The browser tab's title becomes **(N) Gambit**, N = invitations for you + games where it's your move (just **Gambit** when 0).

**Left column, top to bottom:**

1. **Invite a friend** (card, gap 12)
   - Heading **Invite a friend**; Muted, wrapping: They'll get your invitation when they sign in with this address.
   - Row (gap 8): text field, filling the width, placeholder `friend@example.com`; Primary **Send invitation**. Enter in the field sends too.
   - Row (gap 8): Muted **You play**; Chips **White** · **Random** · **Black** (Random on).
   - After sending, below: Muted, wrapping, `Invitation emailed to {email}. You can also send them this link:` (when an email went out) or `Invitation waiting for {email}. You can also send them this link:`; then a row of a read-only text field with the link and a Button **Copy** (toast "Link copied."). The *notify* sound plays and the field empties.
2. **Invitations for you** (card, gap 10; hidden when there are none). Heading, then a row per invitation, newest first: avatar 40 · name (Strong) over `{email} · you play {white|black|a random colour} · {ago}` (Muted; both truncate with "…") · Primary **Accept** (opens the new game) · Ghost **Decline**.
3. **Your games** (card, gap 10). Heading, then a clickable row per game in play, most recently active first: avatar 40 of the opponent · name over `{N moves} · {ago}` plus ` · draw offered` if the opponent has offered one · side dot 12 for your colour · **Your move** (Strong, gold) or **Their move** (Muted). When empty: Muted "No games in play. Invite someone!". A click opens the game.
4. **Waiting for an answer** (card, gap 10; hidden when none). A row per invitation you sent: the email over `sent {ago}` · Ghost **Copy link** · Ghost **Cancel**.

**Right column:**

1. **Contacts** (card, gap 10). Heading, then a clickable row per contact (most recently played first): avatar 40 · name over `{email} · {W}W {L}L {D}D`. When empty: Muted, wrapping "Everyone you play is kept here, with your record and your games against them." A click opens the contact.
2. Ghost **All your games** (history).

If the page was opened from an invitation link (`?challenge=ID`) and that invitation is open and addressed to this account, it is simply there under **Invitations for you**. If it was already accepted, its game opens; otherwise a toast says `That invitation was {declined|cancelled}.` or `That invitation was sent to a different address than {email}.` (error).

## 5. Contact

[screens/10-contact.png](screens/10-contact.png)

Column 820:

1. Card: row (gap 18): avatar 72 · a column (gap 2) of the name (Heading at 30), the email (Muted), the record in words (Strong, e.g. "1 win · 0 losses · 0 draws") · spacer · Primary **Invite to a game** (sends an invitation with Random colour; toast "Invitation sent." or the error).
2. Card: Heading **Your games together**, then a game row per game (in play and finished, newest first); "No games yet." when empty.
3. Row: Ghost **Back**, spacer, Danger **Remove from contacts**, which asks first ("Sure? Remove from contacts", see "Sure?" buttons); then toast "Removed." and back to the lobby.

**Game row** (also used by History): clickable Row, gap 12: the outcome, Strong, 64 px wide: **Won** (green) · **Lost** (red) · **Draw** (muted) · **In play** (gold) · avatar 34 of the opponent · `vs {name}` over `{result or Your move/Their move} · {N moves} · {ago}` · side dot 12 for the player's colour. Finished games open as a replay; games in play open live.

## 6. History

Signed in [11](screens/11-history.png) · signed out [06](screens/06-history-signed-out.png)

Column 820. One card: Heading **Your games**, then a game row per finished game (friends and computer), newest first, 30 at a time; a Ghost **More** under the card loads the next 30 (only shown when there may be more). Empty: Muted "No finished games yet."

Signed out (no longer in the top bar since 2026-11-08, so only reached directly, e.g. `--goto=history`), the card first says (Muted, wrapping) "Games against the computer on this device. Sign in to keep every game, with friends too, wherever you play." and lists the games kept on the device.

## 7. Game

Online, your move with a draw offer, seen as Black [12](screens/12-game-draw-offered.png) · in check [13](screens/13-game-check.png) · a piece picked up [14](screens/14-game-piece-selected.png) · promotion [15](screens/15-game-promotion.png) · looking at an earlier move [16](screens/16-game-looking-back.png) · finished [17](screens/17-game-finished.png) · waiting for the opponent [20](screens/20-game-waiting.png) · against the computer [04](screens/04-computer-your-move.png)

Veil 0. The camera sits behind the player's colour, at distance 15 with offset 0.2, so the board sits left of the panel.

**The panel** is a card anchored to the right: its right edge 24 px from the window's right, 416 px wide, from 84 px below the top to 24 px above the bottom. Inside, a column with gaps of 14:

1. **Black's plate**, then **White's plate** (always in this order). Each is a Row, gap 12: avatar 44 · name (Strong) over email (Muted), both truncated with "…", filling the width · the material lead, if this side is ahead, as `+N` (Strong, green; pawn 1, knight 3, bishop 3, rook 5, queen 9) · side dot 14. The computer's plate reads `Stockfish · {level name}` with an "S" avatar; a signed-out player is "You".
2. **Status**, Heading, wrapping:

   | When | Text | Colour |
   |---|---|---|
   | Your move | Your move | gold |
   | Your move and you're in check | Your move — check! | gold |
   | Their move | Waiting for {name}… | ink |
   | The computer is thinking | Stockfish is thinking… | ink |
   | Over | the result, see below | gold |

   Results: `Checkmate. {winner} wins` · `{loser} resigned. {winner} wins` · `{loser} left. {winner} wins` · `Stalemate. Drawn` · `Insufficient material. Drawn` · `Threefold repetition. Drawn` · `Fifty-move rule. Drawn` · `Draw agreed`.
3. **Reconnecting…** (Muted, red), only while the live connection is down.
4. **Draw banner** (online, only while a draw is offered). Offered by the opponent: `{name} offers a draw.` on one line, then a row of Primary **Accept** and Button **Decline**. Offered by you: "You offered a draw. Your opponent can accept, or answer with a move." (wrapping).
5. **Looking-back banner** (only while looking at an earlier position): `Looking at move {n} of {m}` (full moves), spacer, Primary **Back to the game**. The board can't be moved while looking back.
6. Eyebrow **TRANSCRIPT**.
7. **The transcript**: an Inset that takes all remaining height, scrolling, entries 2 px apart. It scrolls to the newest entry whenever the game changes. Entries, oldest first:

   | Entry | Layout |
   |---|---|
   | Day heading | wherever the date changes (including before the first entry): the day in capitals, Eyebrow at 11 in **muted**, centred |
   | Every other entry | starts with the clock time (Muted 12, 44 px wide, top-aligned), then a gap of 10 (8 for moves) |
   | Game started | Playfair Display Italic 15, muted: "Game started" |
   | A move | the move number (Muted 13, 34 px, right-aligned: `N.` or `N…`) · side dot 9 · the move in SAN as a Ghost button in Inter SemiBold, ink, left-aligned, filling the width, padding 8 3 8 3, radius 8 (highlighted gold at 18 % when it's the position being looked at) · how long it took (Muted 12), measured from the previous move (the first from the start) |
   | Chat | avatar 26 · a bubble filling the width: radius 12, padding 12 8 12 8, bg gold at 12 % for the player's own messages and `#22252C` for the opponent's; inside, the sender's name as given (Eyebrow style, not capitalised) over the message (body, wrapping) |
   | Draw offered / declined | italic note: `{name} offers a draw` · `{name} declines the draw` |
   | Resigned | italic note: `{name} resigns` |
   | The end | Strong, gold: the result text |

   Clicking a move looks at the position after it.
8. **Chat** (online only): a row of a text field (placeholder "Say something…", at most 500 characters, filling the width) and a Primary **Send**. Enter sends. Chat works during and after the game.
9. **Actions** (gap 8; hidden when empty):

   | Game | In play | Over |
   |---|---|---|
   | Online | **Offer draw** (hidden while an offer stands) · Danger **Resign** | Primary **Rematch** (invites the opponent with colours swapped; toast "Rematch sent — it's waiting in their lobby."; goes to the lobby) |
   | Computer | **Take back** · Danger **Resign** | Primary **New game** (set-up) |
10. A row: Ghost **Turn the board** (the camera swings to the other side), spacer, Ghost **Leave** (back to where the player came from: the lobby for online games).

**Promotion** [15](screens/15-game-promotion.png): when a pawn reaches the last rank, a Card appears over the board, centred on the window then moved 200 px left: Heading **Promote to**, then a row (gap 10) of Primary **Queen** and Buttons **Rook**, **Bishop**, **Knight**, and a Ghost **Cancel** (puts the pawn back).

**Sounds:** see the art bible. The player's own moves and the opponent's play *move*/*capture*; an opponent's message plays *chat*; an incoming draw offer plays *notify*; the end plays *win*, *lose* or *draw*.

**Moving.** Only on the player's turn and while nothing is being sent: click (or press) a piece of yours to pick it up (it lifts, its square goes gold, its moves show as dots and rings), then click a destination; or drag it there. Clicking another of your pieces picks that one up instead; clicking anything else puts it down (and plays *illegal* if it wasn't a move). Online, the move shows at once and is confirmed by the server, or undone with an error toast.

## 8. Replay

At the start [18](screens/18-replay-start.png) · partway, after 3. Qh5 [19](screens/19-replay-midway.png)

The game screen, with these differences: no chat field, no actions, and a **replay bar** between the transcript and the last row (column, gap 8):

1. A slider across the width, one step per transcript entry (0 = before the first entry).
2. A row (gap 4): Ghost **Start** · Ghost **Back** · Primary **Play** / **Pause** · Ghost **Next** · Ghost **End**.
3. A row (gap 8): Muted **Pace** · Chips **1×** · **4×** · **16×** (4× on) · spacer · Muted **as played, sped up**.

- Entries after the current point are shown at **28 % opacity**, including day headings; the transcript scrolls to keep the current one in view. The board shows the position at that point (moves glide when stepping forward by one).
- Status (Heading): before anything, `Replay · {clock time of the start}`; partway, `{N}. {SAN} · {elapsed} in` for a White move or `{N}… {SAN} · {elapsed} in` for Black, with the same `N.`/`N…` numbering as the transcript (elapsed since the start, as a duration); these are in ink. At the end, the result, in **gold**.
- **Play** steps through the entries, waiting between them as long as the players did divided by the pace, but at least 0.35 s and at most 3 s. It stops at the end (pressing Play again restarts from the beginning). Start, Back, Next, End, dragging the slider and clicking a move all stop it. The pace chips do **not**: a new pace applies from the next wait.
- Clicking a move in the transcript jumps to just after it.

## 9. Toasts

Information [21](screens/21-toast-info.png) · error [22](screens/22-toast-error.png)

The texts:

| Information | Error |
|---|---|
| Invitation sent. · Link copied. · Removed. · Rematch sent — it's waiting in their lobby. · That invitation was declined. · That invitation was cancelled. | That doesn't look like an email address. · That invitation was sent to a different address than {email}. · Couldn't save this game to your history: {reason} · and the server's own messages, for example "You can't challenge yourself. Try the computer!", "That's a lot of challenges. Try again in an hour.", "The challenge was already answered.", "It isn't your move.", "The board changed; try again.", "That move isn't legal.", "Can't reach the server. Are you online?" |

## Keyboard and accessibility

- Every button is focusable (gold focus ring) and works with Enter/Space. Enter sends in the invitation and chat fields.
- The board is driven by mouse or touch.
- Text contrast (WCAG): ink on card 14.7 : 1, muted on card 5.7 : 1, gold on card 9.0 : 1, `#17140E` on gold 9.2 : 1.
- Nothing is told by colour alone: results are words, and side dots sit next to names.
