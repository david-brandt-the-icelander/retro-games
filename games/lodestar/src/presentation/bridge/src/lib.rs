//! The presentation's door into the sim. GDScript reaches the rules only through the classes
//! here, which convert to Godot types and do nothing else (docs/DESIGN.md § Project layout).
//! `views` works the readouts out in plain Rust; `SimHost` converts them and runs the clock.

mod sim_host;
pub mod views;

pub use sim_host::SimHost;
