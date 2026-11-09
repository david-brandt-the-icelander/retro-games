//! The ship AI: how every non-player object thinks (RULES C.5), the AI byte it thinks with
//! (RULES C.3.3), launching child ships (RULES C.5.7) and becoming angry (RULES C.5.6).
//!
//! A think changes the bubble and the cockpit directly (steering, launching, the E.C.M. pulse,
//! the incoming-missile message) but never the pilot: damage to the player and kills are
//! returned in a [`Thought`] for the combat capability to apply. A think makes no draw after the
//! point where it would hurt the player, so applying the hit afterwards keeps the draw order.
//!
//! See `ai.md` beside this file for what is built.

mod anger;
mod launch;
mod missile;
mod ship;
mod steering;

pub use anger::anger;
pub use launch::{launch_child, STATION_LAUNCH_DISTANCE, STATION_LAUNCH_SPEED};
pub use missile::{
    retarget_missiles, think_missile, DESTROYED_MISSILE_DAMAGE, ECM_CHANCE, HOSTILE_MISSILE_DAMAGE,
};
pub use ship::{
    think_ship, ESCAPE_CHANCE, LASER_RANGE_COARSE, POLICE_LAUNCH_CHANCE, RANDOM_ROLL_CHANCE,
    STATION_POLICE_LIMIT,
};
pub use steering::{pointing, steer, Pointing, POINTING_SCALE};

use crate::capabilities::bubble::{Bubble, Object};
use crate::capabilities::cockpit::Cockpit;
use crate::capabilities::random::MainGenerator;
use crate::capabilities::ships::{ALIEN_DRONE, ALIEN_MOTHERSHIP, ESCAPE_POD, MISSILE, STATION};

/// AI byte bit 7: the object runs its AI.
pub const ACTIVE: u8 = 0x80;
/// AI byte bit 6, for a missile: it is hostile to the player.
pub const HOSTILE: u8 = 0x40;
/// AI byte bit 0: fitted with E.C.M.
pub const ECM_FITTED: u8 = 0x01;
/// The bits safe-zone pacification keeps: the AI and E.C.M. bits (RULES C.5.3 step 1).
pub const PACIFIED: u8 = ACTIVE | ECM_FITTED;
/// An enemy missile's AI byte and an escape pod's: active, hostile, target bits 31
/// (RULES C.5.3 step 5).
pub const ENEMY_LAUNCH: u8 = 0xFE;
/// The AI byte of police launched by a hostile station: active, aggression 56, E.C.M.
/// (RULES C.5.2).
pub const STATION_POLICE: u8 = 0xF1;

/// True when the AI byte's bit 7 is set.
pub const fn is_active(ai: u8) -> bool {
    ai & ACTIVE != 0
}

/// The aggression, bits 1..6 (0..63).
pub const fn aggression(ai: u8) -> u8 {
    (ai >> 1) & 63
}

/// A missile's target slot, bits 1..5.
pub const fn missile_target(ai: u8) -> usize {
    ((ai >> 1) & 31) as usize
}

/// The AI byte of the player's missile aimed at `target`: active, not hostile, no E.C.M.,
/// target slot mod 32 in bits 1..5 (RULES B.10.5, C.7.2).
pub const fn player_missile(target: usize) -> u8 {
    ACTIVE | (((target % 32) as u8) << 1)
}

/// Damage the player takes from a hit, and where the attacker was, which picks the shield
/// (RULES C.10.2: aft when the attacker's z < 0).
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Hit {
    pub damage: u8,
    pub from_z: f64,
}

/// What a think leaves for the caller to apply to the pilot, in this order: the hit, then the
/// kill (RULES C.5.5 step 6 damages before it counts).
#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub struct Thought {
    /// Damage to the player (an enemy laser, a hostile missile, a missile destroyed next to
    /// the player).
    pub hit: Option<Hit>,
    /// A destroyed missile counts as a player kill (RULES C.5.5, C.13).
    pub kill: bool,
}

/// RULES C.4 step 3's condition for the object in `slot` to think this tick: not a planet or
/// the sun, neither killed nor exploding, its AI active, and either a missile (every tick) or
/// ((C XOR slot) AND 7) = 0 (every 8 ticks, staggered by slot). `counter` is C before this
/// tick's decrement.
pub fn due(object: &Object, counter: u8, slot: usize) -> bool {
    !object.is_body()
        && !object.flags.killed
        && !object.flags.exploding
        && is_active(object.ai)
        && (object.kind == MISSILE || (usize::from(counter) ^ slot) & 7 == 0)
}

