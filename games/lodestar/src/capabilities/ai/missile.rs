//! The missile AI (RULES C.5.5), and how missiles follow their targets when the bubble shifts
//! (RULES C.7.4).

use crate::capabilities::ai::{is_active, missile_target, steer, Hit, Thought, ECM_FITTED, HOSTILE, POINTING_SCALE};
use crate::capabilities::bubble::Bubble;
use crate::capabilities::cockpit::Cockpit;
use crate::capabilities::random::MainGenerator;
use crate::capabilities::ships::{MISSILE, STATION};
use crate::capabilities::space::{coarse, Vec3};

/// Damage a hostile missile does when it reaches the player (RULES C.5.5 step 2).
pub const HOSTILE_MISSILE_DAMAGE: u8 = 250;
/// Damage a missile destroyed within 1 unit of the player does (RULES C.5.5 step 6).
pub const DESTROYED_MISSILE_DAMAGE: u8 = 80;
/// A player's missile's target fires its E.C.M. when the byte drawn is below this (RULES C.5.5
/// step 4).
pub const ECM_CHANCE: u8 = 16;
/// The slot the station lives in; a missile reaching the station there is destroyed harmlessly.
const STATION_SLOT: usize = 1;
/// "Close" for a missile and its target: below this on every axis.
const CLOSE: f64 = 256.0;
/// A missile's target slot bits, 1..5.
const TARGET_BITS: u8 = 0x3E;

/// One think of the missile in `slot` (RULES C.5.5): destroyed by an active E.C.M. pulse;
/// a hostile missile homes on the player and hits for 250; the player's missile homes on its
/// target slot, may set off the target's E.C.M., goes unguided when the slot is empty, and
/// kills its target outright when close (unless the target is the station in slot 1).
pub fn think_missile(bubble: &mut Bubble, slot: usize, cockpit: &mut Cockpit, random: &mut MainGenerator) -> Thought {
    let Some(missile) = bubble.get(slot).copied() else {
        return Thought::default();
    };
    if cockpit.ecm_active() {
        return destroy(bubble, slot);
    }
    if missile.ai & HOSTILE != 0 {
        let p = missile.position;
        if coarse(p.x) != 0 || coarse(p.y) != 0 || coarse(p.z) != 0 {
            if let Some(m) = bubble.get_mut(slot) {
                steer(m, (-p).normalised(), POINTING_SCALE, true);
            }
            return Thought::default();
        }
        if let Some(m) = bubble.get_mut(slot) {
            m.flags.killed = true;
        }
        return Thought { hit: Some(Hit { damage: HOSTILE_MISSILE_DAMAGE, from_z: p.z }), kill: false };
    }
    let target_slot = missile_target(missile.ai);
    let Some(target) = bubble.get(target_slot).copied() else {
        if let Some(m) = bubble.get_mut(slot) {
            m.ai = 0;
        }
        return Thought::default();
    };
    let delta = missile.position - target.position;
    let close = delta.x.abs() < CLOSE && delta.y.abs() < CLOSE && delta.z.abs() < CLOSE;
    if !close {
        let roll = random.byte();
        if roll < ECM_CHANCE && target.ai & ECM_FITTED != 0 {
            cockpit.start_ecm(false);
        } else if let Some(m) = bubble.get_mut(slot) {
            steer(m, (-delta).normalised(), POINTING_SCALE, true);
        }
        return Thought::default();
    }
    if !(target_slot == STATION_SLOT && target.kind == STATION) && !target.flags.exploding {
        if let Some(t) = bubble.get_mut(target_slot) {
            t.flags.killed = true;
        }
    }
    destroy(bubble, slot)
}

/// Destroying a missile (RULES C.5.5 step 6): 80 damage to the player when it is within 1 unit
/// on every axis, a kill counted, and the missile marked killed so it explodes.
fn destroy(bubble: &mut Bubble, slot: usize) -> Thought {
    let Some(m) = bubble.get_mut(slot) else {
        return Thought::default();
    };
    m.flags.killed = true;
    let p: Vec3 = m.position;
    let near = p.x.abs() < 1.0 && p.y.abs() < 1.0 && p.z.abs() < 1.0;
    let hit = near.then_some(Hit { damage: DESTROYED_MISSILE_DAMAGE, from_z: p.z });
    Thought { hit, kill: true }
}

