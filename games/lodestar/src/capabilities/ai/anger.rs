//! Becoming angry: what the player's laser hit or missile launch does to the ship it is aimed at
//! (RULES C.5.6).

use crate::capabilities::ai::ACTIVE;
use crate::capabilities::bubble::Bubble;
use crate::capabilities::ships::{MISSILE, STATION, TRADER};
use crate::capabilities::space::SignMagnitude;

/// The acceleration and pitch counter an angered ship takes.
const ANGRY_ACCELERATION: u8 = 2;
const ANGRY_PITCH: SignMagnitude = SignMagnitude::new(false, 4);

/// Angers the object in `slot` (RULES C.5.6). The station turns hostile and nothing more; types
/// 9..13 ignore it; a trader also turns the station hostile, if the station is in the bubble;
/// then a ship whose AI byte is exactly 0 stays passive, and any other gets its AI bit set,
/// acceleration +2 and pitch counter +4. Planets, the sun and an empty slot are left alone.
pub fn anger(bubble: &mut Bubble, slot: usize) {
    let Some(kind) = bubble.get(slot).map(|o| o.kind) else {
        return;
    };
    if kind == STATION {
        if let Some(station) = bubble.get_mut(slot) {
            station.ai |= ACTIVE;
        }
        return;
    }
    if kind >= MISSILE {
        return;
    }
    if kind == TRADER {
        if let Some(station) = bubble.find(STATION).and_then(|s| bubble.get_mut(s)) {
            station.ai |= ACTIVE;
        }
    }
    if let Some(ship) = bubble.get_mut(slot) {
        if ship.ai == 0 {
            return;
        }
        ship.ai |= ACTIVE;
        ship.acceleration = ANGRY_ACCELERATION;
        ship.pitch = ANGRY_PITCH;
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::capabilities::bubble::Object;
    use crate::capabilities::ships::{ALIEN_DRONE, CANISTER, ESCAPE_POD, PLANET_A, SMALL_PIRATE_A};
    use crate::capabilities::space::Vec3;

    fn bubble_with_station() -> Bubble {
        let mut b = Bubble::new();
        b.add(Object::new(PLANET_A, Vec3::ZERO));
        let mut station = Object::new(STATION, Vec3::ZERO);
        station.ai = 1;
        b.add(station);
        b
    }

    #[test]
    fn the_station_turns_hostile_and_nothing_more() {
        let mut b = bubble_with_station();
        anger(&mut b, 1);
        let s = b.get(1).unwrap();
        assert_eq!(s.ai, 0x81);
        assert_eq!((s.acceleration, s.pitch), (0, SignMagnitude::ZERO));
    }

    #[test]
    fn a_trader_angers_the_station_and_itself() {
        let mut b = bubble_with_station();
        let mut trader = Object::new(TRADER, Vec3::ZERO);
        trader.ai = 0x2B; // AI off, aggression 21, E.C.M.
        let slot = b.add(trader).unwrap();
        anger(&mut b, slot);
        assert_eq!(b.get(1).unwrap().ai, 0x81);
        let t = b.get(slot).unwrap();
        assert_eq!(t.ai, 0xAB);
        assert_eq!((t.acceleration, t.pitch), (2, SignMagnitude::new(false, 4)));
    }

    #[test]
    fn a_passive_ship_stays_passive_but_its_trader_role_still_counts() {
        let mut b = bubble_with_station();
        let slot = b.add(Object::new(TRADER, Vec3::ZERO)).unwrap();
        anger(&mut b, slot);
        assert_eq!(b.get(1).unwrap().ai, 0x81, "the station still turns");
        let t = b.get(slot).unwrap();
        assert_eq!((t.ai, t.acceleration), (0, 0));
    }

    #[test]
    fn light_objects_ignore_it() {
        let mut b = bubble_with_station();
        for kind in [MISSILE, CANISTER, ALIEN_DRONE, ESCAPE_POD] {
            let mut o = Object::new(kind, Vec3::ZERO);
            o.ai = 0x7E;
            let slot = b.add(o).unwrap();
            anger(&mut b, slot);
            assert_eq!(*b.get(slot).unwrap(), o, "type {kind}");
        }
        assert_eq!(b.get(1).unwrap().ai, 1);
    }

    #[test]
    fn a_pirate_wakes_up_without_touching_the_station() {
        let mut b = bubble_with_station();
        let mut p = Object::new(SMALL_PIRATE_A, Vec3::ZERO);
        p.ai = 0x01;
        let slot = b.add(p).unwrap();
        anger(&mut b, slot);
        assert_eq!(b.get(slot).unwrap().ai, 0x81);
        assert_eq!(b.get(1).unwrap().ai, 1);
        anger(&mut b, 0);
        assert_eq!(b.get(0).unwrap().ai, 0, "a planet is never angered");
        anger(&mut b, 12);
    }
}
