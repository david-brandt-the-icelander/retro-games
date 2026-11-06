# Lock Keeper (faithful, private)

A faithful JavaScript recreation of *Lock Keeper* (Inventasoft, 1984, ZX Spectrum), by R. T. Placeholder.
It reproduces the original's text and numbers exactly, so it stays private. The original listing is in `reference/`.

Engine API: `newGame(seed)`, `playGame(io, state, best)` (resolves with the new best), `snapshot(state)`.
`io.show(screen)` resolves with the key pressed. Run the tests with `node --test`.
