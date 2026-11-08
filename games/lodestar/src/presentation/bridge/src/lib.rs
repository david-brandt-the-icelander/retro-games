//! The presentation's door into the sim. GDScript reaches the rules only through the classes
//! here, which convert to Godot types and do nothing else (docs/DESIGN.md § Project layout).

mod sim_host;

pub use sim_host::SimHost;
