//! LodeStar's rules, as `docs/RULES.md` states them.
//!
//! Layers point inward only: use cases depend on features and capabilities, features on
//! capabilities, and capabilities on nothing further out. `tests/layers.rs` enforces it.
//! Nothing here depends on Godot, so the same code runs in the game, in tests and, later,
//! in a server.

pub mod capabilities;
pub mod features;
pub mod use_cases;
