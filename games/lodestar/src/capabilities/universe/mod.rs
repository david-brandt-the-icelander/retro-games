//! The universe: eight galaxies of 256 generated systems, their properties, names and
//! inhabitants (RULES A.3), distance, the nearest-system search and fuel range (RULES A.4), the
//! pure parts of choosing and reaching a destination (RULES A.5) and the charts' behaviour
//! (RULES A.6). The data (starting state, syllables, words and labels) come from GDD § 4.2 to
//! § 4.5. Nothing here draws a random number (RULES A.2.3).
//!
//! See `universe.md` beside this file for what is built.

mod chart;
mod galaxy;
mod names;
mod navigation;
mod system;

pub use chart::{
    galaxy_chart_point, galaxy_chart_range_radius, local_chart, local_chart_point,
    local_chart_range_radius, local_cursor_point, local_cursor_visible, Arrow, ChartCursor,
    HeldArrows, LocalChartEntry, FIRST_LABEL_ROW, LOCAL_CHART_CENTRE,
};
pub use galaxy::{Galaxy, Seed, GALAXIES, SYSTEMS};
pub use names::{
    economy_label, government_label, inhabitants, name, reach_name, BODIES, COLOURS, CREATURES,
    DEFAULT_SETTLERS, ECONOMIES, GOVERNMENTS, REACHES, SIZES, SYLLABLES,
};
pub use navigation::{
    distance, fuel_after_jump, in_range, is_misjump, misjump_position, reach_jump, select,
    Selection, MISJUMP_FROM, REACH_JUMP_CURSOR,
};
pub use system::{PlanetStyle, Point, System};
