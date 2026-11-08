//! Contact: collisions, scooping and the station's docking box (RULES C.11, B.12.2, B.15.3).

use crate::capabilities::bubble::Bubble;
use crate::capabilities::cockpit::{Cockpit, Message};
use crate::capabilities::combat::damage::{take_damage, Damage};
use crate::capabilities::flight::FAILED_DOCKING_SPEED;
use crate::capabilities::market;
use crate::capabilities::pilot::Pilot;
use crate::capabilities::random::MainGenerator;
use crate::capabilities::ships::{ALIEN_DRONE, CANISTER, ESCAPE_POD, MISSILE, STATION};

/// The station's docking box: every |coordinate| below this (RULES B.12.1).
pub const DOCKING_BOX: f64 = 128.0;
/// The collision and scooping box: every |coordinate| below this.
pub const CONTACT_BOX: f64 = 64.0;
/// A collision does this plus half the ship's energy.
pub const COLLISION_DAMAGE: u8 = 128;
/// A failed docking at this speed or more kills; below it, speed 1 and this much damage.
pub const FATAL_DOCKING_SPEED: u8 = 5;
pub const FAILED_DOCKING_DAMAGE: u8 = 5;

/// What contact with the object in a slot did.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Contact {
    /// Nothing touched.
    None,
    /// The player is in the station's docking box: the caller runs the docking test (RULES
    /// B.12.2) and calls [`failed_docking`] if it fails.
    DockingBox,
    /// A canister, drone or pod was scooped and marked killed; `gained` is false when the hold
    /// had no room (the crunch sound plays), true when its name shows.
    Scooped { item: usize, gained: bool },
    /// A collision: the object was marked killed and the player took the damage.
    Collided(Damage),
}

/// Contact with the object in `slot` (RULES C.11; C.4 step 6). Only a ship that is not killed,
/// not exploding and not a planet or the sun, with every |coordinate| below 128, can touch. The
/// station reports the docking box. Any other ship within 64 on every axis that is not a missile
/// is scooped when it is a canister, drone or pod, the fuel scoop is fitted and it is below the
/// player (y < 0); otherwise it is rammed: marked killed, and the player takes 128 + ⌊its energy
/// / 2⌋. Neither counts a kill.
pub fn contact(
    pilot: &mut Pilot,
    cockpit: &mut Cockpit,
    bubble: &mut Bubble,
    slot: usize,
    random: &mut MainGenerator,
) -> Contact {
    let Some(object) = bubble.get(slot).copied() else {
        return Contact::None;
    };
    if object.is_body() || object.flags.killed || object.flags.exploding {
        return Contact::None;
    }
    let p = object.position;
    let within = |limit: f64| p.x.abs() < limit && p.y.abs() < limit && p.z.abs() < limit;
    if !within(DOCKING_BOX) {
        return Contact::None;
    }
    if object.kind == STATION {
        return Contact::DockingBox;
    }
    if !within(CONTACT_BOX) || object.kind == MISSILE {
        return Contact::None;
    }
    if let Some(o) = bubble.get_mut(slot) {
        o.flags.killed = true;
    }
    if object.kind >= CANISTER && pilot.fitted.fuel_scoop && p.y < 0.0 {
        let (item, gained) = match object.kind {
            CANISTER => {
                let scooped = market::scoop_canister(pilot, random);
                (scooped.item, scooped.gained)
            }
            ALIEN_DRONE => (market::SPECIAL_ITEM, market::gain_one(pilot, market::SPECIAL_ITEM)),
            _ => {
                debug_assert_eq!(object.kind, ESCAPE_POD);
                (market::ESCAPE_POD_ITEM, market::gain_one(pilot, market::ESCAPE_POD_ITEM))
            }
        };
        if gained {
            cockpit.show(Message::Scooped { item });
        }
        return Contact::Scooped { item, gained };
    }
    let damage = COLLISION_DAMAGE + object.energy / 2;
    Contact::Collided(take_damage(pilot, cockpit, random, damage, p.z))
}

