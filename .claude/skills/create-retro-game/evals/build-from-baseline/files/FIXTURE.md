Fixture for the create-retro-game build-from-baseline test case. "Lock Keeper"
(1984, "Inventasoft Limited", by "R. T. Placeholder") is an invented ZX
Spectrum game. lock-keeper-faithful/ stands in for the owner's private faithful
clone: it embeds the original's messages and data table verbatim
(src/data.js), keeps the original BASIC listing in reference/, comments its
code with BASIC line numbers, and exposes newGame(seed), playGame(io, state,
best) and snapshot(state) for a parity harness. Its invented names are
Marrowdeep, Pellandine and "Lock Seven". `node --test` passes in it.
