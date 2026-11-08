//! One system's properties, worked out from its six bytes (RULES A.3.4 to A.3.7, B.9.2).

use super::galaxy::Seed;
use super::names::{inhabitants, name};
use crate::capabilities::ships::{TypeNumber, PLANET_A, PLANET_B};
use crate::capabilities::space::{Vec3, COARSE, FAR};

/// A point in galactic coordinates: x and y, each 0..255.
pub type Point = (u8, u8);

/// A system and everything the market, the charts, the data screen and the arrival scene need.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct System {
    /// 0..255 within its galaxy.
    pub index: u8,
    /// The generator state the system is made from.
    pub seed: Seed,
    pub x: u8,
    pub y: u8,
    /// Economy `E`, 0..7: 0..3 factory (industrial), 4..7 farm (agricultural).
    pub economy: u8,
    /// Government `G`, 0..7: 0 most lawless, 7 most orderly.
    pub government: u8,
    /// Internal tech level `T`, 0..14 (shown as `T + 1`).
    pub tech_level: u8,
    /// Population `P`, 8..64, in tenths of a billion.
    pub population: u8,
    /// Productivity, 768..56320, in millions of credits.
    pub productivity: u16,
    /// Mean radius, 2816..6911 km.
    pub radius: u16,
    /// The name in capitals, 0..8 letters (RULES A.3.5).
    pub name: String,
    /// The inhabitants phrase, in word case and without brackets (RULES A.3.6).
    pub inhabitants: String,
}

/// The planet's look: style A or B by bit 1 of the tech level (RULES A.3.7, B.9.2).
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum PlanetStyle {
    A,
    B,
}

impl PlanetStyle {
    /// The planet's object type number (RULES B.9.2).
    pub const fn object_type(self) -> TypeNumber {
        match self {
            PlanetStyle::A => PLANET_A,
            PlanetStyle::B => PLANET_B,
        }
    }
}

impl System {
    /// Works out every property from the state, in RULES A.3.4's order.
    pub fn new(index: u8, seed: Seed) -> Self {
        let b = seed.bytes();
        let x = b[3];
        let y = b[1];
        let government = (b[2] >> 3) & 7;
        let mut economy = b[1] & 7;
        if government < 2 {
            economy |= 2;
        }
        let tech_level = (economy ^ 7) + (b[3] & 3) + (government >> 1) + (government & 1);
        let population = 4 * tech_level + economy + government + 1;
        let productivity = (u16::from(economy ^ 7) + 3)
            * (u16::from(government) + 4)
            * u16::from(population)
            * 8;
        let radius = (u16::from(b[5] & 15) + 11) * 256 + u16::from(b[3]);
        Self {
            index,
            seed,
            x,
            y,
            economy,
            government,
            tech_level,
            population,
            productivity,
            radius,
            name: name(seed),
            inhabitants: inhabitants(seed),
        }
    }

    /// The system's galactic position `(x, y)`.
    pub const fn position(&self) -> Point {
        (self.x, self.y)
    }

    /// The tech level as shown, 1..15.
    pub const fn shown_tech_level(&self) -> u8 {
        self.tech_level + 1
    }

    /// True for the farm (agricultural) economies, 4..7.
    pub const fn is_farm(&self) -> bool {
        self.economy & 4 != 0
    }

    /// True when the inhabitants are the default settlers (bit 7 of `b4` clear).
    pub const fn has_default_settlers(&self) -> bool {
        self.seed.bytes()[4] & 0x80 == 0
    }

    /// The galaxy chart dot's width in pixels: 2 for default settlers, else 1 (RULES A.3.7).
    pub const fn chart_dot_width(&self) -> u8 {
        if self.has_default_settlers() {
            2
        } else {
            1
        }
    }

    /// The local chart disc's radius in pixels: `(b5 & 1) + 2` (RULES A.3.7).
    pub const fn local_disc_radius(&self) -> u8 {
        (self.seed.bytes()[5] & 1) + 2
    }

    /// The planet's look, from bit 1 of the tech level (RULES A.3.7, B.9.2).
    pub const fn planet_style(&self) -> PlanetStyle {
        if self.tech_level & 2 != 0 {
            PlanetStyle::B
        } else {
            PlanetStyle::A
        }
    }

    /// Where the planet is placed on arrival, in sim units (RULES A.3.7). `legal_low_bit` is
    /// the low bit of legal status before the arrival halves it.
    pub fn planet_position(&self, legal_low_bit: bool) -> Vec3 {
        let a = (self.seed.bytes()[1] & 7) + 6 + u8::from(legal_low_bit);
        let odd = a & 1 == 1;
        let a = a >> 1;
        let side = f64::from(a >> 1) * FAR;
        let side = if odd { -side } else { side };
        Vec3::new(side, side, f64::from(a) * FAR)
    }

    /// Where the sun is placed on arrival, in sim units (RULES A.3.7).
    pub fn sun_position(&self) -> Vec3 {
        let b = self.seed.bytes();
        let v = f64::from(b[5] & 3);
        let z = -(f64::from((b[3] & 7) | 1) * FAR);
        Vec3::new(v * FAR + v * COARSE, 0.0, z)
    }
}

#[cfg(test)]
mod tests {
    use super::super::galaxy::Galaxy;
    use super::*;

