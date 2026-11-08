//! The GDExtension entry point Godot loads (lodestar.gdextension). It registers the bridge's
//! classes; the game's scenes and scripts do the rest.

use godot::prelude::*;

pub use lodestar_bridge::SimHost;

struct LodeStarExtension;

#[gdextension]
unsafe impl ExtensionLibrary for LodeStarExtension {}
