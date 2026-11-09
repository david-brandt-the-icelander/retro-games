//! Ship types and their stats (RULES C.3; values from the GDD § 5.5).
//!
//! Type numbers are rules: several rules compare them. The presentation-only fields of RULES
//! C.3.2 (gun point, explosion points, dot distance, normal scale, model) live in the art, not
//! here (GDD § 5.5).

/// An object type number (RULES B.9.2).
pub type TypeNumber = u8;

pub const SMALL_PIRATE_A: TypeNumber = 1;
pub const POLICE: TypeNumber = 2;
pub const SMALL_PIRATE_B: TypeNumber = 3;
pub const HEAVY_FIGHTER: TypeNumber = 4;
pub const HUNTER: TypeNumber = 5;
pub const ALIEN_MOTHERSHIP: TypeNumber = 6;
pub const TRADER: TypeNumber = 7;
pub const STATION: TypeNumber = 8;
pub const MISSILE: TypeNumber = 9;
pub const ASTEROID: TypeNumber = 10;
pub const CANISTER: TypeNumber = 11;
pub const ALIEN_DRONE: TypeNumber = 12;
pub const ESCAPE_POD: TypeNumber = 13;
pub const PLANET_A: TypeNumber = 128;
pub const SUN: TypeNumber = 129;
pub const PLANET_B: TypeNumber = 130;

/// The highest ship type number.
pub const LAST_SHIP: TypeNumber = 13;

/// True for planets and the sun (types ≥ 128).
pub const fn is_body(t: TypeNumber) -> bool {
    t >= 128
}

/// True for the two planet styles.
pub const fn is_planet(t: TypeNumber) -> bool {
    t == PLANET_A || t == PLANET_B
}

/// The rule fields of one ship type's record (RULES C.3.2).
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct ShipStats {
    /// Mask for the canister roll when the player's laser destroys the ship (2ⁿ − 1).
    pub canisters: u8,
    /// Square of the sights radius, in sim units².
    pub hit_size: u16,
    /// Bounty in tenths of a credit.
    pub bounty: u16,
    /// Starting and maximum energy.
    pub energy: u8,
    /// Top speed.
    pub speed: u8,
    /// Laser power of the ship's gun, 0..31.
    pub laser: u8,
    /// Starting missiles (drones for the mothership), 0..7.
    pub missiles: u8,
}

impl ShipStats {
    const fn new(canisters: u8, hit_size: u16, bounty: u16, energy: u8, speed: u8, laser: u8, missiles: u8) -> Self {
        Self { canisters, hit_size, bounty, energy, speed, laser, missiles }
    }

    /// Damage one hit from this ship's laser does: laser × 4 + ⌊missiles / 2⌋ (RULES C.3.2).
    pub const fn hit_damage(&self) -> u8 {
        self.laser * 4 + self.missiles / 2
    }
}

/// Stats for ship types 1..13, from the GDD § 5.5.
const STATS: [ShipStats; 13] = [
    ShipStats::new(1, 2_500, 60, 64, 36, 3, 0),     // 1 small pirate fighter A
    ShipStats::new(0, 4_096, 0, 120, 34, 3, 2),     // 2 police interceptor
    ShipStats::new(0, 3_600, 120, 96, 31, 2, 1),    // 3 small pirate fighter B
    ShipStats::new(7, 9_216, 240, 230, 22, 4, 4),   // 4 heavy fighter
    ShipStats::new(3, 6_724, 0, 160, 26, 2, 2),     // 5 medium multi-role, hunter
    ShipStats::new(0, 10_816, 450, 250, 33, 3, 5),  // 6 alien mothership
    ShipStats::new(3, 6_724, 0, 160, 26, 2, 2),     // 7 medium multi-role, trader
    ShipStats::new(0, 22_500, 0, 220, 0, 0, 0),     // 8 station
    ShipStats::new(0, 1_024, 0, 4, 42, 0, 0),       // 9 missile
    ShipStats::new(0, 5_776, 8, 72, 24, 0, 0),      // 10 asteroid
    ShipStats::new(0, 484, 0, 24, 12, 0, 0),        // 11 cargo canister
    ShipStats::new(0, 1_296, 40, 28, 32, 1, 0),     // 12 alien drone
    ShipStats::new(0, 324, 0, 16, 6, 0, 0),         // 13 escape pod
];

/// The stats of a ship type, or `None` for planets, the sun and unknown numbers.
pub fn stats(t: TypeNumber) -> Option<&'static ShipStats> {
    if (1..=LAST_SHIP).contains(&t) {
        Some(&STATS[usize::from(t) - 1])
    } else {
        None
    }
}

/// A type's top speed; types without one clamp to 0 (RULES B.7.3).
pub fn top_speed(t: TypeNumber) -> u8 {
    stats(t).map_or(0, |s| s.speed)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn relationships_the_rules_rely_on() {
        for t in 1..=LAST_SHIP {
            let s = stats(t).unwrap();
            assert!(matches!(s.canisters, 0 | 1 | 3 | 7), "type {t} canisters");
            assert!(s.laser <= 31 && s.missiles <= 7, "type {t} ranges");
            if t > 7 {
                assert_eq!(s.canisters, 0, "type {t} drops no canisters");
            }
        }
        assert_eq!(stats(POLICE).unwrap().bounty, 0);
        assert_eq!(stats(TRADER).unwrap().bounty, 0);
        assert_eq!(stats(HUNTER), stats(TRADER), "type 5 shares type 7's record");
        assert_eq!(top_speed(STATION), 0);
        assert!(f64::from(top_speed(MISSILE)) > 40.0 * 2.0 / 3.0);
        assert!(top_speed(POLICE) > top_speed(TRADER));
        assert!(stats(MISSILE).unwrap().hit_size >= 784, "keeps the own-missile quirk live");
        assert_eq!(stats(HEAVY_FIGHTER).unwrap().hit_damage(), 18);
        assert!(stats(SUN).is_none() && top_speed(PLANET_A) == 0);
    }
}
