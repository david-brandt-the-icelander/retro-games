//! The station and its safe zone: the station appearing near the planet (RULES B.11.1), leaving
//! for distance and the sun taking its slot back (B.9.4), the removal-for-distance test, and the
//! launch scene (B.10.2, D.3.4). See `station.md`.

use crate::capabilities::bubble::{Bubble, Object};
use crate::capabilities::cockpit::{Cockpit, Message};
use crate::capabilities::combat;
use crate::capabilities::flight::LAUNCH_SPEED;
use crate::capabilities::pilot::Pilot;
use crate::capabilities::random::MainGenerator;
use crate::capabilities::ships::{self, STATION, SUN};
use crate::capabilities::space::{coarse, far, SignMagnitude, Vec3, FAR};
use crate::capabilities::universe::Selection;
use crate::features::hyperspace::{Countdown, Navigation};
use crate::features::planet_and_sun::new_planet;

/// The slot the station and the sun share (RULES B.9.1).
pub const STATION_SLOT: usize = 1;
/// How far out along the planet's nose the station appears: twice the planet's radius of 24576
/// sim units (RULES B.11.1). It is also the limit on each of the station's coordinates.
pub const STATION_ORBIT: f64 = 49_152.0;
/// The coarse value above which an object is too far and is removed (RULES B.9.4).
pub const TOO_FAR_COARSE: u8 = 224;
/// Where the sun reappears when the station leaves: (0, 6 L, 0) (RULES B.9.4).
pub const SUN_RETURN: Vec3 = Vec3::new(0.0, 6.0 * FAR, 0.0);
/// The station's AI byte: E.C.M. fitted, AI off, friendly (RULES B.11.1).
pub const STATION_AI: u8 = 1;
/// The station's roll counter: magnitude 127, negative, for ever (RULES B.11.1).
pub const STATION_ROLL: SignMagnitude = SignMagnitude(0xFF);
/// The launch scene: the planet a far unit ahead and the station 256 sim units behind
/// (RULES B.10.2).
pub const LAUNCH_PLANET: Vec3 = Vec3::new(0.0, 0.0, FAR);
pub const LAUNCH_STATION: Vec3 = Vec3::new(0.0, 0.0, -256.0);

/// A station at `position` with the given orientation, AI byte 1, pitch 0 and roll 0xFF
/// (RULES B.11.1). The side is copied as given, so the frame may be left-handed until the first
/// re-orthonormalisation (RULES B.23 Q-B9).
pub fn new_station(position: Vec3, nose: Vec3, roof: Vec3, side: Vec3) -> Object {
    let mut station = Object::new(STATION, position);
    station.nose = nose;
    station.roof = roof;
    station.side = side;
    station.ai = STATION_AI;
    station.pitch = SignMagnitude::ZERO;
    station.roll = STATION_ROLL;
    station
}

/// RULES B.3.3 step 5 and B.11.1: on ticks where C mod 32 = 0, outside mis-jump space, with no
/// station present and a planet in slot 0, the station appears 49152 sim units out along the
/// planet's nose as stored, unless the planet or that point is too far. It replaces the sun in
/// slot 1 and the player is in the safe zone. Returns true when it appeared. No random draws.
pub fn station_appearance(cockpit: &mut Cockpit, bubble: &mut Bubble) -> bool {
    if !cockpit.counter.is_multiple_of(32) || cockpit.misjump || cockpit.station_present {
        return false;
    }
    let Some(planet) = bubble.get(0).filter(|o| ships::is_planet(o.kind)).copied() else {
        return false;
    };
    if planet.position.components().into_iter().any(far) {
        return false;
    }
    let point = planet.position + planet.nose * STATION_ORBIT;
    if point.components().into_iter().any(|v| v.abs() >= STATION_ORBIT) {
        return false;
    }
    let station = new_station(point, -planet.nose, planet.roof, planet.side);
    if bubble.replace(STATION_SLOT, station).is_none() {
        return false;
    }
    cockpit.station_present = true;
    true
}

