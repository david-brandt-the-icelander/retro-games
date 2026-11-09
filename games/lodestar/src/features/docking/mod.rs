//! Docking: when it is checked and its four checks (RULES B.12.1, B.12.2), the auto-dock
//! (B.12.3), and docking itself with the entry into the docked state (B.12.4, D.3.2, D.3.11).
//! What a failed docking does to the player is the combat rules' (C.11). See `docking.md`.

use crate::capabilities::bubble::{Bubble, Object};
use crate::capabilities::cockpit::Cockpit;
use crate::capabilities::pilot::Pilot;
use crate::capabilities::random::MainGenerator;
use crate::capabilities::ships::STATION;
use crate::capabilities::universe::Selection;
use crate::features::hyperspace::{Countdown, Navigation};

/// The box around the station's centre inside which docking is checked: every |coordinate|ᵢ
/// below 128 sim units (RULES B.12.1).
pub const DOCKING_BOX: f64 = 128.0;
/// Check 2: the station's nose z-component at most −86/96 (RULES B.12.2).
pub const SLOT_FACING: f64 = -86.0 / 96.0;
/// Check 3: the z-component of the unit vector to the station at least 89/96 (RULES B.12.2).
pub const DEAD_AHEAD: f64 = 89.0 / 96.0;
/// Check 4: the station's roof x-component at least 80/96 in size (RULES B.12.2).
pub const SLOT_LEVEL: f64 = 80.0 / 96.0;
/// Below this speed a failed docking only bumps the player (RULES B.12.2); the combat rules act
/// on it.
pub const FATAL_DOCKING_SPEED: u8 = 5;
/// Ticks the docking tunnel lasts (RULES B.12.4, D.3.4).
pub const DOCKING_TUNNEL_TICKS: u8 = 16;

/// What the station's proximity step found (RULES B.12.1, B.12.2).
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum DockingContact {
    /// The player is not in the station's docking box, or the station is exploding or killed.
    OutOfBox,
    /// In the box and all four checks pass: dock.
    Docks,
    /// In the box and a check fails: the combat rules crash or bump the player.
    Fails,
}

/// The station's proximity step (RULES B.3.4 step 6, B.12.1): in its docking box, the four
/// checks decide. The tick calls this for the station only.
pub fn docking_contact(station: &Object) -> DockingContact {
    let in_box = station.position.components().into_iter().all(|v| v.abs() < DOCKING_BOX);
    if !in_box || station.flags.exploding || station.flags.killed {
        DockingContact::OutOfBox
    } else if docking_checks_pass(station) {
        DockingContact::Docks
    } else {
        DockingContact::Fails
    }
}

/// The four checks of RULES B.12.2, on the vectors as stored, along the player's forward axis
/// whatever mount is active: the station is not hostile; its slot faces the player; it is
/// nearly dead ahead; its slot is level with the player's wings. At the station's exact centre
/// there is no direction to it, and check 3 fails.
pub fn docking_checks_pass(station: &Object) -> bool {
    let friendly = station.ai & 0x80 == 0;
    let facing = station.nose.z <= SLOT_FACING;
    let length = station.position.length();
    let ahead = length > 0.0 && station.position.z / length >= DEAD_AHEAD;
    let level = station.roof.x.abs() >= SLOT_LEVEL;
    friendly && facing && ahead && level
}

/// The auto-dock action (RULES B.12.3): succeeds when the auto-dock is fitted, the station is
/// present and not hostile, and then docks at once from anywhere in the safe zone. On success
/// the tick's later queued actions and the laser are skipped, and the lead calls [`dock`];
/// otherwise nothing happens.
pub fn auto_dock(pilot: &Pilot, cockpit: &Cockpit, bubble: &Bubble) -> bool {
    pilot.fitted.auto_dock
        && cockpit.station_present
        && bubble.iter().any(|o| o.kind == STATION && o.ai & 0x80 == 0)
}

/// Docking (RULES B.12.4, D.3.11): the countdown is cancelled and the docking tunnel starts; the
/// rest of the tick still runs (RULES B.23 Q-B13). After the 16 tunnel ticks the lead calls
/// [`finish_docking`].
pub fn dock(countdown: &mut Countdown) {
    countdown.cancel();
}

/// The docking tunnel's completion (RULES D.3.4): the flight state is reset (54 draws) with the
/// bubble emptied, and the player enters the docked state. The market is not changed.
pub fn finish_docking(
    pilot: &Pilot,
    cockpit: &mut Cockpit,
    bubble: &mut Bubble,
    navigation: &mut Navigation,
    countdown: &mut Countdown,
    random: &mut MainGenerator,
) -> Selection {
    cockpit.reset(random);
    bubble.clear();
    enter_docked(pilot, navigation, countdown)
}

