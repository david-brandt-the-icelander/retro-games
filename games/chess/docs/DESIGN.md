# Gambit: design

The complete visual and interaction design of Gambit, written so the game can be built from `docs/` alone and come out looking the same. The intent and the decisions behind it are in [GDD.md](GDD.md).

| Document | What it covers |
|---|---|
| [UI-DESIGN.md](UI-DESIGN.md) | Every screen and state: layout, components, styles, text, formats, behaviour |
| [ART-BIBLE.md](ART-BIBLE.md) | The 3D table: environment, lights, materials, board, the piece models (with their exact profiles), marks, camera, motion, and sound |
| [design-tokens.json](design-tokens.json) | Every number and colour from both, in one machine-readable file |
| [screens/](screens/) | 23 reference renders at 1440 × 900, one per screen state (listed below) |
| [contact-sheet.png](contact-sheet.png) | All the reference renders on one page |

Where a document and a render disagree, the document wins and the render is a bug to report. Fonts: [`godot/fonts/`](../godot/fonts/) (Inter 400 and 600, Playfair Display 600 and 400 italic, Latin subset, SIL OFL).

## Acceptance: "visually correct"

An implementation is visually correct when, with the reference scenario below loaded and the window at **1440 × 900**, each of the 23 states renders to match its reference image:

- **Layout:** every element is where the reference shows it, to within **2 px** (positions and sizes come from UI-DESIGN; the renders confirm them).
- **Text:** the same words, fonts, sizes, weights and colours.
- **Colour:** UI colours exactly as the tokens give them; the 3D scene within a small tolerance, since lighting and antialiasing differ slightly between GPUs and between desktop OpenGL and the browser's WebGL. The references were rendered with Godot 4.7.2's Compatibility renderer on Mesa (llvmpipe) under Xvfb.
- **Things that legitimately differ** and are masked when comparing: clock times and "… ago" texts (they depend on when the scenario was loaded), the link in the invitation-sent state, and the slowly turning table on the title screen (its angle depends on time since start).

The quickest check is side by side: render your build's 23 states with `scripts/reference/render.sh` (it writes into `docs/screens/`; use a scratch copy or `git diff` the images) and compare each with the committed reference. An image diff with the masked areas excluded should show only antialiasing noise.

### Reference states

| # | File | State |
|---|---|---|
| 01 | `01-home-signed-out.png` | Title screen, signed out |
| 02 | `02-sign-in.png` | Sign-in (Google and GitHub set up, plus the development sign-in) |
| 03 | `03-computer-setup.png` | Computer set-up, defaults (level 3, Random) |
| 04 | `04-computer-your-move.png` | Against the computer (level 3, playing White) after 1. e4 e5 2. Nf3 Nc6 3. Bc4 Bc5, signed out |
| 05 | `05-home-continue.png` | Title screen with that game unfinished ("Continue your game…") |
| 06 | `06-history-signed-out.png` | History, signed out, one game against the computer kept on the device |
| 07 | `07-home-signed-in.png` | Title screen signed in as Alice |
| 08 | `08-lobby.png` | Lobby: one invitation for Alice, four games in play, four contacts (the "Waiting for an answer" card is below the fold) |
| 09 | `09-lobby-invitation-sent.png` | Lobby just after inviting gina@test.io |
| 10 | `10-contact.png` | Contact: Bob Hansen |
| 11 | `11-history.png` | History, signed in: a win, a loss to the computer, a loss by resignation, a draw |
| 12 | `12-game-draw-offered.png` | Online game seen as Black, Alice's move, Carla has offered a draw, with chat in the transcript |
| 13 | `13-game-check.png` | Online, Alice (White) in check after 2… Qh4+ |
| 14 | `14-game-piece-selected.png` | Online, the g1 knight picked up: lifted, gold square, two move dots |
| 15 | `15-game-promotion.png` | Online, the b7 pawn taking on a8: the promotion picker |
| 16 | `16-game-looking-back.png` | The draw-offer game, looking at the position after move 2 |
| 17 | `17-game-finished.png` | Online game just finished: Scholar's mate, chat before and after |
| 18 | `18-replay-start.png` | That game as a replay, at the start |
| 19 | `19-replay-midway.png` | The replay after 3. Qh5 (transcript entry 7) |
| 20 | `20-game-waiting.png` | Online, waiting for Bob's move; moves on earlier days (day headings) |
| 21 | `21-toast-info.png` | An information toast on the title screen |
| 22 | `22-toast-error.png` | An error toast |
| 23 | `23-pieces.png` | The six pieces in both colours, close up (not a game screen: the models) |