/// The removal-for-distance test (RULES B.9.4, C.4 step 8): a non-body object with any
/// coordinate of a far unit or more, or with a coarse value above 224 (57600 sim units or
/// more). Bodies are never removed for distance.
pub fn too_far(object: &Object) -> bool {
    !object.is_body() && object.position.components().into_iter().any(|v| far(v) || coarse(v) > TOO_FAR_COARSE)
}

/// What the station leaving did.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct StationLeft {
    /// The player's missile lock was on the station and was lost (the target-lost message is
    /// shown).
    pub target_lost: bool,
}

/// The station removed for distance (RULES B.9.4): it is not shifted out; a new sun takes slot 1
/// at (0, 6 L, 0) with the default orientation and counters 0, the player leaves the safe zone,
/// and the missile lock is adjusted as if slot 1 were removed: lost (with message M6) when on
/// slot 1, moved down one when on a later slot, though nothing shifted (RULES B.23 Q-B5). Homing
/// missiles are not retargeted. The tick then processes slot 1, now the sun, again.
pub fn station_leaves(cockpit: &mut Cockpit, bubble: &mut Bubble) -> StationLeft {
    bubble.replace(STATION_SLOT, Object::new(SUN, SUN_RETURN));
    cockpit.station_present = false;
    let target_lost = cockpit.missile.on_removed(STATION_SLOT);
    if target_lost {
        cockpit.show(Message::TargetLost);
    }
    StationLeft { target_lost }
}