/// After the object in slot `removed` has left the bubble (RULES C.7.4): every active,
/// non-hostile missile aimed at it loses its guidance (AI byte 0), and one aimed at a later slot
/// is aimed one slot lower, keeping its other AI bits. The player's lock is the cockpit's
/// (`MissileLock::on_removed`).
pub fn retarget_missiles(bubble: &mut Bubble, removed: usize) {
    for object in bubble.iter_mut() {
        if object.kind != MISSILE || !is_active(object.ai) || object.ai & HOSTILE != 0 {
            continue;
        }
        let target = missile_target(object.ai);
        if target == removed {
            object.ai = 0;
        } else if target > removed {
            object.ai = (object.ai & !TARGET_BITS) | (((target - 1) as u8) << 1);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::capabilities::ai::test_support::{find, next_draw};
    use crate::capabilities::ai::{player_missile, ENEMY_LAUNCH};
    use crate::capabilities::bubble::Object;
    use crate::capabilities::ships::{PLANET_A, SMALL_PIRATE_A, SUN, TRADER};
    use crate::capabilities::space::SignMagnitude;

    fn bubble() -> Bubble {
        let mut b = Bubble::new();
        b.add(Object::new(PLANET_A, Vec3::new(0.0, 0.0, 100_000.0)));
        b.add(Object::new(SUN, Vec3::new(0.0, 0.0, -300_000.0)));
        b
    }

    fn missile(at: Vec3, ai: u8) -> Object {
        let mut m = Object::new(MISSILE, at);
        m.ai = ai;
        m
    }

    #[test]
    fn an_ecm_pulse_destroys_any_guided_missile_and_counts_a_kill() {
        let mut b = bubble();
        let slot = b.add(missile(Vec3::new(0.0, 0.0, 600.0), ENEMY_LAUNCH)).unwrap();
        let mut cockpit = Cockpit::new();
        cockpit.start_ecm(true);
        let mut random = MainGenerator::new();
        let t = think_missile(&mut b, slot, &mut cockpit, &mut random);
        assert_eq!(t, Thought { hit: None, kill: true });
        assert!(b.get(slot).unwrap().flags.killed);
        assert_eq!(random, MainGenerator::new(), "no draw");
    }

    #[test]
    fn a_missile_destroyed_within_one_unit_hurts_the_player() {
        let mut b = bubble();
        let slot = b.add(missile(Vec3::new(0.5, -0.9, -0.2), player_missile(3))).unwrap();
        let mut cockpit = Cockpit::new();
        cockpit.start_ecm(false);
        let t = think_missile(&mut b, slot, &mut cockpit, &mut MainGenerator::new());
        assert_eq!(t, Thought { hit: Some(Hit { damage: 80, from_z: -0.2 }), kill: true });
        let mut b = bubble();
        let slot = b.add(missile(Vec3::new(0.5, -1.0, 0.0), player_missile(3))).unwrap();
        let t = think_missile(&mut b, slot, &mut cockpit, &mut MainGenerator::new());
        assert_eq!(t.hit, None, "1 unit on an axis is not within");
    }

    #[test]
    fn a_hostile_missile_homes_then_hits_for_250() {
        let mut b = bubble();
        let slot = b.add(missile(Vec3::new(0.0, 0.0, 256.0), ENEMY_LAUNCH)).unwrap();
        let mut cockpit = Cockpit::new();
        let mut random = MainGenerator::new();
        let t = think_missile(&mut b, slot, &mut cockpit, &mut random);
        assert_eq!(t, Thought::default());
        let m = b.get(slot).unwrap();
        assert_eq!(m.acceleration, 3, "P = 36 always speeds it up");
        assert!(!m.flags.killed);
        assert_eq!(random, MainGenerator::new(), "a hostile missile never draws");

        b.get_mut(slot).unwrap().position = Vec3::new(-255.9, 100.0, -3.0);
        let t = think_missile(&mut b, slot, &mut cockpit, &mut random);
        assert_eq!(t, Thought { hit: Some(Hit { damage: 250, from_z: -3.0 }), kill: false });
        assert!(b.get(slot).unwrap().flags.killed);
    }

    #[test]
    fn coarse_wraps_so_a_far_hostile_missile_can_look_near() {
        let mut b = bubble();
        let slot = b.add(missile(Vec3::new(0.0, 0.0, 65_600.0), ENEMY_LAUNCH)).unwrap();
        let t = think_missile(&mut b, slot, &mut Cockpit::new(), &mut MainGenerator::new());
        assert_eq!(t.hit.map(|h| h.damage), Some(250), "coarse(65600) = 0");
    }

    #[test]
    fn a_missile_whose_target_slot_is_empty_goes_unguided() {
        let mut b = bubble();
        let slot = b.add(missile(Vec3::new(0.0, 0.0, 600.0), player_missile(9))).unwrap();
        let mut random = MainGenerator::new();
        let t = think_missile(&mut b, slot, &mut Cockpit::new(), &mut random);
        assert_eq!(t, Thought::default());
        assert_eq!(b.get(slot).unwrap().ai, 0);
        assert_eq!(random, MainGenerator::new());
    }

    #[test]
    fn far_from_its_target_it_draws_every_tick_and_steers() {
        let mut b = bubble();
        let target = b.add(Object::new(SMALL_PIRATE_A, Vec3::new(0.0, 1000.0, 2000.0))).unwrap();
        let slot = b.add(missile(Vec3::new(0.0, 0.0, 14.0), player_missile(target))).unwrap();
        let mut cockpit = Cockpit::new();
        let mut random = next_draw(3, 0);
        let t = think_missile(&mut b, slot, &mut cockpit, &mut random);
        assert_eq!(t, Thought::default());
        assert!(!cockpit.ecm_active(), "no E.C.M. fitted on the target, so a low byte only steers");
        let m = b.get(slot).unwrap();
        assert_eq!(m.pitch, SignMagnitude::new(true, 3), "target above: pull up");
        assert_eq!(m.acceleration, 3);
        assert_ne!(random, next_draw(3, 0), "the byte was drawn");
    }

    #[test]
    fn a_target_with_ecm_may_fire_it() {
        let mut b = bubble();
        let mut pirate = Object::new(SMALL_PIRATE_A, Vec3::new(0.0, 1000.0, 2000.0));
        pirate.ai = 0xC1;
        let target = b.add(pirate).unwrap();
        let slot = b.add(missile(Vec3::new(0.0, 0.0, 14.0), player_missile(target))).unwrap();
        let mut cockpit = Cockpit::new();
        think_missile(&mut b, slot, &mut cockpit, &mut next_draw(15, 0));
        assert_eq!((cockpit.ecm_timer, cockpit.ecm_own), (32, false));
        assert_eq!(b.get(slot).unwrap().pitch, SignMagnitude::ZERO, "it does not steer that tick");
        let mut cockpit = Cockpit::new();
        think_missile(&mut b, slot, &mut cockpit, &mut next_draw(16, 0));
        assert!(!cockpit.ecm_active());
        assert_eq!(b.get(slot).unwrap().pitch, SignMagnitude::new(true, 3));
    }

    #[test]
    fn close_to_its_target_it_kills_it_outright() {
        let mut b = bubble();
        let mut big = Object::new(TRADER, Vec3::new(100.0, 0.0, 500.0));
        big.energy = 160;
        let target = b.add(big).unwrap();
        let slot = b.add(missile(Vec3::new(-155.0, 255.0, 300.0), player_missile(target))).unwrap();
        let mut random = MainGenerator::new();
        let t = think_missile(&mut b, slot, &mut Cockpit::new(), &mut random);
        assert_eq!(t, Thought { hit: None, kill: true }, "the kill counted is the missile's");
        assert!(b.get(target).unwrap().flags.killed);
        assert!(b.get(slot).unwrap().flags.killed);
        assert_eq!(random, MainGenerator::new(), "no draw when close");
    }

    #[test]
    fn an_exploding_target_is_not_marked_again() {
        let mut b = bubble();
        let mut t = Object::new(TRADER, Vec3::new(0.0, 0.0, 500.0));
        t.flags.exploding = true;
        let target = b.add(t).unwrap();
        let slot = b.add(missile(Vec3::new(0.0, 0.0, 400.0), player_missile(target))).unwrap();
        think_missile(&mut b, slot, &mut Cockpit::new(), &mut MainGenerator::new());
        assert!(!b.get(target).unwrap().flags.killed);
        assert!(b.get(slot).unwrap().flags.killed);
    }

    #[test]
    fn the_station_in_slot_one_destroys_the_missile_harmlessly() {
        let mut b = Bubble::new();
        b.add(Object::new(PLANET_A, Vec3::new(0.0, 0.0, 100_000.0)));
        b.add(Object::new(STATION, Vec3::new(0.0, 0.0, 500.0)));
        let slot = b.add(missile(Vec3::new(0.0, 0.0, 400.0), player_missile(1))).unwrap();
        let t = think_missile(&mut b, slot, &mut Cockpit::new(), &mut MainGenerator::new());
        assert_eq!(t, Thought { hit: None, kill: true });
        assert!(!b.get(1).unwrap().flags.killed);
        assert!(b.get(slot).unwrap().flags.killed);
    }

    #[test]
    fn removals_retarget_the_players_missiles_only() {
        let mut b = bubble();
        let at_removed = b.add(missile(Vec3::ZERO, player_missile(4))).unwrap();
        let above = b.add(missile(Vec3::ZERO, player_missile(7))).unwrap();
        let below = b.add(missile(Vec3::ZERO, player_missile(2))).unwrap();
        let hostile = b.add(missile(Vec3::ZERO, ENEMY_LAUNCH)).unwrap();
        let unguided = b.add(missile(Vec3::ZERO, 0)).unwrap();
        let mut pirate = Object::new(SMALL_PIRATE_A, Vec3::ZERO);
        pirate.ai = 0x8E;
        let ship = b.add(pirate).unwrap();
        retarget_missiles(&mut b, 4);
        assert_eq!(b.get(at_removed).unwrap().ai, 0);
        assert_eq!(b.get(above).unwrap().ai, player_missile(6));
        assert_eq!(b.get(below).unwrap().ai, player_missile(2));
        assert_eq!(b.get(hostile).unwrap().ai, ENEMY_LAUNCH);
        assert_eq!(b.get(unguided).unwrap().ai, 0);
        assert_eq!(b.get(ship).unwrap().ai, 0x8E, "only missiles");
    }

    #[test]
    fn the_seed_search_reaches_a_branch() {
        let g = find(|r| r.byte() < 16);
        let mut copy = g;
        assert!(copy.byte() < 16);
    }
}