## The reference scenario

What the renders show, so a fresh implementation can set up the same data. `scripts/reference/seed.py` creates it through the game's own API on a fresh local database, and `scripts/reference/retime.py` then gives it realistic times; `scripts/reference/render.sh` renders the states.

**Players** (all signed in through the development sign-in, so they have no profile pictures and show initials): Alice Morgan (alice@test.io, the player in every render), Bob Hansen, Carla Ortiz, Dan Okafor, Eva Lind (all @test.io). The desktop development sign-in names a player from their address, so Alice appears as **Alice** everywhere in the renders; the others keep the full names the scenario gave them.

**Games** (Alice's opponent; who is White; moves in UCI; actions in brackets):

| Key | Opponent | White | Moves and actions | State |
|---|---|---|---|---|
| eva_draw | Eva | Alice | e2e4 c7c5 g1f3 d7d6 d2d4 c5d4 f3d4 g8f6 b1c3 a7a6 [Eva offers a draw] [Alice accepts] [Eva: "Good game, rematch next week?"] | draw agreed, 6 days ago |
| carla_lost | Carla | Alice | d2d4 d7d5 c2c4 e7e6 b1c3 g8f6 c1g5 f8e7 [Alice resigns] [Carla: "Thanks for the game!"] | Carla won, 3 days ago |
| bob_mate | Bob | Alice | [Bob: "Good luck! Have fun."] e2e4 e7e5 f1c4 b8c6 d1h5 [Bob: "Hmm, the queen already?"] g8f6 h5f7 [Alice: "gg, thanks!"] | Alice won by mate, about 2 hours ago |
| bob_check | Bob | Alice | e2e4 e7e5 f2f4 d8h4 | in play, Alice to move, in check |
| dan_promo | Dan | Alice | a2a4 b7b5 a4b5 a7a6 b5a6 c8b7 a6b7 h7h6 | in play, Alice to move (b7 can take on a8 and promote) |
| carla_offer | Carla | Carla | e2e4 e7e5 g1f3 b8c6 f1b5 a7a6 b5a4 g8f6 e1g1 [Carla: "Ruy Lopez again :)"] [Carla offers a draw] | in play, Alice (Black) to move |
| bob_waiting | Bob | Alice | c2c4 e7e5 b1c3 | in play, Bob to move, started 2 days ago |
| (computer) | Stockfish level 5 | Alice | f2f3 e7e5 g2g4 d8h4 (moves at 9 s, 11 s, 31 s, 33 s) | Stockfish won, 2 days ago |

**Invitations:** Bob invited Alice (Bob plays Black, so Alice plays White) 40 minutes before the scenario was loaded; Alice invited frank@test.io (Random) 3 hours before.

**Times:** each game starts at the time in the table and its moves follow at intervals drawn (with a fixed random seed) between 0.25× and 1.9× its pace: eva_draw 90 s, carla_lost 2 min, bob_mate 25 s, bob_check 1 min, dan_promo 2 h, carla_offer 9 min, bob_waiting 6 h; chat 8–40 s after the previous entry; offers and resignations 3–15 s; the end at the same moment as the move or action that caused it.

## Switches the reference renders need

To render the states without clicking through them, the desktop build understands these command-line switches after `--` (they do nothing in the browser). An implementation that wants to use `render.sh` for its own comparison needs the same:

| Switch | Does |
|---|---|
| `--server=URL` | The game's API (default `http://127.0.0.1:8787/retro/chess/`) |
| `--dev-email=EMAIL` | Signs in through the development sign-in first |
| `--goto=setup\|lobby\|history\|computer\|game\|contact` | Opens a screen. `computer` starts a new game at level 3 as White, with `--moves=…` already played (one second apart). `game` opens `--id=ID` (finished games as a replay, unless `--mode=online`). `contact` opens `--contact=EMAIL` |
| `--select=SQ` | Picks up the piece on SQ |
| `--promote=FROMTO` | Moves a pawn to the last rank, opening the promotion picker |
| `--view=PLY` | Looks at the position after PLY half-moves |
| `--seek=N` | In a replay, goes to just after transcript entry N |
| `--play` | In a replay, presses Play |
| `--face=0\|1` | Puts the camera behind White or Black |
| `--toast=TEXT`, `--error-toast=TEXT` | Shows a toast |
| `--invite=EMAIL` | In the lobby, sends an invitation |
| `--click=X,Y;…` | Clicks at those points, two seconds apart |
| `--shot=FILE --shot-after=S` | After S seconds, saves the window to FILE and quits |
