//! Launching a child ship: police from the station, an escape pod, a missile, a drone, a canister
//! (RULES C.5.7, B.10.6).

use crate::capabilities::bubble::{Bubble, Object};
use crate::capabilities::random::MainGenerator;
use crate::capabilities::ships::{TypeNumber, CANISTER, STATION};
use crate::capabilities::space::SignMagnitude;

/// A child of the station starts this far along the station's nose, in sim units.
pub const STATION_LAUNCH_DISTANCE: f64 = 192.0;
/// A child of the station starts at this speed.
pub const STATION_LAUNCH_SPEED: u8 = 32;
/// The roll counter's bit 0 is cleared on every child.
const ROLL_KEEP: u8 = 0xFE;

/// Launches a child of `kind` from `parent` with AI byte `ai` (RULES C.5.7). The child copies
/// the parent's position, orientation, speed and both counters and starts with its own type's
/// full energy and missiles; a child of the station starts 192 units along the station's nose
/// (as stored) at speed 32; the roll counter loses bit 0. A canister then draws a pair (A, X):
/// pitch counter (A × 2) AND 255, speed X AND 15, roll counter 127 with the sign of A's top bit.
///
/// Returns the child's slot, or `None` when the bubble is full; any draw made stays drawn.
pub fn launch_child(
    bubble: &mut Bubble,
    parent: &Object,
    kind: TypeNumber,
    ai: u8,
    random: &mut MainGenerator,
) -> Option<usize> {
    let mut child = Object::new(kind, parent.position);
    child.nose = parent.nose;
    child.roof = parent.roof;
    child.side = parent.side;
    child.speed = parent.speed;
    child.pitch = parent.pitch;
    child.roll = parent.roll;
    if parent.kind == STATION {
        child.speed = STATION_LAUNCH_SPEED;
        child.position += parent.nose * STATION_LAUNCH_DISTANCE;
    }
    child.ai = ai;
    child.roll = SignMagnitude(child.roll.0 & ROLL_KEEP);
    if kind == CANISTER {
        let spin = random.draw();
        child.pitch = SignMagnitude(spin.a.wrapping_mul(2));
        child.speed = spin.x & 15;
        child.roll = SignMagnitude::new(spin.a >= 0x80, SignMagnitude::FOREVER);
    }
    bubble.add(child)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::capabilities::ai::test_support::next_draw;
    use crate::capabilities::ships::{CANISTER, ESCAPE_POD, HEAVY_FIGHTER, MISSILE, POLICE, SUN};
    use crate::capabilities::space::Vec3;

    fn parent() -> Object {
        let mut p = Object::new(HEAVY_FIGHTER, Vec3::new(100.0, -200.0, 3000.0));
        p.nose = Vec3::new(0.0, 0.6, 0.8);
        p.roof = Vec3::new(0.0, 0.8, -0.6);
        p.side = Vec3::new(1.0, 0.0, 0.0);
        p.speed = 20;
        p.pitch = SignMagnitude::new(true, 3);
        p.roll = SignMagnitude(0x85);
        p.energy = 3;
        p.missiles = 1;
        p.ai = 0xC1;
        p.acceleration = 3;
        p.flags.killed = true;
        p
    }

    #[test]
    fn a_child_copies_its_parent_and_takes_its_own_type() {
        let mut bubble = Bubble::new();
        let mut random = MainGenerator::new();
        let slot = launch_child(&mut bubble, &parent(), MISSILE, 0xFE, &mut random).unwrap();
        let c = bubble.get(slot).unwrap();
        assert_eq!(c.kind, MISSILE);
        assert_eq!(c.position, Vec3::new(100.0, -200.0, 3000.0));
        assert_eq!((c.nose, c.roof, c.side), (parent().nose, parent().roof, parent().side));
        assert_eq!(c.speed, 20);
        assert_eq!(c.pitch, SignMagnitude::new(true, 3));
        assert_eq!(c.roll, SignMagnitude(0x84), "roll bit 0 cleared");
        assert_eq!(c.ai, 0xFE);
        assert_eq!((c.energy, c.missiles, c.acceleration), (4, 0, 0), "the type's own energy");
        assert!(!c.flags.killed);
        assert_eq!(random, MainGenerator::new(), "only canisters draw");
    }

    #[test]
    fn a_station_child_starts_ahead_of_the_station_at_speed_32() {
        let mut bubble = Bubble::new();
        let mut station = Object::new(STATION, Vec3::new(0.0, 0.0, 1000.0));
        station.nose = Vec3::new(0.0, 0.0, -1.0);
        station.roll = SignMagnitude(0xFF);
        let slot = launch_child(&mut bubble, &station, POLICE, 0xF1, &mut MainGenerator::new()).unwrap();
        let c = bubble.get(slot).unwrap();
        assert_eq!(c.position, Vec3::new(0.0, 0.0, 808.0));
        assert_eq!(c.speed, 32);
        assert_eq!(c.roll, SignMagnitude(0xFE));
        assert_eq!((c.energy, c.missiles), (120, 2));
    }

    #[test]
    fn a_canister_draws_its_spin_and_speed() {
        let mut bubble = Bubble::new();
        let mut random = next_draw(0xC5, 0x3B);
        let slot = launch_child(&mut bubble, &parent(), CANISTER, 0, &mut random).unwrap();
        let c = bubble.get(slot).unwrap();
        assert_eq!(c.pitch, SignMagnitude(0x8A), "(0xC5 × 2) AND 255");
        assert_eq!(c.speed, 0x0B, "X AND 15");
        assert_eq!(c.roll, SignMagnitude::new(true, 127), "permanent spin, sign from A");
        let mut random = next_draw(0x45, 0x20);
        let slot = launch_child(&mut bubble, &parent(), CANISTER, 0, &mut random).unwrap();
        let c = bubble.get(slot).unwrap();
        assert_eq!((c.pitch, c.speed, c.roll), (SignMagnitude(0x8A), 0, SignMagnitude::new(false, 127)));
    }

    #[test]
    fn a_full_bubble_refuses_but_the_draw_stays_drawn() {
        let mut bubble = Bubble::new();
        for _ in 0..13 {
            bubble.add(Object::new(SUN, Vec3::ZERO));
        }
        let mut random = MainGenerator::new();
        assert_eq!(launch_child(&mut bubble, &parent(), CANISTER, 0, &mut random), None);
        let mut expected = MainGenerator::new();
        expected.draw();
        assert_eq!(random, expected);
        assert_eq!(launch_child(&mut bubble, &parent(), ESCAPE_POD, 0xFE, &mut random), None);
        assert_eq!(random, expected);
    }
}