/// The launch tunnel's completion (RULES D.3.4, B.10.2): reset the flight state (54 draws) with
/// an empty bubble; select from the cursor; the planet (in the current system's style) a far
/// unit ahead and the station 256 sim units behind, facing away, with the player in the safe
/// zone; speed 12; legal status OR the contraband score (RULES A.14 item 20); the front mount
/// active. Returns the selection, for the screens. The mode becomes Flight.
pub fn launch(
    pilot: &mut Pilot,
    cockpit: &mut Cockpit,
    bubble: &mut Bubble,
    navigation: &mut Navigation,
    countdown: &mut Countdown,
    random: &mut MainGenerator,
) -> Selection {
    cockpit.reset(random);
    bubble.clear();
    let selection = navigation.select(pilot, countdown);
    let style = navigation.current_system(pilot).planet_style().object_type();
    bubble.add(new_planet(style, LAUNCH_PLANET));
    bubble.add(new_station(
        LAUNCH_STATION,
        Vec3::new(0.0, 0.0, 1.0),
        Vec3::new(0.0, 1.0, 0.0),
        Vec3::new(1.0, 0.0, 0.0),
    ));
    cockpit.station_present = true;
    cockpit.speed = LAUNCH_SPEED;
    combat::on_launch(pilot);
    cockpit.active_mount = 0;
    selection
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::capabilities::cockpit::MissileLock;
    use crate::capabilities::ships::{CANISTER, PLANET_A, POLICE};

    fn system(planet: Vec3, nose: Vec3) -> Bubble {
        let mut b = Bubble::new();
        let mut p = new_planet(PLANET_A, planet);
        p.nose = nose;
        p.roof = Vec3::new(0.0, 0.5, 0.0);
        p.side = Vec3::new(0.25, 0.0, 0.0);
        b.add(p);
        b.add(Object::new(SUN, Vec3::new(0.0, 0.0, -FAR)));
        b
    }

    #[test]
    fn the_station_appears_two_radii_out_along_the_planets_nose() {
        // Planet 100 K ahead, nose (0, 0, −1): Q = (0, 0, 25600 − 49152) = (0, 0, −23552).
        let mut bubble = system(Vec3::new(0.0, 0.0, 25_600.0), Vec3::new(0.0, 0.0, -1.0));
        let mut cockpit = Cockpit::new();
        assert!(station_appearance(&mut cockpit, &mut bubble));
        assert!(cockpit.station_present);
        let s = bubble.get(1).unwrap();
        assert_eq!(s.kind, STATION);
        assert_eq!(s.position, Vec3::new(0.0, 0.0, -23_552.0));
        assert_eq!(s.nose, Vec3::new(0.0, 0.0, 1.0), "the slot faces the planet");
        assert_eq!((s.roof, s.side), (Vec3::new(0.0, 0.5, 0.0), Vec3::new(0.25, 0.0, 0.0)), "copied as stored");
        assert_eq!((s.ai, s.pitch, s.roll), (1, SignMagnitude::ZERO, SignMagnitude(0xFF)));
        assert_eq!((bubble.count_of(STATION), bubble.len()), (1, 2), "the sun is gone");
        assert!(bubble.iter().all(|o| o.kind != SUN));
    }

    #[test]
    fn a_shrunken_planet_nose_puts_the_station_closer() {
        // RULES B.23 Q-B1: the nose as stored, here half length: Q = 25600 − 24576 = 1024.
        let mut bubble = system(Vec3::new(0.0, 0.0, 25_600.0), Vec3::new(0.0, 0.0, -0.5));
        let mut cockpit = Cockpit::new();
        assert!(station_appearance(&mut cockpit, &mut bubble));
        assert_eq!(bubble.get(1).unwrap().position, Vec3::new(0.0, 0.0, 1024.0));
    }

    #[test]
    fn the_station_waits_for_its_tick_and_a_close_enough_point() {
        let near = Vec3::new(0.0, 0.0, 25_600.0);
        let mut cockpit = Cockpit::new();
        // Not on a C mod 32 = 0 tick.
        cockpit.counter = 31;
        let mut bubble = system(near, Vec3::new(0.0, 0.0, -1.0));
        assert!(!station_appearance(&mut cockpit, &mut bubble));
        cockpit.counter = 224;
        // In mis-jump space, or with a station present: nothing.
        cockpit.misjump = true;
        assert!(!station_appearance(&mut cockpit, &mut bubble));
        cockpit.misjump = false;
        cockpit.station_present = true;
        assert!(!station_appearance(&mut cockpit, &mut bubble));
        cockpit.station_present = false;
        // The point must be within 49152 on every axis: nose (0, 0, 1) puts it at 74752.
        let mut bubble = system(near, Vec3::new(0.0, 0.0, 1.0));
        assert!(!station_appearance(&mut cockpit, &mut bubble));
        // The planet a far unit away on any axis: nothing, wherever the point would be.
        let mut bubble = system(Vec3::new(FAR, 0.0, 0.0), Vec3::new(-1.0, 0.0, 0.0));
        assert!(!station_appearance(&mut cockpit, &mut bubble));
        // No planet in slot 0 (as in mis-jump space): nothing.
        let mut bubble = Bubble::new();
        bubble.add(Object::new(CANISTER, Vec3::ZERO));
        bubble.add(Object::new(CANISTER, Vec3::ZERO));
        assert!(!station_appearance(&mut cockpit, &mut bubble));
        assert!(!cockpit.station_present);
        // At last: on tick 224 with the point close enough.
        let mut bubble = system(near, Vec3::new(0.0, 0.0, -1.0));
        assert!(station_appearance(&mut cockpit, &mut bubble));
    }

    #[test]
    fn too_far_at_57600_or_a_far_unit() {
        let at = |x: f64| Object::new(POLICE, Vec3::new(0.0, x, 0.0));
        assert!(!too_far(&at(57_599.9)));
        assert!(too_far(&at(57_600.0)));
        assert!(too_far(&at(-57_600.0)));
        assert!(too_far(&at(65_536.0)), "coarse wraps to 0 there, but far() catches it");
        assert!(too_far(&at(200_000.0)));
        assert!(!too_far(&new_planet(PLANET_A, Vec3::new(0.0, 0.0, 9.0 * FAR))), "bodies stay");
        assert!(!too_far(&Object::new(SUN, Vec3::new(0.0, 0.0, -7.0 * FAR))));
    }

    #[test]
    fn the_sun_takes_slot_1_back_when_the_station_leaves() {
        let mut bubble = system(Vec3::new(0.0, 0.0, 25_600.0), Vec3::new(0.0, 0.0, -1.0));
        let mut cockpit = Cockpit::new();
        station_appearance(&mut cockpit, &mut bubble);
        bubble.add(Object::new(POLICE, Vec3::ZERO));
        bubble.add(Object::new(CANISTER, Vec3::ZERO));
        cockpit.missile = MissileLock { armed: false, target: Some(3) };
        let left = station_leaves(&mut cockpit, &mut bubble);
        assert_eq!(left, StationLeft { target_lost: false });
        assert!(!cockpit.station_present);
        let sun = bubble.get(1).unwrap();
        assert_eq!((sun.kind, sun.position), (SUN, Vec3::new(0.0, 6.0 * FAR, 0.0)));
        assert_eq!((sun.pitch, sun.roll), (SignMagnitude::ZERO, SignMagnitude::ZERO));
        assert_eq!(bubble.get(3).unwrap().kind, CANISTER, "nothing shifted");
        assert_eq!(cockpit.missile.target, Some(2), "Q-B5: the lock moves down anyway");
        assert_eq!(bubble.count_of(STATION), 0);
        // A lock on the station itself is lost, with the message.
        station_appearance(&mut cockpit, &mut bubble);
        cockpit.missile = MissileLock { armed: false, target: Some(1) };
        assert_eq!(station_leaves(&mut cockpit, &mut bubble), StationLeft { target_lost: true });
        assert_eq!((cockpit.missile.target, cockpit.message), (None, Some(Message::TargetLost)));
    }

    #[test]
    fn launching_builds_the_safe_zone_scene() {
        let mut pilot = Pilot::start();
        pilot.cargo[3] = 1;
        pilot.legal = 64;
        let mut cockpit = Cockpit::new();
        cockpit.active_mount = 2;
        cockpit.counter = 99;
        let mut bubble = Bubble::new();
        bubble.add(Object::new(POLICE, Vec3::ZERO));
        let mut navigation = Navigation::start(&pilot);
        navigation.cursor.position = (170, 243);
        let mut countdown = Countdown::new();
        let mut random = MainGenerator::new();
        let selection = launch(&mut pilot, &mut cockpit, &mut bubble, &mut navigation, &mut countdown, &mut random);
        let mut expected = MainGenerator::new();
        expected.discard(54);
        assert_eq!(random, expected, "the reset's 54 draws, nothing more");
        assert_eq!(selection.system, 1, "selected from the cursor");
        assert_eq!(navigation.cursor.position, (169, 242));
        assert_eq!(bubble.len(), 2);
        let planet = bubble.get(0).unwrap();
        assert_eq!(planet.position, Vec3::new(0.0, 0.0, FAR));
        assert_eq!(planet.kind, navigation.current_system(&pilot).planet_style().object_type());
        assert_eq!((planet.pitch.0, planet.roll.0), (127, 127));
        let station = bubble.get(1).unwrap();
        assert_eq!(station.position, Vec3::new(0.0, 0.0, -256.0));
        assert_eq!(station.nose, Vec3::new(0.0, 0.0, 1.0));
        assert_eq!((station.ai, station.roll), (1, SignMagnitude(0xFF)));
        assert!(cockpit.station_present);
        assert_eq!((cockpit.speed, cockpit.counter, cockpit.active_mount), (12, 0, 0));
        assert_eq!(pilot.legal, 64 | 2, "OR-ed with the contraband score");
    }
}