    #[test]
    fn starting_system_matches_the_gdd() {
        // GDD § 4.2: system 0 of Reach 1 at (60, 93), a wealthy farm world (economy 5) under a
        // free charter (government 5), tech level 6 as shown, population 3.1 billion, radius
        // 6,460 km, settled by the default settlers.
        let s = Galaxy::FIRST.system(0);
        assert_eq!(s.position(), (60, 93));
        assert_eq!((s.economy, s.government), (5, 5));
        assert_eq!((s.tech_level, s.shown_tech_level()), (5, 6));
        assert_eq!(s.population, 31);
        assert_eq!(s.radius, 6460);
        assert!(s.has_default_settlers());
        assert_eq!(s.inhabitants, "Settler families");
        assert!(s.is_farm());
        // ((5 ^ 7) + 3) × (5 + 4) × 31 × 8 = 5 × 9 × 31 × 8.
        assert_eq!(s.productivity, 11_160);
        assert_eq!(s.name, "PAMIFE");
    }

    #[test]
    fn properties_of_systems_1_and_2_by_hand() {
        // System 1, bytes F2 F2 38 A9 3F 44: G = (0x38 >> 3) & 7 = 7, E = 0xF2 & 7 = 2,
        // T = 5 + 1 + 3 + 1 = 10, P = 40 + 2 + 7 + 1 = 50, productivity 8 × 11 × 50 × 8,
        // radius (4 + 11) × 256 + 169.
        let s = Galaxy::FIRST.system(1);
        assert_eq!((s.x, s.y, s.government, s.economy), (169, 242, 7, 2));
        assert_eq!((s.tech_level, s.population, s.productivity, s.radius), (10, 50, 35_200, 4009));
        // System 2, bytes E0 CD 88 F2 D1 A0: G = 1, so E = (0xCD & 7) | 2 = 7.
        let s = Galaxy::FIRST.system(2);
        assert_eq!((s.x, s.y, s.government, s.economy), (242, 205, 1, 7));
        assert_eq!((s.tech_level, s.population, s.productivity, s.radius), (3, 21, 2520, 3058));
    }

    #[test]
    fn governments_0_and_1_force_bit_1_of_the_economy() {
        // b2 = 0x00 gives G = 0; b1 = 0x00 gives E = 0, forced to 2.
        let s = System::new(0, Seed([0x0000, 0x0000, 0x0000]));
        assert_eq!((s.government, s.economy), (0, 2));
        // b2 = 0x08 gives G = 1; b1 low bits 5 force to 7.
        let s = System::new(0, Seed([0x0500, 0x0008, 0x0000]));
        assert_eq!((s.government, s.economy), (1, 7));
        // G = 2 leaves E = 0 alone.
        let s = System::new(0, Seed([0x0000, 0x0010, 0x0000]));
        assert_eq!((s.government, s.economy), (2, 0));
    }

    #[test]
    fn property_ranges_hold_over_every_input() {
        // E (3 bits), G (3 bits) and b3 & 3 drive tech, population and productivity; b5 & 15
        // and b3 drive the radius.
        let (mut t_min, mut t_max, mut p_min, mut p_max, mut q_min, mut q_max) =
            (u8::MAX, 0, u8::MAX, 0, u16::MAX, 0);
        for g in 0..8u16 {
            for e in 0..8u16 {
                for low in 0..4u16 {
                    let seed = Seed([e << 8, (low << 8) | (g << 3), 0]);
                    let s = System::new(0, seed);
                    t_min = t_min.min(s.tech_level);
                    t_max = t_max.max(s.tech_level);
                    p_min = p_min.min(s.population);
                    p_max = p_max.max(s.population);
                    q_min = q_min.min(s.productivity);
                    q_max = q_max.max(s.productivity);
                }
            }
        }
        assert_eq!((t_min, t_max), (0, 14));
        assert_eq!((p_min, p_max), (8, 64));
        assert_eq!((q_min, q_max), (768, 56_320));
        assert_eq!(System::new(0, Seed([0, 0, 0])).radius, 2816);
        assert_eq!(System::new(0, Seed([0, 0xFF00, 0x0F00])).radius, 6911);
    }

    #[test]
    fn chart_marks_follow_b4_and_b5() {
        let g = Galaxy::FIRST;
        // System 0: b4 = 0x31 (bit 7 clear), b5 = 0x0E (bit 0 clear).
        assert_eq!((g.system(0).chart_dot_width(), g.system(0).local_disc_radius()), (2, 2));
        // System 2: b4 = 0xD1 (bit 7 set). System 5: b5 = 0xB7 (bit 0 set).
        assert_eq!(g.system(2).chart_dot_width(), 1);
        assert_eq!(g.system(5).local_disc_radius(), 3);
    }

    #[test]
    fn planet_style_follows_bit_1_of_the_tech_level() {
        let g = Galaxy::FIRST;
        assert_eq!(g.system(0).planet_style(), PlanetStyle::A); // T = 5 = 0b101
        assert_eq!(g.system(1).planet_style(), PlanetStyle::B); // T = 10 = 0b1010
        assert_eq!(g.system(2).planet_style().object_type(), PLANET_B); // T = 3
        assert_eq!(g.system(4).planet_style().object_type(), PLANET_A); // T = 8
    }

    #[test]
    fn arrival_places_planet_and_sun_from_the_bytes() {
        let s = Galaxy::FIRST.system(0);
        // b1 & 7 = 5. With c0 = 0: a = 11, odd, a = 5: z = 5 far, x = y = −2 far.
        assert_eq!(s.planet_position(false), Vec3::new(-2.0 * FAR, -2.0 * FAR, 5.0 * FAR));
        // With c0 = 1: a = 12, even, a = 6: z = 6 far, x = y = 3 far.
        assert_eq!(s.planet_position(true), Vec3::new(3.0 * FAR, 3.0 * FAR, 6.0 * FAR));
        // b3 = 60: (60 & 7) | 1 = 5; b5 & 3 = 2: x = 2 × 65536 + 2 × 256.
        assert_eq!(s.sun_position(), Vec3::new(131_584.0, 0.0, -327_680.0));
    }
}
