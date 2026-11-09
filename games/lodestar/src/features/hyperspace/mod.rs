//! Hyperspace: the selected system, the hyperspace and galaxy-drive keys, the countdown, the
//! jump and the arrival, including the mis-jump into the Deep (RULES A.5, B.16, C.16.6,
//! deliberate differences 5 and 6). The universe capability does the pure computations; this
//! feature holds the state between them and makes the draws in RULES' order. See
//! `hyperspace.md`.

mod countdown;
mod jump;
mod navigation;

pub use countdown::{Countdown, Destination, COUNTDOWN_START, COUNTDOWN_STEP, COUNTDOWN_TICKS};
pub use jump::{
    arrive, jump, press_galaxy_drive, press_hyperspace, Arrived, GalaxyDriveKey, HyperspaceKey, Tunnel,
    AMBUSH_DUST_DRAWS, AMBUSH_MOTHERSHIPS, TUNNEL_TICKS,
};
pub use navigation::{galaxy, Navigation};