/// One think for the object in `slot` (RULES C.5.2 then C.5.3): a missile runs the missile AI,
/// an escape pod heads for the planet, a hostile station may launch police, a drone with no
/// mothership in the bubble drifts, and every other ship runs the full ship AI. The caller has
/// checked [`due`]. An empty slot thinks nothing.
pub fn think(bubble: &mut Bubble, slot: usize, cockpit: &mut Cockpit, random: &mut MainGenerator) -> Thought {
    let Some(kind) = bubble.get(slot).map(|o| o.kind) else {
        return Thought::default();
    };
    match kind {
        MISSILE => think_missile(bubble, slot, cockpit, random),
        ESCAPE_POD => {
            ship::head_for_planet(bubble, slot);
            Thought::default()
        }
        STATION => {
            ship::think_station(bubble, slot, random);
            Thought::default()
        }
        ALIEN_DRONE if bubble.count_of(ALIEN_MOTHERSHIP) == 0 => {
            ship::drift(bubble, slot);
            Thought::default()
        }
        _ => think_ship(bubble, slot, cockpit, random),
    }
}

/// Test helpers shared by the AI and combat tests.
#[cfg(test)]
pub(crate) mod test_support {
    use crate::capabilities::random::MainGenerator;

    /// A generator whose next draw is exactly (a, x): with s0 = s2 = 0 the first step adds
    /// nothing, so A = s1 + s3 and X = s1.
    pub fn next_draw(a: u8, x: u8) -> MainGenerator {
        MainGenerator::with_seed([0, x, 0, a.wrapping_sub(x)])
    }

    /// The first seeded generator, in a fixed search order, whose draws satisfy `wanted`
    /// (given a copy to draw from). Tests use it to reach a branch without hand-solving the
    /// generator for several draws in a row.
    pub fn find(wanted: impl Fn(&mut MainGenerator) -> bool) -> MainGenerator {
        for s0 in [0u8, 0x12, 0x9C] {
            for s1 in 0..=255u8 {
                for s3 in 0..=255u8 {
                    let g = MainGenerator::with_seed([s0, s1, 0x56, s3]);
                    if wanted(&mut g.clone()) {
                        return g;
                    }
                }
            }
        }
        panic!("no seed gives the wanted draws");
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::capabilities::bubble::Object;
    use crate::capabilities::ships::{ASTEROID, PLANET_A, SMALL_PIRATE_A};
    use crate::capabilities::space::Vec3;

    #[test]
    fn ai_byte_fields() {
        assert!(is_active(0x80) && !is_active(0x7F));
        assert_eq!(aggression(0xC0), 32);
        assert_eq!(aggression(STATION_POLICE), 56);
        assert_eq!(aggression(0xFF), 63);
        assert_eq!(missile_target(ENEMY_LAUNCH), 31);
        assert_eq!(player_missile(5), 0x8A);
        assert_eq!(missile_target(player_missile(12)), 12);
        assert_eq!(player_missile(33), player_missile(1), "the target slot is kept mod 32");
    }

    #[test]
    fn missiles_think_every_tick_and_ships_every_eighth() {
        let mut ship = Object::new(SMALL_PIRATE_A, Vec3::ZERO);
        ship.ai = 0xC0;
        // (C XOR slot) AND 7 = 0: C = 3, slot 3, and C = 11, slot 3.
        assert!(due(&ship, 3, 3));
        assert!(due(&ship, 11, 3));
        assert!(!due(&ship, 4, 3));
        let ticks = (0..=255u8).filter(|&c| due(&ship, c, 5)).count();
        assert_eq!(ticks, 32);
        let mut missile = Object::new(MISSILE, Vec3::ZERO);
        missile.ai = player_missile(4);
        assert!((0..=255u8).all(|c| due(&missile, c, 5)));
        missile.ai = 0;
        assert!(!due(&missile, 0, 5), "an unguided missile has no AI");
        ship.flags.killed = true;
        assert!(!due(&ship, 3, 3));
        ship.flags.killed = false;
        ship.flags.exploding = true;
        assert!(!due(&ship, 3, 3));
        let mut planet = Object::new(PLANET_A, Vec3::ZERO);
        planet.ai = 0xFF;
        assert!(!due(&planet, 0, 0));
        let rock = Object::new(ASTEROID, Vec3::ZERO);
        assert!(!due(&rock, 0, 0), "asteroids have no AI");
    }

    #[test]
    fn an_empty_slot_thinks_nothing() {
        let mut bubble = Bubble::new();
        let mut cockpit = Cockpit::new();
        let mut random = MainGenerator::new();
        assert_eq!(think(&mut bubble, 4, &mut cockpit, &mut random), Thought::default());
        assert_eq!(random, MainGenerator::new());
    }

    #[test]
    fn the_test_seed_helper_gives_the_draw_asked_for() {
        for (a, x) in [(0, 0), (255, 3), (17, 200), (128, 128)] {
            let mut g = test_support::next_draw(a, x);
            let d = g.draw();
            assert_eq!((d.a, d.x), (a, x));
        }
    }
}
