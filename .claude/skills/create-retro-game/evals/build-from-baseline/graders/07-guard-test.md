---
type: llm
focus: trace
weight: 1
---

games/canal-lock/test has a guard test that stores SHA-256 (or similar) hashes of the original's normalised strings, not the strings themselves, and fails if any player-facing string of the remake hashes to one of them; the test runs and passes
