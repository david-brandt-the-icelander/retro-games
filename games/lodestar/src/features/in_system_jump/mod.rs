//! The in-system jump (RULES B.13): a leap of one far unit forward when nothing else is about
//! and no body is close ahead. See `in_system_jump.md`.

use crate::capabilities::bubble::Bubble;
use crate::capabilities::cockpit::Cockpit;
use crate::capabilities::ships::{self, ASTEROID, CANISTER, ESCAPE_POD, SUN};
use crate::capabilities::space::FAR;
use crate::features::spawning::SpawnDelay;

/// A body ahead closer than this on every axis blocks the jump: 2 L (RULES B.13 step 2).
pub const BLOCKING_RANGE: f64 = 2.0 * FAR;
/// The main counter after a jump: the tick's chores bring it to 0 and run the periodic spawn
/// at the end of the same tick (RULES B.13).
pub const COUNTER_AFTER_JUMP: u8 = 1;

/// What the in-system jump action did.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum InSystemJump {
    /// Refused, with the long "no" beep; nothing else happened.
    Refused,
    /// The planet and the sun came one far unit nearer. The lead clears the bottom line of the
    /// flight scene (the destination and out-of-range notices).
    Jumped,
}

/// The in-system jump action (RULES B.13). Refused when any ship, missile or drone is present
/// (counting as the baseline does, with two fixed slots taken off even in the Deep, RULES D.14
/// item 13), in the safe zone, in mis-jump space, or when the planet or the sun is ahead (z ≥ 0)
/// and within 2 L on every axis. Otherwise the planet's and sun's z fall by one far unit, other
/// objects stay where they are relative to the player (RULES B.23 Q-B17), C becomes 1, the spawn
/// delay 0, and every object's on-screen, on-scanner and firing flags are cleared as a view
/// selection does (RULES B.20). No fuel or energy cost, no limit on repeats.
pub fn in_system_jump(cockpit: &mut Cockpit, bubble: &mut Bubble, delay: &mut SpawnDelay) -> InSystemJump {
    let companions = [ASTEROID, ESCAPE_POD, CANISTER].map(|k| i32::from(bubble.count_of(k))).iter().sum::<i32>();
    let others = bubble.len() as i32 - 2 - companions;
    if others > 0 || cockpit.station_present || cockpit.misjump {
        return InSystemJump::Refused;
    }
    let bodies = bubble.iter().filter(|o| ships::is_planet(o.kind) || o.kind == SUN);
    for body in bodies {
        let p = body.position;
        let nearest = p.x.abs().max(p.y.abs()).max(p.z.abs());
        if p.z >= 0.0 && nearest < BLOCKING_RANGE {
            return InSystemJump::Refused;
        }
    }
    for object in bubble.iter_mut() {
        if ships::is_planet(object.kind) || object.kind == SUN {
            object.position.z -= FAR;
        }
        object.flags.on_screen = false;
        object.flags.on_scanner = false;
        object.flags.firing = false;
    }
    cockpit.counter = COUNTER_AFTER_JUMP;
    delay.reset();
    InSystemJump::Jumped
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::capabilities::bubble::Object;
    use crate::capabilities::ships::{MISSILE, PLANET_B, STATION, TRADER};
    use crate::capabilities::space::Vec3;

    fn system(planet: Vec3, sun: Vec3) -> Bubble {
        let mut b = Bubble::new();
        b.add(Object::new(PLANET_B, planet));
        b.add(Object::new(SUN, sun));
        b
    }

    #[test]
    fn a_jump_brings_the_bodies_one_far_unit_nearer() {
        let mut bubble = system(Vec3::new(0.0, 0.0, 5.0 * FAR), Vec3::new(FAR, 0.0, -3.0 * FAR));
        let mut rock = Object::new(ASTEROID, Vec3::new(10.0, 20.0, 300.0));
        rock.flags.on_screen = true;
        rock.flags.firing = true;
        bubble.add(rock);
        bubble.add(Object::new(CANISTER, Vec3::new(0.0, 0.0, 50.0)));
        bubble.add(Object::new(ESCAPE_POD, Vec3::new(0.0, 0.0, 60.0)));
        let mut cockpit = Cockpit::new();
        cockpit.counter = 77;
        let mut delay = SpawnDelay(3);
        assert_eq!(in_system_jump(&mut cockpit, &mut bubble, &mut delay), InSystemJump::Jumped);
        assert_eq!(bubble.get(0).unwrap().position, Vec3::new(0.0, 0.0, 4.0 * FAR));
        assert_eq!(bubble.get(1).unwrap().position, Vec3::new(FAR, 0.0, -4.0 * FAR));
        let rock = bubble.get(2).unwrap();
        assert_eq!(rock.position, Vec3::new(10.0, 20.0, 300.0), "companions travel along (Q-B17)");
        assert!(!rock.flags.on_screen && !rock.flags.firing);
        assert_eq!((cockpit.counter, delay), (1, SpawnDelay(0)));
        // C = 1, so the tick's chores bring it to 0 and spawn at the end of this same tick.
        assert!(cockpit.count_down_counter());
    }

    #[test]
    fn any_other_ship_refuses_the_jump() {
        for kind in [TRADER, MISSILE, 12] {
            let mut bubble = system(Vec3::new(0.0, 0.0, 5.0 * FAR), Vec3::new(0.0, 0.0, -5.0 * FAR));
            bubble.add(Object::new(kind, Vec3::new(0.0, 0.0, 9000.0)));
            let mut cockpit = Cockpit::new();
            cockpit.counter = 77;
            let before = bubble.clone();
            assert_eq!(in_system_jump(&mut cockpit, &mut bubble, &mut SpawnDelay(3)), InSystemJump::Refused);
            assert_eq!((bubble, cockpit.counter), (before, 77), "nothing else happens");
        }
    }

    #[test]
    fn the_safe_zone_and_the_deep_refuse_it() {
        let mut bubble = system(Vec3::new(0.0, 0.0, 5.0 * FAR), Vec3::new(0.0, 0.0, -5.0 * FAR));
        bubble.replace(1, Object::new(STATION, Vec3::new(0.0, 0.0, 30_000.0)));
        let mut cockpit = Cockpit::new();
        cockpit.station_present = true;
        assert_eq!(in_system_jump(&mut cockpit, &mut bubble, &mut SpawnDelay(0)), InSystemJump::Refused);
        // In the Deep, two alien ships are "minus 2" = 0 others, but the zone refuses anyway.
        let mut bubble = Bubble::new();
        bubble.add(Object::new(6, Vec3::new(0.0, 0.0, 9000.0)));
        bubble.add(Object::new(12, Vec3::new(0.0, 0.0, 9000.0)));
        let mut cockpit = Cockpit::new();
        cockpit.misjump = true;
        assert_eq!(in_system_jump(&mut cockpit, &mut bubble, &mut SpawnDelay(0)), InSystemJump::Refused);
    }

    #[test]
    fn a_body_close_ahead_blocks_and_one_behind_never_does() {
        let mut cockpit = Cockpit::new();
        // The planet ahead within 2 L on every axis: refused.
        let mut bubble = system(Vec3::new(1.9 * FAR, -1.9 * FAR, 1.9 * FAR), Vec3::new(0.0, 0.0, -5.0 * FAR));
        assert_eq!(in_system_jump(&mut cockpit, &mut bubble, &mut SpawnDelay(0)), InSystemJump::Refused);
        // z = 0 counts as ahead.
        let mut bubble = system(Vec3::new(0.0, 0.0, 0.0), Vec3::new(0.0, 0.0, -5.0 * FAR));
        assert_eq!(in_system_jump(&mut cockpit, &mut bubble, &mut SpawnDelay(0)), InSystemJump::Refused);
        // Exactly 2 L on one axis does not block.
        let mut bubble = system(Vec3::new(2.0 * FAR, 0.0, 0.5 * FAR), Vec3::new(0.0, 0.0, -5.0 * FAR));
        assert_eq!(in_system_jump(&mut cockpit, &mut bubble, &mut SpawnDelay(0)), InSystemJump::Jumped);
        // The sun close ahead blocks too.
        let mut bubble = system(Vec3::new(0.0, 0.0, 5.0 * FAR), Vec3::new(0.0, 0.0, 1.5 * FAR));
        assert_eq!(in_system_jump(&mut cockpit, &mut bubble, &mut SpawnDelay(0)), InSystemJump::Refused);
        // A body right behind (z < 0) never blocks.
        let mut bubble = system(Vec3::new(0.0, 0.0, -0.5 * FAR), Vec3::new(0.0, 0.0, -0.1 * FAR));
        assert_eq!(in_system_jump(&mut cockpit, &mut bubble, &mut SpawnDelay(0)), InSystemJump::Jumped);
    }
}
