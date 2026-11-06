---
type: llm
focus: trace
weight: 1
---

The remake's engine under games/canal-lock/src exports newGame(seed), playGame(io, state, best) and snapshot(state), and drives every screen through one io.show(screen) call that resolves with a key, so it can run headless
