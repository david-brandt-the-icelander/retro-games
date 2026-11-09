//! The chart cursor, the selected system and the current system (RULES A.5.1).

use super::countdown::Countdown;
use crate::capabilities::pilot::Pilot;
use crate::capabilities::universe::{ChartCursor, Galaxy, Selection, System};

/// Where the pilot is and where they are pointing: the chart cursor, the selected system with
/// its distance, and the current system. The tick keeps it beside the cockpit.
///
/// The current system is kept apart from the pilot's position because a mis-jump moves the
/// position and leaves the current system (its data and market) as it was (RULES A.5.5).
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Navigation {
    pub cursor: ChartCursor,
    /// The selected system and the distance measured when it was selected (RULES A.5.1).
    pub selected: Selection,
    /// The current system's number in the pilot's galaxy.
    pub current: u8,
}

impl Navigation {
    /// At game start, or when a pilot is loaded: the cursor on the pilot's position, selected
    /// from there, and that system current (RULES A.5.1).
    pub fn start(pilot: &Pilot) -> Self {
        let mut cursor = ChartCursor::at(pilot.position);
        let selected = cursor.select(galaxy(pilot), pilot.position);
        Self { cursor, selected, current: selected.system }
    }

    /// Selects from the cursor (RULES A.5.1): the system nearest the cursor, measured from the
    /// pilot, with the cursor snapped onto it. While a normal countdown runs, the new selection
    /// becomes its destination only when in range (deliberate difference 6). Every selection
    /// (the hyperspace key, the show-distance key, the system-data and status screens, launch,
    /// entering the docked state) goes through here.
    pub fn select(&mut self, pilot: &Pilot, countdown: &mut Countdown) -> Selection {
        self.selected = self.cursor.select(galaxy(pilot), pilot.position);
        countdown.retarget(self.selected, pilot.fuel);
        self.selected
    }

    /// The current system with all its properties.
    pub fn current_system(&self, pilot: &Pilot) -> System {
        galaxy(pilot).system(self.current)
    }
}

/// The pilot's galaxy, from its stored number and system-0 state.
pub fn galaxy(pilot: &Pilot) -> Galaxy {
    Galaxy::new(pilot.galaxy, pilot.galaxy_state)
}

#[cfg(test)]
mod tests {
    use super::super::countdown::Destination;
    use super::*;

    #[test]
    fn the_game_starts_at_home_with_home_selected() {
        let pilot = Pilot::start();
        let n = Navigation::start(&pilot);
        assert_eq!(n.cursor.position, (60, 93));
        assert_eq!(n.selected, Selection { system: 0, position: (60, 93), distance: 0 });
        assert_eq!(n.current, 0);
        assert_eq!(n.current_system(&pilot).position(), (60, 93));
    }

    #[test]
    fn selecting_snaps_the_cursor_and_retargets_only_within_range() {
        let mut pilot = Pilot::start();
        let mut n = Navigation::start(&pilot);
        let mut countdown = Countdown::new();
        // System 1 at (169, 242) is 52.4 LY from home (RULES A.4.1 worked in the universe
        // capability): far beyond a full tank.
        n.cursor.position = (168, 241);
        let s = n.select(&pilot, &mut countdown);
        assert_eq!((s.system, s.distance), (1, 524));
        assert_eq!(n.cursor.position, (169, 242));
        // During a countdown to home's neighbour, selecting system 1 changes the selection shown
        // but not the destination.
        let near = Selection { system: 9, position: (62, 98), distance: 20 };
        countdown.start(Destination::System(near));
        n.select(&pilot, &mut countdown);
        assert_eq!(n.selected.system, 1);
        assert_eq!(countdown.destination(), Some(Destination::System(near)));
        // From (165, 240) system 1 is in range: dx = 4, dy = 2 >> 1 = 1, q = 17, root 4,
        // distance 16. Now the destination follows.
        pilot.position = (165, 240);
        let s = n.select(&pilot, &mut countdown);
        assert_eq!((s.system, s.distance), (1, 16));
        assert_eq!(countdown.destination(), Some(Destination::System(s)));
    }
}