/// Entering the docked state (RULES D.3.2), after docking and after the escape pod: the
/// countdown is cleared, and the status screen first selects from the cursor. Returns that
/// selection. The mode becomes Docked, on the status screen.
pub fn enter_docked(pilot: &Pilot, navigation: &mut Navigation, countdown: &mut Countdown) -> Selection {
    countdown.cancel();
    navigation.select(pilot, countdown)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::capabilities::space::Vec3;
    use crate::features::hyperspace::Destination;
    use crate::features::station::new_station;

    /// A station dead ahead, slot facing the player, level with the wings.
    fn lined_up(position: Vec3) -> Object {
        new_station(position, Vec3::new(0.0, 0.0, -1.0), Vec3::new(1.0, 0.0, 0.0), Vec3::new(0.0, 1.0, 0.0))
    }

    #[test]
    fn docking_is_checked_only_inside_the_128_box() {
        assert_eq!(docking_contact(&lined_up(Vec3::new(0.0, 0.0, 100.0))), DockingContact::Docks);
        assert_eq!(docking_contact(&lined_up(Vec3::new(0.0, 0.0, 127.9))), DockingContact::Docks);
        assert_eq!(docking_contact(&lined_up(Vec3::new(0.0, 0.0, 128.0))), DockingContact::OutOfBox);
        assert_eq!(docking_contact(&lined_up(Vec3::new(0.0, -128.0, 100.0))), DockingContact::OutOfBox);
        let mut exploding = lined_up(Vec3::new(0.0, 0.0, 100.0));
        exploding.flags.exploding = true;
        assert_eq!(docking_contact(&exploding), DockingContact::OutOfBox);
        let mut killed = lined_up(Vec3::new(0.0, 0.0, 100.0));
        killed.flags.killed = true;
        assert_eq!(docking_contact(&killed), DockingContact::OutOfBox);
    }

    #[test]
    fn each_check_at_its_threshold() {
        let ok = lined_up(Vec3::new(0.0, 0.0, 100.0));
        assert!(docking_checks_pass(&ok));
        // 1: hostile.
        let mut s = ok;
        s.ai |= 0x80;
        assert!(!docking_checks_pass(&s));
        assert_eq!(docking_contact(&s), DockingContact::Fails);
        // 2: nose z at −86/96 passes, a little above fails.
        let mut s = ok;
        s.nose = Vec3::new(0.0, 0.0, -86.0 / 96.0);
        assert!(docking_checks_pass(&s));
        s.nose.z = -0.895;
        assert!(!docking_checks_pass(&s));
        // 3: the direction to the station must be within about 22° of straight ahead.
        let mut s = ok;
        s.position = Vec3::new(40.0, 0.0, 89.0);
        assert!(!docking_checks_pass(&s), "89 / √(89² + 40²) ≈ 0.912");
        s.position = Vec3::new(30.0, 0.0, 89.0);
        assert!(docking_checks_pass(&s), "89 / √(89² + 30²) ≈ 0.948");
        // Behind the player: fails.
        s.position = Vec3::new(0.0, 0.0, -50.0);
        assert!(!docking_checks_pass(&s));
        // At the very centre: no direction, fails.
        s.position = Vec3::ZERO;
        assert!(!docking_checks_pass(&s));
        // 4: |roof x| at 80/96 passes either way up; below fails.
        let mut s = ok;
        s.roof = Vec3::new(-80.0 / 96.0, 0.5, 0.0);
        assert!(docking_checks_pass(&s));
        s.roof.x = 0.83;
        assert!(!docking_checks_pass(&s));
    }

    #[test]
    fn the_auto_dock_needs_the_unit_and_a_friendly_station() {
        let mut pilot = Pilot::start();
        let mut cockpit = Cockpit::new();
        let mut bubble = Bubble::new();
        bubble.add(Object::new(128, Vec3::ZERO));
        bubble.add(lined_up(Vec3::new(0.0, 0.0, 30_000.0)));
        cockpit.station_present = true;
        assert!(!auto_dock(&pilot, &cockpit, &bubble), "not fitted");
        pilot.fitted.auto_dock = true;
        assert!(auto_dock(&pilot, &cockpit, &bubble), "from anywhere in the safe zone");
        bubble.get_mut(1).unwrap().ai |= 0x80;
        assert!(!auto_dock(&pilot, &cockpit, &bubble), "hostile");
        bubble.get_mut(1).unwrap().ai = 1;
        cockpit.station_present = false;
        assert!(!auto_dock(&pilot, &cockpit, &bubble), "no safe zone");
    }

    #[test]
    fn docking_cancels_the_countdown_and_the_tunnel_ends_docked() {
        let mut pilot = Pilot::start();
        pilot.market_byte = 77;
        let before = pilot.clone();
        let mut nav = Navigation::start(&pilot);
        nav.cursor.position = (170, 243);
        let mut countdown = Countdown::new();
        countdown.start(Destination::NextGalaxy);
        dock(&mut countdown);
        assert!(!countdown.running());
        let mut cockpit = Cockpit::new();
        cockpit.counter = 40;
        cockpit.station_present = true;
        let mut bubble = Bubble::new();
        bubble.add(lined_up(Vec3::ZERO));
        let mut random = MainGenerator::new();
        let s = finish_docking(&pilot, &mut cockpit, &mut bubble, &mut nav, &mut countdown, &mut random);
        assert_eq!(s.system, 1, "the status screen selects from the cursor");
        assert!(bubble.is_empty() && !cockpit.station_present);
        assert_eq!(cockpit.counter, 0);
        let mut expected = MainGenerator::new();
        expected.discard(54);
        assert_eq!(random, expected);
        assert_eq!(pilot, before, "the market is not changed");
    }

    #[test]
    fn entering_the_docked_state_clears_a_countdown_before_selecting() {
        let pilot = Pilot::start();
        let mut nav = Navigation::start(&pilot);
        let mut countdown = Countdown::new();
        countdown.start(Destination::NextGalaxy);
        enter_docked(&pilot, &mut nav, &mut countdown);
        assert_eq!(countdown, Countdown::new());
    }
}
