//! Flight: the player's attitude and speed, and how every object in the bubble moves and turns
//! (RULES B.5 to B.8, and the rotation counters and ship speed of C.1).
//!
//! The player never moves: each substep the universe is carried past and rotated around the
//! origin. The knowledge document `flight.md` says which of these rules are built.

mod attitude;
mod motion;
mod speed;
mod tidy;

pub use attitude::{pitch_magnitude, roll_magnitude, Attitude, CENTRE, PITCH_STEP, RESET_ROLL_ANGLE, ROLL_STEP};
pub use motion::{move_substep, move_object, own_motion_tick, H, OWN_SPEED_FACTOR};
pub use speed::{apply_speed_keys, DEATH_SPEED, FAILED_DOCKING_SPEED, LAUNCH_SPEED, MAX_SPEED, MIN_KEY_SPEED, RESET_SPEED};
pub use tidy::{tidy, tidy_due, tidy_if_due};

/// The held flight keys, sampled once per tick (RULES B.5.2, B.6). Fire and the chart cursor are
/// held keys too, but other rules read them.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct HeldControls {
    pub roll_left: bool,
    pub roll_right: bool,
    pub climb: bool,
    pub dive: bool,
    pub speed_up: bool,
    pub slow_down: bool,
}

impl HeldControls {
    /// Nothing held; what the attitude sees while dying (RULES B.3.3 step 1).
    pub const NONE: HeldControls = HeldControls {
        roll_left: false,
        roll_right: false,
        climb: false,
        dive: false,
        speed_up: false,
        slow_down: false,
    };
}