/// A failed docking test (RULES C.11, B.12.2): at speed 5 or more the player dies; below it the
/// speed becomes 1 and the player takes 5 damage from the station at `station_z`.
pub fn failed_docking(pilot: &mut Pilot, cockpit: &mut Cockpit, random: &mut MainGenerator, station_z: f64) -> Damage {
    if cockpit.speed >= FATAL_DOCKING_SPEED {
        return Damage::Died;
    }
    cockpit.speed = FAILED_DOCKING_SPEED;
    take_damage(pilot, cockpit, random, FAILED_DOCKING_DAMAGE, station_z)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::capabilities::ai::test_support::next_draw;
    use crate::capabilities::bubble::Object;
    use crate::capabilities::ships::{ASTEROID, PLANET_A, SMALL_PIRATE_A};
    use crate::capabilities::space::Vec3;

    fn one(kind: u8, at: Vec3) -> (Pilot, Cockpit, Bubble, usize) {
        let mut b = Bubble::new();
        let slot = b.add(Object::new(kind, at)).unwrap();
        (Pilot::start(), Cockpit::new(), b, slot)
    }

    #[test]
    fn the_station_reports_the_docking_box() {
        let (mut pilot, mut cockpit, mut b, slot) = one(STATION, Vec3::new(127.9, -100.0, 50.0));
        let r = contact(&mut pilot, &mut cockpit, &mut b, slot, &mut MainGenerator::new());
        assert_eq!(r, Contact::DockingBox);
        assert!(!b.get(slot).unwrap().flags.killed);
        b.get_mut(slot).unwrap().position.x = 128.0;
        assert_eq!(contact(&mut pilot, &mut cockpit, &mut b, slot, &mut MainGenerator::new()), Contact::None);
    }

    #[test]
    fn a_collision_kills_the_ship_and_hurts_the_player() {
        // Pirate A: energy 64, so 128 + 32 = 160 to the fore shield.
        let (mut pilot, mut cockpit, mut b, slot) = one(SMALL_PIRATE_A, Vec3::new(63.0, -63.0, 63.9));
        let mut random = MainGenerator::new();
        let r = contact(&mut pilot, &mut cockpit, &mut b, slot, &mut random);
        assert_eq!(r, Contact::Collided(Damage::Shielded));
        assert_eq!(cockpit.fore_shield, 95);
        assert!(b.get(slot).unwrap().flags.killed);
        assert_eq!(pilot.kills, 0, "no kill counted");
        assert_eq!(random, MainGenerator::new());
    }

    #[test]
    fn a_collision_behind_hits_the_aft_shield() {
        let (mut pilot, mut cockpit, mut b, slot) = one(ASTEROID, Vec3::new(0.0, 0.0, -10.0));
        b.get_mut(slot).unwrap().energy = 7;
        contact(&mut pilot, &mut cockpit, &mut b, slot, &mut MainGenerator::new());
        assert_eq!((cockpit.aft_shield, cockpit.fore_shield), (255 - 131, 255));
    }

    #[test]
    fn outside_the_box_nothing_touches() {
        let (mut pilot, mut cockpit, mut b, slot) = one(SMALL_PIRATE_A, Vec3::new(0.0, 64.0, 0.0));
        assert_eq!(contact(&mut pilot, &mut cockpit, &mut b, slot, &mut MainGenerator::new()), Contact::None);
        assert!(!b.get(slot).unwrap().flags.killed);
    }

    #[test]
    fn missiles_killed_and_exploding_ships_and_bodies_never_touch() {
        for setup in [
            |o: &mut Object| o.kind = MISSILE,
            |o: &mut Object| o.flags.killed = true,
            |o: &mut Object| o.flags.exploding = true,
            |o: &mut Object| o.kind = PLANET_A,
        ] {
            let (mut pilot, mut cockpit, mut b, slot) = one(SMALL_PIRATE_A, Vec3::ZERO);
            setup(b.get_mut(slot).unwrap());
            let before = *b.get(slot).unwrap();
            assert_eq!(contact(&mut pilot, &mut cockpit, &mut b, slot, &mut MainGenerator::new()), Contact::None);
            assert_eq!(*b.get(slot).unwrap(), before);
            assert_eq!(cockpit.fore_shield, 255);
        }
    }

    #[test]
    fn a_canister_below_with_the_scoop_is_scooped_by_a_byte() {
        let (mut pilot, mut cockpit, mut b, slot) = one(CANISTER, Vec3::new(5.0, -0.5, 30.0));
        pilot.fitted.fuel_scoop = true;
        let r = contact(&mut pilot, &mut cockpit, &mut b, slot, &mut next_draw(0x2E, 0));
        assert_eq!(r, Contact::Scooped { item: 6, gained: true });
        assert_eq!(pilot.cargo[6], 1);
        assert_eq!(cockpit.message, Some(Message::Scooped { item: 6 }));
        assert!(b.get(slot).unwrap().flags.killed);
        assert_eq!(cockpit.fore_shield, 255);
    }

    #[test]
    fn a_full_hold_still_destroys_the_canister() {
        let (mut pilot, mut cockpit, mut b, slot) = one(CANISTER, Vec3::new(5.0, -0.5, 30.0));
        pilot.fitted.fuel_scoop = true;
        pilot.cargo[0] = 22;
        let r = contact(&mut pilot, &mut cockpit, &mut b, slot, &mut next_draw(0x01, 0));
        assert_eq!(r, Contact::Scooped { item: 1, gained: false });
        assert_eq!(cockpit.message, None);
        assert!(b.get(slot).unwrap().flags.killed);
    }

    #[test]
    fn drones_and_pods_give_their_items_without_a_draw() {
        for (kind, item) in [(ALIEN_DRONE, 16), (ESCAPE_POD, 3)] {
            let (mut pilot, mut cockpit, mut b, slot) = one(kind, Vec3::new(0.0, -20.0, 0.0));
            pilot.fitted.fuel_scoop = true;
            let mut random = MainGenerator::new();
            let r = contact(&mut pilot, &mut cockpit, &mut b, slot, &mut random);
            assert_eq!(r, Contact::Scooped { item, gained: true });
            assert_eq!(pilot.cargo[item], 1);
            assert_eq!(random, MainGenerator::new());
        }
    }

    #[test]
    fn without_the_scoop_or_from_above_a_canister_is_rammed() {
        // Canister energy 24: 128 + 12.
        let (mut pilot, mut cockpit, mut b, slot) = one(CANISTER, Vec3::new(0.0, -5.0, 10.0));
        let r = contact(&mut pilot, &mut cockpit, &mut b, slot, &mut MainGenerator::new());
        assert_eq!(r, Contact::Collided(Damage::Shielded));
        assert_eq!(cockpit.fore_shield, 255 - 140);
        let (mut pilot, mut cockpit, mut b, slot) = one(CANISTER, Vec3::new(0.0, 0.0, 10.0));
        pilot.fitted.fuel_scoop = true;
        let r = contact(&mut pilot, &mut cockpit, &mut b, slot, &mut MainGenerator::new());
        assert_eq!(r, Contact::Collided(Damage::Shielded), "y = 0 is not below");
    }

    #[test]
    fn a_collision_can_kill() {
        let (mut pilot, mut cockpit, mut b, slot) = one(SMALL_PIRATE_A, Vec3::new(0.0, 0.0, 10.0));
        cockpit.fore_shield = 0;
        cockpit.energy = 160;
        assert_eq!(contact(&mut pilot, &mut cockpit, &mut b, slot, &mut MainGenerator::new()), Contact::Collided(Damage::Died));
    }

    #[test]
    fn a_failed_docking_kills_fast_and_bumps_slow() {
        let mut pilot = Pilot::start();
        let mut cockpit = Cockpit::new();
        cockpit.speed = 5;
        assert_eq!(failed_docking(&mut pilot, &mut cockpit, &mut MainGenerator::new(), 50.0), Damage::Died);
        cockpit.speed = 4;
        assert_eq!(failed_docking(&mut pilot, &mut cockpit, &mut MainGenerator::new(), 50.0), Damage::Shielded);
        assert_eq!((cockpit.speed, cockpit.fore_shield), (1, 250));
        failed_docking(&mut pilot, &mut cockpit, &mut MainGenerator::new(), -50.0);
        assert_eq!(cockpit.aft_shield, 250);
    }
}
