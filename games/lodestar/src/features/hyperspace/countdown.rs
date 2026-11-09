//! The hyperspace countdown and its destination (RULES A.5.4, B.16.2, deliberate differences 5
//! and 6).

use crate::capabilities::universe::{in_range, Selection};

/// Both of the countdown's values start here (RULES A.5.4).
pub const COUNTDOWN_START: u8 = 15;
/// Ticks per shown step after the first (RULES A.5.4).
pub const COUNTDOWN_STEP: u8 = 5;
/// Ticks from the key to the jump: 15 + 14 × 5 (RULES A.5.4).
pub const COUNTDOWN_TICKS: u32 = 85;

/// Where a countdown leads.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Destination {
    /// A normal jump to this system, charged this distance (RULES A.5.5).
    System(Selection),
    /// A galactic jump to the next galaxy (RULES A.5.7).
    NextGalaxy,
}

/// The hyperspace countdown: a shown value and an inner frame counter, and where it leads. The
/// tick keeps it beside the cockpit. The flight-state reset does not touch it; docking, entering
/// the docked state, death (deliberate difference 5) and the return to the title cancel it.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct Countdown {
    inner: u8,
    shown: u8,
    destination: Option<Destination>,
}

impl Countdown {
    /// No countdown running.
    pub const fn new() -> Self {
        Self { inner: 0, shown: 0, destination: None }
    }

    /// Starts counting down to `destination`: both values 15.
    pub fn start(&mut self, destination: Destination) {
        self.inner = COUNTDOWN_START;
        self.shown = COUNTDOWN_START;
        self.destination = Some(destination);
    }

    /// True while the shown value is not 0.
    pub fn running(&self) -> bool {
        self.shown != 0
    }

    /// The value shown in the corner, 15..1, or 0 when none is running (RULES D.9.2 N5).
    pub fn shown(&self) -> u8 {
        self.shown
    }

    /// Where the running countdown leads.
    pub fn destination(&self) -> Option<Destination> {
        self.destination.filter(|_| self.running())
    }

    /// Stops the countdown: both values 0 (RULES A.5.4, D.3.2).
    pub fn cancel(&mut self) {
        *self = Self::new();
    }

    /// A new selection during a normal countdown (RULES A.14 item 3, deliberate difference 6):
    /// it becomes the destination only when it is in range of `fuel` (`0 < distance ≤ fuel`, so
    /// the current system never is); otherwise the old destination and distance stay. Returns
    /// true when the destination changed. A galactic countdown ignores selections.
    pub fn retarget(&mut self, selection: Selection, fuel: u8) -> bool {
        match self.destination() {
            Some(Destination::System(_)) if in_range(selection.distance, fuel) => {
                self.destination = Some(Destination::System(selection));
                true
            }
            _ => false,
        }
    }

    /// One flight tick (RULES A.5.4, B.16.2): when running, the inner counter falls by 1; on
    /// reaching 0 it goes back to 5 and the shown value falls by 1. Returns the destination on
    /// the tick the shown value reaches 0, which is when the jump happens.
    pub fn tick(&mut self) -> Option<Destination> {
        if !self.running() {
            return None;
        }
        self.inner -= 1;
        if self.inner > 0 {
            return None;
        }
        self.inner = COUNTDOWN_STEP;
        self.shown -= 1;
        if self.shown > 0 {
            return None;
        }
        let destination = self.destination;
        self.cancel();
        destination
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const NEAR: Selection = Selection { system: 7, position: (62, 98), distance: 20 };

    #[test]
    fn the_jump_comes_85_ticks_after_the_key() {
        let mut c = Countdown::new();
        assert_eq!(c.tick(), None, "idle");
        c.start(Destination::System(NEAR));
        let mut shown = Vec::new();
        for tick in 1..COUNTDOWN_TICKS {
            assert_eq!(c.tick(), None, "tick {tick}");
            shown.push(c.shown());
        }
        assert_eq!(c.tick(), Some(Destination::System(NEAR)));
        assert!(!c.running());
        assert_eq!(c.destination(), None);
        // 15 for the first 14 ticks after the key's own, then 14 on tick 15; each of 14..1 for
        // 5 ticks.
        assert_eq!(shown[13], 15);
        assert_eq!(shown[14], 14);
        assert_eq!(shown[18], 14);
        assert_eq!(shown[19], 13);
        assert_eq!(shown[83], 1);
        assert_eq!(c.tick(), None, "and then nothing");
    }

    #[test]
    fn cancelling_clears_both_values() {
        let mut c = Countdown::new();
        c.start(Destination::NextGalaxy);
        c.tick();
        c.cancel();
        assert_eq!((c.running(), c.shown(), c.destination()), (false, 0, None));
        for _ in 0..100 {
            assert_eq!(c.tick(), None);
        }
    }

    #[test]
    fn retargeting_is_range_checked() {
        let mut c = Countdown::new();
        assert!(!c.retarget(NEAR, 70), "no countdown, no destination to change");
        c.start(Destination::System(NEAR));
        let farther = Selection { system: 9, position: (80, 93), distance: 68 };
        assert!(c.retarget(farther, 70));
        assert_eq!(c.destination(), Some(Destination::System(farther)));
        // Beyond the fuel: the destination and its distance stay.
        let too_far = Selection { system: 4, position: (120, 93), distance: 72 };
        assert!(!c.retarget(too_far, 70));
        assert_eq!(c.destination(), Some(Destination::System(farther)));
        // The current system (distance 0) is never in range.
        let here = Selection { system: 0, position: (60, 93), distance: 0 };
        assert!(!c.retarget(here, 70));
        assert_eq!(c.destination(), Some(Destination::System(farther)));
        // A galactic countdown ignores selections.
        c.start(Destination::NextGalaxy);
        assert!(!c.retarget(NEAR, 70));
        assert_eq!(c.destination(), Some(Destination::NextGalaxy));
    }
}
